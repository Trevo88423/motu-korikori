-- =============================================================================
-- 20261024160000 — Make Trevor the first admin
--
-- Production had no admin accounts, so nobody could reach /admin: moderation,
-- the consensus backfill (#28) or the exceptions list. This bootstraps the
-- project owner (Trevor, at his request, 2026-10-24) by user id rather than
-- email, so no address is published in the repo. Further admins are appointed
-- from /admin (see the assign-admin issue), not by migration.
--
-- guard_protected_profile_columns() blocks is_admin changes unless the request
-- claims the service_role, so the claim is set for this transaction only.
-- Idempotent: re-running changes nothing. On a database without this user
-- (e.g. local) it updates 0 rows.
--
-- Also hardens the guard: once a connection has used set_config on
-- request.jwt.claims, current_setting() returns '' (not NULL) after the
-- transaction, and ''::jsonb raised "invalid input syntax for type json" on
-- every later profiles UPDATE in that connection, e.g. a later migration in
-- the same `db push`. nullif() treats it as "no claims". Logic otherwise
-- unchanged from 20261024090000.
-- =============================================================================

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

SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);

UPDATE public.profiles
SET is_admin = true
WHERE id = 'bb995417-5e24-49e2-9eda-d5c76a1c60b0'
  AND is_admin IS DISTINCT FROM true;
