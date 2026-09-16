package com.nomadgames.session.internal;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.session.WsTicketResponse;

@Service
public class WsTicketService {

    static final Duration TTL = Duration.ofSeconds(60);
    private static final int TICKET_BYTES = 32;

    private final SecureRandom random = new SecureRandom();
    private final ConcurrentHashMap<String, Issued> tickets = new ConcurrentHashMap<>();

    public WsTicketResponse issue(UUID playerId, UUID matchId) {
        byte[] raw = new byte[TICKET_BYTES];
        random.nextBytes(raw);
        Instant expiresAt = Instant.now().plus(TTL);
        tickets.put(hashKey(raw), new Issued(playerId, matchId, expiresAt));
        String ticket = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        return new WsTicketResponse(ticket, expiresAt);
    }

    public Bound consume(String ticket, UUID matchId) {
        if (ticket == null || ticket.isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "missing ticket");
        }
        byte[] raw;
        try {
            raw = Base64.getUrlDecoder().decode(ticket);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid ticket");
        }
        Issued issued = tickets.remove(hashKey(raw));
        if (issued == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid ticket");
        }
        if (issued.expiresAt().isBefore(Instant.now())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "expired ticket");
        }
        if (!issued.matchId().equals(matchId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "wrong match");
        }
        return new Bound(issued.playerId(), issued.matchId());
    }

    private static String hashKey(byte[] raw) {
        return HexFormat.of().formatHex(sha256(raw));
    }

    private static byte[] sha256(byte[] raw) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(raw);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 required", ex);
        }
    }

    record Issued(UUID playerId, UUID matchId, Instant expiresAt) {}

    public record Bound(UUID playerId, UUID matchId) {}
}
