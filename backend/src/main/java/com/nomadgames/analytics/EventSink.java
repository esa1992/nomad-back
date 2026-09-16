package com.nomadgames.analytics;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.nomadgames.analytics.internal.AnalyticsJdbc;

import tools.jackson.databind.ObjectMapper;

/**
 * Thin ANLT-01 sink: structured JSON log + append-only analytics_events (D-107).
 * Never rethrows into caller TX (T-07-26).
 */
@Service
public class EventSink {

    private static final Logger log = LoggerFactory.getLogger(EventSink.class);

    private final AnalyticsJdbc jdbc;
    private final ObjectMapper mapper;

    public EventSink(AnalyticsJdbc jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    /**
     * Fire-and-forget emit. playerId is UUID only — never passwords or tokens in attrs.
     */
    public void emit(String type, UUID playerId, UUID matchId, Map<String, ?> attrs) {
        try {
            Instant ts = Instant.now();
            Map<String, Object> scrubbed = scrub(attrs);
            String attrsJson = mapper.writeValueAsString(scrubbed);
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("type", type);
            payload.put("playerId", playerId == null ? null : playerId.toString());
            payload.put("matchId", matchId == null ? null : matchId.toString());
            payload.put("attrs", scrubbed);
            payload.put("ts", ts.toString());
            log.info("analytics_event {}", mapper.writeValueAsString(payload));
            jdbc.append(type, playerId, matchId, attrsJson, OffsetDateTime.ofInstant(ts, ZoneOffset.UTC));
        } catch (Throwable t) {
            log.error("EventSink emit failed type={} playerId={} matchId={}", type, playerId, matchId, t);
        }
    }

    private static Map<String, Object> scrub(Map<String, ?> attrs) {
        if (attrs == null || attrs.isEmpty()) {
            return Map.of();
        }
        Map<String, Object> out = new LinkedHashMap<>();
        for (Map.Entry<String, ?> e : attrs.entrySet()) {
            String key = e.getKey();
            if (key == null) {
                continue;
            }
            String lower = key.toLowerCase();
            if (lower.contains("password") || lower.contains("token") || lower.contains("secret")) {
                continue;
            }
            out.put(key, e.getValue());
        }
        return out;
    }
}
