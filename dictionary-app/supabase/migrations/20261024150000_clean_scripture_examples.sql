-- Clean the scripture examples and the malformed AI suggestions (#32).
--
-- The examples came from a CSV of the aligned Motu/World English Bible text,
-- built from USFM. Three kinds of damage reached words:
--   1. The CSV was split on the first comma inside the quoted Motu field, so
--      example_motu holds only the start of the verse (with a leading ") and
--      example_english holds the rest of the Motu, then "," and the English.
--      Other rows kept the English as a quoted CSV field ("...""...""...").
--   2. USFM leftovers: \+w ... \+w* and other \x markers, word attributes
--      (|strong="H1234"), and footnotes/cross-references written as
--      "+ 1:1 <note> *" (the * is all that is left of \f*).
--   3. 110 AI suggestions with an unbalanced parenthesis.
--
-- Only inserts that aren't scripture are removed. The Motu Bible is
-- © 1959–1973 Bible Society of Papua New Guinea, CC BY-NC-ND 4.0, and its
-- terms forbid changing any words or punctuation, so every word and
-- punctuation mark of each verse is kept exactly as published, verses are
-- never merged, and each excerpt keeps its reference. (The WEB English is
-- public domain; it gets the same treatment.)
--
-- Everything here is deterministic and safe to re-run: a repaired row no
-- longer matches the repair conditions, and clean_scripture_text() leaves
-- clean text unchanged.

-- --- The cleaner ---------------------------------------------------------
-- Kept as a function so the same rules clean data/bible-indices
-- (scripts/clean-bible-indices.mjs runs it against the local database).

CREATE OR REPLACE FUNCTION public.clean_scripture_text(t text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $fn$
DECLARE
  note text;
  -- Footnotes and cross-references whose end marker was lost, so the note
  -- runs straight into the verse text. Exact note text from the WEB and
  -- Motu USFM \f/\x spans, longest first. Notes that kept their * or sit at
  -- the end of the text are left to the generic rules below, except where
  -- one starts with a listed note: it is listed too, so the shorter note
  -- can't cut it in half ("or, tassels" / "or, tassels (Hebrew ...)").
  unmarked_notes constant text[] := ARRAY[
    $n$A cubit is the length from the tip of the middle finger to the elbow on a man’s arm, or about 18 inches or 46 centimeters. A span is the length from the tip of a man’s thumb to the tip of his little finger when his hand is stretched out (about half a cubit, or 9 inches, or 22.8 cm.) Therefore, Goliath was about 9 feet and 9 inches or 2.97 meters tall.$n$,
    $n$phylacteries (tefillin in Hebrew) are small leather pouches that some Jewish men wear on their forehead and arm in prayer. They are used to carry a small scroll with some Scripture in it. See Deuteronomy 6:8.$n$,
    $n$Hebrew: Elohim. The word Elohim, used here, usually means “God”, but can also mean “gods”, “princes”, or “angels”. The Septuagint reads “angels” here. See also the quote from the Septuagint in Hebrews 2:7.$n$,
    $n$darnel is a weed grass (probably bearded darnel or lolium temulentum) that looks very much like wheat until it is mature, when the difference becomes very apparent.$n$,
    $n$“Teio” be nadi ta ladana, Heiene gado ai. E aramu, hena bonana dika-hereana e daemu, taunimanima e hamasediamu. Ladana English gado ai na “sulphur”.$n$,
    $n$Alefa: Omega. Ini na Helene taudia edia leta ladadia. Edia leta gini-gunana bona gini-gabena bini, ita eda A bona Z heḡereḡeredia.$n$,
    $n$“Behemoto” na sinavai ai e nohomu ḡauna ta, ita-itana na boroma bada-hereana na heto. Ladana English gado ai na “hippopotamus”.$n$,
    $n$literally, ten yokes, or the amount of land that ten yokes of oxen can plow in one day, which is about 10 acres or 4 hectares.$n$,
    $n$“Sakada” na au huahua ta ladana, Heberu gado ai. A reḡena mia heḡereḡere herevana ta be “sokede”; ia anina be “balaia heni”.$n$,
    $n$A cubit is the length from the tip of the middle finger to the elbow on a man’s arm, or about 18 inches or 46 centimeters.$n$,
    $n$Ina Rahaba na dia hahine ta ladana, a gadobada ai e nohova ḡauna hadana bona dikana ta ladana, Heberu taudia edia gori ai.$n$,
    $n$cumin is an aromatic seed from Cuminum cyminum, resembling caraway in flavor and appearance. It is used as a spice.$n$,
    $n$“Behold”, from “ἰδοὺ”, means look at, take notice, observe, see, or gaze at. It is often used as an interjection.$n$,
    $n$Proverbs 31:10-31 form an acrostic, with each verse starting with each letter of the Hebrew alphabet, in order.$n$,
    $n$“Behold”, from “”, means look at, take notice, observe, see, or gaze at. It is often used as an interjection.$n$,
    $n$A shekel is about 10 grams or about 0.35 ounces, so 1000 shekels is about 10 kilograms or about 22 pounds.$n$,
    $n$“Raca” is an Aramaic insult, related to the word for “empty” and conveying the idea of empty-headedness.$n$,
    $n$The word for “brothers” here may be also correctly translated “brothers and sisters” or “siblings.”$n$,
    $n$An assarion was a small copper coin worth about an hour’s wages for an agricultural laborer.$n$,
    $n$“Aivori” na eiefant doana. “Sapairo” na Heberu taudia edia nadi hururu-hururuna ta ladana.$n$,
    $n$“Yahweh” is God’s proper Name, sometimes rendered “LORD” (all caps) in other translations.$n$,
    $n$100 denarii was about one sixtieth of a talent, or about 500 grams (1.1 pounds) of silver.$n$,
    $n$“Sosana” na Heberu taudia edia herahera avana ta. “Muro” na edia muramura mai honana ta.$n$,
    $n$Beroso bona teasuru na au ladadia, Heberu gado ai. Oak na au ta ladana English gado ai.$n$,
    $n$“Sosana” na Heberu taudia edia herahera ta ladana; English gado ai ladana na “lily”.$n$,
    $n$Time was measured from sunrise to sunset, so the third hour would be about 9:00 a.m.$n$,
    $n$Puku, sapairo, kadakodo. Ini na Heberu taudia edia herahera nadidia haida ladadia.$n$,
    $n$Leviathan na Heberu taudia edia gori ḡauna ta, e laloa ila-itana na sia na heto.$n$,
    $n$Ina Rahaba na gadobada ai e nohova ḡauna badana ta, Heberu taudia edia gori ai.$n$,
    $n$“Sakada” na au ta ladana Heberu gado ai; una au burena na kuroka-kuroka herea.$n$,
    $n$So read the Dead Sea Scrolls and Septuagint. Masoretic Text omits “the light”.$n$,
    $n$Beroso, tidara, teasuru. Ini na au haida ladadia, Heberu taudia edia gado ai.$n$,
    $n$literally, three sata. 3 sata is about 39 liters or a bit more than a bushel.$n$,
    $n$Kima; Kesili; Masaroto; Asa. Ini na hisiu haida iadadia, Heberu gado ai.$n$,
    $n$Peter’s name, Petros in Greek, is the word for a specific rock or stone.$n$,
    $n$The word for “sorcerers” here also includes users of potions and drugs.$n$,
    $n$Rabboni is a transliteration of the Hebrew word for “great teacher.”$n$,
    $n$Bata; homere; efa. Ini na Heberu taudia edia hahetoho ḡaudia haida.$n$,
    $n$Asa bona Kesili bona Kima na hisiu haida ladadia, Heheru gado ai.$n$,
    $n$TR adds “I am the Alpha and the Omega, the First and the Last.”$n$,
    $n$Corban is a Hebrew word for an offering devoted to God.$n$,
    $n$or, messengers (here and wherever angels are mentioned)$n$,
    $n$“Sosana” na Heberu taudia edia herahera avana ta.$n$,
    $n$A shekel is about 10 grams or about 0.35 ounces.$n$,
    $n$Bel bona Merodak na Babulono taudia edia dirava.$n$,
    $n$“koni” na uda ḡauna maragina ta, mada na heto.$n$,
    $n$1 bath is about 22 liters or 5.8 U. S. gallons$n$,
    $n$The Hebrew word rendered “God” is “” (Elohim).$n$,
    $n$“Rimono” na Heberu taudia edia au huahua ta.$n$,
    $n$Beth Ophrah means literally “House of Dust.”$n$,
    $n$Aivori na elefant doadia amo e abimu ḡauna.$n$,
    $n$Exodus 20:13-15,17; Deuteronomy 5:17-19,21$n$,
    $n$Literally, Lord of the Flies, or the devil$n$,
    $n$“Telimi” na au ta ladana, Heberu gado ai.$n$,
    $n$NU, TR read “knowing” instead of “seeing”$n$,
    $n$“Beroso” na au ta ladana Heberu gado ai.$n$,
    $n$1 homer is about 220 liters or 6 bushels$n$,
    $n$Isaiah 9:7; Daniel 2:44; See Isaiah 53:8$n$,
    $n$The word translated “Lord” is “Adonai.”$n$,
    $n$Greek, petra, a rock mass or bedrock.$n$,
    $n$Exodus 20:12-16; Deuteronomy 5:16-20$n$,
    $n$Isaiah 40:11; Ezekiel 34:11-12,15,22$n$,
    $n$TR, NU read “that” instead of “your”$n$,
    $n$Hephzibah means “I delight in her”.$n$,
    $n$TR reads “Because” instead of “How”$n$,
    $n$Leviticus 20:10; Deuteronomy 22:22$n$,
    $n$1 Kings 17:17-23; 2 Kings 4:32-37$n$,
    $n$1 Kings 19:1-3; 2 Kings 6:31—7:20$n$,
    $n$TR reads “lama” instead of “lima”$n$,
    $n$Jeremiah 26:20-23; 1 Kings 19:10$n$,
    $n$i.e., has sexual relations with$n$,
    $n$Sheol is the place of the dead.$n$,
    $n$Exodus 20:12; Deuteronomy 5:16$n$,
    $n$Exodus 20:13; Deuteronomy 5:17$n$,
    $n$Exodus 20:14; Deuteronomy 5:18$n$,
    $n$or, tassels (Hebrew צִיצִ֛ת)$n$,
    $n$NU omits “without a cause”.$n$,
    $n$TR adds “which are in Asia”$n$,
    $n$“Aivori” na elefant doana.$n$,
    $n$Isaiah 52:5; Ezekiel 36:22$n$,
    $n$Daniel 9:17; 11:31; 12:11$n$,
    $n$Daniel 9:27; 11:31; 12:11$n$,
    $n$Genesis 12:7; 13:15; 24:7$n$,
    $n$TR and NU add “therefore”$n$,
    $n$Abaddon means Destroyer.$n$,
    $n$Exodus 19:6; Isaiah 61:6$n$,
    $n$TR and NU omit “sinners”$n$,
    $n$Beulah means “married”$n$,
    $n$TR adds “of the heart”$n$,
    $n$2 Chronicles 24:20-21$n$,
    $n$literally, “blood”$n$,
    $n$noon and 3:00 p.m.$n$,
    $n$Deuteronomy 30:12$n$,
    $n$Deuteronomy 30:13$n$,
    $n$Deuteronomy 30:14$n$,
    $n$Deuteronomy 32:35$n$,
    $n$Deuteronomy 6:4-5$n$,
    $n$‘Ammi’ in Hebrew$n$,
    $n$Deuteronomy 25:4$n$,
    $n$or, lapis lazuli$n$,
    $n$Psalms 118:25-26$n$,
    $n$TR adds “to you”$n$,
    $n$Deuteronomy 6:5$n$,
    $n$Leviticus 19:18$n$,
    $n$literally, iota$n$,
    $n$TR omits “also”$n$,
    $n$Jeremiah 31:31$n$,
    $n$or, oppression$n$,
    $n$Proverbs 26:11$n$,
    $n$2 Samuel 7:12$n$,
    $n$Daniel 3:1-30$n$,
    $n$Isaiah 40:3-5$n$,
    $n$Isaiah 53:7-8$n$,
    $n$Proverbs 4:26$n$,
    $n$Psalms 116:10$n$,
    $n$Psalms 118:26$n$,
    $n$TR adds “all”$n$,
    $n$Amos 5:25-27$n$,
    $n$Exodus 20:13$n$,
    $n$Exodus 30:12$n$,
    $n$Genesis 15:6$n$,
    $n$Genesis 17:5$n$,
    $n$Genesis 2:24$n$,
    $n$Isaiah 40:13$n$,
    $n$Isaiah 53:12$n$,
    $n$Isaiah 54:13$n$,
    $n$Numbers 16:5$n$,
    $n$Psalms 22:18$n$,
    $n$Psalms 50:23$n$,
    $n$Psalms 95:11$n$,
    $n$Daniel 7:13$n$,
    $n$Exodus 3:14$n$,
    $n$Genesis 1:3$n$,
    $n$Genesis 2:7$n$,
    $n$Isaiah 35:5$n$,
    $n$Isaiah 40:3$n$,
    $n$Isaiah 56:7$n$,
    $n$Isaiah 56:8$n$,
    $n$Isaiah 60:1$n$,
    $n$Malachi 4:6$n$,
    $n$or, “I AM!”$n$,
    $n$or, tassels$n$,
    $n$See Job 9:8$n$,
    $n$Exodus 3:6$n$,
    $n$John 13:16$n$,
    $n$or, angels$n$,
    $n$or, breath$n$,
    $n$Psalms 2:9$n$,
    $n$Psalms 4:4$n$,
    $n$Psalms 5:9$n$,
    $n$Psalms 8:6$n$,
    $n$5:00 p.m.$n$,
    $n$Hosea 6:6$n$,
    $n$Micah 5:2$n$,
    $n$or, equip$n$,
    $n$or, Judas$n$,
    $n$or, seeds$n$,
    $n$or, serif$n$,
    $n$or, Hell$n$,
    $n$or, seed$n$
  ];
BEGIN
  IF t IS NULL THEN
    RETURN NULL;
  END IF;

  -- Every rule below only deletes an insert that isn't scripture (USFM
  -- markup, a translator's note, a * marker), together with the space that
  -- delimited it. No word or punctuation mark of the verse is touched.

  -- USFM word attributes: \w Sheol|strong="H7585"\w*
  t := regexp_replace(t, '\|[a-z-]+="[^"]*"', '', 'g');
  -- USFM character markers. A closing marker (\+w*, \it*) has no delimiter;
  -- an opening one (\+w, \it) is followed by the one space that ends it.
  t := regexp_replace(t, '\\\+?[a-z]+[0-9]*\*', '', 'g');
  t := regexp_replace(t, '\\\+?[a-z]+[0-9]*( |$)', '', 'g');

  -- Notes: "+ 1:1 <note>", optionally ending in the * left from \f*. Each is
  -- removed with the whitespace before it, where the \f marker sat.
  IF t ~ '(^|\s)\+\s\d' THEN
    FOREACH note IN ARRAY unmarked_notes LOOP
      IF strpos(t, note) > 0 THEN
        t := regexp_replace(
          t,
          '(^|\s+)\+\s\d+[:.]\d+(-\d+)?\s'
            || regexp_replace(note, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g')
            -- "or, seed" must not match the start of "or, seeds"
            || CASE WHEN note ~ '[[:alnum:]]$' THEN '(?![[:alnum:]])' ELSE '' END
            || '(\s*\*)?',
          '', 'g');
      END IF;
    END LOOP;
    -- A row that is nothing but a note (a verse WEB moved to a footnote,
    -- e.g. Acts 8:37): keep the note, drop its markers.
    IF t ~ '^\s*\+\s\d+[:.]\d+(-\d+)?\s[^*]*\*?\s*$' THEN
      t := regexp_replace(t, '^\s*\+\s\d+[:.]\d+(-\d+)?\s', '');
    END IF;
    -- "+ 1:1 <note> *": a note that kept its end marker.
    t := regexp_replace(t, '(^|\s+)\+\s\d+[:.]\d+(-\d+)?\s[^*]*\*', '', 'g');
    -- "+ 1:1 <note>" at the end of the text.
    t := regexp_replace(t, '\s+\+\s\d+[:.]\d+(-\d+)?\s.*$', '');
  END IF;

  -- Remaining * markers (left from \it ...\it* and \f*), with the space
  -- before them. "\it gold\it*darikidia" stays "golddarikidia", as published.
  -- A run of stars is the published "*****" divider in the Motu Song of
  -- Songs, so it stays.
  t := regexp_replace(t, '\s*(?<!\*)\*{1,2}(?!\*)', '', 'g');
  -- Removals can leave a doubled or edge space; the stored text has none of
  -- its own (checked: 0 rows), so this only tidies what the removals left.
  t := btrim(regexp_replace(t, '\s{2,}', ' ', 'g'));
  RETURN t;
END;
$fn$;

-- Internal helper, not part of the API.
REVOKE ALL ON FUNCTION public.clean_scripture_text(text) FROM PUBLIC, anon, authenticated;

-- --- Repair and clean the examples ------------------------------------------
-- Text cleanup, not an edit: pause the updated_at trigger.

ALTER TABLE public.words DISABLE TRIGGER update_words_updated_at;

WITH src AS (
  SELECT id, example_motu AS mo, example_english AS en,
         strpos(example_english, '",') AS p
  FROM public.words
),
unsplit AS (
  -- Undo the comma split: '"<motu start>' + '<motu rest>",<english>'.
  -- A comma between digits (60,000) had no space after it.
  SELECT id,
    CASE WHEN mo LIKE '"%' AND p > 0 THEN
      substr(mo, 2) || ','
        || CASE WHEN p = 1 THEN ''
                WHEN mo ~ '\d$' AND en ~ '^\d' THEN left(en, p - 1)
                ELSE ' ' || left(en, p - 1) END
    ELSE mo END AS mo,
    CASE WHEN mo LIKE '"%' AND p > 0 THEN substr(en, p + 2) ELSE en END AS en
  FROM src
),
unquoted AS (
  -- A quoted CSV field: "...""strong""...".
  SELECT id, mo,
    CASE WHEN en ~ '^".*"$' AND length(en) >= 2
      THEN replace(substr(en, 2, length(en) - 2), '""', '"')
      ELSE en END AS en
  FROM unsplit
),
cleaned AS (
  SELECT id,
         public.clean_scripture_text(mo) AS mo,
         public.clean_scripture_text(en) AS en
  FROM unquoted
)
UPDATE public.words w
SET example_motu = c.mo,
    example_english = c.en
FROM cleaned c
WHERE w.id = c.id
  AND (w.example_motu IS DISTINCT FROM c.mo
       OR w.example_english IS DISTINCT FROM c.en);

ALTER TABLE public.words ENABLE TRIGGER update_words_updated_at;

-- --- Malformed AI suggestions ---------------------------------------------
-- Reviewed list. Each is the word's only suggestion. A split abbreviation is
-- rejoined (PERMI (T/JUSS -> PERMIT/JUSS), a missing ")" is added, a
-- parenthetical cut off at "..." is dropped; a chip left with no usable
-- gloss ("unknown content word") is removed. Only applied while the old
-- value is still there.

ALTER TABLE public.words DISABLE TRIGGER update_words_updated_at;

WITH fixes(id, old_value, new_value) AS (
  VALUES
    ('0e535287-5755-4481-8e54-8fb66fcc9838'::uuid, $s$CONJ (contrastive conjunction ("but, though")$s$, $s$CONJ (contrastive conjunction ("but, though"))$s$),
    ('2a1f74de-8182-4f9d-a721-1a29d6ca66de'::uuid, $s$NEG (negation marker ("not, didn't")$s$, $s$NEG (negation marker ("not, didn't"))$s$),
    ('d6957164-9d92-47c1-bcdf-f604bec95efa'::uuid, $s$COM (comitative case marker ("with, together with")$s$, $s$COM (comitative case marker ("with, together with"))$s$),
    ('e9ee8180-cfea-45f9-8269-9df8fddcae56'::uuid, $s$GEN (genitive/possessive case marker ("of, belonging to")$s$, $s$GEN (genitive/possessive case marker ("of, belonging to"))$s$),
    ('372c4b94-b375-4f78-b9b4-9050fa9480ed'::uuid, $s$SEQ (sequential conjunction ("and then, then")$s$, $s$SEQ (sequential conjunction ("and then, then"))$s$),
    ('a0446fb0-80b1-4a63-a7eb-1c178fca212d'::uuid, $s$conditional/negative marker ("unless, if not, c...$s$, $s$conditional/negative marker$s$),
    ('e80cf211-74ad-4f55-babc-2bf7dc521feb'::uuid, $s$INCEP (inceptive aspect marker ("begin to, start")$s$, $s$INCEP (inceptive aspect marker ("begin to, start"))$s$),
    ('55ea3159-60b9-42df-b03e-e7990227e0f9'::uuid, $s$fruit/produce (especially grapes, figs, pomegra...$s$, $s$fruit/produce$s$),
    ('903fb6a0-fe31-4a41-bf91-5f39e06dac2c'::uuid, $s$INTER (R - interrogative marker ("how, what, where")$s$, $s$INTERR - interrogative marker ("how, what, where")$s$),
    ('4b372e11-8a6d-4414-bb85-ac8418e05b4b'::uuid, $s$COMPL (completive aspect marker ("completely, utterly, finished")$s$, $s$COMPL (completive aspect marker ("completely, utterly, finished"))$s$),
    ('d1c0a6ed-e172-4c23-a59f-6f8a21b29651'::uuid, $s$uncertain (possible variant of "vada" perfectiv...$s$, NULL),
    ('4d69b217-ab2a-43b9-ac9b-c01bc8ea896b'::uuid, $s$unknown content word (possibly related to speec...$s$, NULL),
    ('2e12ea9e-53eb-444e-993d-430a3dc8956b'::uuid, $s$unknown complex form (possibly causative/intens...$s$, NULL),
    ('f27a1c9b-d4e7-4596-b074-79585068a7fc'::uuid, $s$plural form related to "gageva" (unknown base m...$s$, NULL),
    ('97551908-0669-4346-8d2a-6d23a6379e8b'::uuid, $s$EPIST (epistemic marker (supposition/belief)$s$, $s$EPIST (epistemic marker (supposition/belief))$s$),
    ('f969acdd-a036-4a6f-a455-99996292fffa'::uuid, $s$NEG (.VOLITION - negative volitional marker ("won't, refuse to")$s$, $s$NEG.VOLITION - negative volitional marker ("won't, refuse to")$s$),
    ('fbcfd2b1-ee28-4a0a-91ea-570e8f8272fb'::uuid, $s$Abishai (proper name - biblical warrior, brothe...$s$, $s$Abishai$s$),
    ('ded7aadb-0b04-4068-8415-963f8ee02862'::uuid, $s$unknown content word (possibly "metal/iron" or ...$s$, NULL),
    ('a2fab482-f82b-41fb-852b-5d44dd48a7fd'::uuid, $s$metal fittings; structural components (sockets,...$s$, $s$metal fittings; structural components$s$),
    ('2dab5469-4132-4185-82e6-bef3281b04ac'::uuid, $s$"fasteners/connectors" (metal clasps, hooks, or...$s$, $s$fasteners/connectors$s$),
    ('25c2642c-aee0-46bc-92ac-31bff3fddf75'::uuid, $s$metal (bron$s$, $s$metal$s$),
    ('892172da-cd9b-4f92-969f-59501dbcc4ae'::uuid, $s$unknown content word (possibly "crowd" or "mult...$s$, NULL),
    ('ef83bdd1-9e1a-4213-b266-100c5461b62a'::uuid, $s$[unknown base] + mu (2SG possessive) = "your (s...$s$, NULL),
    ('7cf78989-60ec-48cb-8c93-dc510f1e3ea6'::uuid, $s$uncertain (possible reduplicated noun with -na ...$s$, NULL),
    ('6868198f-06f8-41fc-83de-8ef6cc4c1f84'::uuid, $s$LOC (locative case marker ("at, in, on, to")$s$, $s$LOC (locative case marker ("at, in, on, to"))$s$),
    ('6eb4b980-bf43-4455-9ec4-54e3c8f20890'::uuid, $s$uncertain (possibly possessive or associative m...$s$, NULL),
    ('0c0e09c0-5799-4fc8-8bb6-2df3308627a8'::uuid, $s$COMIT (comitative marker ("with, together with")$s$, $s$COMIT (comitative marker ("with, together with"))$s$),
    ('bff69c51-773f-4981-8a16-95b8f8069bc9'::uuid, $s$NEG (negation marker ("not, never")$s$, $s$NEG (negation marker ("not, never"))$s$),
    ('b4c956f2-20a6-41e6-a8fa-ad7665c6b0da'::uuid, $s$PERMI (T/JUSS (permissive/jussive mood)$s$, $s$PERMIT/JUSS (permissive/jussive mood)$s$),
    ('c7195d6b-0ccf-4db7-a0dc-97250ae0e2a6'::uuid, $s$temporal/locative marker ("at the time of, duri...$s$, $s$temporal/locative marker$s$),
    ('a4f83172-5bcb-47cb-a32f-bbc8da787677'::uuid, $s$LOC ("in, at" (locative)$s$, $s$LOC ("in, at" (locative))$s$),
    ('23317ad1-c23c-4d1c-ae47-db59d9c7f627'::uuid, $s$unknown (possibly proper noun or speciali$s$, NULL),
    ('b28904d9-08fc-46be-93d1-6164d60633a3'::uuid, $s$uncertain (possibly compound verb or descriptiv...$s$, NULL),
    ('3158f2ae-4218-4efb-a45c-32c7a30ee5f6'::uuid, $s$PURP (purpose/benefactive marker ("for, in order to")$s$, $s$PURP (purpose/benefactive marker ("for, in order to"))$s$),
    ('2df841c9-705a-4d8c-9801-10977d7ddf69'::uuid, $s$RED (action (intensive/repetitive)$s$, $s$RED (action (intensive/repetitive))$s$),
    ('53827bf8-f99d-4209-80d8-e2fb55306c2d'::uuid, $s$unknown plural noun (possibly people who perfor...$s$, NULL),
    ('d701dbe0-c26b-46ea-8112-38e116a62cd7'::uuid, $s$unknown (possibly emphatic particle or content ...$s$, NULL),
    ('6080d56e-4867-4e19-bac2-4bf6453340a7'::uuid, $s$unknown compound (possibly place name or proper...$s$, NULL),
    ('75566a82-da50-49bb-933e-a6303c932c8e'::uuid, $s$[unknown proper noun or compound] + -amu (2PL p...$s$, NULL),
    ('d1dba042-aa0f-4ea5-9121-fae63e51eccb'::uuid, $s$two/both + 2PL possessive ("your two" or "both ...$s$, $s$two/both + 2PL possessive$s$),
    ('ea40d04b-05ed-41dc-9790-559c7dd6effe'::uuid, $s$uncertain (possible reduplicated noun with 2SG ...$s$, NULL),
    ('bea9ea0a-fa44-438d-a2d3-a72a7a81a508'::uuid, $s$unknown (possible reduplicated form with posses...$s$, NULL),
    ('741f5479-1f26-4292-9228-b55baa1bede9'::uuid, $s$unknown verb/adjective (possibly "shining/gleam...$s$, NULL),
    ('23f41371-82ac-44ee-b473-563007ec83e8'::uuid, $s$unknown content word (possibly proper noun or t...$s$, NULL),
    ('17e1f0dd-34ef-4c85-9c43-567ad26b354c'::uuid, $s$unknown action/state (possibly "circumcised" re...$s$, NULL),
    ('0940d1d3-a788-435b-8af8-a250a394d943'::uuid, $s$POSS (.PL - plural possessive marker ("of, belonging to")$s$, $s$POSS.PL - plural possessive marker ("of, belonging to")$s$),
    ('e4ba9ffb-78f5-4405-8558-4ff336874280'::uuid, $s$pillars, columns, capitals (architectural eleme...$s$, $s$pillars, columns, capitals$s$),
    ('71e43212-2b55-4fa6-b7a0-7525ae3a96ab'::uuid, $s$verb (unknown meaning, possibly related to bles...$s$, NULL),
    ('db235e3c-a8de-4c86-954c-41818b21739a'::uuid, $s$PERF (.3SG (perfective aspect, 3rd person singular)$s$, $s$PERF.3SG (perfective aspect, 3rd person singular)$s$),
    ('fc879813-d53a-47e1-89a0-875848a9cfe4'::uuid, $s$plural noun (likely referring to multiple simil...$s$, NULL),
    ('8cf5e3bc-766c-4971-bd75-c3a3baaebba6'::uuid, $s$INDEF (indefinite article/determiner ("a, one, any")$s$, $s$INDEF (indefinite article/determiner ("a, one, any"))$s$),
    ('0cea69b6-532e-42f1-a4b2-5899feed8d0f'::uuid, $s$TAM (tense/aspect/mood marker (past/realis)$s$, $s$TAM (tense/aspect/mood marker (past/realis))$s$),
    ('dc5e9e08-f82d-4ebd-8c66-ad72e329c377'::uuid, $s$QUOT (quotative marker ("that", introducing reported speech/thoughts)$s$, $s$QUOT (quotative marker ("that", introducing reported speech/thoughts))$s$),
    ('7abb5763-ffcd-4058-8ecb-63ccbde5c3c8'::uuid, $s$buildings; structures (towers, altars, construc...$s$, $s$buildings; structures$s$),
    ('69bc9ba6-277f-4de4-90d6-c4e2c8a87989'::uuid, $s$textiles; cloth items (hangings, garments, fabr...$s$, $s$textiles; cloth items$s$),
    ('68cfadf9-9a91-4f1c-965e-e88eef8038ed'::uuid, $s$INTER (R - interrogative particle ("why, what")$s$, $s$INTERR - interrogative particle ("why, what")$s$),
    ('0ef0fe97-8efa-4807-92ac-a1a98264522e'::uuid, $s$livestock; animals (domestic animals for sacrif...$s$, $s$livestock; animals$s$),
    ('5298261c-21db-46b5-9c24-d0ea9472989b'::uuid, $s$CAUS (causative marker ("let, allow, make")$s$, $s$CAUS (causative marker ("let, allow, make"))$s$),
    ('105729a7-8692-4bec-9f94-07a4dbcf3bcb'::uuid, $s$prohibition/negative modal (would not allow, sh...$s$, $s$prohibition/negative modal$s$),
    ('4c7b677f-21d0-408a-b920-a05152b9bf89'::uuid, $s$PAST (/PERF (completed action)$s$, $s$PAST/PERF (completed action)$s$),
    ('c73ec60f-d649-4dc8-8da3-638a6728d32f'::uuid, $s$corner; structural element (corner, gate, wall,...$s$, $s$corner; structural element$s$),
    ('d483d512-70ba-4561-a4b4-55b0b483ee09'::uuid, $s$net, network (fishing equipment or decorative m...$s$, $s$net, network$s$),
    ('032e880e-a4df-4c4d-a244-40cfa05318b0'::uuid, $s$Michal (proper name: Saul's daughter, David's w...$s$, $s$Michal$s$),
    ('a11cba0d-0f94-4717-bb2c-e677e230c926'::uuid, $s$Ephrath/Ephrathah (place name, ancient name for...$s$, $s$Ephrath/Ephrathah$s$),
    ('b9cdf104-3ac9-4248-aff3-d0e3638b4f85'::uuid, $s$settle, establish residence (build houses and d...$s$, $s$settle, establish residence$s$),
    ('4e4e0da6-1208-447c-a08c-3f89154a7ec0'::uuid, $s$pieces, fragments (especially of wood or burnt ...$s$, $s$pieces, fragments$s$),
    ('3473e80b-fa71-4dc8-9d2b-b92b809c7007'::uuid, $s$PREP (locative/directional preposition ("in, into, from")$s$, $s$PREP (locative/directional preposition ("in, into, from"))$s$),
    ('86773fc4-aeb8-4cbf-a38c-8dc3df3de67c'::uuid, $s$precious stone (topa$s$, $s$precious stone$s$),
    ('b5c4e556-9052-4b92-8b77-898e5a7e85ad'::uuid, $s$CONJ (discourse connector ("but, however, then")$s$, $s$CONJ (discourse connector ("but, however, then"))$s$),
    ('267ff2d3-41da-4742-8027-c097c95a427f'::uuid, $s$DEM (.DIST.PL - distal plural demonstrative ("those")$s$, $s$DEM.DIST.PL - distal plural demonstrative ("those")$s$),
    ('4bfec096-c7ea-4889-b1a8-96f3c26a450d'::uuid, $s$unknown content word (possibly kinship/person t...$s$, NULL),
    ('1de613a0-3104-4367-954a-8858457260f9'::uuid, $s$uncertain (possibly personal name or pronoun wi...$s$, NULL),
    ('c2feb99e-2136-4881-bf54-15a751e30e78'::uuid, $s$uncertain (possibly discourse marker or complex...$s$, NULL),
    ('6d8b0247-8213-46c9-936c-c2531c2b96b4'::uuid, $s$Ophel (proper noun - fortified area/citadel in ...$s$, $s$Ophel$s$),
    ('4ed69ec1-dc1c-42ca-bfb5-975b0c96c269'::uuid, $s$valuation; assessment (especially of people/pro...$s$, $s$valuation; assessment$s$),
    ('481d3714-f560-4d8d-a88c-5816c55cd452'::uuid, $s$from/of Metah (place name with ablative/genitiv...$s$, $s$from/of Metah$s$),
    ('02944764-36c6-49c0-80f4-45f984c749db'::uuid, $s$uncertain (possibly proper noun or locative exp...$s$, NULL),
    ('5d208c05-1b13-49c1-a4b9-4ea878b7c291'::uuid, $s$unknown plural noun (possibly ritual/ceremonial...$s$, NULL),
    ('4bbd244e-be0b-4135-8b29-436868d45c67'::uuid, $s$kinship term (2SG possessive, "your relative/fa...$s$, NULL),
    ('c03238e9-5967-47dd-aa45-5f5e38bd5e98'::uuid, $s$"towards; in the direction of" (directional mar...$s$, $s$towards; in the direction of$s$),
    ('867fe008-bb50-4fdb-acac-bf632b19ba40'::uuid, $s$unknown term (possibly proper noun or technical...$s$, NULL),
    ('6bde5b37-08cf-4642-ae40-5c8bae9d877f'::uuid, $s$INTER (J (interjection or particle)$s$, $s$INTERJ (interjection or particle)$s$),
    ('9d2fa3a6-192a-417f-be3a-80a4a9440e65'::uuid, $s$speak/talk (reduplicated verb for continuous/ha...$s$, $s$speak/talk$s$),
    ('4703ffe7-7424-4589-9560-ff83e4a7988b'::uuid, $s$unknown content word (possibly ritual/ceremonia...$s$, NULL),
    ('5757d2cf-cb22-4533-9c7e-846074c8b310'::uuid, $s$uncertain content word (possibly "reproach" or ...$s$, NULL),
    ('224b5626-4e2b-4478-8964-2b72accd7951'::uuid, $s$uncertain (possibly proper noun or rare content...$s$, NULL),
    ('d21eab0b-09da-48ae-9407-34be9ba6aacd'::uuid, $s$unknown content word (possibly place name or co...$s$, NULL),
    ('c7d45a3a-98c1-4598-bb82-666eb189040d'::uuid, $s$proper noun (likely biblical name "Exol" or var...$s$, NULL),
    ('be5e5378-efcc-4ed1-96ad-dc42816e847f'::uuid, $s$unknown noun (possibly personal name or kinship...$s$, NULL),
    ('493db93b-6203-4ec6-98d2-25f3e5fea265'::uuid, $s$[unknown noun, possibly related to "ḡau" (what/...$s$, NULL),
    ('2fca16c7-764b-4e0e-b49b-98ab24ad22cc'::uuid, $s$unknown compound (possibly "those who oppose/fi...$s$, NULL),
    ('3c8f63c7-0b1d-4666-b604-d7ccc0c2fc7f'::uuid, $s$unknown complex form (possibly "workers" or "do...$s$, NULL),
    ('b4eb1b58-ec93-474d-a383-50db0d5a8a23'::uuid, $s$compound form (possibly "those who X and those ...$s$, NULL),
    ('f15e2148-7ca5-46e2-8651-980e278afb8a'::uuid, $s$uncertain (possibly a proper name or complex de...$s$, NULL),
    ('9e5822bc-a129-4839-bd96-a5ba6d05b194'::uuid, $s$uncertain content word (possibly related to tim...$s$, NULL),
    ('3abc457d-ecf3-4567-98e4-0f4752888374'::uuid, $s$unknown compound noun (possibly "those who teac...$s$, NULL),
    ('86f53671-2918-4e97-9e71-80fb0ea50d84'::uuid, $s$visit (likely borrowing from Spanish/English "v...$s$, $s$visit$s$),
    ('af574a46-5aca-4da2-903f-979edaad8894'::uuid, $s$and-people-all-people (compound meaning "and al...$s$, $s$and-people-all-people$s$),
    ('31893119-337d-49cb-8d6e-8b0d62631fd9'::uuid, $s$unknown noun (possibly body part or abstract co...$s$, NULL),
    ('ff5bbeb7-38bf-440a-a49f-154dc3bc006f'::uuid, $s$unknown (possibly borrowed conjunction or prepo...$s$, NULL),
    ('60ff8fe9-be89-45b9-b768-cdd2fbbf8b23'::uuid, $s$unknown verb (possibly "to gather/collect/assem...$s$, NULL),
    ('253a5ee5-b908-4953-82d9-bce2274a59f4'::uuid, $s$plural noun (possibly "their provisions/belongi...$s$, NULL),
    ('8951465d-5a23-4120-83ca-d30ae8946a65'::uuid, $s$possessed action/state (possibly "your tremblin...$s$, NULL),
    ('e036cd7b-1e22-4808-b20b-e4bfb1a72410'::uuid, $s$uncertain (complex derived form with 2SG posses...$s$, NULL),
    ('5b6d833d-602b-4a25-9610-0b9250224225'::uuid, $s$[reduplicated form] + -na (3SG possessive/defin...$s$, NULL),
    ('d8936977-eb74-4331-ac12-21e92a8f23f4'::uuid, $s$unknown noun (possibly place name or group desi...$s$, NULL),
    ('3ea2979f-d8f2-4f1a-8503-3005c1a3fd4b'::uuid, $s$"Boanerges" (proper name meaning "sons of thund...$s$, $s$Boanerges$s$),
    ('8dcad037-21e6-4ec5-96db-a05112c979ea'::uuid, $s$unknown content word (possibly reduplicated/rep...$s$, NULL),
    ('f191ad96-3bff-45a3-9a7f-541cbb47e87f'::uuid, $s$gather, collect (reduplication suggests repeate...$s$, $s$gather, collect$s$),
    ('0a1a1785-3715-4499-a9fa-04f2eef44779'::uuid, $s$unknown (possibly proper noun or rare lexical i...$s$, NULL)
)
UPDATE public.words w
SET suggested_translations = CASE
      WHEN f.new_value IS NULL THEN array_remove(w.suggested_translations, f.old_value)
      ELSE array_replace(w.suggested_translations, f.old_value, f.new_value)
    END
FROM fixes f
WHERE w.id = f.id
  AND f.old_value = ANY (w.suggested_translations);

ALTER TABLE public.words ENABLE TRIGGER update_words_updated_at;
