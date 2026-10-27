-- =============================================================================
-- 20261027093325 — Derive is_18_or_older from age_range (issue #79, part of #12)
--
-- Signup asked for age twice (an age range, then an "18 or older?" radio) and
-- stored the radio exactly as the client sent it. Someone who picked
-- "Under 18" could switch the radio and skip the guardian step; a direct
-- auth API call could send anything.
--
-- Now the age range decides: under_18 is a minor, every other range is an
-- adult, and only prefer_not_to_say keeps the submitted flag. A new minor
-- without guardian details is refused.
--
-- The trigger is named so it sorts before normalize_display_name and
-- reject_blocked_display_name (BEFORE triggers fire in name order), which both
-- read is_18_or_older.
--
-- Additive: the previous app code sends values this accepts.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.derive_is_18_or_older()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.age_range = 'under_18' THEN
    NEW.is_18_or_older := false;
  ELSIF NEW.age_range <> 'prefer_not_to_say' THEN
    NEW.is_18_or_older := true;
  ELSE
    NEW.is_18_or_older := coalesce(NEW.is_18_or_older, false);
  END IF;

  IF TG_OP = 'INSERT'
     AND NOT NEW.is_18_or_older
     AND (nullif(btrim(coalesce(NEW.guardian_name, '')), '') IS NULL
          OR nullif(btrim(coalesce(NEW.guardian_email, '')), '') IS NULL)
  THEN
    RAISE EXCEPTION 'profiles: guardian name and email are required for members under 18'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS derive_is_18_or_older ON public.profiles;
CREATE TRIGGER derive_is_18_or_older
  BEFORE INSERT OR UPDATE OF age_range, is_18_or_older ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.derive_is_18_or_older();

-- Existing rows where the two answers disagree: the age range wins.
UPDATE public.profiles
SET is_18_or_older = (age_range <> 'under_18')
WHERE age_range <> 'prefer_not_to_say'
  AND is_18_or_older IS DISTINCT FROM (age_range <> 'under_18');
