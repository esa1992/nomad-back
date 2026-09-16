-- Guest profile: avatar presets, XP/level, soft casual MMR, per-game stats (PROF-01…03 / D-75…D-77)

ALTER TABLE players ADD COLUMN avatar_preset VARCHAR(32) NOT NULL DEFAULT 'avatar_01';
ALTER TABLE players ADD COLUMN xp INT NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN level INT NOT NULL DEFAULT 1;
ALTER TABLE players ADD COLUMN soft_rating INT NOT NULL DEFAULT 1000;
ALTER TABLE players ADD COLUMN best_rating INT NOT NULL DEFAULT 1000;

CREATE TABLE player_game_stats (
    player_id UUID NOT NULL REFERENCES players (id),
    game VARCHAR(32) NOT NULL,
    matches INT NOT NULL DEFAULT 0,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    draws INT NOT NULL DEFAULT 0,
    PRIMARY KEY (player_id, game)
);

CREATE TABLE profile_settlements (
    match_id UUID NOT NULL,
    player_id UUID NOT NULL REFERENCES players (id),
    PRIMARY KEY (match_id, player_id)
);
