-- =============================================================================
-- 20261024141000 — Dictionary browsing finds every word (issue #33)
--
-- 1. word_initials(): the distinct first letters (upper-cased) with their word
--    counts, so the alphabet bar is built from the data and includes Ḡ.
-- 2. search_words(): the filtered list (Motu substring, English substring,
--    first letter, status) as one function, so user input is passed as
--    parameters instead of being interpolated into PostgREST filters. English
--    matches a substring of consensus_gloss or of any suggested_translations
--    element; comma- or semicolon-separated terms match any of them
--    ("house, home"). LIKE wildcards in the input are escaped. The caller adds
--    the order, range and exact count through PostgREST.
-- 3. word_neighbors(): the previous and next word in the list's order,
--    (frequency DESC NULLS LAST, motu_word ASC), with a keyset comparison so
--    words that share a frequency are walked one at a time.
-- 4. Indexes: a pg_trgm GIN index on the English search text, and a btree
--    matching the list order.
--
-- The functions are SECURITY INVOKER (words are readable by anyone under RLS),
-- with search_path pinned. Nothing existing changes, so the app deployed
-- before this migration keeps working.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- Escape \, % and _ so text can be used literally inside a LIKE pattern
-- (backslash is the default LIKE escape character).
CREATE OR REPLACE FUNCTION public.escape_like(p_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path TO ''
AS $$
  SELECT replace(replace(replace(p_text, '\', '\\'), '%', '\%'), '_', '\_');
$$;

-- The English text of a word, lower-cased: the gloss and each suggested
-- translation on its own line. Search terms never contain a newline, so a
-- match can't span two translations. (array_to_string is only STABLE in
-- general, but for text[] it is immutable, which the index needs.)
CREATE OR REPLACE FUNCTION public.word_search_text(p_gloss text, p_translations text[])
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path TO ''
AS $$
  SELECT lower(coalesce(p_gloss, '') || E'\n'
               || array_to_string(coalesce(p_translations, '{}'), E'\n'));
$$;

CREATE INDEX IF NOT EXISTS idx_words_search_text_trgm
  ON public.words
  USING gin (public.word_search_text(consensus_gloss, suggested_translations) extensions.gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_words_frequency_motu_word
  ON public.words (frequency DESC NULLS LAST, motu_word);

CREATE OR REPLACE FUNCTION public.word_initials()
RETURNS TABLE(letter text, word_count bigint)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $$
  SELECT upper(left(w.motu_word, 1)) AS letter, count(*) AS word_count
  FROM public.words w
  GROUP BY 1;
$$;

CREATE OR REPLACE FUNCTION public.search_words(
  p_motu text DEFAULT NULL,
  p_english text DEFAULT NULL,
  p_letter text DEFAULT NULL,
  p_status text DEFAULT NULL
)
RETURNS SETOF public.words
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $$
DECLARE
  english_pats text[];
BEGIN
  IF coalesce(p_english, '') <> '' THEN
    -- One pattern per term; input with no terms left (such as ",") is
    -- matched as typed, minus line breaks.
    SELECT array_agg('%' || public.escape_like(lower(t.term)) || '%')
      INTO english_pats
      FROM regexp_split_to_table(p_english, '[,;\r\n]') AS s(raw),
           btrim(s.raw) AS t(term)
     WHERE t.term <> '';

    english_pats := coalesce(
      english_pats,
      ARRAY['%' || public.escape_like(lower(regexp_replace(p_english, '[\r\n]', '', 'g'))) || '%']
    );
  END IF;

  -- Dynamic SQL so each call is planned with its own patterns, which lets the
  -- planner use the trigram index for selective searches.
  RETURN QUERY EXECUTE
    'SELECT w.* FROM public.words w WHERE true'
    || CASE WHEN coalesce(p_motu, '') <> ''
            THEN ' AND w.motu_word ILIKE ''%'' || public.escape_like($1) || ''%''' ELSE '' END
    || CASE WHEN english_pats IS NOT NULL
            THEN ' AND public.word_search_text(w.consensus_gloss, w.suggested_translations) LIKE ANY ($2)' ELSE '' END
    -- Same expression as word_initials(), so every letter it lists matches
    -- its words whatever the collation's case mapping (Ḡ/ḡ included).
    || CASE WHEN coalesce(p_letter, '') <> ''
            THEN ' AND upper(left(w.motu_word, 1)) = $3' ELSE '' END
    || CASE WHEN coalesce(p_status, '') <> ''
            THEN ' AND w.status::text = $4' ELSE '' END
    USING p_motu, english_pats, p_letter, p_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.word_neighbors(p_word_id uuid)
RETURNS TABLE(direction text, id uuid, motu_word text)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $$
  -- A null frequency sorts last, like the list (NULLS LAST); frequencies are
  -- never negative, so -1 stands in for it.
  WITH cur AS (
    SELECT coalesce(w.frequency, -1) AS f, w.motu_word AS m
    FROM public.words w
    WHERE w.id = p_word_id
  )
  (
    SELECT 'prev', w.id, w.motu_word
    FROM public.words w, cur
    WHERE coalesce(w.frequency, -1) > cur.f
       OR (coalesce(w.frequency, -1) = cur.f AND w.motu_word < cur.m)
    ORDER BY coalesce(w.frequency, -1) ASC, w.motu_word DESC
    LIMIT 1
  )
  UNION ALL
  (
    SELECT 'next', w.id, w.motu_word
    FROM public.words w, cur
    WHERE coalesce(w.frequency, -1) < cur.f
       OR (coalesce(w.frequency, -1) = cur.f AND w.motu_word > cur.m)
    ORDER BY coalesce(w.frequency, -1) DESC, w.motu_word ASC
    LIMIT 1
  );
$$;

REVOKE ALL ON FUNCTION public.escape_like(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.word_search_text(text, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.word_initials() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.search_words(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.word_neighbors(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.escape_like(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.word_search_text(text, text[]) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.word_initials() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.search_words(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.word_neighbors(uuid) TO anon, authenticated;
