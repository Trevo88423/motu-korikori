SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;
COMMENT ON SCHEMA "public" IS 'standard public schema';
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE TYPE "public"."age_range" AS ENUM (
    'under_18',
    '18_24',
    '25_34',
    '35_44',
    '45_54',
    '55_64',
    '65_plus',
    'prefer_not_to_say'
);
ALTER TYPE "public"."age_range" OWNER TO "postgres";
CREATE TYPE "public"."confidence_level" AS ENUM (
    'certain',
    'somewhat_certain',
    'unsure'
);
ALTER TYPE "public"."confidence_level" OWNER TO "postgres";
CREATE TYPE "public"."connection_type" AS ENUM (
    'native_speaker',
    'heritage_speaker',
    'second_language',
    'learning_now',
    'researcher',
    'other'
);
ALTER TYPE "public"."connection_type" OWNER TO "postgres";
CREATE TYPE "public"."moderation_action" AS ENUM (
    'warn',
    'suspend',
    'ban',
    'exclude_from_ai',
    'exclude_contributions',
    'verify_word',
    'flag_word',
    'unflag_word'
);
ALTER TYPE "public"."moderation_action" OWNER TO "postgres";
CREATE TYPE "public"."user_status" AS ENUM (
    'active',
    'warned',
    'suspended',
    'banned'
);
ALTER TYPE "public"."user_status" OWNER TO "postgres";
CREATE TYPE "public"."word_status" AS ENUM (
    'pending',
    'consensus',
    'verified',
    'flagged'
);
ALTER TYPE "public"."word_status" OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."can_vote_on_contribution"("p_contribution_id" "uuid", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."can_vote_on_contribution"("p_contribution_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."check_comment_flags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  -- If flag_count >= 3, auto-hide
  IF NEW.flag_count >= 3 THEN
    NEW.is_flagged = true;
  END IF;
  RETURN NEW;
END;
$$;
ALTER FUNCTION "public"."check_comment_flags"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."get_next_word_for_user"("user_uuid" "uuid") RETURNS TABLE("id" "uuid", "motu_word" "text", "frequency" integer, "example_reference" "text", "example_motu" "text", "example_english" "text", "suggested_translations" "text"[], "status" "public"."word_status", "consensus_gloss" "text", "total_contributions" integer)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
    -- Exclude words user has already contributed to
    SELECT 1 FROM contributions c
    WHERE c.word_id = w.id AND c.user_id = user_uuid
  )
  AND NOT EXISTS (
    -- Exclude words user has marked as complete
    SELECT 1 FROM user_word_completion uwc
    WHERE uwc.word_id = w.id AND uwc.user_id = user_uuid
  )
  ORDER BY (w.frequency * RANDOM()) DESC
  LIMIT 1;
END;
$$;
ALTER FUNCTION "public"."get_next_word_for_user"("user_uuid" "uuid") OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."increment_comment_flags"("comment_uuid" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE comments
  SET flag_count = flag_count + 1
  WHERE id = comment_uuid;
END;
$$;
ALTER FUNCTION "public"."increment_comment_flags"("comment_uuid" "uuid") OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."increment_contribution_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."increment_contribution_count"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."reset_comment_votes_on_edit"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."reset_comment_votes_on_edit"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_author_trust_on_vote"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."update_author_trust_on_vote"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_comment_vote_counts"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."update_comment_vote_counts"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_contribution_count_on_comment"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  -- When a comment is added or deleted, recalculate total contribution count
  -- Count = unique words with contributions + unique words with comments
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    UPDATE profiles
    SET contribution_count = (
      SELECT COUNT(DISTINCT word_id) FROM (
        SELECT word_id FROM contributions WHERE user_id = NEW.user_id
        UNION
        SELECT word_id FROM comments WHERE user_id = NEW.user_id
      ) AS all_contributions
    )
    WHERE id = NEW.user_id;

    RETURN NEW;
  END IF;

  IF (TG_OP = 'DELETE') THEN
    UPDATE profiles
    SET contribution_count = (
      SELECT COUNT(DISTINCT word_id) FROM (
        SELECT word_id FROM contributions WHERE user_id = OLD.user_id
        UNION
        SELECT word_id FROM comments WHERE user_id = OLD.user_id
      ) AS all_contributions
    )
    WHERE id = OLD.user_id;

    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;
ALTER FUNCTION "public"."update_contribution_count_on_comment"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_contribution_vote_counts"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."update_contribution_vote_counts"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_profile_contribution_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  -- When a contribution is inserted or updated
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    -- Count unique words contributed (including agreements)
    UPDATE profiles
    SET contribution_count = (
      SELECT COUNT(DISTINCT word_id)
      FROM contributions
      WHERE user_id = NEW.user_id
    )
    WHERE id = NEW.user_id;

    RETURN NEW;
  END IF;

  -- When a contribution is deleted
  IF (TG_OP = 'DELETE') THEN
    UPDATE profiles
    SET contribution_count = (
      SELECT COUNT(DISTINCT word_id)
      FROM contributions
      WHERE user_id = OLD.user_id
    )
    WHERE id = OLD.user_id;

    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;
ALTER FUNCTION "public"."update_profile_contribution_count"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_unique_contributors"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;
ALTER FUNCTION "public"."update_unique_contributors"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;
ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."update_word_contribution_counts"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment counts for new contribution
    UPDATE words
    SET
      total_contributions = total_contributions + 1,
      unique_contributors = (
        SELECT COUNT(DISTINCT user_id)
        FROM contributions
        WHERE word_id = NEW.word_id AND is_excluded = false
      )
    WHERE id = NEW.word_id;

  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement counts for deleted contribution
    UPDATE words
    SET
      total_contributions = GREATEST(0, total_contributions - 1),
      unique_contributors = (
        SELECT COUNT(DISTINCT user_id)
        FROM contributions
        WHERE word_id = OLD.word_id AND is_excluded = false
      )
    WHERE id = OLD.word_id;

  ELSIF TG_OP = 'UPDATE' THEN
    -- If is_excluded changed, recalculate
    IF OLD.is_excluded != NEW.is_excluded THEN
      UPDATE words
      SET
        total_contributions = (
          SELECT COUNT(*)
          FROM contributions
          WHERE word_id = NEW.word_id AND is_excluded = false
        ),
        unique_contributors = (
          SELECT COUNT(DISTINCT user_id)
          FROM contributions
          WHERE word_id = NEW.word_id AND is_excluded = false
        )
      WHERE id = NEW.word_id;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;
ALTER FUNCTION "public"."update_word_contribution_counts"() OWNER TO "postgres";
SET default_tablespace = '';
SET default_table_access_method = "heap";
CREATE TABLE IF NOT EXISTS "public"."comment_votes" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "comment_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "vote_type" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "comment_votes_vote_type_check" CHECK (("vote_type" = ANY (ARRAY['-1'::integer, 1])))
);
ALTER TABLE "public"."comment_votes" OWNER TO "postgres";
CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "word_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "comment_text" "text" NOT NULL,
    "is_flagged" boolean DEFAULT false,
    "flag_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "upvote_count" integer DEFAULT 0,
    "downvote_count" integer DEFAULT 0,
    "net_votes" integer DEFAULT 0,
    CONSTRAINT "comments_comment_text_check" CHECK ((("char_length"("comment_text") >= 20) AND ("char_length"("comment_text") <= 500)))
);
ALTER TABLE "public"."comments" OWNER TO "postgres";
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "age_range" "public"."age_range" NOT NULL,
    "locations" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "connection_type" "public"."connection_type" NOT NULL,
    "who_taught" "text",
    "consent_tos" boolean DEFAULT false NOT NULL,
    "consent_dictionary" boolean DEFAULT false NOT NULL,
    "consent_ai_training" boolean DEFAULT false NOT NULL,
    "is_18_or_older" boolean DEFAULT false NOT NULL,
    "guardian_name" "text",
    "guardian_email" "text",
    "trust_score" numeric(3,2) DEFAULT 1.00 NOT NULL,
    "contribution_count" integer DEFAULT 0 NOT NULL,
    "consensus_rate" numeric(5,2) DEFAULT 0.00,
    "streak_days" integer DEFAULT 0 NOT NULL,
    "last_contribution_date" "date",
    "status" "public"."user_status" DEFAULT 'active'::"public"."user_status" NOT NULL,
    "is_admin" boolean DEFAULT false NOT NULL,
    "contributions_excluded" boolean DEFAULT false NOT NULL,
    "excluded_from_ai" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "guardian_consent" boolean DEFAULT false
);
ALTER TABLE "public"."profiles" OWNER TO "postgres";
CREATE OR REPLACE VIEW "public"."comments_with_votes" WITH ("security_invoker"='true') AS
 SELECT "c"."id",
    "c"."word_id",
    "c"."user_id",
    "c"."comment_text",
    "c"."is_flagged",
    "c"."flag_count",
    "c"."created_at",
    "c"."updated_at",
    "c"."upvote_count",
    "c"."downvote_count",
    "c"."net_votes",
    "p"."name" AS "author_name",
    "p"."connection_type" AS "author_type",
    "p"."trust_score" AS "author_trust"
   FROM ("public"."comments" "c"
     JOIN "public"."profiles" "p" ON (("c"."user_id" = "p"."id")))
  WHERE ("c"."is_flagged" = false);
