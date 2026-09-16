CREATE TABLE matches (
    id UUID PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players (id),
    game VARCHAR(32) NOT NULL,
    mode VARCHAR(32) NOT NULL,
    difficulty VARCHAR(16) NOT NULL,
    status VARCHAR(32) NOT NULL,
    player_score INT NOT NULL,
    bot_score INT NOT NULL,
    player_turns INT NOT NULL,
    bot_turns INT NOT NULL,
    bones_left JSONB NOT NULL,
    turn VARCHAR(16) NOT NULL,
    turn_deadline TIMESTAMPTZ NOT NULL,
    match_deadline TIMESTAMPTZ NOT NULL,
    hard_cap TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
