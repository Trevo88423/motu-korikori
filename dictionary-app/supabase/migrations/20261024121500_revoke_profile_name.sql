-- =============================================================================
-- 20261024121500 — Stop the API returning contributors' full names (issue #13,
-- part 2 of 2)
--
-- Part 1 (20261024121300_display_names) added display_name and moved every
-- public and signed-in read onto it. This removes name from the anon and
-- authenticated SELECT grants, so the full name can't be read through the API
-- at all. A member still sees their own full row through get_my_profile()
-- (SECURITY DEFINER), and can still update their own name.
--
-- Depends on part 1's app code being live: the code before it selected name.
-- =============================================================================

REVOKE SELECT ON public.profiles FROM anon, authenticated;

GRANT SELECT (
  id,
  display_name,
  connection_type,
  trust_score,
  contribution_count,
  status
) ON public.profiles TO anon, authenticated;
