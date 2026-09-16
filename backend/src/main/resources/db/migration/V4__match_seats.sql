ALTER TABLE matches ADD COLUMN host_id UUID REFERENCES players (id);
ALTER TABLE matches ADD COLUMN joiner_id UUID REFERENCES players (id);
