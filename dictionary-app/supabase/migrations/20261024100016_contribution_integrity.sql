-- =============================================================================
-- 20261024100016 — Votes, flags and word counters work; authors can't edit
-- their own counters (issues #27 and #11)
--
-- #27: five trigger functions were SECURITY INVOKER. They ran as the voter or
--   contributor and, under that member's RLS, updated 0 rows whenever the row
--   belonged to someone else (comments, contributions) or had no member UPDATE
--   policy at all (words). Votes were saved but net_votes never moved, and
--   words.unique_contributors never changed. Same class of bug as #5
--   (20261024090000). Fix: SECURITY DEFINER; every one already pins
--   search_path.
--
--   The counters also had more than one owner. On insert,
--   increment_contribution_count() added 1 to words.total_contributions and
--   update_word_contribution_counts() added another, so any insert where both
--   could write (service role, admin, imports) counted twice; and
--   update_unique_contributors() recomputed what update_word_contribution_counts()
--   already does. Now:
--     words.total_contributions / unique_contributors -> update_word_contribution_counts()
--     contributions.upvote_count / net_votes          -> update_contribution_vote_counts()
--     comments.upvote_count / downvote_count / net_votes -> update_comment_vote_counts()
--   Each recomputes from the source rows instead of adding +/-1, so they can't
--   drift, and existing values are recomputed once at the end.
--
--   Flags: check_comment_flags() did set is_flagged at three flags, but nothing
--   hid a flagged comment, and increment_comment_flags() let one member flag
--   the same comment any number of times. Flags are now one per member
--   (comment_flags), and flagged comments are hidden by RLS from everyone but
--   their author and admins.
--
--   Editing a comment's text resets its votes. reset_comment_votes_on_edit()
--   deleted the votes from inside a BEFORE trigger as the author, whose RLS
--   only covers their own votes, so other members' votes stayed behind while
--   the counts went to 0. The delete now happens in an AFTER trigger as
--   definer, which then recounts.
--
-- #11: "Users can update own contributions" had no WITH CHECK and
--   `authenticated` held INSERT/UPDATE on every column, so an author could
--   write upvote_count, net_votes, matches_consensus and is_excluded on their
--   own rows. comments had the same hole (upvote_count, net_votes, flag_count,
--   is_flagged). Members now hold only the columns the app writes:
--     contributions: app/contribute/actions.ts insert, update and upsert. The
--       upsert sets word_id and user_id in its ON CONFLICT DO UPDATE, so those
--       need UPDATE too; WITH CHECK keeps user_id the caller's, and moving a
--       contribution to another word is no more than delete + insert.
--     comments: app/contribute/comment-actions.ts (insert; update comment_text).
--   Moderation (is_excluded, matches_consensus) uses the service-role client
--   (app/admin/actions.ts, lib/consensus.ts) and is unaffected.
--
-- Not in scope: the trust-score ratchet (removing a vote never reverses the
-- trust it gave), switching a comment vote between up and down (comment_votes
-- has no UPDATE policy, so it is a silent no-op today).
-- =============================================================================

-- --- #27: counter triggers run as definer ----------------------------------

-- Exactly one owner for each counter: recompute from the vote rows.
CREATE OR REPLACE FUNCTION public.update_comment_vote_counts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  target uuid := CASE WHEN TG_OP = 'DELETE' THEN OLD.comment_id ELSE NEW.comment_id END;
BEGIN
  UPDATE comments c
  SET
    upvote_count = v.up,
    downvote_count = v.down,
    net_votes = v.up - v.down
  FROM (
    SELECT
      count(*) FILTER (WHERE vote_type = 1)::int AS up,
      count(*) FILTER (WHERE vote_type = -1)::int AS down
    FROM comment_votes
    WHERE comment_id = target
  ) v
  WHERE c.id = target;
  RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_contribution_vote_counts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  target uuid := CASE WHEN TG_OP = 'DELETE' THEN OLD.contribution_id ELSE NEW.contribution_id END;
  votes int;
BEGIN
  -- Contribution votes are up-votes only.
  SELECT count(*) INTO votes FROM contribution_votes WHERE contribution_id = target;
  UPDATE contributions
  SET upvote_count = votes, net_votes = votes
  WHERE id = target;
  RETURN NULL;
END;
$function$;

-- BEFORE trigger that only sets NEW.is_flagged; definer for consistency.
ALTER FUNCTION public.check_comment_flags() SECURITY DEFINER;

-- Sole owner of words.total_contributions and words.unique_contributors.
CREATE OR REPLACE FUNCTION public.update_word_contribution_counts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.word_id = NEW.word_id
     AND OLD.is_excluded IS NOT DISTINCT FROM NEW.is_excluded THEN
    RETURN NULL;
  END IF;

  UPDATE words w
  SET
    total_contributions = c.total,
    unique_contributors = c.contributors
  FROM (
    SELECT
      wid,
      (SELECT count(*) FROM contributions
        WHERE word_id = wid AND is_excluded = false)::int AS total,
      (SELECT count(DISTINCT user_id) FROM contributions
        WHERE word_id = wid AND is_excluded = false)::int AS contributors
    FROM unnest(CASE TG_OP
      WHEN 'INSERT' THEN ARRAY[NEW.word_id]
      WHEN 'DELETE' THEN ARRAY[OLD.word_id]
      ELSE ARRAY[OLD.word_id, NEW.word_id]
    END) AS wid
  ) c
  WHERE w.id = c.wid;

  RETURN NULL;
END;
$function$;

-- Duplicate of update_word_contribution_counts().
DROP TRIGGER IF EXISTS update_unique_contributors_trigger ON public.contributions;
DROP FUNCTION IF EXISTS public.update_unique_contributors();

-- Keeps the profile half; words.total_contributions is no longer its job.
CREATE OR REPLACE FUNCTION public.increment_contribution_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE profiles
  SET
    contribution_count = contribution_count + 1,
    last_contribution_date = CURRENT_DATE
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$function$;

-- --- Comment edits: delete the old votes after the update, as definer -------

CREATE OR REPLACE FUNCTION public.reset_comment_votes_on_edit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- The votes themselves are deleted by delete_comment_votes_on_edit() once
  -- this update has happened; deleting them here, in a BEFORE trigger, would
  -- make the vote counter update this same row mid-update.
  IF OLD.comment_text IS DISTINCT FROM NEW.comment_text THEN
    NEW.upvote_count = 0;
    NEW.downvote_count = 0;
    NEW.net_votes = 0;
    NEW.updated_at = now();
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.delete_comment_votes_on_edit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.comment_text IS DISTINCT FROM NEW.comment_text THEN
    DELETE FROM comment_votes WHERE comment_id = NEW.id;
  END IF;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS delete_votes_on_comment_edit ON public.comments;
CREATE TRIGGER delete_votes_on_comment_edit
  AFTER UPDATE OF comment_text ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.delete_comment_votes_on_edit();

-- --- Flags: one per member; flagged comments hidden ------------------------

-- user_id references auth.users, not profiles: a second comments<->profiles
-- path would make the app's `profile:profiles(...)` embeds on comments
-- ambiguous in PostgREST (PGRST201).
CREATE TABLE IF NOT EXISTS public.comment_flags (
  comment_id uuid NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_id)
);

