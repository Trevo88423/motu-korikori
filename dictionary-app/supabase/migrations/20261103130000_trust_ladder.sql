-- =============================================================================
-- 20261103130000 — Trust recomputed from the record; the trust ladder
-- (#53, part of #51; fixes #44)
--
-- #44: update_author_trust_on_vote() added trust on every vote insert and never
-- took it back on delete, so vote / un-vote / vote pushed a member's trust up
-- without limit. Trust now never accumulates per event. recompute_trust()
-- derives it from what is on record right now, so toggling a vote any number
-- of times lands back on exactly the same value.
--
-- The record (each weight is a row in moderation_settings, tunable without code):
--   base                    trust_base
--   + agreement             trust_per_match per translation that matches the
--                           agreed meaning of a decided word, up to trust_match_cap.
--                           Disagreeing costs nothing: a different translation can
--                           be a real variant (docs/PHILOSOPHY.md, principle 3).
--   + votes received        trust_per_vote per up-vote on their translations and
--                           per net comment vote, from established voters only (so
--                           a farm of fresh accounts can't vote anyone up), within
--                           +/- trust_vote_cap.
--   - flagged-down items    trust_per_hidden_item per translation or comment of
--                           theirs that is currently hidden by flags. An admin
--                           restore gives it back.
--   clamped to [0, trust_max].
--
-- The ladder (profiles.trust_level), from that record score:
--   restricted       restricted_until is in the future (set by #57; nothing sets
--                    it yet).
--   trusted_speaker  established, a native or heritage speaker, and record score
--                    >= trusted_min_trust.
--   member           established: no item hidden by flags, and either
--                    member_min_matches translations matching consensus or record
--                    score >= member_min_trust.
--   new              everyone else, including every new signup.
-- is_established_contributor(uuid), added by #30 (20261103120000), stays the one
-- definition of "established" for visitor-facing reads (the 2026-10-24 decision
-- in docs/DECISIONS.md); this replaces its interim body with "Member or above".
-- Needs 20261103120000 applied first (it's earlier, so db push orders it).
--
-- profiles.trust_score is what a member counts for: record score x the level's
-- weight (trust_level_weight_<level>). New members count half, restricted zero.
-- Consensus (lib/consensus.ts) already weighs by trust_score, so it uses the new
-- trust with no code change; flag_weight() now goes by level.
--
-- When it's recomputed: by triggers on votes, on a translation's consensus match,
-- exclusion or hiding, on a comment being hidden or deleted, on a profile's
-- connection type or restriction changing, and for everyone when a
-- moderation_settings row changes (so a threshold change moves levels at once).
-- A level change also recomputes the authors that member voted for, since their
-- votes start or stop counting.
--
-- Also from #44:
--   - Switching a comment vote between up and down works: comment_votes gets an
--     UPDATE policy (own vote, active member, vote_type only) and the counters
--     follow updates.
--   - profiles.contribution_count has one definition: the number of distinct words
--     the member has translated or commented on. Both triggers call
--     recount_contribution_count(); increment_contribution_count() no longer adds 1.
--
-- Safe with the current app: no column is removed or renamed, every app write
-- still works, and the app's vote code already did nothing to trust itself.
-- =============================================================================

-- --- Settings --------------------------------------------------------------------

INSERT INTO public.moderation_settings (key, value, description) VALUES
  ('trust_base', 1,
   'Trust everyone starts from, before their record'),
  ('trust_per_match', 0.05,
   'Trust added for each translation that matches the agreed meaning of a decided word'),
  ('trust_match_cap', 1.5,
   'Most trust that matching translations can add'),
  ('trust_per_vote', 0.02,
   'Trust added per up-vote on a translation or net comment vote, from established members'),
  ('trust_vote_cap', 0.5,
   'Most trust that votes received can add or take away'),
  ('trust_per_hidden_item', 0.5,
   'Trust taken away for each of their translations or comments currently hidden by flags'),
  ('trust_max', 3,
   'Highest trust score from the record'),
  ('member_min_matches', 10,
   'Translations matching consensus that make a New member a Member (with no items hidden by flags)'),
  ('member_min_trust', 1.5,
   'Trust from the record that also makes a New member a Member (with no items hidden by flags)'),
  ('trusted_min_trust', 1.5,
   'Trust from the record a native or heritage speaker Member needs to be a Trusted speaker'),
  ('trust_level_weight_new', 0.5,
   'How much a New member counts in consensus (multiplies their trust)'),
  ('trust_level_weight_member', 1,
   'How much a Member counts in consensus (multiplies their trust)'),
  ('trust_level_weight_trusted_speaker', 1,
   'How much a Trusted speaker counts in consensus (multiplies their trust; speaker type adds more)'),
  ('trust_level_weight_restricted', 0,
   'How much a Restricted member counts in consensus'),
  ('flag_weight_new', 0.5,
   'Weight of a flag from a New member')
ON CONFLICT (key) DO NOTHING;

-- flag_weight() now goes by level; "trusted" is the Trusted speaker level.
DELETE FROM public.moderation_settings WHERE key = 'flag_trusted_min_trust';
UPDATE public.moderation_settings
SET description = 'Weight of a flag from a Member'
WHERE key = 'flag_weight_member';
UPDATE public.moderation_settings
SET description = 'Weight of a flag from a Trusted speaker'
WHERE key = 'flag_weight_trusted';

-- --- Profile columns ---------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS trust_level text NOT NULL DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS restricted_until timestamptz;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_trust_level_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_trust_level_check
  CHECK (trust_level IN ('new', 'member', 'trusted_speaker', 'restricted'));

CREATE INDEX IF NOT EXISTS profiles_trust_level_idx ON public.profiles (trust_level);

-- The level is public (contributions show "new contributor"); restricted_until
-- isn't granted, so it stays private. Members can't UPDATE either column: their
-- UPDATE grant covers only the columns the profile form writes.
GRANT SELECT (trust_level) ON public.profiles TO anon, authenticated;

-- Same body as 20261024160000, with the two new columns protected too.
CREATE OR REPLACE FUNCTION public.guard_protected_profile_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- service_role bypasses this guard; everyone else is held to the invariant.
  IF nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Updates made by another trigger (the contribution/comment/vote counters)
  -- are trusted. A member's direct UPDATE fires this guard at depth 1.
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  IF NEW.is_admin               IS DISTINCT FROM OLD.is_admin
     OR NEW.status              IS DISTINCT FROM OLD.status
     OR NEW.trust_score         IS DISTINCT FROM OLD.trust_score
     OR NEW.trust_level         IS DISTINCT FROM OLD.trust_level
     OR NEW.restricted_until    IS DISTINCT FROM OLD.restricted_until
     OR NEW.contribution_count  IS DISTINCT FROM OLD.contribution_count
     OR NEW.excluded_from_ai    IS DISTINCT FROM OLD.excluded_from_ai
     OR NEW.contributions_excluded IS DISTINCT FROM OLD.contributions_excluded
     OR NEW.email               IS DISTINCT FROM OLD.email
     OR NEW.id                  IS DISTINCT FROM OLD.id
  THEN
    RAISE EXCEPTION 'profiles: attempt to modify a protected column'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$function$;

-- --- The old per-vote ratchet goes ---------------------------------------------------

DROP TRIGGER IF EXISTS update_trust_on_contribution_vote ON public.contribution_votes;
DROP TRIGGER IF EXISTS update_trust_on_comment_vote ON public.comment_votes;
DROP FUNCTION IF EXISTS public.update_author_trust_on_vote();

-- --- Recompute from the record -------------------------------------------------------

-- Recomputes one member's trust_score and trust_level from the record. Returns
-- whether either changed. With cascade, a level change also recomputes the
-- authors this member voted for (one step only, so it can't loop).
CREATE OR REPLACE FUNCTION public.recompute_trust(member uuid, cascade boolean DEFAULT true)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  prof record;
  matched int;
  votes int;
  hidden int;
  record_score numeric;
  lvl text;
  score numeric;
  author uuid;
BEGIN
  SELECT connection_type, restricted_until, trust_score, trust_level
  INTO prof
  FROM profiles WHERE id = member;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  SELECT count(*) INTO matched
  FROM contributions
  WHERE user_id = member AND matches_consensus AND NOT is_excluded AND NOT is_hidden;

  -- Votes from established members only; never the member's own.
  SELECT
    (SELECT count(*)
       FROM contribution_votes v
       JOIN contributions c ON c.id = v.contribution_id
       JOIN profiles vp ON vp.id = v.user_id
      WHERE c.user_id = member AND v.user_id <> member
        AND NOT c.is_excluded AND NOT c.is_hidden
        AND vp.status = 'active' AND vp.trust_level IN ('member', 'trusted_speaker'))
    +
    (SELECT coalesce(sum(v.vote_type), 0)
       FROM comment_votes v
       JOIN comments c ON c.id = v.comment_id
       JOIN profiles vp ON vp.id = v.user_id
      WHERE c.user_id = member AND v.user_id <> member
        AND NOT coalesce(c.is_flagged, false)
        AND vp.status = 'active' AND vp.trust_level IN ('member', 'trusted_speaker'))
  INTO votes;

  SELECT
    (SELECT count(*) FROM contributions WHERE user_id = member AND is_hidden)
    + (SELECT count(*) FROM comments WHERE user_id = member AND coalesce(is_flagged, false))
  INTO hidden;

  record_score := least(moderation_setting('trust_max'), greatest(0,
      moderation_setting('trust_base')
    + least(moderation_setting('trust_match_cap'), matched * moderation_setting('trust_per_match'))
    + greatest(-moderation_setting('trust_vote_cap'),
               least(moderation_setting('trust_vote_cap'), votes * moderation_setting('trust_per_vote')))
    - hidden * moderation_setting('trust_per_hidden_item')));

  lvl := CASE
    WHEN prof.restricted_until > now() THEN 'restricted'
    WHEN hidden = 0
         AND (matched >= moderation_setting('member_min_matches')
              OR record_score >= moderation_setting('member_min_trust')) THEN
      CASE
        WHEN prof.connection_type IN ('native_speaker', 'heritage_speaker')
             AND record_score >= moderation_setting('trusted_min_trust') THEN 'trusted_speaker'
        ELSE 'member'
      END
    ELSE 'new'
  END;

  -- trust_score is numeric(3,2).
  score := least(9.99, round(record_score * coalesce(moderation_setting('trust_level_weight_' || lvl), 1), 2));

  IF prof.trust_score = score AND prof.trust_level = lvl THEN
    RETURN false;
  END IF;

  UPDATE profiles SET trust_score = score, trust_level = lvl WHERE id = member;

  IF cascade AND prof.trust_level IS DISTINCT FROM lvl THEN
    FOR author IN
      SELECT c.user_id FROM contribution_votes v JOIN contributions c ON c.id = v.contribution_id
       WHERE v.user_id = member
      UNION
      SELECT c.user_id FROM comment_votes v JOIN comments c ON c.id = v.comment_id
       WHERE v.user_id = member
    LOOP
      IF author <> member THEN
        PERFORM recompute_trust(author, false);
      END IF;
    END LOOP;
  END IF;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.recompute_trust(uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_trust(uuid, boolean) TO service_role;

-- Everyone. Votes count by the voter's level, so passes repeat until nothing
-- moves (a few at most). Returns how many members changed in the first pass.
CREATE OR REPLACE FUNCTION public.recompute_all_trust()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  first_pass int;
  changed int;
  pass int := 0;
BEGIN
  LOOP
    SELECT count(*) FILTER (WHERE recompute_trust(id, false)) INTO changed FROM profiles;
    pass := pass + 1;
    IF pass = 1 THEN
      first_pass := changed;
    END IF;
    EXIT WHEN changed = 0 OR pass >= 5;
  END LOOP;
  RETURN first_pass;
END;
$function$;

REVOKE ALL ON FUNCTION public.recompute_all_trust() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_all_trust() TO service_role;

-- The one definition of "established" (#53 decision, 2026-10-24): Member or
-- Trusted speaker. Same signature and privileges as #30's interim version
-- (20261103120000); contribution_is_public() calls it for visitor reads.
CREATE OR REPLACE FUNCTION public.is_established_contributor(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce(
    (SELECT trust_level IN ('member', 'trusted_speaker') FROM public.profiles WHERE id = p_user),
    false)
$$;

REVOKE ALL ON FUNCTION public.is_established_contributor(uuid) FROM PUBLIC, anon, authenticated;

-- --- Triggers ---------------------------------------------------------------------------

-- Finds whose record a changed row belongs to and recomputes them.
CREATE OR REPLACE FUNCTION public.recompute_trust_on_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r jsonb;
  member uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    r := to_jsonb(OLD);
  ELSE
    r := to_jsonb(NEW);
  END IF;

  IF TG_TABLE_NAME = 'contribution_votes' THEN
    SELECT user_id INTO member FROM contributions WHERE id = (r ->> 'contribution_id')::uuid;
  ELSIF TG_TABLE_NAME = 'comment_votes' THEN
    SELECT user_id INTO member FROM comments WHERE id = (r ->> 'comment_id')::uuid;
  ELSIF TG_TABLE_NAME = 'profiles' THEN
    member := (r ->> 'id')::uuid;
  ELSE
    member := (r ->> 'user_id')::uuid;
  END IF;

  IF member IS NOT NULL THEN
    PERFORM recompute_trust(member);
  END IF;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS recompute_trust_on_vote ON public.contribution_votes;
CREATE TRIGGER recompute_trust_on_vote
  AFTER INSERT OR DELETE ON public.contribution_votes
  FOR EACH ROW EXECUTE FUNCTION public.recompute_trust_on_change();

DROP TRIGGER IF EXISTS recompute_trust_on_vote ON public.comment_votes;
CREATE TRIGGER recompute_trust_on_vote
  AFTER INSERT OR DELETE OR UPDATE OF vote_type ON public.comment_votes
  FOR EACH ROW EXECUTE FUNCTION public.recompute_trust_on_change();

DROP TRIGGER IF EXISTS recompute_trust_on_record ON public.contributions;
CREATE TRIGGER recompute_trust_on_record
  AFTER DELETE OR UPDATE OF matches_consensus, is_excluded, is_hidden ON public.contributions
  FOR EACH ROW EXECUTE FUNCTION public.recompute_trust_on_change();

DROP TRIGGER IF EXISTS recompute_trust_on_record ON public.comments;
CREATE TRIGGER recompute_trust_on_record
  AFTER DELETE OR UPDATE OF is_flagged ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.recompute_trust_on_change();

-- New signups (the signup function writes trust_score 1.0) and changes to
-- speaker type or restriction. recompute_trust's own UPDATE sets neither
-- column, so this doesn't fire on it.
DROP TRIGGER IF EXISTS recompute_trust_on_profile ON public.profiles;
CREATE TRIGGER recompute_trust_on_profile
  AFTER INSERT OR UPDATE OF connection_type, restricted_until ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.recompute_trust_on_change();

CREATE OR REPLACE FUNCTION public.recompute_all_trust_on_settings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM recompute_all_trust();
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS recompute_trust_on_settings ON public.moderation_settings;
CREATE TRIGGER recompute_trust_on_settings
  AFTER INSERT OR UPDATE OR DELETE ON public.moderation_settings
  FOR EACH STATEMENT EXECUTE FUNCTION public.recompute_all_trust_on_settings();

-- --- Flags weigh by level ---------------------------------------------------------------
-- Same contract as 20261024171056 (the one place a flag's weight is decided).
--   base     by level: New, Member, Trusted speaker; Restricted flags weigh nothing
--   x record 1 - penalty * overturned flags, never below 0
CREATE OR REPLACE FUNCTION public.flag_weight(flagger uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT round(
    CASE p.trust_level
      WHEN 'trusted_speaker' THEN public.moderation_setting('flag_weight_trusted')
      WHEN 'member'          THEN public.moderation_setting('flag_weight_member')
      WHEN 'new'             THEN public.moderation_setting('flag_weight_new')
      ELSE 0
    END
    * greatest(0, 1 - public.moderation_setting('flag_overturn_penalty')
                      * coalesce(r.flags_overturned, 0)),
    2)
  FROM public.profiles p
  LEFT JOIN public.member_flag_record r ON r.user_id = p.id
  WHERE p.id = flagger
$$;

REVOKE ALL ON FUNCTION public.flag_weight(uuid) FROM PUBLIC, anon, authenticated;

-- --- #44: switching a comment vote -----------------------------------------------------

REVOKE UPDATE ON public.comment_votes FROM anon, authenticated;
GRANT UPDATE (vote_type) ON public.comment_votes TO authenticated;

DROP POLICY IF EXISTS "Users can change their own comment votes" ON public.comment_votes;
CREATE POLICY "Users can change their own comment votes"
  ON public.comment_votes FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND public.is_current_user_active())
  WITH CHECK (auth.uid() = user_id AND public.is_current_user_active());

DROP TRIGGER IF EXISTS comment_vote_counter ON public.comment_votes;
CREATE TRIGGER comment_vote_counter
  AFTER INSERT OR DELETE OR UPDATE OF vote_type ON public.comment_votes
  FOR EACH ROW EXECUTE FUNCTION public.update_comment_vote_counts();

-- --- #44: one definition of contribution_count ----------------------------------------
-- The number of distinct words the member has translated or commented on.

CREATE OR REPLACE FUNCTION public.recount_contribution_count(member uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  UPDATE profiles
  SET contribution_count = (
    SELECT count(*) FROM (
      SELECT word_id FROM contributions WHERE user_id = member
      UNION
      SELECT word_id FROM comments WHERE user_id = member
    ) words_touched
  )
  WHERE id = member
$$;

REVOKE ALL ON FUNCTION public.recount_contribution_count(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_profile_contribution_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM recount_contribution_count(OLD.user_id);
    RETURN OLD;
  END IF;
  PERFORM recount_contribution_count(NEW.user_id);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_contribution_count_on_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM recount_contribution_count(OLD.user_id);
    RETURN OLD;
  END IF;
  PERFORM recount_contribution_count(NEW.user_id);
  RETURN NEW;
END;
$function$;

-- Keeps only the last-contribution date; the count belongs to the recount.
CREATE OR REPLACE FUNCTION public.increment_contribution_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE profiles
  SET last_contribution_date = CURRENT_DATE
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$function$;

-- --- Recompute everyone once ------------------------------------------------------------
-- As the service role, so the profile guard lets the backfill through.

SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);

SELECT public.recount_contribution_count(id) FROM public.profiles;
SELECT public.recompute_all_trust();
