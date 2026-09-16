package com.nomadgames.session.internal;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Connection-level Stick Pull tap flood gate (ASVS L1). Soft clamp is 10 TPS;
 * this cuts useless applyTap/DB/broadcast work above ~15 msg/s per seat.
 */
@Component
public class TapRateLimiter {

    private static final Duration WINDOW = Duration.ofSeconds(1);

    private final int limitPerSecond;
    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Long>> hits = new ConcurrentHashMap<>();

    public TapRateLimiter(@Value("${nomad.stick-pull.tap-limit-per-second:15}") int limitPerSecond) {
        this.limitPerSecond = Math.max(1, limitPerSecond);
        this.clock = Clock.systemUTC();
    }

    /** @return true if the tap may proceed; false = silent drop */
    public boolean tryAcquire(UUID matchId, UUID playerId) {
        String key = (matchId == null ? "unknown-match" : matchId.toString())
                + ":"
                + (playerId == null ? "unknown-player" : playerId.toString());
        long now = clock.millis();
        long cutoff = now - WINDOW.toMillis();
        Deque<Long> window = hits.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (window) {
            while (!window.isEmpty() && window.peekFirst() < cutoff) {
                window.removeFirst();
            }
            if (window.size() >= limitPerSecond) {
                return false;
            }
            window.addLast(now);
            return true;
        }
    }

    /** Clears all windows — used by ITs so flood cases do not poison later tests. */
    public void reset() {
        hits.clear();
    }
}
