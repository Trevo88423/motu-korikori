-- =============================================================================
-- 20261024100000 — Skip on /contribute moves to a different word (issue #31)
--
-- get_next_word_for_user picked ORDER BY frequency * random() DESC, which lets
-- the most frequent word (e, 45,342) win most of the time, so Skip kept
-- showing it. It also trusted a user_uuid argument, so a member could ask for
-- another member's next word.
--
-- Changes:
--   1. Weighted sampling: ORDER BY -ln(1 - random()) / frequency ASC picks
--      each word with probability proportional to its frequency
--      (Efraimidis–Spirakis). Common words are still favoured, but e comes up
--      about 6% of the time rather than most of the time.
--   2. exclude_ids: the app passes the words the member recently skipped, so
--      they don't come straight back. If excluding them leaves nothing, the
--      function falls back to ignoring the list.
--   3. The member comes from auth.uid(). user_uuid is kept (and ignored) so
--      the app deployed alongside this migration, which still sends it, keeps
--      working; it can be dropped once no caller passes it.
--   4. EXECUTE for authenticated only (was PUBLIC/anon too). SECURITY INVOKER
--      is enough: RLS lets a member read contributions and their own
--      completions. search_path stays pinned.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_next_word_for_user(uuid);

CREATE OR REPLACE FUNCTION public.get_next_word_for_user(
  user_uuid uuid DEFAULT NULL,
  exclude_ids uuid[] DEFAULT '{}'
)
RETURNS TABLE(
  id uuid,
  motu_word text,
  frequency integer,
  example_reference text,
  example_motu text,
  example_english text,
  suggested_translations text[],
  status public.word_status,
  consensus_gloss text,
  total_contributions integer
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  -- user_uuid is ignored on purpose: the caller is always auth.uid().
  caller uuid := auth.uid();
  skipped uuid[] := COALESCE(exclude_ids, '{}');
BEGIN
  IF caller IS NULL THEN
    RETURN;
  END IF;

  FOR attempt IN 1..2 LOOP
    RETURN QUERY
    SELECT
      w.id,
      w.motu_word,
      w.frequency,
      w.example_reference,
      w.example_motu,
      w.example_english,
      w.suggested_translations,
      w.status,
      w.consensus_gloss,
      w.total_contributions
    FROM words w
    WHERE NOT (w.id = ANY (skipped))
    AND NOT EXISTS (
      -- Exclude words the member has already contributed to
      SELECT 1 FROM contributions c
      WHERE c.word_id = w.id AND c.user_id = caller
    )
    AND NOT EXISTS (
      -- Exclude words the member has marked as complete
      SELECT 1 FROM user_word_completion uwc
      WHERE uwc.word_id = w.id AND uwc.user_id = caller
    )
    -- Weighted random pick, probability proportional to frequency.
    -- 1 - random() is in (0, 1], so ln() never sees 0.
    ORDER BY -ln(1 - random()) / GREATEST(COALESCE(w.frequency, 0), 1)
    LIMIT 1;

    -- Found one, or there was nothing to relax.
    IF FOUND OR cardinality(skipped) = 0 THEN
      RETURN;
    END IF;

    -- Every remaining word was skipped recently: offer them again.
    skipped := '{}';
  END LOOP;
END;
$$;

ALTER FUNCTION public.get_next_word_for_user(uuid, uuid[]) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.get_next_word_for_user(uuid, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_next_word_for_user(uuid, uuid[]) TO authenticated, service_role;
