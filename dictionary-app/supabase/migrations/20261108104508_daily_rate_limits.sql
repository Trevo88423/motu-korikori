-- =============================================================================
-- 20261108104508 — Daily rate limits by trust level (#55, part of #51)
--
-- Every member write is capped per day by the member's trust level (#53), in
-- the database, so a script holding the public anon key and a member's token
-- can't flood the site. Four things are counted:
--
--   translations  contributions: a new translation or agreement, or changing
--                 the English of your own translation
--   comments      comments: a new comment, or editing its text
--   votes         contribution_votes and comment_votes: a new vote, or switching
--                 a comment vote between up and down
--   flags         contribution_flags and comment_flags (written by flag_content())
--
-- Deleting never counts and never gives a write back, so vote / un-vote /
-- vote can't be used to go round the cap.
--
-- The caps are rows in moderation_settings, rate_<thing>_<level>, which the
-- admin page edits without code. Restricted members (#57 sets restricted_until)
-- keep a small allowance for translations and comments, which carry zero weight
-- (#53), and none for votes or flags: #51 says restriction lowers weight and
-- visibility and switches flags off, but never bans. Set the restricted rows
-- to 0 to stop restricted writes altogether.
--
-- A day is a calendar day in Port Moresby (UTC+10, no daylight saving), so the
-- limits reset at local midnight. rate_limit_day() is the one place to change
-- that for another language community.
--
-- Who is limited: only requests made as `authenticated` (a member's own token).
-- The service role (admin actions, consensus) and migrations aren't. Admins
-- aren't limited either.
--
-- A refused write raises SQLSTATE TMRAT with the thing in DETAIL and the cap in
-- HINT; lib/rate-limits.ts turns that into the friendly message. The refused
-- statement rolls back, including its count, so only accepted writes use up
-- the allowance. my_daily_limits() tells the app how many are left today.
--
-- For #58 (proposed words): add rate_words_<level> rows and attach
-- count_daily_write('words') to the proposed-word insert.
-- For #57 (auto-restriction): nothing to do here; setting restricted_until
-- moves the member to 'restricted' and the restricted caps apply at once.
--
-- Safe with the current app: every write still works below the caps, and the
-- app shows a generic error until its friendly message ships in the same push.
-- =============================================================================

-- --- Settings --------------------------------------------------------------------
-- Starting values; #51 suggested 20 translations and 10 comments for New.
-- ON CONFLICT keeps values already tuned.

INSERT INTO public.moderation_settings (key, value, description) VALUES
  ('rate_translations_new', 20,
   'Daily limit: translations (and agreements) a New member can add or change'),
  ('rate_translations_member', 100,
   'Daily limit: translations (and agreements) a Member can add or change'),
  ('rate_translations_trusted_speaker', 300,
   'Daily limit: translations (and agreements) a Trusted speaker can add or change'),
  ('rate_translations_restricted', 5,
   'Daily limit: translations (and agreements) a Restricted member can add or change'),
  ('rate_comments_new', 10,
   'Daily limit: comments a New member can post or edit'),
  ('rate_comments_member', 40,
   'Daily limit: comments a Member can post or edit'),
  ('rate_comments_trusted_speaker', 100,
   'Daily limit: comments a Trusted speaker can post or edit'),
  ('rate_comments_restricted', 2,
   'Daily limit: comments a Restricted member can post or edit'),
  ('rate_votes_new', 50,
   'Daily limit: votes a New member can cast or change'),
  ('rate_votes_member', 300,
   'Daily limit: votes a Member can cast or change'),
  ('rate_votes_trusted_speaker', 500,
   'Daily limit: votes a Trusted speaker can cast or change'),
  ('rate_votes_restricted', 0,
   'Daily limit: votes a Restricted member can cast or change'),
  ('rate_flags_new', 5,
   'Daily limit: flags a New member can raise'),
  ('rate_flags_member', 20,
   'Daily limit: flags a Member can raise'),
  ('rate_flags_trusted_speaker', 40,
   'Daily limit: flags a Trusted speaker can raise'),
  ('rate_flags_restricted', 0,
   'Daily limit: flags a Restricted member can raise')
ON CONFLICT (key) DO NOTHING;

-- --- Today's counts ----------------------------------------------------------------
-- One row per member, day and thing. A counter rather than counting rows, so
-- deleted votes and comments still count. Members read their own through
-- my_daily_limits(); nobody writes it directly.

CREATE TABLE IF NOT EXISTS public.daily_write_counts (
  user_id uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day     date    NOT NULL,
  thing   text    NOT NULL CHECK (thing IN ('translations', 'comments', 'votes', 'flags', 'words')),
  count   integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day, thing)
);

ALTER TABLE public.daily_write_counts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.daily_write_counts FROM anon, authenticated;

-- The calendar day the limits count in.
CREATE OR REPLACE FUNCTION public.rate_limit_day()
RETURNS date
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT (now() AT TIME ZONE 'Pacific/Port_Moresby')::date
$$;

-- The cap for a member and thing; NULL means no limit (admins, or a setting
-- that has been deleted).
CREATE OR REPLACE FUNCTION public.daily_limit(p_user uuid, p_thing text)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN p.is_admin THEN NULL
              ELSE floor(public.moderation_setting('rate_' || p_thing || '_' || p.trust_level))::integer
         END
  FROM public.profiles p
  WHERE p.id = p_user
$$;

REVOKE ALL ON FUNCTION public.daily_limit(uuid, text) FROM PUBLIC, anon, authenticated;

-- --- Counting and refusing ---------------------------------------------------------
-- AFTER row trigger, so it sees only rows actually written (an
-- INSERT ... ON CONFLICT DO NOTHING that changed nothing doesn't count), and
-- raising still rolls the whole statement back. TG_ARGV[0] is the thing.
CREATE OR REPLACE FUNCTION public.count_daily_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_thing text := TG_ARGV[0];
  caller  uuid := auth.uid();
  cap     integer;
  used    integer;
BEGIN
  -- Only a member's own requests are limited.
  IF caller IS NULL
     OR coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') <> 'authenticated'
     OR NEW.user_id IS DISTINCT FROM caller THEN
    RETURN NULL;
  END IF;

  -- Updates count only when they change what the member wrote. Nested IFs:
  -- PL/pgSQL would fail reading a field another table's row doesn't have.
  IF TG_OP = 'UPDATE' THEN
    IF TG_TABLE_NAME = 'contributions' THEN
      IF NEW.english_gloss IS NOT DISTINCT FROM OLD.english_gloss THEN RETURN NULL; END IF;
    ELSIF TG_TABLE_NAME = 'comments' THEN
      IF NEW.comment_text IS NOT DISTINCT FROM OLD.comment_text THEN RETURN NULL; END IF;
    ELSIF TG_TABLE_NAME = 'comment_votes' THEN
      IF NEW.vote_type IS NOT DISTINCT FROM OLD.vote_type THEN RETURN NULL; END IF;
    ELSE
      RETURN NULL;
    END IF;
  END IF;

  cap := public.daily_limit(caller, v_thing);
  IF cap IS NULL THEN
    RETURN NULL;
  END IF;

  -- The upsert locks this member's row for the day, so concurrent writes are
  -- counted one at a time.
  INSERT INTO public.daily_write_counts AS d (user_id, day, thing, count)
  VALUES (caller, public.rate_limit_day(), v_thing, 1)
  ON CONFLICT (user_id, day, thing) DO UPDATE SET count = d.count + 1
  RETURNING d.count INTO used;

  IF used > cap THEN
    RAISE EXCEPTION 'Daily limit reached for %', v_thing
      USING ERRCODE = 'TMRAT', DETAIL = v_thing, HINT = cap::text;
  END IF;

  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.count_daily_write() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS daily_limit_translations ON public.contributions;
CREATE TRIGGER daily_limit_translations
  AFTER INSERT OR UPDATE OF english_gloss ON public.contributions
  FOR EACH ROW EXECUTE FUNCTION public.count_daily_write('translations');

DROP TRIGGER IF EXISTS daily_limit_comments ON public.comments;
CREATE TRIGGER daily_limit_comments
  AFTER INSERT OR UPDATE OF comment_text ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.count_daily_write('comments');

DROP TRIGGER IF EXISTS daily_limit_contribution_votes ON public.contribution_votes;
CREATE TRIGGER daily_limit_contribution_votes
  AFTER INSERT ON public.contribution_votes
  FOR EACH ROW EXECUTE FUNCTION public.count_daily_write('votes');

DROP TRIGGER IF EXISTS daily_limit_comment_votes ON public.comment_votes;
CREATE TRIGGER daily_limit_comment_votes
  AFTER INSERT OR UPDATE OF vote_type ON public.comment_votes
  FOR EACH ROW EXECUTE FUNCTION public.count_daily_write('votes');

DROP TRIGGER IF EXISTS daily_limit_contribution_flags ON public.contribution_flags;
CREATE TRIGGER daily_limit_contribution_flags
  AFTER INSERT ON public.contribution_flags
  FOR EACH ROW EXECUTE FUNCTION public.count_daily_write('flags');

DROP TRIGGER IF EXISTS daily_limit_comment_flags ON public.comment_flags;
CREATE TRIGGER daily_limit_comment_flags
  AFTER INSERT ON public.comment_flags
  FOR EACH ROW EXECUTE FUNCTION public.count_daily_write('flags');

-- --- What's left today ----------------------------------------------------------------
-- For the signed-in member only: one row per thing with today's limit, how
-- many they've used and how many are left. limit_per_day and remaining are
-- NULL when there's no limit.
CREATE OR REPLACE FUNCTION public.my_daily_limits()
RETURNS TABLE (thing text, limit_per_day integer, used integer, remaining integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT t.thing,
         public.daily_limit(auth.uid(), t.thing) AS limit_per_day,
         coalesce(d.count, 0) AS used,
         greatest(0, public.daily_limit(auth.uid(), t.thing) - coalesce(d.count, 0)) AS remaining
  FROM unnest(ARRAY['translations', 'comments', 'votes', 'flags']) AS t(thing)
  LEFT JOIN public.daily_write_counts d
    ON d.user_id = auth.uid() AND d.day = public.rate_limit_day() AND d.thing = t.thing
  WHERE auth.uid() IS NOT NULL
$$;

REVOKE ALL ON FUNCTION public.my_daily_limits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_daily_limits() TO authenticated;
