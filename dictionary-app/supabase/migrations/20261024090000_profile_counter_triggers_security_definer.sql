-- =============================================================================
-- 20261024090000 — Let contributions, comments and votes through again (issue #5)
--
-- 20260803084707_lock_down_profile_updates left `authenticated` with UPDATE on
-- only five profiles columns. These trigger functions update other profile
-- columns (contribution_count, last_contribution_date, trust_score) and were
-- SECURITY INVOKER, so they ran as the signed-in user and failed with
-- "permission denied for table profiles", aborting the insert that fired them.
-- Every contribution, comment and vote has been rejected since then.
--
-- Two layers block them, and both need fixing:
--   1. Privilege: the functions run as the caller, who may only UPDATE five
--      columns. Fix: SECURITY DEFINER. Each function only touches the profile
--      of the user named on the row that fired it, and all four pin
--      search_path, so this doesn't widen what a user can write.
--   2. guard_protected_profile_columns() rejects changes to contribution_count
--      and trust_score unless the request's JWT role is service_role. It
--      checks who made the request, not which code is writing, so it blocks
--      these trusted triggers too. Fix: let changes made from inside another
--      trigger through (pg_trigger_depth() > 1). A member's own UPDATE on
--      profiles fires the guard at depth 1 and is still checked; members
--      can't create triggers, so they can't reach depth > 1 on purpose.
-- The column grants from the lockdown stay as they are.
-- =============================================================================

ALTER FUNCTION public.increment_contribution_count() SECURITY DEFINER;
ALTER FUNCTION public.update_profile_contribution_count() SECURITY DEFINER;
ALTER FUNCTION public.update_contribution_count_on_comment() SECURITY DEFINER;
ALTER FUNCTION public.update_author_trust_on_vote() SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.guard_protected_profile_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- service_role bypasses this guard; everyone else is held to the invariant.
  IF current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role' THEN
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
