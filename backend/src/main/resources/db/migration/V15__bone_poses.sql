ALTER TABLE matches
    ADD COLUMN bone_poses JSONB NOT NULL DEFAULT '[]'::jsonb;
