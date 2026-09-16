-- AUTH-02 / D-94: username + Argon2id password hash for bound credentials
ALTER TABLE credentials
    ADD COLUMN username VARCHAR(20),
    ADD COLUMN password_hash TEXT,
    ADD COLUMN created_at TIMESTAMPTZ;

-- Case-insensitive uniqueness (ASVS V5 / D-93)
CREATE UNIQUE INDEX credentials_username_ci_uidx ON credentials (LOWER(username))
    WHERE username IS NOT NULL;
