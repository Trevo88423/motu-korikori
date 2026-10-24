-- =============================================================================
-- 20261024174154 — Bad-language filter enforced in the database (#54, part of #51)
--
-- A list of blocked terms, matched as whole words after normalising case,
-- diacritics, leetspeak and repeated letters. BEFORE triggers refuse a member's
-- free text that contains one, so the PostgREST API can't bypass it the way it
-- could bypass a check in the app. The app maps the error (SQLSTATE TMBLK) to
-- a fixed, polite message.
--
-- Checked: contributions.english_gloss and notes, comments.comment_text, and
-- profiles.display_name (shown publicly on the leaderboard). Signup never
-- fails over a display name: a blocked one becomes 'Member' instead.
-- who_taught, locations and guardian fields are never shown to other people,
-- so they aren't checked.
--
-- Safe with the current app code and data: only a value that is inserted or
-- actually changed is checked, so existing rows, and updates to other columns
-- (consensus flags, vote counts, exclusions), are never refused. The current
-- app shows a generic "Failed to save" for a refusal until the new code
-- deploys from the same push.
--
-- Logging attempts: the statement that raises rolls back, and a log row
-- written in that transaction would roll back with it. Supabase has no
-- autonomous transactions (pg_background isn't available, and dblink would
-- need stored credentials), so the app logs instead: on catching TMBLK, the
-- server action calls log_blocked_language_attempt(), which re-checks the text
-- itself, so it can't be used to log fake attempts against anyone, and stores
-- who, where and when, never the text. Attempts sent straight to the REST API
-- are still refused, but aren't logged.
-- =============================================================================

-- --- Normalising -------------------------------------------------------------
-- Lower case, diacritics stripped (ḡ -> g, ā -> a), and every run of
-- non-letters collapsed to one space, padded with a space at each end so a
-- term can be matched as whole words with ' term '. With leet = true, tokens
-- that contain a letter also have 0 1 3 4 5 @ $ read as o i e a s a s (and a
-- ! inside a word as i), so 'sh1t', '$h!t' and '$hit' are read as letters but
-- a plain number like '455', or a ! ending a sentence, isn't.
CREATE OR REPLACE FUNCTION public.normalize_filter_text(t text, leet boolean DEFAULT true)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$
  SELECT ' ' || btrim(regexp_replace(
    coalesce(
      (SELECT string_agg(
                CASE WHEN leet AND tok ~ '[a-z]'
                     THEN translate(regexp_replace(tok, '!+(?=[a-z0-9])', 'i', 'g'), '01345@$', 'oieasas')
                     ELSE tok END,
                ' ' ORDER BY ord)
         FROM regexp_split_to_table(
                regexp_replace(lower(normalize(coalesce(t, ''), NFD)), '[̀-ͯ]', '', 'g'),
                '\s+') WITH ORDINALITY AS s(tok, ord)),
      ''),
    '[^a-z]+', ' ', 'g')) || ' '
$$;

-- A term's regex. The term is normalised exactly as text is (leetspeak too, so
-- a term with a digit in it still matches). Each run of a letter may repeat
-- ('fuuuck'), but not shrink,
-- so a term with a double letter doesn't match the word with a single one. An
-- optional trailing s covers plurals. Multi-word phrases match across any
-- spacing or punctuation.
CREATE OR REPLACE FUNCTION public.blocked_term_pattern(term text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$
DECLARE
  n text := btrim(public.normalize_filter_text(term, true));
  pattern text := '';
  prev text := '';
  run integer := 0;
  c text;
BEGIN
  IF n = '' THEN
    RETURN NULL;
  END IF;

  FOREACH c IN ARRAY regexp_split_to_array(n || '|', '') LOOP
    IF c = prev THEN
      run := run + 1;
    ELSE
      IF prev = ' ' THEN
        pattern := pattern || ' ';
      ELSIF prev <> '' THEN
        pattern := pattern || prev || CASE WHEN run = 1 THEN '+' ELSE '{' || run || ',}' END;
      END IF;
      prev := c;
      run := 1;
    END IF;
  END LOOP;

  RETURN pattern || 's*';
END;
$$;

-- --- The list ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blocked_terms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  term text NOT NULL CHECK (char_length(btrim(term)) BETWEEN 2 AND 60),
  language text NOT NULL CHECK (language IN ('en', 'tpi', 'meu')),
  category text NOT NULL DEFAULT 'profanity' CHECK (category IN ('profanity', 'slur', 'sexual', 'abuse')),
  approved boolean NOT NULL DEFAULT false,
  added_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  term_normalized text GENERATED ALWAYS AS (btrim(public.normalize_filter_text(term, true))) STORED,
  pattern text GENERATED ALWAYS AS (public.blocked_term_pattern(term)) STORED,
  CHECK (term_normalized <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS blocked_terms_term_normalized_key
  ON public.blocked_terms (term_normalized);

ALTER TABLE public.blocked_terms ENABLE ROW LEVEL SECURITY;

-- Native and heritage speakers can suggest terms until the trust ladder (#53)
-- gives a better definition of a trusted speaker.
CREATE OR REPLACE FUNCTION public.can_suggest_blocked_terms()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT coalesce(
    (SELECT connection_type IN ('native_speaker', 'heritage_speaker')
            AND status IN ('active', 'warned')
       FROM public.profiles WHERE id = auth.uid()),
    false
  )
$$;

REVOKE ALL ON FUNCTION public.can_suggest_blocked_terms() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_suggest_blocked_terms() TO authenticated;

-- Members can't read the list (it isn't published); admins manage it.
DROP POLICY IF EXISTS "Admins can read blocked terms" ON public.blocked_terms;
CREATE POLICY "Admins can read blocked terms"
  ON public.blocked_terms FOR SELECT TO authenticated
  USING (public.is_current_user_admin());

DROP POLICY IF EXISTS "Admins can add blocked terms" ON public.blocked_terms;
CREATE POLICY "Admins can add blocked terms"
  ON public.blocked_terms FOR INSERT TO authenticated
  WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Trusted speakers can suggest blocked terms" ON public.blocked_terms;
CREATE POLICY "Trusted speakers can suggest blocked terms"
  ON public.blocked_terms FOR INSERT TO authenticated
  WITH CHECK (approved = false AND added_by = auth.uid() AND public.can_suggest_blocked_terms());

DROP POLICY IF EXISTS "Admins can update blocked terms" ON public.blocked_terms;
CREATE POLICY "Admins can update blocked terms"
  ON public.blocked_terms FOR UPDATE TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Admins can delete blocked terms" ON public.blocked_terms;
CREATE POLICY "Admins can delete blocked terms"
  ON public.blocked_terms FOR DELETE TO authenticated
  USING (public.is_current_user_admin());

REVOKE ALL ON public.blocked_terms FROM anon;
REVOKE ALL ON public.blocked_terms FROM authenticated;
GRANT SELECT, DELETE ON public.blocked_terms TO authenticated;
GRANT INSERT (term, language, category, approved, added_by) ON public.blocked_terms TO authenticated;
GRANT UPDATE (term, language, category, approved) ON public.blocked_terms TO authenticated;

-- --- Matching ----------------------------------------------------------------
-- The one reusable check (#58 applies it to proposed words). All approved
-- terms go into a single regex; the string is the same on every call, so
-- Postgres compiles it once per session and short texts match in well under a
-- millisecond. SECURITY DEFINER because members can't read the list; not
-- executable by members, so it can't be used to probe the list directly.
CREATE OR REPLACE FUNCTION public.contains_blocked_language(t text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN t IS NULL OR btrim(t) = '' THEN false
    ELSE coalesce(
      public.normalize_filter_text(t, true)
        ~ (SELECT ' (' || string_agg(pattern, '|') || ') '
             FROM public.blocked_terms
            WHERE approved AND pattern IS NOT NULL),
      false)
  END
$$;

REVOKE ALL ON FUNCTION public.contains_blocked_language(text) FROM PUBLIC, anon, authenticated;

-- --- Enforcement -------------------------------------------------------------
-- Generic BEFORE trigger: the arguments name the text columns to check. Only
-- inserted or changed values are checked. The error carries SQLSTATE TMBLK,
-- and the column in DETAIL so the app can show the message by the right field.
CREATE OR REPLACE FUNCTION public.reject_blocked_language()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  new_row jsonb := to_jsonb(NEW);
  old_row jsonb := CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END;
  col text;
BEGIN
  FOREACH col IN ARRAY TG_ARGV LOOP
    IF (TG_OP = 'INSERT' OR (new_row ->> col) IS DISTINCT FROM (old_row ->> col))
       AND public.contains_blocked_language(new_row ->> col)
    THEN
      RAISE EXCEPTION 'blocked_language'
        USING ERRCODE = 'TMBLK',
              DETAIL = TG_TABLE_NAME || '.' || col,
              HINT = 'That text includes language we don''t allow on True Motu. Please rephrase.';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reject_blocked_language ON public.contributions;
CREATE TRIGGER reject_blocked_language
  BEFORE INSERT OR UPDATE OF english_gloss, notes ON public.contributions
  FOR EACH ROW EXECUTE FUNCTION public.reject_blocked_language('english_gloss', 'notes');

DROP TRIGGER IF EXISTS reject_blocked_language ON public.comments;
CREATE TRIGGER reject_blocked_language
  BEFORE INSERT OR UPDATE OF comment_text ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.reject_blocked_language('comment_text');

-- Display names. Runs after normalize_display_name (triggers fire in name
-- order), so it sees the final value. At signup a blocked name quietly becomes
-- 'Member' rather than failing the whole signup inside the auth trigger.
CREATE OR REPLACE FUNCTION public.reject_blocked_display_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF public.contains_blocked_language(NEW.display_name) THEN
      NEW.display_name := 'Member';
    END IF;
  ELSIF NEW.display_name IS DISTINCT FROM OLD.display_name
        AND public.contains_blocked_language(NEW.display_name) THEN
    RAISE EXCEPTION 'blocked_language'
      USING ERRCODE = 'TMBLK',
            DETAIL = 'profiles.display_name',
            HINT = 'That text includes language we don''t allow on True Motu. Please rephrase.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reject_blocked_display_name ON public.profiles;
CREATE TRIGGER reject_blocked_display_name
  BEFORE INSERT OR UPDATE OF display_name, name, is_18_or_older ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.reject_blocked_display_name();

-- --- Attempt log -------------------------------------------------------------
-- Who and where, never the text (we don't store abuse). #57 reads it to
-- restrict repeat offenders.
CREATE TABLE IF NOT EXISTS public.blocked_language_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  table_name text NOT NULL CHECK (table_name IN ('contributions', 'comments', 'profiles', 'words')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS blocked_language_attempts_user_created_idx
  ON public.blocked_language_attempts (user_id, created_at DESC);

ALTER TABLE public.blocked_language_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can read blocked language attempts" ON public.blocked_language_attempts;
CREATE POLICY "Admins can read blocked language attempts"
  ON public.blocked_language_attempts FOR SELECT TO authenticated
  USING (public.is_current_user_admin());

REVOKE ALL ON public.blocked_language_attempts FROM anon, authenticated;
GRANT SELECT ON public.blocked_language_attempts TO authenticated;

-- Called by the server action after a refusal. Logs only if the text really is
-- blocked, and only against the caller.
CREATE OR REPLACE FUNCTION public.log_blocked_language_attempt(p_table text, p_text text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_table NOT IN ('contributions', 'comments', 'profiles', 'words')
     OR NOT public.contains_blocked_language(p_text) THEN
    RETURN false;
  END IF;

  INSERT INTO public.blocked_language_attempts (user_id, table_name)
  VALUES (auth.uid(), p_table);
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.log_blocked_language_attempt(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_blocked_language_attempt(text, text) TO authenticated;

-- --- Starter list ------------------------------------------------------------
-- Strong profanity, slurs, and sexual and abusive terms in English and Tok
-- Pisin, kept modest. Each was checked against the 15,610 Motu headwords after
-- normalisation (no collisions). Left out on purpose because they have
-- innocent senses a dictionary needs: ass (donkey), bitch (female dog), cock
-- (rooster), whore and harlot (Bible text), prick, pussy, dick, piss, sit and
-- pekpek (ordinary Tok Pisin). Motu terms will come from fluent speakers.
INSERT INTO public.blocked_terms (term, language, category, approved) VALUES
  ('fuck', 'en', 'profanity', true),
  ('fucker', 'en', 'profanity', true),
  ('fucking', 'en', 'profanity', true),
  ('fuckin', 'en', 'profanity', true),
  ('fucked', 'en', 'profanity', true),
  ('fuckwit', 'en', 'abuse', true),
  ('fuckface', 'en', 'abuse', true),
  ('fuck off', 'en', 'abuse', true),
  ('motherfucker', 'en', 'abuse', true),
  ('motherfucking', 'en', 'abuse', true),
  ('shit', 'en', 'profanity', true),
  ('shitty', 'en', 'profanity', true),
  ('shithead', 'en', 'abuse', true),
  ('bullshit', 'en', 'profanity', true),
  ('cunt', 'en', 'abuse', true),
  ('asshole', 'en', 'abuse', true),
  ('arsehole', 'en', 'abuse', true),
  ('dickhead', 'en', 'abuse', true),
  ('cocksucker', 'en', 'abuse', true),
  ('wanker', 'en', 'abuse', true),
  ('twat', 'en', 'abuse', true),
  ('slut', 'en', 'abuse', true),
  ('kill yourself', 'en', 'abuse', true),
  ('nigger', 'en', 'slur', true),
  ('nigga', 'en', 'slur', true),
  ('faggot', 'en', 'slur', true),
  ('kike', 'en', 'slur', true),
  ('spic', 'en', 'slur', true),
  ('gook', 'en', 'slur', true),
  ('wetback', 'en', 'slur', true),
  ('tranny', 'en', 'slur', true),
  ('boong', 'en', 'slur', true),
  ('blowjob', 'en', 'sexual', true),
  ('handjob', 'en', 'sexual', true),
  ('jizz', 'en', 'sexual', true),
  ('dildo', 'en', 'sexual', true),
  ('kan', 'tpi', 'sexual', true),
  ('kok', 'tpi', 'sexual', true),
  ('puspus', 'tpi', 'sexual', true),
  ('kan bilong mama', 'tpi', 'abuse', true)
ON CONFLICT (term_normalized) DO NOTHING;
