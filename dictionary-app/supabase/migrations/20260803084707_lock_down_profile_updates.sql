-- =============================================================================
-- 20260803_01 — Lock down profile updates (audit findings 1 and 6)
--
-- Finding 1: "Users can update own profile" had USING (auth.uid() = id) and NO
--   WITH CHECK. Postgres reuses USING as the check, so the only invariant was
--   "the id still equals my uid" — every other column was freely writable, and
--   `authenticated` held UPDATE on all 25 columns. Any signed-in user could
--   PATCH themselves to is_admin = true.
--
-- Finding 6: production's admin policies had drifted to
--   ((auth.uid() = id) OR (is_admin = true)). An unqualified column in a policy
--   refers to the ROW BEING SCANNED, not the caller — so the predicate meant
--   "visible if this row is an admin row". With roles={public} that also
--   applied to anon.
--
-- Privileged columns (is_admin, status, trust_score, ...) are henceforth
-- writable only via the service-role key. app/admin/actions.ts uses
-- createAdminClient() for exactly that, gated by its own requireAdmin() check.
-- =============================================================================

-- --- Column grants: users may edit only their own descriptive fields ---------
REVOKE UPDATE ON public.profiles FROM anon, authenticated;

GRANT UPDATE (name, locations, who_taught, connection_type, age_range)
  ON public.profiles TO authenticated;

-- --- Caller-identity helper (avoids policy self-recursion on profiles) ------
CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT coalesce((SELECT is_admin FROM public.profiles WHERE id = auth.uid()), false)
$$;

REVOKE ALL ON FUNCTION public.is_current_user_admin() FROM public;
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO authenticated;

-- --- Self-update policy: add the missing WITH CHECK, scope to authenticated --
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- --- Admin policies: test the CALLER, not the scanned row -------------------
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (public.is_current_user_admin());

DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
CREATE POLICY "Admins can update any profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- --- Defence in depth: reject privileged-column edits from non-service roles -
CREATE OR REPLACE FUNCTION public.guard_protected_profile_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- service_role bypasses this guard; everyone else is held to the invariant.
  IF current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role' THEN
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
$$;

DROP TRIGGER IF EXISTS guard_protected_profile_columns ON public.profiles;
CREATE TRIGGER guard_protected_profile_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_protected_profile_columns();
