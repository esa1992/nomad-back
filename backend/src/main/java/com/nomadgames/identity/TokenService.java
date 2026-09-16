package com.nomadgames.identity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.identity.internal.PlayerEntity;
import com.nomadgames.identity.internal.PlayerRepository;
import com.nomadgames.identity.internal.RefreshTokenEntity;
import com.nomadgames.identity.internal.RefreshTokenRepository;

@Service
public class TokenService {

    private static final Duration ACCESS_TTL = Duration.ofMinutes(15);
    private static final Duration REFRESH_TTL = Duration.ofDays(30);
    private static final int REFRESH_BYTES = 32;

    private final RefreshTokenRepository refreshTokens;
    private final PlayerRepository players;
    private final JwtEncoder jwtEncoder;
    private final JwtDecoder jwtDecoder;
    private final SecureRandom random = new SecureRandom();

    public TokenService(
            RefreshTokenRepository refreshTokens,
            PlayerRepository players,
            @Value("${nomad.jwt.secret}") String secret) {
        byte[] secretBytes = secret.getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < 32) {
            throw new IllegalStateException("NOMAD_JWT_SECRET must be at least 32 bytes");
        }
        SecretKey key = new SecretKeySpec(secretBytes, "HmacSHA256");
        this.refreshTokens = refreshTokens;
        this.players = players;
        this.jwtEncoder = NimbusJwtEncoder.withSecretKey(key).algorithm(MacAlgorithm.HS256).build();
        this.jwtDecoder = NimbusJwtDecoder.withSecretKey(key).macAlgorithm(MacAlgorithm.HS256).build();
    }

    public JwtDecoder jwtDecoder() {
        return jwtDecoder;
    }

    @Transactional
    public TokenPair issue(UUID playerId, boolean guest) {
        String accessToken = encodeAccess(playerId, guest);
        String refreshToken = mintRefresh(playerId);
        return new TokenPair(accessToken, refreshToken, guest);
    }

    @Transactional
    public TokenPair rotate(String refreshToken) {
        byte[] hash = hashRefresh(refreshToken);
        RefreshTokenEntity existing = refreshTokens
                .findByTokenHash(hash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid refresh"));
        if (existing.getExpiresAt().isBefore(Instant.now())) {
            refreshTokens.delete(existing);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "expired refresh");
        }
        refreshTokens.delete(existing);
        refreshTokens.flush();
        PlayerEntity player = players
                .findById(existing.getPlayerId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid refresh"));
        return issue(player.getId(), player.isGuest());
    }

    @Transactional
    public void revokeAll(UUID playerId) {
        refreshTokens.deleteByPlayerId(playerId);
    }

    /**
     * Prove control of {@code guestPlayerId}: valid guest access JWT (sub match) or a live refresh
     * row for that player. Used by login adopt (CR-01 / ASVS L1).
     */
    public void requireGuestPossession(UUID guestPlayerId, String bearerAccess, String guestRefreshToken) {
        if (guestPlayerId == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "guest possession required");
        }
        if (bearerAccess != null && !bearerAccess.isBlank() && accessProvesGuest(guestPlayerId, bearerAccess)) {
            return;
        }
        if (guestRefreshToken != null
                && !guestRefreshToken.isBlank()
                && refreshProvesGuest(guestPlayerId, guestRefreshToken)) {
            return;
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "guest possession required");
    }

    private boolean accessProvesGuest(UUID guestPlayerId, String accessToken) {
        try {
            Jwt jwt = jwtDecoder.decode(accessToken);
            if (!guestPlayerId.toString().equals(jwt.getSubject())) {
                return false;
            }
            Boolean guestClaim = jwt.getClaim("guest");
            if (!Boolean.TRUE.equals(guestClaim)) {
                return false;
            }
            PlayerEntity player = players.findById(guestPlayerId).orElse(null);
            return player != null && player.isGuest();
        } catch (JwtException | IllegalArgumentException ex) {
            return false;
        }
    }

    private boolean refreshProvesGuest(UUID guestPlayerId, String refreshToken) {
        try {
            byte[] hash = hashRefresh(refreshToken);
            RefreshTokenEntity existing = refreshTokens.findByTokenHash(hash).orElse(null);
            if (existing == null || existing.getExpiresAt().isBefore(Instant.now())) {
                return false;
            }
            if (!guestPlayerId.equals(existing.getPlayerId())) {
                return false;
            }
            PlayerEntity player = players.findById(guestPlayerId).orElse(null);
            return player != null && player.isGuest();
        } catch (ResponseStatusException ex) {
            return false;
        }
    }

    private String encodeAccess(UUID playerId, boolean guest) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .subject(playerId.toString())
                .id(UUID.randomUUID().toString())
                .claim("guest", guest)
                .issuedAt(now)
                .expiresAt(now.plus(ACCESS_TTL))
                .build();
        return jwtEncoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
    }

    private String mintRefresh(UUID playerId) {
        byte[] raw = new byte[REFRESH_BYTES];
        random.nextBytes(raw);
        Instant now = Instant.now();
        refreshTokens.save(new RefreshTokenEntity(
                UUID.randomUUID(), playerId, sha256(raw), now.plus(REFRESH_TTL), now));
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
    }

    private static byte[] hashRefresh(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid refresh");
        }
        try {
            return sha256(Base64.getUrlDecoder().decode(refreshToken));
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid refresh");
        }
    }

    private static byte[] sha256(byte[] raw) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(raw);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 required", ex);
        }
    }
}
