package com.nomadgames.identity;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.http.HttpStatus;
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
public class BindService {

    private static final Pattern USERNAME = Pattern.compile("^[A-Za-z0-9_]{3,20}$");
    private static final int MAX_PASSWORD_LENGTH = 128;

    private final PlayerRepository players;
    private final CredentialRepository credentials;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final EventSink events;

    public BindService(
            PlayerRepository players,
            CredentialRepository credentials,
            PasswordEncoder passwordEncoder,
            TokenService tokens,
            EventSink events) {
        this.players = players;
        this.credentials = credentials;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.events = events;
    }

    /**
     * Bind username+password to the same guest playerId (AUTH-02 / D-93). Never merges wallets.
     */
    @Transactional
    public GuestSessionResponse bind(UUID playerId, String username, String password) {
        if (password == null || password.length() < 8 || password.length() > MAX_PASSWORD_LENGTH) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "password");
        }
        if (username == null || !USERNAME.matcher(username).matches()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "username");
        }

        PlayerEntity player = players
                .findById(playerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "player"));
        if (!player.isGuest() || credentials.existsById(playerId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "already_bound");
        }
        if (credentials.existsByUsernameIgnoreCase(username)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "username_taken");
        }

        String hash = passwordEncoder.encode(password);
        credentials.save(new CredentialEntity(playerId, username, hash, Instant.now()));
        player.setGuest(false);

        TokenPair pair = tokens.issue(playerId, false);
        events.emit("REGISTERED", playerId, null, Map.of());
        return new GuestSessionResponse(playerId, pair.accessToken(), pair.refreshToken(), false);
    }
}
