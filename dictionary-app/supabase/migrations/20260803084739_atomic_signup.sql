-- =============================================================================
-- 20260803_02 — Make signup atomic (audit finding 2)
--
-- Signup performed two independent writes: supabase.auth.signUp created the
-- auth.users row, then a separate client-initiated call inserted the profile.
-- Nothing rolled back the first write when the second failed, and the client
-- fallback was dead code. Result in production: 8 auth users, 2 profiles —
-- every signup between 2026-01-25 and 2026-06-11 left an unusable shell account
-- whose email could never be re-registered.
--
-- The profile is now created by a trigger inside the same transaction as the
-- auth.users insert, from the metadata passed to signUp({ options: { data } }).
-- Either both rows exist or neither does.
--
-- Also adds guardian_consent, which exists in production but in no repo SQL
-- file (audit finding 15) — without it a fresh environment orphans 100% of
-- signups.
-- =============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS guardian_consent boolean NOT NULL DEFAULT false;

-- --- Enum-safe casts: never raise inside the auth transaction ---------------
CREATE OR REPLACE FUNCTION public.safe_age_range(v text)
RETURNS age_range LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN v::age_range;
EXCEPTION WHEN others THEN
  RETURN 'prefer_not_to_say'::age_range;
END;
$$;

CREATE OR REPLACE FUNCTION public.safe_connection_type(v text)
RETURNS connection_type LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN v::connection_type;
EXCEPTION WHEN others THEN
  RETURN 'other'::connection_type;
END;
$$;

-- --- Create the profile in the same transaction as the auth user ------------
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
    id, email, name, age_range, locations, connection_type, who_taught,
    consent_tos, consent_dictionary, consent_ai_training,
    is_18_or_older, guardian_name, guardian_email, guardian_consent,
    status, trust_score, contribution_count, is_admin
  )
  VALUES (
    NEW.id,
    NEW.email,
    left(trim(coalesce(meta ->> 'name', '')), 100),
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
