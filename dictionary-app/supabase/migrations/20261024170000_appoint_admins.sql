-- =============================================================================
-- 20261024170000 — Appoint and remove admins from /admin (#64)
--
-- Until now is_admin could only be set by a migration (#63 bootstrapped
-- Trevor). This lets an admin appoint and remove other admins, with the
-- safeguards enforced here rather than only in the UI:
--
--   * At least one active admin always remains. A trigger on profiles refuses
--     any UPDATE or DELETE that would leave none: removing the flag, suspending
--     or banning the last active admin, or deleting their account. It applies
--     to every path, the service role and migrations included.
--   * Only active, email-confirmed members can become admin, also enforced by
--     that trigger whenever is_admin turns on.
--   * grant_admin() / revoke_admin() make the change, record who appointed
--     whom in admin_appointments and write moderation_log, in one transaction.
--     Only the service role can call them; the server actions check the caller
--     is an admin first, and the functions check again.
--
-- Safe with the current app code: it only adds enum values, a table, two
-- functions and a trigger. Existing actions keep working; the one new refusal
-- (suspending or banning the last active admin) can't happen on production,
-- which has one admin after #63, unless they target themselves.
-- Idempotent: IF NOT EXISTS / CREATE OR REPLACE / DROP ... IF EXISTS.
-- =============================================================================

-- --- Moderation log actions --------------------------------------------------
-- ADD VALUE can't be used in the transaction that adds it, but the functions
-- below are plpgsql, so the values are only resolved when they run.
ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'grant_admin';
ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'revoke_admin';

-- --- Who appointed whom ------------------------------------------------------
-- One row per current appointed admin. Admins made before this table existed
-- (e.g. by #63's migration) have no row; /admin shows them without a date.
-- welcomed_at is null until the new admin first opens /admin (the banner).
-- History lives in moderation_log; a removal deletes the row.
CREATE TABLE IF NOT EXISTS public.admin_appointments (
  user_id      uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  appointed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  appointed_at timestamptz NOT NULL DEFAULT now(),
  welcomed_at  timestamptz
);

-- Service role only: the anon key ships in the client bundle.
ALTER TABLE public.admin_appointments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.admin_appointments FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.admin_appointments TO service_role;

-- --- Invariant: eligible admins, and never zero of them ----------------------
CREATE OR REPLACE FUNCTION public.guard_admin_membership()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  was_active_admin boolean;
  is_active_admin  boolean;
BEGIN
  was_active_admin := OLD.is_admin AND OLD.status NOT IN ('suspended', 'banned');

  IF TG_OP = 'UPDATE' THEN
    -- Becoming an admin: only an active member with a confirmed email.
    IF NEW.is_admin AND NOT OLD.is_admin THEN
      IF NEW.status NOT IN ('active', 'warned') THEN
        RAISE EXCEPTION 'Only active members can be made admin.'
          USING ERRCODE = 'check_violation';
      END IF;
      IF NOT EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = NEW.id AND u.email_confirmed_at IS NOT NULL
      ) THEN
        RAISE EXCEPTION 'Only members who have confirmed their email can be made admin.'
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;

    is_active_admin := NEW.is_admin AND NEW.status NOT IN ('suspended', 'banned');
  ELSE
    is_active_admin := false;
  END IF;

  -- Losing an active admin: someone else must still be one. The lock
  -- serialises concurrent removals, so two admins can't each remove the other.
  IF was_active_admin AND NOT is_active_admin THEN
    PERFORM pg_advisory_xact_lock(hashtext('public.guard_admin_membership'));
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.is_admin
        AND p.status NOT IN ('suspended', 'banned')
        AND p.id <> OLD.id
    ) THEN
      RAISE EXCEPTION 'The last admin can''t be removed. Make someone else an admin first.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS guard_admin_membership ON public.profiles;
CREATE TRIGGER guard_admin_membership
  BEFORE UPDATE OF is_admin, status OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_admin_membership();

REVOKE ALL ON FUNCTION public.guard_admin_membership() FROM PUBLIC, anon, authenticated;

-- --- Shared: the caller must be an active admin --------------------------------
CREATE OR REPLACE FUNCTION public.assert_active_admin(p_actor uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_actor AND is_admin AND status IN ('active', 'warned')
  ) THEN
    RAISE EXCEPTION 'Admin access required.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.assert_active_admin(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assert_active_admin(uuid) TO service_role;

-- --- Make admin -----------------------------------------------------------------
-- Returns false if the member was already an admin (nothing changes, nothing
-- is logged), true if they were appointed.
CREATE OR REPLACE FUNCTION public.grant_admin(p_target uuid, p_actor uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  target_is_admin boolean;
BEGIN
  PERFORM public.assert_active_admin(p_actor);

  SELECT is_admin INTO target_is_admin FROM public.profiles WHERE id = p_target FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found.' USING ERRCODE = 'no_data_found';
  END IF;
  IF target_is_admin THEN
    RETURN false;
  END IF;

  -- guard_protected_profile_columns only lets the service role change is_admin.
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);

  -- guard_admin_membership refuses inactive or unconfirmed members here.
  UPDATE public.profiles SET is_admin = true WHERE id = p_target;

  INSERT INTO public.admin_appointments (user_id, appointed_by, appointed_at, welcomed_at)
  VALUES (p_target, p_actor, now(), NULL)
  ON CONFLICT (user_id) DO UPDATE
    SET appointed_by = EXCLUDED.appointed_by,
        appointed_at = EXCLUDED.appointed_at,
        welcomed_at  = NULL;

  INSERT INTO public.moderation_log (admin_id, target_user_id, action, reason)
  VALUES (p_actor, p_target, 'grant_admin', 'Made admin');

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.grant_admin(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.grant_admin(uuid, uuid) TO service_role;

-- --- Remove admin ----------------------------------------------------------------
-- Returns false if the member wasn't an admin. The last active admin can't be
-- removed (guard_admin_membership), including by themselves.
CREATE OR REPLACE FUNCTION public.revoke_admin(p_target uuid, p_actor uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  target_is_admin boolean;
BEGIN
  PERFORM public.assert_active_admin(p_actor);

  SELECT is_admin INTO target_is_admin FROM public.profiles WHERE id = p_target FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found.' USING ERRCODE = 'no_data_found';
  END IF;
  IF NOT target_is_admin THEN
    RETURN false;
  END IF;

  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);

  UPDATE public.profiles SET is_admin = false WHERE id = p_target;

  DELETE FROM public.admin_appointments WHERE user_id = p_target;

  INSERT INTO public.moderation_log (admin_id, target_user_id, action, reason)
  VALUES (p_actor, p_target, 'revoke_admin',
          CASE WHEN p_target = p_actor THEN 'Stepped down as admin' ELSE 'Removed as admin' END);

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.revoke_admin(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_admin(uuid, uuid) TO service_role;
