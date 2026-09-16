-- Ranked Glicko-2 per game + season (MODE-04 / D-104). SoftElo columns untouched.

CREATE TABLE glicko_ratings (
    player_id UUID NOT NULL REFERENCES players (id),
    game VARCHAR(32) NOT NULL,
    season_key VARCHAR(16) NOT NULL,
    rating DOUBLE PRECISION NOT NULL DEFAULT 1500,
    rd DOUBLE PRECISION NOT NULL DEFAULT 350,
    sigma DOUBLE PRECISION NOT NULL DEFAULT 0.06,
    matches INT NOT NULL DEFAULT 0,
    all_time_rating DOUBLE PRECISION NOT NULL DEFAULT 1500,
    all_time_peak DOUBLE PRECISION NOT NULL DEFAULT 1500,
    all_time_matches INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (player_id, game, season_key)
);

CREATE INDEX idx_glicko_season_rating ON glicko_ratings (game, season_key, rating DESC);
CREATE INDEX idx_glicko_all_time_peak ON glicko_ratings (game, all_time_peak DESC);

CREATE TABLE glicko_settlements (
    match_id UUID NOT NULL,
    player_id UUID NOT NULL REFERENCES players (id),
    PRIMARY KEY (match_id, player_id)
);
