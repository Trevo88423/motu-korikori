-- 20261024121400 — Suspended and banned members can't write (#14)
--
-- The app now checks profiles.status on every protected page and server
-- action (lib/auth.ts), but the anon key ships in the client bundle, so a
-- member's own access token can still reach PostgREST directly until it
-- expires. Only the contributions INSERT policy checked status. This adds the
-- same check to every member write: contributions, comments, votes, flags and
-- word completions.
--
-- Safe with the current app: active and warned members pass exactly as before;
-- admin moderation writes use the service role and bypass RLS.

-- --- Helper ----------------------------------------------------------------
-- SECURITY DEFINER so policies don't depend on the caller's column grants on
-- profiles. Answers only for the caller.
CREATE OR REPLACE FUNCTION public.is_current_user_active()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT coalesce(
    (SELECT status IN ('active', 'warned') FROM public.profiles WHERE id = auth.uid()),
    false
  )
$$;

REVOKE ALL ON FUNCTION public.is_current_user_active() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_active() TO authenticated;

-- --- Ending a member's sessions ---------------------------------------------
-- Called by the admin actions (service role only) after blocking a member in
-- Supabase Auth. The Auth block already refuses their tokens; deleting the
-- sessions (refresh tokens cascade) means a later reinstatement doesn't bring
-- old sessions back to life.
CREATE OR REPLACE FUNCTION public.revoke_user_sessions(target_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  DELETE FROM auth.sessions WHERE user_id = target_user_id;
$$;

REVOKE ALL ON FUNCTION public.revoke_user_sessions(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_user_sessions(uuid) TO service_role;

-- --- Moderation log: admins can record a reinstatement ---------------------
ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'reinstate';

-- --- Contributions -----------------------------------------------------------
ALTER POLICY "Users can insert own contributions" ON public.contributions
  WITH CHECK (auth.uid() = user_id AND public.is_current_user_active());

ALTER POLICY "Users can update own contributions" ON public.contributions
  USING (auth.uid() = user_id AND public.is_current_user_active())
  WITH CHECK (auth.uid() = user_id AND public.is_current_user_active());

ALTER POLICY "Users can delete own contributions" ON public.contributions
  USING (auth.uid() = user_id AND public.is_current_user_active());

-- --- Comments ----------------------------------------------------------------
ALTER POLICY "Users can insert their own comments" ON public.comments
  WITH CHECK (auth.uid() = user_id AND public.is_current_user_active());

ALTER POLICY "Users can update their own comments" ON public.comments
  USING (auth.uid() = user_id AND public.is_current_user_active())
  WITH CHECK (auth.uid() = user_id AND public.is_current_user_active());

ALTER POLICY "Users can delete their own comments" ON public.comments
  USING (auth.uid() = user_id AND public.is_current_user_active());

-- --- Votes -------------------------------------------------------------------
ALTER POLICY "Users can vote on comments" ON public.comment_votes
  WITH CHECK (
    auth.uid() = user_id
    AND auth.uid() <> (SELECT comments.user_id FROM public.comments WHERE comments.id = comment_votes.comment_id)
    AND public.is_current_user_active()
  );

ALTER POLICY "Users can delete their own comment votes" ON public.comment_votes
  USING (auth.uid() = user_id AND public.is_current_user_active());

ALTER POLICY "Users can vote on contributions" ON public.contribution_votes
  WITH CHECK (
    auth.uid() = user_id
    AND auth.uid() <> (SELECT contributions.user_id FROM public.contributions WHERE contributions.id = contribution_votes.contribution_id)
    AND public.is_current_user_active()
  );

ALTER POLICY "Users can delete their own contribution votes" ON public.contribution_votes
  USING (auth.uid() = user_id AND public.is_current_user_active());

-- --- Word completions --------------------------------------------------------
ALTER POLICY "Users can insert own completions" ON public.user_word_completion
  WITH CHECK (auth.uid() = user_id AND public.is_current_user_active());

ALTER POLICY "Users can delete own completions" ON public.user_word_completion
  USING (auth.uid() = user_id AND public.is_current_user_active());

-- --- Flags -------------------------------------------------------------------
-- Same body as 20261024100016, plus the status check.
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

  IF NOT public.is_current_user_active() THEN
    RAISE EXCEPTION 'Account suspended or banned' USING ERRCODE = 'insufficient_privilege';
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
