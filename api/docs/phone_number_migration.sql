-- Adds a phone column for storing the user's contact number.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone VARCHAR(32);

-- Optionally normalize placeholder values that should be treated as NULL.
UPDATE users
SET phone = NULL
WHERE phone IS NOT NULL AND TRIM(phone) IN ('', 'null', 'undefined');
