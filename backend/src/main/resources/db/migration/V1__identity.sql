CREATE TABLE players (
    id UUID PRIMARY KEY,
    guest BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players (id),
    token_hash BYTEA NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE credentials (
    player_id UUID PRIMARY KEY REFERENCES players (id)
);
