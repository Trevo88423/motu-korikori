-- =============================================================================
-- 20261023040436 — Own-profile function and admin policies that don't read
-- profiles.is_admin as the caller (issue #4, part 1 of 2)
--
-- Prepares for revoking authenticated's table-wide SELECT on profiles, which
-- lets any signed-in member read every member's email, guardian_email,
-- age_range, locations, who_taught and is_admin. Part 2 is the revoke itself;
-- it ships in a later PR, after the app code from this PR has deployed,
-- because the old code reads its own row with select('*').
--
-- Column grants are role-wide, not row-aware, so a member's own full row moves
-- behind get_my_profile(), a SECURITY DEFINER function that only ever returns
-- the caller's row.
--
-- RLS policies run with the caller's privileges. Four admin policies read
-- profiles.is_admin inline and would hit "permission denied" once that column
-- is revoked, so they switch to is_current_user_admin() (SECURITY DEFINER,
-- already used by the profiles admin policies).
--
-- Everything here is additive: safe with the previous app code still serving.
-- =============================================================================

-- 1. A member's own full profile.
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS public.profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT * FROM public.profiles WHERE id = auth.uid()
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

-- 2. Admin policies: stop reading profiles.is_admin as the caller.
ALTER POLICY "Admins can manage words" ON public.words
  USING (public.is_current_user_admin());

ALTER POLICY "Admins can manage all contributions" ON public.contributions
  USING (public.is_current_user_admin());

ALTER POLICY "Admins can view moderation log" ON public.moderation_log
  USING (public.is_current_user_admin());

ALTER POLICY "Admins can insert moderation log" ON public.moderation_log
  WITH CHECK (public.is_current_user_admin());
