-- Add AI linguistic analysis fields to words table
-- These store the LLM-generated morphological and pattern analysis

ALTER TABLE words
ADD COLUMN IF NOT EXISTS ai_morphology TEXT,
ADD COLUMN IF NOT EXISTS ai_patterns TEXT,
ADD COLUMN IF NOT EXISTS ai_notes TEXT;

-- Add comment explaining the fields
COMMENT ON COLUMN words.ai_morphology IS 'LLM-generated morphological analysis (e.g., "tau + -dia = people")';
COMMENT ON COLUMN words.ai_patterns IS 'LLM-generated collocation patterns (e.g., "follows case markers, precedes verbs")';
COMMENT ON COLUMN words.ai_notes IS 'LLM-generated linguistic notes and insights';
