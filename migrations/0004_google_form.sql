-- Google Form responses: each one remembers which form response it came from, so sending the
-- same response twice (e.g. "Send all responses" after the live link is set up) never duplicates it.
-- Runs automatically once.
ALTER TABLE enquiries ADD COLUMN external_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_enquiries_external ON enquiries(external_id);
