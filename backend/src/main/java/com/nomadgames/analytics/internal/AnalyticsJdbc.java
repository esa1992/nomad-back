package com.nomadgames.analytics.internal;

import java.time.OffsetDateTime;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

@Component
public class AnalyticsJdbc {

    private final JdbcClient jdbc;

    public AnalyticsJdbc(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public void append(String eventType, UUID playerId, UUID matchId, String attrsJson, OffsetDateTime ts) {
        jdbc.sql(
                        """
                        INSERT INTO analytics_events (event_type, player_id, match_id, attrs, ts)
                        VALUES (:eventType, :playerId, :matchId, CAST(:attrs AS jsonb), :ts)
                        """)
                .param("eventType", eventType)
                .param("playerId", playerId)
                .param("matchId", matchId)
                .param("attrs", attrsJson == null ? "{}" : attrsJson)
                .param("ts", ts)
                .update();
    }
}
