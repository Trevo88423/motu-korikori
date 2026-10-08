-- =============================================================================
-- 20261008000001 — Stop publishing contributor emails (audit finding 8 / §2.1)
--
-- profiles carries a policy "Anyone can view profiles for leaderboard",
-- FOR SELECT USING (true), with no column restriction. The anon key is public —
-- it ships inside the client JavaScript bundle — so any visitor could read every
-- contributor's email, guardian_email, age_range, locations and who_taught.
-- Verified live against production: querying as the anon role returned every
-- profile row with emails intact.
--
-- RLS cannot restrict columns, so the fix is column-level SELECT grants.
-- The policy is left in place: rows stay visible, but anon can only read the
-- columns the public pages actually render.
--
-- Columns granted below are exactly what anon-reachable queries select:
--   app/leaderboard/page.tsx:12          id, name, contribution_count,
--                                        connection_type, trust_score, status
--   app/dictionary/page.tsx:76           connection_type
--   app/dictionary/[id]/page.tsx:55,65   name, connection_type, trust_score
--   lib/consensus.ts:190                 connection_type, trust_score
--   lib/consensus.ts:297                 id, contribution_count
-- The one select('*') on profiles reachable from the leaderboard is guarded by
-- `if (user && ...)` (app/leaderboard/page.tsx:21), so it only ever runs as
-- `authenticated` and is unaffected.
--
-- is_admin is deliberately NOT granted: finding 6's attack began with
-- GET /rest/v1/profiles?is_admin=eq.true to locate an administrator.
--
-- NOTE: `authenticated` keeps full SELECT, because getCurrentUserProfile
-- (lib/supabase.ts:102) reads the caller's own row with select('*') and column
-- grants are role-wide, not row-aware. A signed-in user can therefore still read
-- other members' emails. Closing that needs an explicit column list there plus a
-- separate projection for other people's rows — tracked, not done here.
-- =============================================================================

REVOKE SELECT ON public.profiles FROM anon;

GRANT SELECT (
  id,
  name,
  connection_type,
  trust_score,
  contribution_count,
  status
) ON public.profiles TO anon;
