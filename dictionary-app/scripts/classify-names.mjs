/**
 * Classify the dictionary's words as Motu vocabulary or Bible names (issue #75).
 *
 * The words table was seeded from files/motu_vocabulary.csv, a lower-cased
 * tokenisation of the 1973 Motu Bible, so personal and place names (iehova,
 * iesu, ierusalem, aigupto...) sit in it as if they were vocabulary. A name
 * is the one kind of token the Bible never writes in lower case, so this
 * script reads every verse in data/bible-indices/verses.json and, for each
 * word, counts how it is written:
 *
 *   lower     all lower case                      ("hanua")
 *   capMid    capitalised in the middle of a sentence  (", bena Hadad na")
 *   capStart  capitalised where a sentence may start: the first word of a
 *             verse, after . ! ? or :, after an opening quote, or after
 *             "eto," ("saying,")
 *
 * A word is a name when it is never lower case and is capitalised mid-sentence
 * at least once. A word that is only ever capitalised at the start of a
 * sentence is an ordinary word that happens to open sentences (kara-dika,
 * "Bena", "Vadaeni"...), so it stays vocabulary. The cost is that a name that
 * only ever opens a sentence is missed; those are listed for review.
 *
 * English-looking tokens: a name candidate whose lower-cased form is a common
 * lower-case word in the English text of the same Bible (king, lord...) is
 * not tagged; it is listed in data/word-types/english-review.json for a
 * speaker to look at (principle 2). Nothing is changed for them.
 *
 * Outputs (from dictionary-app/, deterministic: sorted, no timestamps):
 *   data/word-types/names.tsv            the words tagged as names, with evidence
 *   data/word-types/sentence-start.json  never lower case, only sentence-initial:
 *                                        left as vocabulary (the false-positive
 *                                        class the rule avoids), with evidence
 *   data/word-types/english-review.json  English-looking tokens for review
 *   data/word-types/near-misses.json     rarely lower case: names with typos,
 *                                        or real words that share a name's
 *                                        spelling (see REVIEWED_NAMES)
 *   data/word-types/summary.json         counts
 * With --sql it also prints the VALUES list used by the migration.
 *
 * Usage (from dictionary-app/):
 *   node scripts/classify-names.mjs
 *   node scripts/classify-names.mjs --sql > /tmp/names-values.sql
 */
import { readFileSync, writeFileSync, mkdirSync } from 'fs'
import { join } from 'path'

const root = process.cwd()
const verses = JSON.parse(readFileSync(join(root, 'data', 'bible-indices', 'verses.json'), 'utf-8'))
const csv = readFileSync(join(root, '..', 'files', 'motu_vocabulary.csv'), 'utf-8')
const outDir = join(root, 'data', 'word-types')

// The dictionary's words, as seeded (lower case, hyphens kept)
const dictionary = new Set(
  csv
    .split(/\r?\n/)
    .slice(1)
    .map((line) => line.split(',')[0])
    .filter(Boolean)
)

