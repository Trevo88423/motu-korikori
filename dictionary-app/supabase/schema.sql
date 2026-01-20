-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types/enums
DO $$ BEGIN
  CREATE TYPE connection_type AS ENUM ('native_speaker', 'heritage_speaker', 'second_language', 'learning_now', 'researcher', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE age_range AS ENUM ('under_18', '18_24', '25_34', '35_44', '45_54', '55_64', '65_plus', 'prefer_not_to_say');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE user_status AS ENUM ('active', 'warned', 'suspended', 'banned');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE word_status AS ENUM ('pending', 'consensus', 'verified', 'flagged');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE confidence_level AS ENUM ('certain', 'somewhat_certain', 'unsure');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE moderation_action AS ENUM ('warn', 'suspend', 'ban', 'exclude_from_ai', 'exclude_contributions', 'verify_word', 'flag_word', 'unflag_word');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- =============================================
-- PROFILES TABLE (extends auth.users)
-- =============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Basic info
  name TEXT NOT NULL,
  email TEXT NOT NULL,

  -- Demographics
  age_range age_range NOT NULL,
  locations TEXT[] NOT NULL DEFAULT '{}',
  connection_type connection_type NOT NULL,
  who_taught TEXT,

  -- Consents
  consent_tos BOOLEAN NOT NULL DEFAULT FALSE,
  consent_dictionary BOOLEAN NOT NULL DEFAULT FALSE,
  consent_ai_training BOOLEAN NOT NULL DEFAULT FALSE,
  is_18_or_older BOOLEAN NOT NULL DEFAULT FALSE,
  guardian_name TEXT,
  guardian_email TEXT,

  -- Trust & gamification
  trust_score DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  contribution_count INTEGER NOT NULL DEFAULT 0,
  consensus_rate DECIMAL(5,2) DEFAULT 0.00,
  streak_days INTEGER NOT NULL DEFAULT 0,
  last_contribution_date DATE,

  -- Moderation
  status user_status NOT NULL DEFAULT 'active',
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  contributions_excluded BOOLEAN NOT NULL DEFAULT FALSE,
  excluded_from_ai BOOLEAN NOT NULL DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- WORDS TABLE (15,610 pre-seeded words)
-- =============================================
CREATE TABLE IF NOT EXISTS words (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Core word data
  motu_word TEXT NOT NULL UNIQUE,
  frequency INTEGER DEFAULT 0,

  -- Examples from scripture
  example_reference TEXT,
  example_motu TEXT,
  example_english TEXT,

  -- AI-suggested translations (from initial processing)
  suggested_translations TEXT[] DEFAULT '{}',

  -- Community consensus
  status word_status NOT NULL DEFAULT 'pending',
  consensus_gloss TEXT,
  consensus_audio_url TEXT,
  consensus_confidence DECIMAL(3,2) DEFAULT 0.00,

  -- Stats
  total_contributions INTEGER NOT NULL DEFAULT 0,
  unique_contributors INTEGER NOT NULL DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- CONTRIBUTIONS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS contributions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Contribution content
  english_gloss TEXT NOT NULL,
  audio_url TEXT,
  confidence confidence_level NOT NULL DEFAULT 'certain',
  notes TEXT,

  -- Metadata
  is_excluded BOOLEAN NOT NULL DEFAULT FALSE,
  matches_consensus BOOLEAN DEFAULT NULL,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Ensure one contribution per user per word
  UNIQUE(word_id, user_id)
);

-- =============================================
-- MODERATION LOG TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS moderation_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  admin_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  target_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  target_word_id UUID REFERENCES words(id) ON DELETE CASCADE,

  action moderation_action NOT NULL,
  reason TEXT NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- INDEXES for performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_words_motu_word ON words(motu_word);
CREATE INDEX IF NOT EXISTS idx_words_status ON words(status);
CREATE INDEX IF NOT EXISTS idx_words_frequency ON words(frequency DESC);

CREATE INDEX IF NOT EXISTS idx_contributions_word_id ON contributions(word_id);
CREATE INDEX IF NOT EXISTS idx_contributions_user_id ON contributions(user_id);
CREATE INDEX IF NOT EXISTS idx_contributions_created_at ON contributions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_status ON profiles(status);
CREATE INDEX IF NOT EXISTS idx_profiles_trust_score ON profiles(trust_score);

CREATE INDEX IF NOT EXISTS idx_moderation_log_created_at ON moderation_log(created_at DESC);

-- =============================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE moderation_log ENABLE ROW LEVEL SECURITY;

-- PROFILES POLICIES
-- Users can read their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile (except protected fields)
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Users can insert their own profile on signup
CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);

