package com.nomadgames.identity.internal;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/** Per-IP login attempt window (T-07-09 credential stuffing). */
@Component
public class LoginRateLimiter {

    private static final Duration WINDOW = Duration.ofMinutes(1);

    private final int limitPerMinute;
    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Long>> hits = new ConcurrentHashMap<>();

    public LoginRateLimiter(@Value("${nomad.identity.login-limit-per-minute:20}") int limitPerMinute) {
        this.limitPerMinute = limitPerMinute;
        this.clock = Clock.systemUTC();
    }

    public void check(String ip) {
        String key = (ip == null || ip.isBlank()) ? "unknown" : ip;
        long now = clock.millis();
        long cutoff = now - WINDOW.toMillis();
        Deque<Long> window = hits.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (window) {
            while (!window.isEmpty() && window.peekFirst() < cutoff) {
                window.removeFirst();
            }
            if (window.size() >= limitPerMinute) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "login rate limit");
            }
            window.addLast(now);
        }
    }
}
