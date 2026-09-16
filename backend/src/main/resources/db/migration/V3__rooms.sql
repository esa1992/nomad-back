CREATE TABLE rooms (
    id UUID PRIMARY KEY,
    code VARCHAR(6) NOT NULL UNIQUE,
    host_id UUID NOT NULL REFERENCES players (id),
    joiner_id UUID NULL REFERENCES players (id),
    host_ready BOOLEAN NOT NULL DEFAULT FALSE,
    joiner_ready BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(32) NOT NULL,
    match_id UUID NULL,
    idle_expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