-- Written only by increment_comment_flags(); no member access.
ALTER TABLE public.comment_flags ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.comment_flags FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.increment_comment_flags(comment_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  caller uuid := auth.uid();
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- One flag per member per comment, and not on your own comment. Flags
  -- counted before this migration have no per-member record and are kept.
  INSERT INTO comment_flags (comment_id, user_id)
  SELECT c.id, caller FROM comments c
  WHERE c.id = comment_uuid AND c.user_id <> caller
  ON CONFLICT DO NOTHING;

  IF FOUND THEN
    UPDATE comments
    SET flag_count = coalesce(flag_count, 0) + 1
    WHERE id = comment_uuid;
  END IF;
END;
$function$;

-- Two policies so anon never evaluates is_current_user_admin(), which only
-- authenticated may execute. Policies for the same command are OR'd.
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON public.comments;
DROP POLICY IF EXISTS "Unflagged comments are viewable by everyone" ON public.comments;
CREATE POLICY "Unflagged comments are viewable by everyone"
  ON public.comments FOR SELECT
  USING (is_flagged IS NOT TRUE);

DROP POLICY IF EXISTS "Authors and admins can view flagged comments" ON public.comments;
CREATE POLICY "Authors and admins can view flagged comments"
  ON public.comments FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR public.is_current_user_admin());

