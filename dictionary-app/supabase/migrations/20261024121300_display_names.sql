-- =============================================================================
-- 20261024121300 — Public display names instead of full names (issue #13,
-- part 1 of 2)
--
-- profiles.name is the full name signup collects, and the leaderboard shows it
-- to anyone, minors included. This adds display_name: chosen at signup
-- (optional), editable later, and defaulting to the first word of name. Public
-- pages switch to it in the same PR.
--
-- Part 2 revokes SELECT on name from anon and authenticated. It ships in a
-- later PR, after the app code from this PR has deployed, because the old code
-- still selects name.
--
-- Everything here is additive: safe with the previous app code still serving.
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name text;

-- Tidy whatever was submitted and fill in a default. Under-18s can't use their
-- full name; they fall back to the first name. (is_18_or_older is
-- self-asserted at signup until the safeguarding work in #12.)
CREATE OR REPLACE FUNCTION public.normalize_display_name()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  full_name text := btrim(regexp_replace(coalesce(NEW.name, ''), '\s+', ' ', 'g'));
  first_name text := left(split_part(full_name, ' ', 1), 40);
BEGIN
  NEW.display_name := left(btrim(regexp_replace(coalesce(NEW.display_name, ''), '\s+', ' ', 'g')), 40);

  IF NOT coalesce(NEW.is_18_or_older, false)
     AND position(' ' IN full_name) > 0
     AND lower(NEW.display_name) = lower(full_name)
  THEN
    NEW.display_name := first_name;
  END IF;

  IF NEW.display_name = '' THEN
    NEW.display_name := first_name;
  END IF;

  IF NEW.display_name = '' THEN
    NEW.display_name := 'Member';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS normalize_display_name ON public.profiles;
CREATE TRIGGER normalize_display_name
  BEFORE INSERT OR UPDATE OF display_name, name, is_18_or_older ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.normalize_display_name();

-- Existing rows: the trigger fills in the first name.
UPDATE public.profiles SET display_name = '' WHERE display_name IS NULL;

ALTER TABLE public.profiles ALTER COLUMN display_name SET NOT NULL;

GRANT SELECT (display_name) ON public.profiles TO anon, authenticated;
GRANT UPDATE (display_name) ON public.profiles TO authenticated;

-- Signup: same as 20260803084739_atomic_signup, plus display_name from the
-- signup metadata (the trigger above defaults it when it's missing).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  meta jsonb := coalesce(NEW.raw_user_meta_data, '{}'::jsonb);
  locs text[];
BEGIN
  IF jsonb_typeof(meta -> 'locations') = 'array' THEN
    SELECT array_agg(value) INTO locs
    FROM jsonb_array_elements_text(meta -> 'locations') AS value
    WHERE length(trim(value)) > 0;
  END IF;

  INSERT INTO public.profiles (
    id, email, name, display_name, age_range, locations, connection_type, who_taught,
    consent_tos, consent_dictionary, consent_ai_training,
    is_18_or_older, guardian_name, guardian_email, guardian_consent,
    status, trust_score, contribution_count, is_admin
  )
  VALUES (
    NEW.id,
    NEW.email,
    left(trim(coalesce(meta ->> 'name', '')), 100),
    coalesce(meta ->> 'display_name', ''),
    public.safe_age_range(meta ->> 'age_range'),
    coalesce(locs, '{}'::text[]),
    public.safe_connection_type(meta ->> 'connection_type'),
    nullif(trim(coalesce(meta ->> 'who_taught', '')), ''),
    coalesce((meta ->> 'consent_tos')::boolean, false),
    coalesce((meta ->> 'consent_dictionary')::boolean, false),
    coalesce((meta ->> 'consent_ai_training')::boolean, false),
    coalesce((meta ->> 'is_18_or_older')::boolean, false),
    nullif(trim(coalesce(meta ->> 'guardian_name', '')), ''),
    nullif(trim(coalesce(meta ->> 'guardian_email', '')), ''),
    false,          -- guardian_consent is never self-asserted; see finding 7
    'active', 1.0, 0, false
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;