ALTER VIEW "public"."comments_with_votes" OWNER TO "postgres";
CREATE TABLE IF NOT EXISTS "public"."contribution_votes" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "contribution_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);
ALTER TABLE "public"."contribution_votes" OWNER TO "postgres";
CREATE TABLE IF NOT EXISTS "public"."contributions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "word_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "english_gloss" "text" NOT NULL,
    "audio_url" "text",
    "confidence" "public"."confidence_level" DEFAULT 'certain'::"public"."confidence_level" NOT NULL,
    "notes" "text",
    "is_excluded" boolean DEFAULT false NOT NULL,
    "matches_consensus" boolean,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "upvote_count" integer DEFAULT 0,
    "net_votes" integer DEFAULT 0,
    "agreement_type" "text" DEFAULT 'full'::"text",
    CONSTRAINT "contributions_agreement_type_check" CHECK (("agreement_type" = ANY (ARRAY['full'::"text", 'agree'::"text"])))
);
ALTER TABLE "public"."contributions" OWNER TO "postgres";
COMMENT ON COLUMN "public"."contributions"."confidence" IS 'DEPRECATED - use voting system instead';
COMMENT ON COLUMN "public"."contributions"."notes" IS 'DEPRECATED - migrated to comments table';
CREATE TABLE IF NOT EXISTS "public"."words" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "motu_word" "text" NOT NULL,
    "frequency" integer DEFAULT 0,
    "example_reference" "text",
    "example_motu" "text",
    "example_english" "text",
    "suggested_translations" "text"[] DEFAULT '{}'::"text"[],
    "status" "public"."word_status" DEFAULT 'pending'::"public"."word_status" NOT NULL,
    "consensus_gloss" "text",
    "consensus_audio_url" "text",
    "consensus_confidence" numeric(3,2) DEFAULT 0.00,
    "total_contributions" integer DEFAULT 0 NOT NULL,
    "unique_contributors" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ai_morphology" "text",
    "ai_patterns" "text",
    "ai_notes" "text"
);
ALTER TABLE "public"."words" OWNER TO "postgres";
CREATE OR REPLACE VIEW "public"."contributions_with_votes" WITH ("security_invoker"='true') AS
 SELECT "c"."id",
    "c"."word_id",
    "c"."user_id",
    "c"."english_gloss",
    "c"."audio_url",
    "c"."confidence",
    "c"."notes",
    "c"."is_excluded",
    "c"."matches_consensus",
    "c"."created_at",
    "c"."updated_at",
    "c"."upvote_count",
    "c"."net_votes",
    "p"."name" AS "author_name",
    "p"."connection_type" AS "author_type",
    "p"."trust_score" AS "author_trust",
    "w"."motu_word"
   FROM (("public"."contributions" "c"
     JOIN "public"."profiles" "p" ON (("c"."user_id" = "p"."id")))
     JOIN "public"."words" "w" ON (("c"."word_id" = "w"."id")));