-- --- #11: members write only their own editable columns --------------------

REVOKE INSERT, UPDATE ON public.contributions FROM anon, authenticated;
GRANT INSERT (word_id, user_id, english_gloss, audio_url, confidence, notes, agreement_type)
  ON public.contributions TO authenticated;
GRANT UPDATE (word_id, user_id, english_gloss, audio_url, confidence, notes, agreement_type)
  ON public.contributions TO authenticated;

DROP POLICY IF EXISTS "Users can update own contributions" ON public.contributions;
CREATE POLICY "Users can update own contributions"
  ON public.contributions FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

REVOKE INSERT, UPDATE ON public.comments FROM anon, authenticated;
GRANT INSERT (word_id, user_id, comment_text) ON public.comments TO authenticated;
GRANT UPDATE (comment_text) ON public.comments TO authenticated;

DROP POLICY IF EXISTS "Users can update their own comments" ON public.comments;
CREATE POLICY "Users can update their own comments"
  ON public.comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- --- One-off recompute of derived counters ---------------------------------
-- Every value below is derived from rows that already exist. updated_at
-- triggers are paused so the recompute doesn't look like an edit.

ALTER TABLE public.words DISABLE TRIGGER update_words_updated_at;
UPDATE public.words w
SET
  total_contributions = coalesce(c.total, 0),
  unique_contributors = coalesce(c.contributors, 0)
FROM public.words w2
LEFT JOIN (
  SELECT word_id, count(*)::int AS total, count(DISTINCT user_id)::int AS contributors
  FROM public.contributions
  WHERE is_excluded = false
  GROUP BY word_id
) c ON c.word_id = w2.id
WHERE w.id = w2.id
  AND (w.total_contributions IS DISTINCT FROM coalesce(c.total, 0)
       OR w.unique_contributors IS DISTINCT FROM coalesce(c.contributors, 0));
ALTER TABLE public.words ENABLE TRIGGER update_words_updated_at;

ALTER TABLE public.contributions DISABLE TRIGGER update_contributions_updated_at;
UPDATE public.contributions ct
SET upvote_count = v.votes, net_votes = v.votes
FROM (
  SELECT ct2.id, count(cv.id)::int AS votes
  FROM public.contributions ct2
  LEFT JOIN public.contribution_votes cv ON cv.contribution_id = ct2.id
  GROUP BY ct2.id
) v
WHERE ct.id = v.id
  AND (ct.upvote_count IS DISTINCT FROM v.votes OR ct.net_votes IS DISTINCT FROM v.votes);
ALTER TABLE public.contributions ENABLE TRIGGER update_contributions_updated_at;

-- comments has no updated_at trigger; reset_comment_votes_on_edit() only acts
-- when comment_text changes.
UPDATE public.comments cm
SET upvote_count = v.up, downvote_count = v.down, net_votes = v.up - v.down
FROM (
  SELECT cm2.id,
    count(*) FILTER (WHERE cv.vote_type = 1)::int AS up,
    count(*) FILTER (WHERE cv.vote_type = -1)::int AS down
  FROM public.comments cm2
  LEFT JOIN public.comment_votes cv ON cv.comment_id = cm2.id
  GROUP BY cm2.id
) v
WHERE cm.id = v.id
  AND (cm.upvote_count IS DISTINCT FROM v.up
       OR cm.downvote_count IS DISTINCT FROM v.down
       OR cm.net_votes IS DISTINCT FROM v.up - v.down);
