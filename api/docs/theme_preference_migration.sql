-- Adds persistent theme preference storage for each user.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS theme_preference VARCHAR(16) DEFAULT 'light';

-- Ensure existing records are populated.
UPDATE users
SET theme_preference = COALESCE(theme_preference, 'light');

-- Match the application expectation that the column is non-null with a default.
ALTER TABLE users
    ALTER COLUMN theme_preference SET DEFAULT 'light',
    ALTER COLUMN theme_preference SET NOT NULL;
