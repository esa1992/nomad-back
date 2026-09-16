package com.nomadgames.matchmaking.internal;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class JoinRateLimiter {

    private static final Duration WINDOW = Duration.ofMinutes(1);

    private final int limitPerMinute;
    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Long>> hits = new ConcurrentHashMap<>();

    public JoinRateLimiter(@Value("${nomad.rooms.join-limit-per-minute:20}") int limitPerMinute) {
        this.limitPerMinute = limitPerMinute;
        this.clock = Clock.systemUTC();
    }

    public void check(String ip, UUID playerId) {
        String ipKey = (ip == null || ip.isBlank()) ? "unknown" : ip;
        checkKey(ipKey);
        checkKey(playerId == null ? "unknown-player" : playerId.toString());
    }

    /** Clears all windows — used by ITs so flood cases do not poison later tests. */
    public void reset() {
        hits.clear();
    }

    private void checkKey(String key) {
        long now = clock.millis();
        long cutoff = now - WINDOW.toMillis();
        Deque<Long> window = hits.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (window) {
            while (!window.isEmpty() && window.peekFirst() < cutoff) {
                window.removeFirst();
            }
            if (window.size() >= limitPerMinute) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "join rate limit");
            }
            window.addLast(now);
        }
    }
}