ALTER VIEW "public"."contributions_with_votes" OWNER TO "postgres";
CREATE TABLE IF NOT EXISTS "public"."moderation_log" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "admin_id" "uuid" NOT NULL,
    "target_user_id" "uuid",
    "target_word_id" "uuid",
    "action" "public"."moderation_action" NOT NULL,
    "reason" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);
ALTER TABLE "public"."moderation_log" OWNER TO "postgres";
CREATE TABLE IF NOT EXISTS "public"."user_word_completion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "word_id" "uuid" NOT NULL,
    "completed_at" timestamp with time zone DEFAULT "now"()
);
ALTER TABLE "public"."user_word_completion" OWNER TO "postgres";
ALTER TABLE ONLY "public"."comment_votes"
    ADD CONSTRAINT "comment_votes_comment_id_user_id_key" UNIQUE ("comment_id", "user_id");
ALTER TABLE ONLY "public"."comment_votes"
    ADD CONSTRAINT "comment_votes_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_word_id_user_id_key" UNIQUE ("word_id", "user_id");
ALTER TABLE ONLY "public"."contribution_votes"
    ADD CONSTRAINT "contribution_votes_contribution_id_user_id_key" UNIQUE ("contribution_id", "user_id");
ALTER TABLE ONLY "public"."contribution_votes"
    ADD CONSTRAINT "contribution_votes_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."contributions"
    ADD CONSTRAINT "contributions_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."contributions"
    ADD CONSTRAINT "contributions_word_id_user_id_key" UNIQUE ("word_id", "user_id");
