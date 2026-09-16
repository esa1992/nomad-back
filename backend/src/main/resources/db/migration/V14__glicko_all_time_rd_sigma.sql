-- Separate all-time Glicko RD/σ so settles do not collapse all_time_rating onto season (WR-05).

ALTER TABLE glicko_ratings
    ADD COLUMN IF NOT EXISTS all_time_rd DOUBLE PRECISION NOT NULL DEFAULT 350,
    ADD COLUMN IF NOT EXISTS all_time_sigma DOUBLE PRECISION NOT NULL DEFAULT 0.06;
