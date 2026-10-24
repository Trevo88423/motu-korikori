-- =============================================================================
-- 20261024171056 — Flags on translations; weighted auto-hide (#56, part of #51)
--
-- Members can flag a translation (contributions) for abuse or junk, with a
-- reason. Flags are weighted by the flagger's trust, and enough weight hides
-- the item from everyone but its author and admins. Comments move to the same
-- weighted rule. Hidden items wait in a short admin exceptions list, where an
-- admin restores them (which counts against the flaggers) or confirms the hide.
--
-- Flags are for abuse and junk, never for "I'd translate it differently": a
-- disagreement can be a real variant (docs/PHILOSOPHY.md, principle 3), so
-- there is no "I disagree" reason. Disagreement is a contribution or a vote.
--
-- Built to be reused by proposed words (#58):
--   moderation_settings     thresholds and weights, tunable without code
--   flag_weight(uuid)       the one place a flag's weight is decided (#53 swaps it)
--   flags_hide(numeric)     the hide rule
--   flag_reason_allowed()   which reasons apply to which kind of item
--   member_flag_record      each member's upheld / overturned flags
--   flag_content(kind, id, reason)    the member RPC; one branch per kind
--   resolve_flags(kind, id, decision) the admin decision; one branch per kind
-- A new kind adds a <kind>_flags table, the same four columns on its table,
-- and a branch in the two functions.
--
-- Counters: words.total_contributions / unique_contributors count only
-- contributions that are neither excluded nor hidden, so a hidden junk entry
-- doesn't inflate a word. The profile's own contribution_count is unchanged
-- (it counts excluded contributions too).
--
-- Consensus: lib/consensus.ts treats a hidden contribution like an excluded one.
--
-- Safe with the current app: increment_comment_flags() keeps its signature and
-- behaviour (one flag per member, own comment ignored), now weighted; nothing
-- is hidden until someone flags.
-- =============================================================================

-- --- Settings --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.moderation_settings (
  key         text PRIMARY KEY,
  value       numeric NOT NULL,
  description text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.moderation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.moderation_settings FROM anon, authenticated;
-- Readable so the app can explain the rules; written only by the service role
-- (the admin page).
GRANT SELECT ON public.moderation_settings TO anon, authenticated;
DROP POLICY IF EXISTS "Moderation settings are readable" ON public.moderation_settings;
CREATE POLICY "Moderation settings are readable"
  ON public.moderation_settings FOR SELECT
  USING (true);

-- Starting values. 3 ordinary members (1 each) or 2 trusted speakers (1.5
-- each) reach the threshold of 3. ON CONFLICT keeps values already tuned.
INSERT INTO public.moderation_settings (key, value, description) VALUES
  ('flag_hide_threshold', 3,
   'Total flag weight that hides an item'),
  ('flag_weight_member', 1,
   'Weight of a flag from an ordinary member with full trust'),
  ('flag_weight_trusted', 1.5,
   'Weight of a flag from a trusted speaker (native or heritage speaker with good trust)'),
  ('flag_trusted_min_trust', 1,
   'Trust score a native or heritage speaker needs to count as trusted'),
  ('flag_overturn_penalty', 0.25,
   'Share of flag weight lost for each of a member''s flags an admin overturned')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.moderation_setting(setting_key text)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT value FROM public.moderation_settings WHERE key = setting_key
$$;

REVOKE ALL ON FUNCTION public.moderation_setting(text) FROM PUBLIC, anon, authenticated;

-- --- Each member's flag record -----------------------------------------------
-- Upheld and overturned flags, set when an admin decides on a hidden item.
-- Counters rather than a query over the flag rows, so deleting a restored
-- comment later doesn't erase the record.

CREATE TABLE IF NOT EXISTS public.member_flag_record (
  user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  flags_upheld     integer NOT NULL DEFAULT 0,
  flags_overturned integer NOT NULL DEFAULT 0,
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.member_flag_record ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.member_flag_record FROM anon, authenticated;

-- --- Weight and the hide rule ----------------------------------------------

-- The weight of a new flag from this member. The trust ladder (#53) will
-- replace this body; everything else calls it.
--   base     trusted speaker (native/heritage with trust >= the setting) or member
--   x trust  min(1, trust_score), so low-trust members carry less
--   x record 1 - penalty * overturned flags, never below 0
CREATE OR REPLACE FUNCTION public.flag_weight(flagger uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT round(
    CASE
      WHEN p.connection_type IN ('native_speaker', 'heritage_speaker')
           AND p.trust_score >= public.moderation_setting('flag_trusted_min_trust')
        THEN public.moderation_setting('flag_weight_trusted')
      ELSE public.moderation_setting('flag_weight_member')
    END
    * least(1, greatest(0, p.trust_score))
    * greatest(0, 1 - public.moderation_setting('flag_overturn_penalty')
                      * coalesce(r.flags_overturned, 0)),
    2)
  FROM public.profiles p
  LEFT JOIN public.member_flag_record r ON r.user_id = p.id
  WHERE p.id = flagger
$$;

REVOKE ALL ON FUNCTION public.flag_weight(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.flags_hide(total_weight numeric)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT total_weight >= public.moderation_setting('flag_hide_threshold')
$$;

REVOKE ALL ON FUNCTION public.flags_hide(numeric) FROM PUBLIC, anon, authenticated;

-- Reasons per kind. Disagreement is deliberately not a reason (principle 3).
CREATE OR REPLACE FUNCTION public.flag_reason_allowed(target_kind text, reason text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE target_kind
    WHEN 'contribution' THEN reason IN ('offensive', 'spam', 'deliberately_wrong', 'not_true_motu')
    WHEN 'comment'      THEN reason IN ('offensive', 'spam', 'off_topic')
    ELSE false
  END
$$;

-- --- Flag state on the items -------------------------------------------------
-- flag_weight is the weight of flags not yet decided by an admin; a restore
-- resets it, so later flags from other members start fresh.
-- hide_confirmed_at: an admin confirmed the hide; it leaves the exceptions list.

ALTER TABLE public.contributions
  ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS flag_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS flag_weight numeric(6,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz,
  ADD COLUMN IF NOT EXISTS hide_confirmed_at timestamptz;

CREATE INDEX IF NOT EXISTS contributions_hidden_idx
  ON public.contributions (hidden_at) WHERE is_hidden;

-- comments already has is_flagged (its "hidden") and flag_count.
ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS flag_weight numeric(6,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz,
  ADD COLUMN IF NOT EXISTS hide_confirmed_at timestamptz;

CREATE INDEX IF NOT EXISTS comments_flagged_idx
  ON public.comments (hidden_at) WHERE is_flagged;

-- Existing flags each weighed 1 under the old rule. Only touches rows not yet
-- carried over, so a re-run changes nothing.
UPDATE public.comments
SET flag_weight = coalesce(flag_count, 0)
WHERE flag_weight = 0 AND coalesce(flag_count, 0) > 0;

UPDATE public.comments
SET hidden_at = coalesce(updated_at, created_at, now())
WHERE is_flagged AND hidden_at IS NULL;

-- The old trigger set is_flagged whenever flag_count >= 3, on any update, so
-- an admin couldn't restore a comment. Hiding is now decided in flag_content().
DROP TRIGGER IF EXISTS auto_hide_flagged_comments ON public.comments;

-- --- Flag rows ----------------------------------------------------------------
-- user_id references auth.users, not profiles, so PostgREST has only one
-- contributions<->profiles path (see comment_flags in 20261024100016).

CREATE TABLE IF NOT EXISTS public.contribution_flags (
  contribution_id uuid NOT NULL REFERENCES public.contributions(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason          text NOT NULL CHECK (public.flag_reason_allowed('contribution', reason)),
  weight          numeric(4,2) NOT NULL,
  outcome         text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending', 'upheld', 'overturned')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (contribution_id, user_id)
);

-- Flags from before this migration have no reason; they keep weight 1.
ALTER TABLE public.comment_flags
  ADD COLUMN IF NOT EXISTS reason text CHECK (reason IS NULL OR public.flag_reason_allowed('comment', reason)),
  ADD COLUMN IF NOT EXISTS weight numeric(4,2) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending', 'upheld', 'overturned'));

-- Written only by flag_content() and resolve_flags(). Admins can read them for
-- the exceptions list; members can't see who flagged what.
ALTER TABLE public.contribution_flags ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.contribution_flags FROM anon, authenticated;
REVOKE ALL ON public.comment_flags FROM anon, authenticated;
GRANT SELECT ON public.contribution_flags, public.comment_flags TO authenticated;

DROP POLICY IF EXISTS "Admins can view contribution flags" ON public.contribution_flags;
CREATE POLICY "Admins can view contribution flags"
  ON public.contribution_flags FOR SELECT
  TO authenticated
  USING (public.is_current_user_admin());

DROP POLICY IF EXISTS "Admins can view comment flags" ON public.comment_flags;
CREATE POLICY "Admins can view comment flags"
  ON public.comment_flags FOR SELECT
  TO authenticated
  USING (public.is_current_user_admin());

-- --- Flagging -----------------------------------------------------------------

-- Returns {"status": "flagged" | "already_flagged", "hidden": bool,
-- "hidden_now": bool, "word_id": uuid}. Refuses anon, inactive members,
-- unknown reasons and the caller's own items.
CREATE OR REPLACE FUNCTION public.flag_content(target_kind text, target_id uuid, reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  caller uuid := auth.uid();
  w numeric;
  author uuid;
  word uuid;
  was_hidden boolean;
  total numeric;
  now_hidden boolean;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF NOT public.is_current_user_active() THEN
    RAISE EXCEPTION 'Account suspended or banned' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF NOT public.flag_reason_allowed(target_kind, reason) THEN
    RAISE EXCEPTION 'Unknown flag reason % for %', reason, target_kind USING ERRCODE = 'invalid_parameter_value';
  END IF;

  w := coalesce(public.flag_weight(caller), 0);

  IF target_kind = 'contribution' THEN
    -- Row lock: concurrent flags add up one at a time.
    SELECT user_id, word_id, is_hidden INTO author, word, was_hidden
    FROM contributions WHERE id = target_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Translation not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF author = caller THEN
      RAISE EXCEPTION 'You can''t flag your own translation' USING ERRCODE = 'insufficient_privilege';
    END IF;

    INSERT INTO contribution_flags (contribution_id, user_id, reason, weight)
    VALUES (target_id, caller, reason, w)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'already_flagged', 'hidden', was_hidden,
                                'hidden_now', false, 'word_id', word);
    END IF;

    UPDATE contributions
    SET flag_count = flag_count + 1,
        flag_weight = flag_weight + w
    WHERE id = target_id
    RETURNING flag_weight INTO total;

    now_hidden := NOT was_hidden AND public.flags_hide(total);
    IF now_hidden THEN
      UPDATE contributions
      SET is_hidden = true, hidden_at = now(), hide_confirmed_at = NULL
      WHERE id = target_id;
    END IF;

  ELSIF target_kind = 'comment' THEN
    SELECT user_id, word_id, coalesce(is_flagged, false) INTO author, word, was_hidden
    FROM comments WHERE id = target_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Comment not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF author = caller THEN
      RAISE EXCEPTION 'You can''t flag your own comment' USING ERRCODE = 'insufficient_privilege';
    END IF;

    INSERT INTO comment_flags (comment_id, user_id, reason, weight)
    VALUES (target_id, caller, reason, w)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'already_flagged', 'hidden', was_hidden,
                                'hidden_now', false, 'word_id', word);
    END IF;

    UPDATE comments
    SET flag_count = coalesce(flag_count, 0) + 1,
        flag_weight = flag_weight + w
    WHERE id = target_id
    RETURNING flag_weight INTO total;

    now_hidden := NOT was_hidden AND public.flags_hide(total);
    IF now_hidden THEN
      UPDATE comments
      SET is_flagged = true, hidden_at = now(), hide_confirmed_at = NULL
      WHERE id = target_id;
    END IF;

  ELSE
    RAISE EXCEPTION 'Unknown flag target %', target_kind USING ERRCODE = 'invalid_parameter_value';
  END IF;

  RETURN jsonb_build_object('status', 'flagged', 'hidden', was_hidden OR now_hidden,
                            'hidden_now', now_hidden, 'word_id', word);
END;
$function$;

REVOKE ALL ON FUNCTION public.flag_content(text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.flag_content(text, uuid, text) TO authenticated;

-- The app's existing call. Same behaviour as before (own comment silently
-- ignored), now weighted; flags from it count as off-topic, which is what its
-- button said ("Flag as irrelevant").
CREATE OR REPLACE FUNCTION public.increment_comment_flags(comment_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF EXISTS (SELECT 1 FROM comments WHERE id = comment_uuid AND user_id = auth.uid()) THEN
    RETURN;
  END IF;

  PERFORM public.flag_content('comment', comment_uuid, 'off_topic');
END;
$function$;

-- --- Admin decisions ----------------------------------------------------------
-- decision 'restore': the item comes back, its pending flags are overturned and
--   count against each flagger's weight.
-- decision 'confirm': it stays hidden, its pending flags are upheld, and it
--   leaves the exceptions list.
-- Service role only: app/admin/actions.ts checks the caller is an admin, then
-- logs to moderation_log. Returns what the log needs.
CREATE OR REPLACE FUNCTION public.resolve_flags(target_kind text, target_id uuid, decision text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  outcome_value text;
  author uuid;
  word uuid;
  hidden boolean;
  summary text;
  flaggers uuid[];
BEGIN
  IF decision NOT IN ('restore', 'confirm') THEN
    RAISE EXCEPTION 'Unknown decision %', decision USING ERRCODE = 'invalid_parameter_value';
  END IF;
  outcome_value := CASE decision WHEN 'restore' THEN 'overturned' ELSE 'upheld' END;

  IF target_kind = 'contribution' THEN
    SELECT user_id, word_id, is_hidden, english_gloss INTO author, word, hidden, summary
    FROM contributions WHERE id = target_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Translation not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF NOT hidden THEN
      RAISE EXCEPTION 'Translation is not hidden' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    WITH decided AS (
      UPDATE contribution_flags SET outcome = outcome_value
      WHERE contribution_id = target_id AND outcome = 'pending'
      RETURNING user_id
    )
    SELECT coalesce(array_agg(user_id), '{}') INTO flaggers FROM decided;

    IF decision = 'restore' THEN
      UPDATE contributions
      SET is_hidden = false, flag_weight = 0, hidden_at = NULL, hide_confirmed_at = NULL
      WHERE id = target_id;
    ELSE
      UPDATE contributions SET hide_confirmed_at = now() WHERE id = target_id;
    END IF;

  ELSIF target_kind = 'comment' THEN
    SELECT user_id, word_id, coalesce(is_flagged, false), left(comment_text, 80)
    INTO author, word, hidden, summary
    FROM comments WHERE id = target_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Comment not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF NOT hidden THEN
      RAISE EXCEPTION 'Comment is not hidden' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    WITH decided AS (
      UPDATE comment_flags SET outcome = outcome_value
      WHERE comment_id = target_id AND outcome = 'pending'
      RETURNING user_id
    )
    SELECT coalesce(array_agg(user_id), '{}') INTO flaggers FROM decided;

    IF decision = 'restore' THEN
      UPDATE comments
      SET is_flagged = false, flag_weight = 0, hidden_at = NULL, hide_confirmed_at = NULL
      WHERE id = target_id;
    ELSE
      UPDATE comments SET hide_confirmed_at = now() WHERE id = target_id;
    END IF;

  ELSE
    RAISE EXCEPTION 'Unknown flag target %', target_kind USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Flaggers whose accounts are gone have no record to keep.
  INSERT INTO member_flag_record (user_id, flags_upheld, flags_overturned)
  SELECT u.id,
         CASE WHEN decision = 'confirm' THEN 1 ELSE 0 END,
         CASE WHEN decision = 'restore' THEN 1 ELSE 0 END
  FROM auth.users u WHERE u.id = ANY (flaggers)
  ON CONFLICT (user_id) DO UPDATE
  SET flags_upheld = member_flag_record.flags_upheld + EXCLUDED.flags_upheld,
      flags_overturned = member_flag_record.flags_overturned + EXCLUDED.flags_overturned,
      updated_at = now();

  RETURN jsonb_build_object('author_id', author, 'word_id', word, 'summary', summary,
                            'flaggers', coalesce(array_length(flaggers, 1), 0));
END;
$function$;

REVOKE ALL ON FUNCTION public.resolve_flags(text, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_flags(text, uuid, text) TO service_role;

-- --- Hidden translations: author and admins only ------------------------------
-- Admins already see every row through "Admins can manage all contributions".
ALTER POLICY "Users can view all contributions" ON public.contributions
  USING (auth.uid() IS NOT NULL AND (is_hidden = false OR auth.uid() = user_id));

-- --- Word counters skip hidden translations -----------------------------------
-- Same body as 20261024100016, with is_hidden alongside is_excluded.
CREATE OR REPLACE FUNCTION public.update_word_contribution_counts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.word_id = NEW.word_id
     AND OLD.is_excluded IS NOT DISTINCT FROM NEW.is_excluded
     AND OLD.is_hidden IS NOT DISTINCT FROM NEW.is_hidden THEN
    RETURN NULL;
  END IF;

  UPDATE words w
  SET
    total_contributions = c.total,
    unique_contributors = c.contributors
  FROM (
    SELECT
      wid,
      (SELECT count(*) FROM contributions
        WHERE word_id = wid AND is_excluded = false AND is_hidden = false)::int AS total,
      (SELECT count(DISTINCT user_id) FROM contributions
        WHERE word_id = wid AND is_excluded = false AND is_hidden = false)::int AS contributors
    FROM unnest(CASE TG_OP
      WHEN 'INSERT' THEN ARRAY[NEW.word_id]
      WHEN 'DELETE' THEN ARRAY[OLD.word_id]
      ELSE ARRAY[OLD.word_id, NEW.word_id]
    END) AS wid
  ) c
  WHERE w.id = c.wid;

  RETURN NULL;
END;
$function$;

-- --- Moderation log -------------------------------------------------------------
ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'restore_content';
ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'confirm_hide';

-- Which item a content decision was about ('contribution', 'comment', later 'word').
ALTER TABLE public.moderation_log
  ADD COLUMN IF NOT EXISTS target_kind text,
  ADD COLUMN IF NOT EXISTS target_id uuid;