ALTER TABLE ONLY "public"."moderation_log"
    ADD CONSTRAINT "moderation_log_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."user_word_completion"
    ADD CONSTRAINT "user_word_completion_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."user_word_completion"
    ADD CONSTRAINT "user_word_completion_user_id_word_id_key" UNIQUE ("user_id", "word_id");
ALTER TABLE ONLY "public"."words"
    ADD CONSTRAINT "words_motu_word_key" UNIQUE ("motu_word");
ALTER TABLE ONLY "public"."words"
    ADD CONSTRAINT "words_pkey" PRIMARY KEY ("id");
CREATE INDEX "idx_comment_votes_comment_id" ON "public"."comment_votes" USING "btree" ("comment_id");
CREATE INDEX "idx_comment_votes_user_id" ON "public"."comment_votes" USING "btree" ("user_id");
CREATE INDEX "idx_comments_flagged" ON "public"."comments" USING "btree" ("is_flagged") WHERE ("is_flagged" = true);
CREATE INDEX "idx_comments_user_id" ON "public"."comments" USING "btree" ("user_id");
CREATE INDEX "idx_comments_word_id" ON "public"."comments" USING "btree" ("word_id");
CREATE INDEX "idx_contribution_votes_contribution_id" ON "public"."contribution_votes" USING "btree" ("contribution_id");
CREATE INDEX "idx_contribution_votes_user_id" ON "public"."contribution_votes" USING "btree" ("user_id");
CREATE INDEX "idx_contributions_created_at" ON "public"."contributions" USING "btree" ("created_at" DESC);
CREATE INDEX "idx_contributions_user_id" ON "public"."contributions" USING "btree" ("user_id");
CREATE INDEX "idx_contributions_word_id" ON "public"."contributions" USING "btree" ("word_id");
CREATE INDEX "idx_moderation_log_created_at" ON "public"."moderation_log" USING "btree" ("created_at" DESC);
CREATE INDEX "idx_profiles_status" ON "public"."profiles" USING "btree" ("status");
CREATE INDEX "idx_profiles_trust_score" ON "public"."profiles" USING "btree" ("trust_score");
CREATE INDEX "idx_user_word_completion_user" ON "public"."user_word_completion" USING "btree" ("user_id");
CREATE INDEX "idx_user_word_completion_word" ON "public"."user_word_completion" USING "btree" ("word_id");
CREATE INDEX "idx_words_frequency" ON "public"."words" USING "btree" ("frequency" DESC);
CREATE INDEX "idx_words_motu_word" ON "public"."words" USING "btree" ("motu_word");
CREATE INDEX "idx_words_status" ON "public"."words" USING "btree" ("status");
CREATE OR REPLACE TRIGGER "auto_hide_flagged_comments" BEFORE UPDATE ON "public"."comments" FOR EACH ROW WHEN (("new"."flag_count" >= 3)) EXECUTE FUNCTION "public"."check_comment_flags"();
CREATE OR REPLACE TRIGGER "comment_vote_counter" AFTER INSERT OR DELETE ON "public"."comment_votes" FOR EACH ROW EXECUTE FUNCTION "public"."update_comment_vote_counts"();
CREATE OR REPLACE TRIGGER "contribution_vote_counter" AFTER INSERT OR DELETE ON "public"."contribution_votes" FOR EACH ROW EXECUTE FUNCTION "public"."update_contribution_vote_counts"();
CREATE OR REPLACE TRIGGER "increment_contribution_count_trigger" AFTER INSERT ON "public"."contributions" FOR EACH ROW EXECUTE FUNCTION "public"."increment_contribution_count"();
CREATE OR REPLACE TRIGGER "reset_votes_on_comment_edit" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."reset_comment_votes_on_edit"();
CREATE OR REPLACE TRIGGER "update_contribution_count_on_comment" AFTER INSERT OR DELETE OR UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."update_contribution_count_on_comment"();
CREATE OR REPLACE TRIGGER "update_contribution_count_on_delete" AFTER DELETE ON "public"."contributions" FOR EACH ROW EXECUTE FUNCTION "public"."update_profile_contribution_count"();
CREATE OR REPLACE TRIGGER "update_contribution_count_on_insert" AFTER INSERT OR UPDATE ON "public"."contributions" FOR EACH ROW EXECUTE FUNCTION "public"."update_profile_contribution_count"();
CREATE OR REPLACE TRIGGER "update_contributions_updated_at" BEFORE UPDATE ON "public"."contributions" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();
CREATE OR REPLACE TRIGGER "update_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();
CREATE OR REPLACE TRIGGER "update_trust_on_comment_vote" AFTER INSERT ON "public"."comment_votes" FOR EACH ROW EXECUTE FUNCTION "public"."update_author_trust_on_vote"();
CREATE OR REPLACE TRIGGER "update_trust_on_contribution_vote" AFTER INSERT ON "public"."contribution_votes" FOR EACH ROW EXECUTE FUNCTION "public"."update_author_trust_on_vote"();
CREATE OR REPLACE TRIGGER "update_unique_contributors_trigger" AFTER INSERT OR UPDATE ON "public"."contributions" FOR EACH ROW EXECUTE FUNCTION "public"."update_unique_contributors"();
CREATE OR REPLACE TRIGGER "update_word_counts_on_contribution" AFTER INSERT OR DELETE OR UPDATE ON "public"."contributions" FOR EACH ROW EXECUTE FUNCTION "public"."update_word_contribution_counts"();
CREATE OR REPLACE TRIGGER "update_words_updated_at" BEFORE UPDATE ON "public"."words" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();
ALTER TABLE ONLY "public"."comment_votes"
    ADD CONSTRAINT "comment_votes_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."comment_votes"
    ADD CONSTRAINT "comment_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "public"."words"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."contribution_votes"
    ADD CONSTRAINT "contribution_votes_contribution_id_fkey" FOREIGN KEY ("contribution_id") REFERENCES "public"."contributions"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."contribution_votes"
    ADD CONSTRAINT "contribution_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."contributions"
    ADD CONSTRAINT "contributions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."contributions"
    ADD CONSTRAINT "contributions_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "public"."words"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."moderation_log"
    ADD CONSTRAINT "moderation_log_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."moderation_log"
    ADD CONSTRAINT "moderation_log_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."moderation_log"
    ADD CONSTRAINT "moderation_log_target_word_id_fkey" FOREIGN KEY ("target_word_id") REFERENCES "public"."words"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."user_word_completion"
    ADD CONSTRAINT "user_word_completion_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."user_word_completion"
    ADD CONSTRAINT "user_word_completion_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "public"."words"("id") ON DELETE CASCADE;