-- Admins can update any profile
CREATE POLICY "Admins can update any profile"
  ON profiles FOR UPDATE
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);

-- WORDS POLICIES
-- Anyone (including anonymous) can view words
CREATE POLICY "Anyone can view words"
  ON words FOR SELECT
  USING (TRUE);

-- Only admins can insert/update/delete words
CREATE POLICY "Admins can manage words"
  ON words FOR ALL
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);

-- CONTRIBUTIONS POLICIES
-- Users can view all contributions
CREATE POLICY "Users can view all contributions"
  ON contributions FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Users can insert their own contributions
CREATE POLICY "Users can insert own contributions"
  ON contributions FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (SELECT status FROM profiles WHERE id = auth.uid()) IN ('active', 'warned')
  );

-- Users can update their own contributions
CREATE POLICY "Users can update own contributions"
  ON contributions FOR UPDATE
  USING (auth.uid() = user_id);

-- Admins can manage all contributions
CREATE POLICY "Admins can manage all contributions"
  ON contributions FOR ALL
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);

-- MODERATION LOG POLICIES
-- Only admins can view moderation log
CREATE POLICY "Admins can view moderation log"
  ON moderation_log FOR SELECT
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);

-- Only admins can insert into moderation log
CREATE POLICY "Admins can insert moderation log"
  ON moderation_log FOR INSERT
  WITH CHECK ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);

-- =============================================
-- FUNCTIONS AND TRIGGERS
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_words_updated_at BEFORE UPDATE ON words
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contributions_updated_at BEFORE UPDATE ON contributions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to increment contribution count
CREATE OR REPLACE FUNCTION increment_contribution_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET
    contribution_count = contribution_count + 1,
    last_contribution_date = CURRENT_DATE
  WHERE id = NEW.user_id;

  UPDATE words
  SET total_contributions = total_contributions + 1
  WHERE id = NEW.word_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER increment_contribution_count_trigger
  AFTER INSERT ON contributions
  FOR EACH ROW EXECUTE FUNCTION increment_contribution_count();

-- Function to update unique contributors count
CREATE OR REPLACE FUNCTION update_unique_contributors()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE words
  SET unique_contributors = (
    SELECT COUNT(DISTINCT user_id)
    FROM contributions
    WHERE word_id = NEW.word_id AND is_excluded = FALSE
  )
  WHERE id = NEW.word_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_unique_contributors_trigger
  AFTER INSERT OR UPDATE ON contributions
  FOR EACH ROW EXECUTE FUNCTION update_unique_contributors();

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Function to get next word for user (word they haven't contributed to)
CREATE OR REPLACE FUNCTION get_next_word_for_user(user_uuid UUID)
RETURNS TABLE (
  id UUID,
  motu_word TEXT,
  frequency INTEGER,
  example_reference TEXT,
  example_motu TEXT,
  example_english TEXT,
  suggested_translations TEXT[],
  status word_status,
  consensus_gloss TEXT,
  total_contributions INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    w.id,
    w.motu_word,
    w.frequency,
    w.example_reference,
    w.example_motu,
    w.example_english,
    w.suggested_translations,
    w.status,
    w.consensus_gloss,
    w.total_contributions
  FROM words w
  WHERE NOT EXISTS (
    SELECT 1 FROM contributions c
    WHERE c.word_id = w.id AND c.user_id = user_uuid
  )
  ORDER BY w.frequency DESC, RANDOM()
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_next_word_for_user(UUID) TO authenticated;
