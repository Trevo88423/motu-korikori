-- =============================================================================
-- 20261103120000 — Signed-out visitors see a word's contributions (#30)
--
-- contributions had one SELECT policy, auth.uid() IS NOT NULL, so a visitor
-- opening a word saw "7 contributions" in the header and "No contributions
-- yet" below it. This adds a visitor (anon) policy, limited by the rules on
-- record in docs/DECISIONS.md:
--   * not excluded, not hidden by flags (#56)
--   * its author is active (or warned), not suspended or banned
--   * its author consented to the public dictionary (consent_dictionary)
--   * an author under 18 has guardian consent (#12)
--   * its author is established (2026-10-24 decision): a New contributor's
--     entries stay members-only until the community has seen them
--
-- is_established_contributor(uuid) is the one place "established" is decided.
-- The trust ladder (#53) will replace its body with "level is Member or
-- above"; until then, an author is established once at least one of their
-- visible entries matches the consensus and none of their flags was upheld.
--
-- Column grants: anon keeps SELECT only on the columns the word page renders,
-- and loses every write privilege (RLS already refused anon writes).
--
-- Signed-in members are unchanged: they still see every entry that isn't
-- hidden, plus their own hidden ones.
-- =============================================================================

-- --- Who counts as established ---------------------------------------------

-- The trust ladder (#53) will replace this body; everything else calls it.
CREATE OR REPLACE FUNCTION public.is_established_contributor(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
           SELECT 1
           FROM public.contributions c
           WHERE c.user_id = p_user
             AND c.matches_consensus
             AND NOT c.is_excluded
             AND NOT c.is_hidden
         )
     AND coalesce((SELECT r.flags_upheld
                   FROM public.member_flag_record r
                   WHERE r.user_id = p_user), 0) = 0
$$;

REVOKE ALL ON FUNCTION public.is_established_contributor(uuid) FROM PUBLIC, anon, authenticated;

-- --- What a visitor may see ------------------------------------------------

-- Takes a contribution id rather than a user id, so calling it through the API
-- tells a visitor nothing about a member (consent, age) that the visitor
-- policy below doesn't already show by returning the row or not.
CREATE OR REPLACE FUNCTION public.contribution_is_public(p_contribution uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce((
    SELECT NOT c.is_excluded
       AND NOT c.is_hidden
       AND p.status IN ('active', 'warned')
       AND p.consent_dictionary
       AND (p.is_18_or_older OR coalesce(p.guardian_consent, false))
       AND public.is_established_contributor(c.user_id)
    FROM public.contributions c
    JOIN public.profiles p ON p.id = c.user_id
    WHERE c.id = p_contribution
  ), false)
$$;

REVOKE ALL ON FUNCTION public.contribution_is_public(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.contribution_is_public(uuid) TO anon, authenticated;

DROP POLICY IF EXISTS "Visitors can view public contributions" ON public.contributions;
CREATE POLICY "Visitors can view public contributions"
  ON public.contributions FOR SELECT
  TO anon
  USING (NOT is_excluded AND NOT is_hidden AND public.contribution_is_public(id));

-- --- Columns a visitor may read --------------------------------------------

REVOKE ALL ON public.contributions FROM anon;

GRANT SELECT (
  id,
  word_id,
  user_id,
  english_gloss,
  audio_url,
  confidence,
  notes,
  is_excluded,
  is_hidden,
  agreement_type,
  created_at
) ON public.contributions TO anon;