CREATE POLICY "Admins can insert moderation log" ON "public"."moderation_log" FOR INSERT WITH CHECK ((( SELECT "profiles"."is_admin"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = true));
CREATE POLICY "Admins can manage all contributions" ON "public"."contributions" USING ((( SELECT "profiles"."is_admin"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = true));
CREATE POLICY "Admins can manage words" ON "public"."words" USING ((( SELECT "profiles"."is_admin"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())
 LIMIT 1) = true));
CREATE POLICY "Admins can update any profile" ON "public"."profiles" FOR UPDATE USING ((("auth"."uid"() = "id") OR ("is_admin" = true)));
CREATE POLICY "Admins can view all profiles" ON "public"."profiles" FOR SELECT USING ((("auth"."uid"() = "id") OR ("is_admin" = true)));
CREATE POLICY "Admins can view moderation log" ON "public"."moderation_log" FOR SELECT USING ((( SELECT "profiles"."is_admin"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = true));
CREATE POLICY "Anyone can view profiles for leaderboard" ON "public"."profiles" FOR SELECT USING (true);
CREATE POLICY "Anyone can view words" ON "public"."words" FOR SELECT USING (true);
CREATE POLICY "Comment votes are viewable by everyone" ON "public"."comment_votes" FOR SELECT USING (true);
CREATE POLICY "Comments are viewable by everyone" ON "public"."comments" FOR SELECT USING (true);
CREATE POLICY "Contribution votes are viewable by everyone" ON "public"."contribution_votes" FOR SELECT USING (true);
CREATE POLICY "Users can delete own completions" ON "public"."user_word_completion" FOR DELETE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can delete own contributions" ON "public"."contributions" FOR DELETE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can delete their own comment votes" ON "public"."comment_votes" FOR DELETE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can delete their own comments" ON "public"."comments" FOR DELETE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can delete their own contribution votes" ON "public"."contribution_votes" FOR DELETE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can insert own completions" ON "public"."user_word_completion" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can insert own contributions" ON "public"."contributions" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND (( SELECT "profiles"."status"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = ANY (ARRAY['active'::"public"."user_status", 'warned'::"public"."user_status"]))));
CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));
CREATE POLICY "Users can insert their own comments" ON "public"."comments" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can update own contributions" ON "public"."contributions" FOR UPDATE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));
CREATE POLICY "Users can update their own comments" ON "public"."comments" FOR UPDATE USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can view all contributions" ON "public"."contributions" FOR SELECT USING (("auth"."uid"() IS NOT NULL));
CREATE POLICY "Users can view own completions" ON "public"."user_word_completion" FOR SELECT USING (("auth"."uid"() = "user_id"));
CREATE POLICY "Users can view own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));
CREATE POLICY "Users can vote on comments" ON "public"."comment_votes" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND ("auth"."uid"() <> ( SELECT "comments"."user_id"
   FROM "public"."comments"
  WHERE ("comments"."id" = "comment_votes"."comment_id")))));
