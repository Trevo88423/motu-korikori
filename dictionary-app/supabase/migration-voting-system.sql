-- Migration: Voting and Comment System
-- Replaces notes with community comments and adds voting
-- Run this in Supabase SQL Editor

-- ============================================================================
-- STEP 1: Create Comments Table (replaces individual notes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  comment_text TEXT NOT NULL CHECK (char_length(comment_text) >= 20 AND char_length(comment_text) <= 500),
  is_flagged BOOLEAN DEFAULT false,
  flag_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  -- One comment per user per word
  UNIQUE(word_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_comments_word_id ON comments(word_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_flagged ON comments(is_flagged) WHERE is_flagged = true;

-- ============================================================================
-- STEP 2: Create Comment Votes Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS comment_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  vote_type INT NOT NULL CHECK (vote_type IN (-1, 1)), -- -1 = downvote, 1 = upvote
  created_at TIMESTAMPTZ DEFAULT now(),
  -- One vote per user per comment
  UNIQUE(comment_id, user_id)
);

-- Indexes
CREATE INDEX idx_comment_votes_comment_id ON comment_votes(comment_id);
CREATE INDEX idx_comment_votes_user_id ON comment_votes(user_id);

-- ============================================================================
-- STEP 3: Create Contribution Votes Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS contribution_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contribution_id UUID NOT NULL REFERENCES contributions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  -- One vote per user per contribution
  UNIQUE(contribution_id, user_id)
);

-- Indexes
CREATE INDEX idx_contribution_votes_contribution_id ON contribution_votes(contribution_id);
CREATE INDEX idx_contribution_votes_user_id ON contribution_votes(user_id);

-- ============================================================================
-- STEP 4: Add vote count columns to contributions (denormalized for performance)
-- ============================================================================

ALTER TABLE contributions
ADD COLUMN IF NOT EXISTS upvote_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS net_votes INT DEFAULT 0;

-- ============================================================================
-- STEP 5: Add vote count columns to comments (denormalized for performance)
-- ============================================================================

ALTER TABLE comments
ADD COLUMN IF NOT EXISTS upvote_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS downvote_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS net_votes INT DEFAULT 0;

-- ============================================================================
-- STEP 6: Migrate existing notes to comments
-- ============================================================================

-- Temporarily disable the check constraint for migration
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_comment_text_check;

-- Insert notes as comments (where notes exist and are valid length)
INSERT INTO comments (word_id, user_id, comment_text, created_at)
SELECT
  word_id,
  user_id,
  CASE
    WHEN char_length(notes) > 500 THEN substring(notes from 1 for 497) || '...'
    WHEN char_length(notes) < 20 THEN notes || ' (migrated from notes)'
    ELSE notes
  END as comment_text,
  created_at
FROM contributions
WHERE notes IS NOT NULL
  AND notes != ''
  AND char_length(trim(notes)) > 0
ON CONFLICT (word_id, user_id) DO NOTHING;

-- Re-add the check constraint (new comments must follow the rule)
ALTER TABLE comments ADD CONSTRAINT comments_comment_text_check
  CHECK (char_length(comment_text) >= 20 AND char_length(comment_text) <= 500);

-- ============================================================================
-- STEP 7: Update contributions table - remove old fields
-- ============================================================================

-- Note: We'll keep notes and confidence for now during transition
-- You can drop them later after confirming migration worked
-- ALTER TABLE contributions DROP COLUMN IF EXISTS notes;
-- ALTER TABLE contributions DROP COLUMN IF EXISTS confidence;

-- For now, just add a comment noting they're deprecated
COMMENT ON COLUMN contributions.notes IS 'DEPRECATED - migrated to comments table';
COMMENT ON COLUMN contributions.confidence IS 'DEPRECATED - use voting system instead';

-- ============================================================================
-- STEP 8: Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE contribution_votes ENABLE ROW LEVEL SECURITY;

-- Comments: Anyone can read
CREATE POLICY "Comments are viewable by everyone"
  ON comments FOR SELECT
  USING (true);

-- Comments: Users can insert their own
CREATE POLICY "Users can insert their own comments"
  ON comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Comments: Users can update their own (but will lose votes)
CREATE POLICY "Users can update their own comments"
  ON comments FOR UPDATE
  USING (auth.uid() = user_id);

-- Comments: Users can delete their own
CREATE POLICY "Users can delete their own comments"
  ON comments FOR DELETE
  USING (auth.uid() = user_id);

-- Comment Votes: Anyone can read
CREATE POLICY "Comment votes are viewable by everyone"
  ON comment_votes FOR SELECT
  USING (true);

-- Comment Votes: Users can vote (but not on their own comments)
CREATE POLICY "Users can vote on comments"
  ON comment_votes FOR INSERT
  WITH CHECK (
    auth.uid() = user_id AND
    auth.uid() != (SELECT user_id FROM comments WHERE id = comment_id)
  );

-- Comment Votes: Users can delete their own votes
CREATE POLICY "Users can delete their own comment votes"
  ON comment_votes FOR DELETE
  USING (auth.uid() = user_id);

-- Contribution Votes: Anyone can read
CREATE POLICY "Contribution votes are viewable by everyone"
  ON contribution_votes FOR SELECT
  USING (true);

-- Contribution Votes: Users can vote (but can't have own contribution)
CREATE POLICY "Users can vote on contributions"
  ON contribution_votes FOR INSERT
  WITH CHECK (
    auth.uid() = user_id AND
    auth.uid() != (SELECT user_id FROM contributions WHERE id = contribution_id)
  );

-- Contribution Votes: Users can delete their own votes
CREATE POLICY "Users can delete their own contribution votes"
  ON contribution_votes FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- STEP 9: Functions to update vote counts (triggers)
-- ============================================================================

-- Function to update comment vote counts
CREATE OR REPLACE FUNCTION update_comment_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE comments
    SET
      upvote_count = upvote_count + CASE WHEN NEW.vote_type = 1 THEN 1 ELSE 0 END,
      downvote_count = downvote_count + CASE WHEN NEW.vote_type = -1 THEN 1 ELSE 0 END,
      net_votes = net_votes + NEW.vote_type
    WHERE id = NEW.comment_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE comments
    SET
      upvote_count = upvote_count - CASE WHEN OLD.vote_type = 1 THEN 1 ELSE 0 END,
      downvote_count = downvote_count - CASE WHEN OLD.vote_type = -1 THEN 1 ELSE 0 END,
      net_votes = net_votes - OLD.vote_type
    WHERE id = OLD.comment_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for comment votes
DROP TRIGGER IF EXISTS comment_vote_counter ON comment_votes;
CREATE TRIGGER comment_vote_counter
  AFTER INSERT OR DELETE ON comment_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_vote_counts();

-- Function to update contribution vote counts
CREATE OR REPLACE FUNCTION update_contribution_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE contributions
    SET
      upvote_count = upvote_count + 1,
      net_votes = net_votes + 1
    WHERE id = NEW.contribution_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE contributions
    SET
      upvote_count = upvote_count - 1,
      net_votes = net_votes - 1
    WHERE id = OLD.contribution_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for contribution votes
DROP TRIGGER IF EXISTS contribution_vote_counter ON contribution_votes;
CREATE TRIGGER contribution_vote_counter
  AFTER INSERT OR DELETE ON contribution_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_contribution_vote_counts();

-- Function to reset comment votes when edited
CREATE OR REPLACE FUNCTION reset_comment_votes_on_edit()
RETURNS TRIGGER AS $$
BEGIN
  -- If comment text changed, reset votes
  IF OLD.comment_text != NEW.comment_text THEN
    -- Delete all votes for this comment
    DELETE FROM comment_votes WHERE comment_id = NEW.id;

    -- Reset counts (trigger will handle this, but set explicitly for clarity)
    NEW.upvote_count = 0;
    NEW.downvote_count = 0;
    NEW.net_votes = 0;
    NEW.updated_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to reset votes on edit
DROP TRIGGER IF EXISTS reset_votes_on_comment_edit ON comments;
CREATE TRIGGER reset_votes_on_comment_edit
  BEFORE UPDATE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION reset_comment_votes_on_edit();

-- Function to auto-hide flagged comments
CREATE OR REPLACE FUNCTION check_comment_flags()
RETURNS TRIGGER AS $$
BEGIN
  -- If flag_count >= 3, auto-hide
  IF NEW.flag_count >= 3 THEN
    NEW.is_flagged = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-hiding flagged comments
DROP TRIGGER IF EXISTS auto_hide_flagged_comments ON comments;
CREATE TRIGGER auto_hide_flagged_comments
  BEFORE UPDATE ON comments
  FOR EACH ROW
  WHEN (NEW.flag_count >= 3)
  EXECUTE FUNCTION check_comment_flags();

-- ============================================================================
-- STEP 10: Create helper views for easy querying
-- ============================================================================

-- View: Comments with vote counts and user info
CREATE OR REPLACE VIEW comments_with_votes AS
SELECT
  c.*,
  p.name as author_name,
  p.connection_type as author_type,
  p.trust_score as author_trust
FROM comments c
JOIN profiles p ON c.user_id = p.id
WHERE c.is_flagged = false;

-- View: Contributions with vote counts
CREATE OR REPLACE VIEW contributions_with_votes AS
SELECT
  c.*,
  p.name as author_name,
  p.connection_type as author_type,
  p.trust_score as author_trust,
  w.motu_word
FROM contributions c
JOIN profiles p ON c.user_id = p.id
JOIN words w ON c.word_id = w.id;

-- ============================================================================
-- STEP 11: Helper functions for actions
-- ============================================================================

-- Function to increment comment flag count
CREATE OR REPLACE FUNCTION increment_comment_flags(comment_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE comments
  SET flag_count = flag_count + 1
  WHERE id = comment_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update trust score when content gets voted
CREATE OR REPLACE FUNCTION update_author_trust_on_vote()
RETURNS TRIGGER AS $$
DECLARE
  author_id UUID;
  voter_trust FLOAT;
  voter_type TEXT;
  type_weight FLOAT;
  trust_multiplier FLOAT;
  vote_weight FLOAT;
  score_change FLOAT;
BEGIN
  -- Get voter's trust score and type
  SELECT trust_score, connection_type
  INTO voter_trust, voter_type
  FROM profiles
  WHERE id = NEW.user_id;

  -- Calculate vote weight
  type_weight := CASE voter_type
    WHEN 'native_speaker' THEN 2.0
    WHEN 'heritage_speaker' THEN 1.5
    WHEN 'second_language' THEN 1.0
    WHEN 'learning_now' THEN 0.5
    WHEN 'researcher' THEN 1.0
    ELSE 0.5
  END;

  trust_multiplier := CASE
    WHEN voter_trust >= 1.0 THEN 1.0
    WHEN voter_trust >= 0.5 THEN 0.75
    WHEN voter_trust >= 0.2 THEN 0.25
    ELSE 0.1
  END;

  vote_weight := type_weight * trust_multiplier;

  -- Get author_id based on table
  IF TG_TABLE_NAME = 'contribution_votes' THEN
    SELECT user_id INTO author_id
    FROM contributions
    WHERE id = NEW.contribution_id;

    score_change := 0.1 * vote_weight; -- Upvote only for contributions
  ELSIF TG_TABLE_NAME = 'comment_votes' THEN
    SELECT user_id INTO author_id
    FROM comments
    WHERE id = NEW.comment_id;

    -- For comments: upvote = +0.1, downvote = -0.2
    score_change := CASE
      WHEN NEW.vote_type = 1 THEN 0.1 * vote_weight
      ELSE -0.2 * vote_weight
    END;
  END IF;

  -- Update author's trust score
  IF author_id IS NOT NULL THEN
    UPDATE profiles
    SET trust_score = GREATEST(0.0, trust_score + score_change)
    WHERE id = author_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for trust score updates
DROP TRIGGER IF EXISTS update_trust_on_contribution_vote ON contribution_votes;
CREATE TRIGGER update_trust_on_contribution_vote
  AFTER INSERT ON contribution_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_author_trust_on_vote();

DROP TRIGGER IF EXISTS update_trust_on_comment_vote ON comment_votes;
CREATE TRIGGER update_trust_on_comment_vote
  AFTER INSERT ON comment_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_author_trust_on_vote();

-- Function to check if user can vote on contribution (no own translation)
CREATE OR REPLACE FUNCTION can_vote_on_contribution(p_contribution_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  word_uuid UUID;
  has_own_contribution BOOLEAN;
BEGIN
  -- Get word_id from contribution
  SELECT word_id INTO word_uuid
  FROM contributions
  WHERE id = p_contribution_id;

  -- Check if user has their own contribution for this word
  SELECT EXISTS(
    SELECT 1 FROM contributions
    WHERE word_id = word_uuid
    AND user_id = p_user_id
  ) INTO has_own_contribution;

  RETURN NOT has_own_contribution;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DONE! Migration Complete
-- ============================================================================

-- Verify the migration
SELECT 'Comments created:' as status, COUNT(*) as count FROM comments
UNION ALL
SELECT 'Comment votes created:', COUNT(*) FROM comment_votes
UNION ALL
SELECT 'Contribution votes created:', COUNT(*) FROM contribution_votes;
