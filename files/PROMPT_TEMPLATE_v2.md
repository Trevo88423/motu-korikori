# Improved Prompt Template for Bible-Context Translation

## What's New in V2

✅ **Applicative/Dative paradigm** (henigu, henimu, henia, henimui, henidia)
✅ **Discourse markers** (bena, eto)
✅ **Clare-verified everyday words** (io, lasi)
✅ **Polysemy detection** with context-specific meanings
✅ **Confidence levels** (high/medium/low)
✅ **Multiple meaning structure** for words with different spoken vs. biblical meanings

---

## Output Format

### Simple Words (Non-Polysemous)

```json
{
  "translation": "I will; I shall",
  "notes": "First person singular irrealis/future verb marker...",
  "confidence": "high",
  "polysemous": false,
  "meanings": []
}
```

**Example output:**
```
✓ Translation: I will; I shall
  Confidence: high

Notes:
First person singular irrealis/future verb marker. Part of the irrealis
paradigm: baina (1sg), ba (2sg), baine (3sg), bae (3pl). Common collocations...
```

### Polysemous Words (Multiple Meanings)

```json
{
  "translation": "spear; yes",
  "notes": "Polysemous word with distinct meanings by context...",
  "confidence": "high",
  "polysemous": true,
  "meanings": [
    {"context": "biblical/formal", "gloss": "spear"},
    {"context": "spoken/everyday", "gloss": "yes"}
  ]
}
```

**Example output:**
```
✓ Translation: spear; yes
  Confidence: high
  ⚠️  Polysemous word - multiple meanings:
     • biblical/formal: spear
     • spoken/everyday: yes

Notes:
Polysemous word with distinct meanings by context. In Biblical contexts,
'io' means 'spear'... In spoken contexts, means 'yes' as affirmative...
```

---

## Full Prompt Template

```
You are a linguistic expert analyzing True Motu (Motu korikori), an endangered
Austronesian language from Papua New Guinea.

You have access to a Bible corpus with 31,116 parallel verses. Study the Motu
examples alongside their English translations to understand the word's meaning
and grammatical function.

[WORD CONTEXT - verses, collocations, frequencies]

**Analysis Method:**

1. **Study the English translations carefully** - Look at where the bolded Motu
   word appears and how it's reflected in English
   - In "unu **baina** kara" → "that I should do" → baina = I (future/modal)
   - In "**baina** henimu" → "I will give you" → baina = I will
   - The English consistently shows what the Motu word means

2. **Verify with collocation patterns**:
   - "baina kara" (91×), "baina henimu" (68×), "baina abia" (68×) → precedes verbs
   - Pattern: baina + VERB = grammatical marker (not lexical word)

**Known Motu Grammar (from previous analyses):**

**Irrealis/Future Verb Markers:**
- ba (2sg) = you will; you shall
- baine (3sg) = he/she/it will; let (3sg)
- bae (3pl) = they will; let them
- [Missing: 1sg form - should follow this paradigm]

**Realis Verb Markers:**
- e = he/she/it (did); they (did) - 3rd person realis
- na = I (did); is/am/are (copula) - 1sg realis OR topic/copula marker
- o = you (did) - 2sg realis

**Aspect Marker:**
- vada = (perfective) already; has/have done

**Discourse/Narrative Markers:**
- bena = then; and then (sequential/narrative connector - very common, freq 8760)
- eto = said; saying (quotative marker introducing direct speech)

**Particles:**
- ese = (ergative marker) marks agent/doer
- ai = at; in; on; to (locative) OR we (exclusive pronoun) **[POLYSEMOUS]**
- amo = from; out of (ablative/source)
- bona = and; with (conjunction)
- ta = a; one; a certain (indefinite article)
- be = is; are; (copula); because
- danu = also; too; as well
- badina = why; because (interrogative/causal)

**Applicative/Dative (recipient marking):**
- henigu = to me; give me
- henimu = to you (sg); give you
- henia = to him/her; give him/her
- henimui = to you (pl); give you all
- henidia = to them; give them

**Pronouns:**
- lau = I; me (1sg)
- oi = you (2sg)
- ia = he; she; it; him; her (3sg)
- idia = they; them (3pl)

**Possessives:**
- egu = my; mine (1sg)
- emu = your; yours (2sg)
- ena = his; her; its (3sg)
- edia = their; theirs (3pl)

**Everyday/Spoken Words (Clare-verified):**
- io = yes (spoken/everyday) OR spear (Biblical) **[POLYSEMOUS - context matters!]**
- lasi = no; not; out (directional/negation)

**Word order**: Subject + ese + verb-marker + verb

**Note on Polysemy**: Some words have different meanings in spoken vs. Biblical
contexts. Check both!

**Your task:**
Provide:
1. **Translation**: Precise English gloss (if polysemous, use format: "meaning1; meaning2")
2. **Notes**: Include:
   - Grammatical category (verb marker, particle, pronoun, noun, etc.)
   - Common collocations with frequencies
   - If part of a paradigm, mention related forms
   - Usage examples from the verses
3. **Confidence**: high (matches known pattern/paradigm), medium (clear from verses),
   or low (uncertain)
4. **Polysemous flag**: If word has multiple distinct meanings in different contexts

Format as JSON:
{
  "translation": "precise English gloss",
  "notes": "detailed linguistic analysis",
  "confidence": "high|medium|low",
  "polysemous": false,
  "meanings": []
}

**If polysemous** (like "io" = yes/spear or "ai" = locative/pronoun):
{
  "translation": "primary meaning; secondary meaning",
  "notes": "detailed analysis noting both contexts",
  "confidence": "high|medium|low",
  "polysemous": true,
  "meanings": [
    {"context": "spoken/everyday", "gloss": "yes"},
    {"context": "biblical/formal", "gloss": "spear"}
  ]
}

**CRITICAL**:
- Base translation primarily on English verses, verify with collocations
- Flag polysemous words when verse contexts show multiple distinct meanings
- Set confidence based on: high = matches known paradigm, medium = clear from data,
  low = ambiguous
```

