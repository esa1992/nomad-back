package com.nomadgames.identity;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.nomadgames.economy.EconomyService;
import com.nomadgames.identity.internal.PlayerEntity;
import com.nomadgames.identity.internal.PlayerRepository;
import com.nomadgames.profile.ProfileService;

@Service
public class GuestService {

    private final PlayerRepository players;
    private final TokenService tokens;
    private final EconomyService economy;
    private final ProfileService profile;

    public GuestService(
            PlayerRepository players, TokenService tokens, EconomyService economy, ProfileService profile) {
        this.players = players;
        this.tokens = tokens;
        this.economy = economy;
        this.profile = profile;
    }

    @Transactional
    public GuestSessionResponse createGuest() {
        UUID playerId = UUID.randomUUID();
        players.save(new PlayerEntity(playerId, true, Instant.now()));
        // Flush so JdbcClient wallet inserts see the player FK in this TX (D-53).
        players.flush();
        economy.ensureDefaults(playerId);
        profile.ensureDefaults(playerId);
        TokenPair pair = tokens.issue(playerId, true);
        return new GuestSessionResponse(playerId, pair.accessToken(), pair.refreshToken(), true);
    }
}
