-- Append-only analytics events (ANLT-01 / D-107). No public write API.

CREATE TABLE analytics_events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(64) NOT NULL,
    player_id UUID NULL,
    match_id UUID NULL,
    attrs JSONB NOT NULL DEFAULT '{}'::jsonb,
    ts TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_analytics_events_type_ts ON analytics_events (event_type, ts DESC);
CREATE INDEX idx_analytics_events_player_ts ON analytics_events (player_id, ts DESC);