---

## Confidence Levels

**High**: Word matches a known grammatical paradigm or pattern
- Example: "baina" completes the irrealis paradigm (ba/baine/bae → baina must be 1sg)
- Example: "henigu" follows applicative pattern (henimu/henia → henigu is 1sg form)

**Medium**: Meaning clear from verse translations, but not part of known paradigm
- Example: Novel nouns, verbs, or content words with consistent translations
- Example: Words with consistent collocation patterns but no paradigm

**Low**: Ambiguous or uncertain
- Example: Low frequency words with inconsistent translations
- Example: Words where Bible context doesn't clearly reveal meaning

---

## Key Improvements

### 1. **Applicative Paradigm**
Now recognizes recipient-marking forms:
- henigu/henimu/henia/henimui/henidia pattern
- Completes applicative suffixation system

### 2. **Discourse Markers**
Includes critical narrative connectors:
- **bena** (freq 8760!) = then; and then
- **eto** = quotative marker for direct speech

### 3. **Clare-Verified Words**
Everyday spoken vocabulary:
- **io** = yes (polysemous with biblical "spear")
- **lasi** = no; not; out

### 4. **Polysemy Detection**
Flags words with multiple meanings:
- Identifies spoken vs. biblical contexts
- Provides structured meaning breakdown
- Visual warning in output (⚠️)

### 5. **Confidence Assessment**
Claude evaluates its own certainty:
- **High**: Matches paradigms, strong evidence
- **Medium**: Clear but novel/no paradigm
- **Low**: Ambiguous or uncertain

---

## Usage

```bash
# Test with simple word
python ai_classify_with_bible_context.py --word "baina"
# Output: high confidence, paradigm match

# Test with polysemous word
python ai_classify_with_bible_context.py --word "io"
# Output: high confidence, polysemous flag, two meanings

# Batch process with confidence tracking
python ai_classify_with_bible_context.py --batch 20 --update-db
# Shows confidence for each word processed
```

---

## Database Storage

Results are stored in `words` table:
- `suggested_translations` = ["translation string"]
- `ai_notes` = detailed linguistic analysis
- `ai_confidence` = "high"|"medium"|"low" (now uses Claude's assessment!)

---

## Credit

Prompt design based on:
- Claude Desktop's manual analysis methodology
- Bible corpus collocation analysis (README.md instructions)
- Clare's everyday vocabulary verification
- Your feedback on paradigm completion and polysemy detection!
