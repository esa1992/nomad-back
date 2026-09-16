package com.nomadgames.session.internal;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

import com.nomadgames.session.MatchStatus;

/**
 * Reconnect grace + Ranked pause budgets (SESS-02/03/04, D-41, D-86, D-101…D-103).
 * Casual Alchiki 30s / Stick Pull 8s; Ranked Alchiki 18s / Stick Pull 12s.
 * Ranked pause budgets Alchiki 45s / Stick Pull 20s; non-Ranked unlimited.
 */
public final class ReconnectPolicy {

    public static final int GRACE_SECONDS = 30;
    public static final int STICK_PULL_GRACE_SECONDS = 8;
    public static final int RANKED_ALCHIKI_GRACE_SECONDS = 18;
    public static final int RANKED_STICK_PULL_GRACE_SECONDS = 12;
    public static final int RANKED_ALCHIKI_PAUSE_BUDGET_SECONDS = 45;
    public static final int RANKED_STICK_PULL_PAUSE_BUDGET_SECONDS = 20;
    public static final Duration GRACE = Duration.ofSeconds(GRACE_SECONDS);
    static final int TOKEN_BYTES = 32;

    private static final SecureRandom RANDOM = new SecureRandom();

    private ReconnectPolicy() {}

    /** Game-aware grace (Casual / Private): STICK_PULL → 8s, else Alchiki/default 30s (D-86). */
    public static int graceSeconds(String game) {
        return graceSeconds(null, game);
    }

    /** Mode+game grace: RANKED Stick 12 / Alchiki 18; else Casual 8 / 30 (D-101). */
    public static int graceSeconds(String mode, String game) {
        boolean ranked = "RANKED".equals(mode);
        if ("STICK_PULL".equals(game)) {
            return ranked ? RANKED_STICK_PULL_GRACE_SECONDS : STICK_PULL_GRACE_SECONDS;
        }
        return ranked ? RANKED_ALCHIKI_GRACE_SECONDS : GRACE_SECONDS;
    }

    /**
     * Aggregate pause budget for Ranked (D-102). Non-Ranked returns {@link Integer#MAX_VALUE}
     * so budget forfeit never fires.
     */
    public static int pauseBudgetSeconds(String mode, String game) {
        if (!"RANKED".equals(mode)) {
            return Integer.MAX_VALUE;
        }
        return "STICK_PULL".equals(game)
                ? RANKED_STICK_PULL_PAUSE_BUDGET_SECONDS
                : RANKED_ALCHIKI_PAUSE_BUDGET_SECONDS;
    }

    public static String mintToken() {
        byte[] raw = new byte[TOKEN_BYTES];
        RANDOM.nextBytes(raw);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
    }

    public static byte[] hashToken(String token) {
        if (token == null || token.isBlank()) {
            return new byte[0];
        }
        try {
            return sha256(Base64.getUrlDecoder().decode(token));
        } catch (IllegalArgumentException ex) {
            return new byte[0];
        }
    }

    public static boolean tokenMatches(byte[] storedHash, String token) {
        if (storedHash == null || storedHash.length == 0) {
            return false;
        }
        byte[] incoming = hashToken(token);
        if (incoming.length != storedHash.length) {
            return false;
        }
        return MessageDigest.isEqual(storedHash, incoming);
    }

    /** @deprecated Prefer {@link #graceDeadline(Instant, String, String)} with mode+game. */
    public static Instant graceDeadline(Instant now) {
        return graceDeadline(now, null, null);
    }

    /** @deprecated Prefer {@link #graceDeadline(Instant, String, String)} with mode. */
    public static Instant graceDeadline(Instant now, String game) {
        return graceDeadline(now, null, game);
    }

    public static Instant graceDeadline(Instant now, String mode, String game) {
        return now.plusSeconds(graceSeconds(mode, game));
    }

    public static FrozenClocks freeze(Instant now, Instant turnDeadline, Instant matchDeadline, Instant hardCap) {
        return new FrozenClocks(remaining(now, turnDeadline), remaining(now, matchDeadline), remaining(now, hardCap));
    }

    public static void applyFreeze(MatchEntity match, FrozenClocks frozen, Instant now) {
        match.setTurnDeadline(now.plus(frozen.turn()));
        match.setMatchDeadline(now.plus(frozen.match()));
        match.setHardCap(now.plus(frozen.hardCap()));
    }

    public static String remainingWinStatus(boolean droppedHost) {
        return droppedHost ? MatchStatus.JOINER_WIN.name() : MatchStatus.HOST_WIN.name();
    }

    private static Duration remaining(Instant now, Instant deadline) {
        Duration left = Duration.between(now, deadline);
        return left.isNegative() ? Duration.ZERO : left;
    }

    private static byte[] sha256(byte[] raw) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(raw);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 required", ex);
        }
    }

    public record FrozenClocks(Duration turn, Duration match, Duration hardCap) {}
}