const TOKEN = /[A-Za-zÀ-ÿḡḠḻṉṣṭẓ\-]+/g
const stripHyphens = (t) => t.replace(/^-+|-+$/g, '')
// Text that ends a sentence: . ! ? or : (speech is introduced with a colon and
// starts with a capital), optionally followed by closing quotes or brackets.
const ENDS_SENTENCE = /[.!?:][\s"'”’)\]]*$/
// An opening quote or bracket right before a word also starts a sentence.
const OPENS = /["'“‘(\[]\s*$/

// Speech is also introduced with "eto," / "baoto," / "nato," ("saying,"),
// and the quoted words start with a capital.
const INTRODUCES_SPEECH = /\b(eto|baoto|nato),\s*["'“‘]?\s*$/i

const stats = new Map() // lower-cased form -> { lower, capMid, capStart, sampleMid, sampleStart }
function stat(form) {
  let s = stats.get(form)
  if (!s) {
    s = { lower: 0, capMid: 0, capStart: 0, sampleMid: null, sampleStart: null }
    stats.set(form, s)
  }
  return s
}

// English lower-case word counts, for spotting English tokens in the Motu text
const englishLower = new Map()

const refs = Object.keys(verses).sort()
for (const ref of refs) {
  const { motu, english } = verses[ref]

  if (english) {
    for (const m of english.matchAll(/[A-Za-z]+/g)) {
      const w = m[0]
      if (w === w.toLowerCase()) englishLower.set(w, (englishLower.get(w) || 0) + 1)
    }
  }

  if (!motu) continue

  let first = true
  for (const m of motu.matchAll(TOKEN)) {
    const raw = stripHyphens(m[0])
    if (!raw) continue
    const form = raw.toLowerCase()
    const s = stat(form)

    if (raw === form) {
      s.lower++
    } else {
      const before = motu.slice(0, m.index)
      // The first word of a verse always counts as a start: poetry (Psalms,
      // Job, Isaiah...) capitalises every verse, even mid-sentence.
      const atStart =
        first || ENDS_SENTENCE.test(before) || OPENS.test(before) || INTRODUCES_SPEECH.test(before)
      if (atStart) {
        s.capStart++
        s.sampleStart ??= ref
      } else {
        s.capMid++
        s.sampleMid ??= ref
      }
    }
    first = false
  }
}

// Common English words: written in lower case in the English text at least
// this often. High enough that names used as English common nouns rarely
// (a "lot", a "job") don't swamp the list, low enough to catch "king".
const ENGLISH_MIN = 20

// Names whose few lower-case occurrences are typos in the Bible text, checked
// by hand against data/word-types/near-misses.json (EXO.28.1 "ida, israel
// taudia"; EXO.14.26 "ese mose e hamaoroa"). The other near-misses are real
// Motu words that share a spelling with a name (benaia "so that", sinai,
// sera, turo...) or are capitalised for God (Dirava, Lohiabada), so they stay
// vocabulary.
const REVIEWED_NAMES = new Set(['israel', 'mose'])

// Near-misses: written in lower case, but rarely (at most 1 in 10 of its
// mid-sentence uses, with 5 or more of those).
const isNearMiss = (s) => s.lower > 0 && s.capMid >= 5 && s.lower / s.capMid <= 0.1

const names = []
const sentenceStart = []
const englishReview = []
const nearMisses = []

for (const word of [...dictionary].sort()) {
  const s = stats.get(word)
  if (!s) continue

  const evidence = {
    motu_word: word,
    capitalised_mid_sentence: s.capMid,
    capitalised_sentence_start: s.capStart,
    example_mid: s.sampleMid,
    example_start: s.sampleStart,
  }

  if (s.lower > 0) {
    if (isNearMiss(s)) {
      const reviewedName = REVIEWED_NAMES.has(word)
      nearMisses.push({ ...evidence, lower_case: s.lower, tagged_as_name: reviewedName })
      if (reviewedName) names.push(evidence)
    }
    continue
  }

  // Only plain-letter forms can be English words
  const englishCount = /^[a-z]+$/.test(word) ? englishLower.get(word) || 0 : 0
  if (englishCount >= ENGLISH_MIN) {
    englishReview.push({ ...evidence, english_lower_case_count: englishCount })
  } else if (s.capMid > 0) {
    names.push(evidence)
  } else {
    sentenceStart.push(evidence)
  }
}

const notInBible = [...dictionary].filter((w) => !stats.has(w)).length

const summary = {
  dictionary_words: dictionary.size,
  never_lower_case: names.length - REVIEWED_NAMES.size + sentenceStart.length + englishReview.length,
  names: names.length,
  names_reviewed_by_hand: REVIEWED_NAMES.size,
  near_misses: nearMisses.length,
  sentence_start_only_kept_as_vocabulary: sentenceStart.length,
  english_looking_for_review: englishReview.length,
  vocabulary: dictionary.size - names.length,
  dictionary_words_not_found_in_verses: notInBible,
}

mkdirSync(outDir, { recursive: true })
writeFileSync(
  join(outDir, 'names.tsv'),
  ['motu_word\tcapitalised_mid_sentence\tcapitalised_sentence_start\texample_mid']
    .concat(
      names.map((n) =>
        [n.motu_word, n.capitalised_mid_sentence, n.capitalised_sentence_start, n.example_mid].join('\t')
      )
    )
    .join('\n') + '\n'
)
writeFileSync(join(outDir, 'sentence-start.json'), JSON.stringify(sentenceStart, null, 2) + '\n')
writeFileSync(join(outDir, 'near-misses.json'), JSON.stringify(nearMisses, null, 2) + '\n')
writeFileSync(join(outDir, 'english-review.json'), JSON.stringify(englishReview, null, 2) + '\n')
writeFileSync(join(outDir, 'summary.json'), JSON.stringify(summary, null, 2) + '\n')

if (process.argv.includes('--sql')) {
  // Words are lower-case letters and hyphens only, but quote defensively
  const rows = names.map((n) => `  ('${n.motu_word.replace(/'/g, "''")}')`)
  process.stdout.write(rows.join(',\n') + '\n')
} else {
  console.log(summary)
}
