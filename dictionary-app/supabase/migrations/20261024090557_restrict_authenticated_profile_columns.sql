-- =============================================================================
-- 20261024090557 — Stop signed-in members reading each other's private fields
-- (issue #4, part 2 of 2)
--
-- 20261008000001 limited `anon` to the public profile columns but left
-- `authenticated` with table-wide SELECT. Combined with the policy
-- "Anyone can view profiles for leaderboard" (USING true), anyone who signed up
-- could read every member's email, guardian_email, age_range, locations,
-- who_taught and is_admin.
--
-- Depends on part 1 (20261023040436_profile_access_helpers), which is live: the
-- app reads its own full row through get_my_profile(), and the admin policies
-- no longer read profiles.is_admin as the caller.
--
-- SECURITY DEFINER functions (get_my_profile, is_current_user_admin, the
-- counter triggers, the signup trigger) run as the owner and are unaffected.
-- =============================================================================

REVOKE SELECT ON public.profiles FROM authenticated;

GRANT SELECT (
  id,
  name,
  connection_type,
  trust_score,
  contribution_count,
  status
) ON public.profiles TO authenticated;
