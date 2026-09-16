package com.nomadgames.identity;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.analytics.EventSink;
import com.nomadgames.identity.internal.CredentialEntity;
import com.nomadgames.identity.internal.CredentialRepository;
import com.nomadgames.identity.internal.PlayerEntity;
import com.nomadgames.identity.internal.PlayerRepository;

@Service
public class AuthService {

    private static final int MAX_PASSWORD_LENGTH = 128;

    private final CredentialRepository credentials;
    private final PlayerRepository players;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final GuestService guests;
    private final JdbcClient jdbc;
    private final EventSink events;

    public AuthService(
            CredentialRepository credentials,
            PlayerRepository players,
            PasswordEncoder passwordEncoder,
            TokenService tokens,
            GuestService guests,
            JdbcClient jdbc,
            EventSink events) {
        this.credentials = credentials;
        this.players = players;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.guests = guests;
        this.jdbc = jdbc;
        this.events = events;
    }

    /**
     * Bound sign-in with D-93 adopt contract (AUTH-03). Never sums wallets onto a non-empty target.
     * When {@code guestPlayerId} is present, caller must prove guest session possession (CR-01).
     */
    @Transactional
    public GuestSessionResponse login(
            String username,
            String password,
            UUID guestPlayerId,
            String adoptRaw,
            String guestAccessToken,
            String guestRefreshToken) {
        if (username == null || username.isBlank() || password == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "bad credentials");
        }
        if (password.length() > MAX_PASSWORD_LENGTH) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "password");
        }
        CredentialEntity cred = credentials
                .findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "bad credentials"));
        if (!passwordEncoder.matches(password, cred.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "bad credentials");
        }

        UUID boundId = cred.getPlayerId();
        AdoptMode adopt = parseAdopt(adoptRaw);

        AdoptHint hint = null;
        if (guestPlayerId != null) {
            tokens.requireGuestPossession(guestPlayerId, guestAccessToken, guestRefreshToken);
            requireGuestPlayer(guestPlayerId);
            if (guestPlayerId.equals(boundId)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "guest_is_bound");
            }
            boolean eligible = isImportEligible(boundId);
            switch (adopt) {
                case NONE -> hint = eligible ? AdoptHint.IMPORT_ELIGIBLE : AdoptHint.DROP_REQUIRED;
                case IMPORT -> {
                    if (!eligible) {
                        throw new ResponseStatusException(HttpStatus.CONFLICT, "import_not_eligible");
                    }
                    copyGuestProgressOntoBound(guestPlayerId, boundId);
                    abandonGuestEconomy(guestPlayerId);
                    tokens.revokeAll(guestPlayerId);
                }
                case DROP -> tokens.revokeAll(guestPlayerId);
            }
        } else if (adopt == AdoptMode.IMPORT || adopt == AdoptMode.DROP) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "guestPlayerId required");
        }

        TokenPair pair = tokens.issue(boundId, false);
        events.emit("LOGIN", boundId, null, Map.of());
        return new GuestSessionResponse(boundId, pair.accessToken(), pair.refreshToken(), false, hint);
    }

    /**
     * Revoke bound refresh rows and mint a fresh guest session (AUTH-04 / BindIT logoutMintsGuest).
     */
    @Transactional
    public GuestSessionResponse logout(UUID playerId) {
        tokens.revokeAll(playerId);
        return guests.createGuest();
    }

    private void requireGuestPlayer(UUID guestPlayerId) {
        PlayerEntity guest = players
                .findById(guestPlayerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "unknown_guest"));
        if (!guest.isGuest()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "not_a_guest");
        }
    }

    /** Empty-target import: matches==0 AND ledger/soft spend==0 (D-93). */
    private boolean isImportEligible(UUID boundId) {
        Integer matches = jdbc.sql(
                        """
                        SELECT COALESCE(SUM(matches), 0)
                        FROM player_game_stats
                        WHERE player_id = :playerId
                        """)
                .param("playerId", boundId)
                .query(Integer.class)
                .optional()
                .orElse(0);
        Boolean spent = jdbc.sql(
                        """
                        SELECT EXISTS (
                            SELECT 1 FROM wallet_ledger
                            WHERE player_id = :playerId AND delta < 0
                        )
                        OR EXISTS (
                            SELECT 1 FROM soft_purchases
                            WHERE player_id = :playerId
                        )
                        """)
                .param("playerId", boundId)
                .query(Boolean.class)
                .single();
        return matches != null && matches == 0 && Boolean.FALSE.equals(spent);
    }

    /** One-time overwrite of wallets + cosmetics from guest onto empty bound — never sum. */
    private void copyGuestProgressOntoBound(UUID guestId, UUID boundId) {
        List<WalletRow> guestWallets = jdbc.sql(
                        """
                        SELECT currency, balance FROM wallets
                        WHERE player_id = :playerId
                        """)
                .param("playerId", guestId)
                .query((rs, rowNum) -> new WalletRow(rs.getString("currency"), rs.getLong("balance")))
                .list();
        for (WalletRow row : guestWallets) {
            jdbc.sql(
                            """
                            INSERT INTO wallets (player_id, currency, balance)
                            VALUES (:playerId, :currency, :balance)
                            ON CONFLICT (player_id, currency) DO UPDATE SET balance = EXCLUDED.balance
                            """)
                    .param("playerId", boundId)
                    .param("currency", row.currency())
                    .param("balance", row.balance())
                    .update();
        }

        OffsetDateTime now = OffsetDateTime.now();
        List<InventoryRow> inventory = jdbc.sql(
                        """
                        SELECT sku_id FROM inventory WHERE player_id = :playerId
                        """)
                .param("playerId", guestId)
                .query((rs, rowNum) -> new InventoryRow(rs.getString("sku_id")))
                .list();
        for (InventoryRow row : inventory) {
            jdbc.sql(
                            """
                            INSERT INTO inventory (player_id, sku_id, acquired_at)
                            VALUES (:playerId, :skuId, :acquiredAt)
                            ON CONFLICT (player_id, sku_id) DO NOTHING
                            """)
                    .param("playerId", boundId)
                    .param("skuId", row.skuId())
                    .param("acquiredAt", now)
                    .update();
        }

        List<LoadoutRow> loadout = jdbc.sql(
                        """
                        SELECT slot, sku_id FROM loadout WHERE player_id = :playerId
                        """)
                .param("playerId", guestId)
                .query((rs, rowNum) -> new LoadoutRow(rs.getString("slot"), rs.getString("sku_id")))
                .list();
        for (LoadoutRow row : loadout) {
            jdbc.sql(
                            """
                            INSERT INTO loadout (player_id, slot, sku_id)
                            VALUES (:playerId, :slot, :skuId)
                            ON CONFLICT (player_id, slot) DO UPDATE SET sku_id = EXCLUDED.sku_id
                            """)
                    .param("playerId", boundId)
                    .param("slot", row.slot())
                    .param("skuId", row.skuId())
                    .update();
        }
    }

    /**
     * After adopt=import copy: zero guest wallets and clear inventory/loadout in the same TX
     * so dual-spend cannot continue on the abandoned guest device row (WR-01 / D-93).
     */
    private void abandonGuestEconomy(UUID guestId) {
        jdbc.sql(
                        """
                        UPDATE wallets SET balance = 0 WHERE player_id = :playerId
                        """)
                .param("playerId", guestId)
                .update();
        jdbc.sql("DELETE FROM inventory WHERE player_id = :playerId")
                .param("playerId", guestId)
                .update();
        jdbc.sql("DELETE FROM loadout WHERE player_id = :playerId")
                .param("playerId", guestId)
                .update();
    }

    private static AdoptMode parseAdopt(String adoptRaw) {
        if (adoptRaw == null || adoptRaw.isBlank()) {
            return AdoptMode.NONE;
        }
        try {
            return AdoptMode.valueOf(adoptRaw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "adopt");
        }
    }

    private enum AdoptMode {
        NONE,
        IMPORT,
        DROP
    }

    private record WalletRow(String currency, long balance) {}

    private record InventoryRow(String skuId) {}

    private record LoadoutRow(String slot, String skuId) {}
}