CREATE POLICY "Users can vote on contributions" ON "public"."contribution_votes" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND ("auth"."uid"() <> ( SELECT "contributions"."user_id"
   FROM "public"."contributions"
  WHERE ("contributions"."id" = "contribution_votes"."contribution_id")))));
ALTER TABLE "public"."comment_votes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."contribution_votes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."contributions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."moderation_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_word_completion" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."words" ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT ALL ON FUNCTION "public"."can_vote_on_contribution"("p_contribution_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_vote_on_contribution"("p_contribution_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_vote_on_contribution"("p_contribution_id" "uuid", "p_user_id" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."check_comment_flags"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_comment_flags"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_comment_flags"() TO "service_role";
GRANT ALL ON FUNCTION "public"."get_next_word_for_user"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_next_word_for_user"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_next_word_for_user"("user_uuid" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."increment_comment_flags"("comment_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_comment_flags"("comment_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_comment_flags"("comment_uuid" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."increment_contribution_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_contribution_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_contribution_count"() TO "service_role";
GRANT ALL ON FUNCTION "public"."reset_comment_votes_on_edit"() TO "anon";
GRANT ALL ON FUNCTION "public"."reset_comment_votes_on_edit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_comment_votes_on_edit"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_author_trust_on_vote"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_author_trust_on_vote"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_author_trust_on_vote"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_comment_vote_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_comment_vote_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_comment_vote_counts"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_contribution_count_on_comment"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_contribution_count_on_comment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_contribution_count_on_comment"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_contribution_vote_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_contribution_vote_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_contribution_vote_counts"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_profile_contribution_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_profile_contribution_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_profile_contribution_count"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_unique_contributors"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_unique_contributors"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_unique_contributors"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";
GRANT ALL ON FUNCTION "public"."update_word_contribution_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_word_contribution_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_word_contribution_counts"() TO "service_role";
GRANT ALL ON TABLE "public"."comment_votes" TO "anon";
GRANT ALL ON TABLE "public"."comment_votes" TO "authenticated";
GRANT ALL ON TABLE "public"."comment_votes" TO "service_role";
GRANT ALL ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";
GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";
GRANT ALL ON TABLE "public"."comments_with_votes" TO "anon";
GRANT ALL ON TABLE "public"."comments_with_votes" TO "authenticated";
GRANT ALL ON TABLE "public"."comments_with_votes" TO "service_role";
GRANT ALL ON TABLE "public"."contribution_votes" TO "anon";
GRANT ALL ON TABLE "public"."contribution_votes" TO "authenticated";
GRANT ALL ON TABLE "public"."contribution_votes" TO "service_role";
GRANT ALL ON TABLE "public"."contributions" TO "anon";
GRANT ALL ON TABLE "public"."contributions" TO "authenticated";
GRANT ALL ON TABLE "public"."contributions" TO "service_role";
GRANT ALL ON TABLE "public"."words" TO "anon";
GRANT ALL ON TABLE "public"."words" TO "authenticated";
GRANT ALL ON TABLE "public"."words" TO "service_role";
GRANT ALL ON TABLE "public"."contributions_with_votes" TO "anon";
GRANT ALL ON TABLE "public"."contributions_with_votes" TO "authenticated";
GRANT ALL ON TABLE "public"."contributions_with_votes" TO "service_role";
GRANT ALL ON TABLE "public"."moderation_log" TO "anon";
GRANT ALL ON TABLE "public"."moderation_log" TO "authenticated";
GRANT ALL ON TABLE "public"."moderation_log" TO "service_role";
GRANT ALL ON TABLE "public"."user_word_completion" TO "anon";
GRANT ALL ON TABLE "public"."user_word_completion" TO "authenticated";
GRANT ALL ON TABLE "public"."user_word_completion" TO "service_role";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
