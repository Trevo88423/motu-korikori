#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Automate Claude Desktop's Bible-context translation process

This script replicates what you've been doing manually:
1. Takes a word
2. Loads Bible corpus context (just like Claude Desktop reads the README)
3. Calls Claude API with full context
4. Gets high-quality translation + notes

Usage:
    # Process single word
    python ai_classify_with_bible_context.py --word "baina"

    # Process next N words without translations
    python ai_classify_with_bible_context.py --batch 10

    # Process and auto-update database
    python ai_classify_with_bible_context.py --batch 10 --update-db
"""

import json
import os
import sys
import anthropic
import time
from pathlib import Path
from typing import Optional, Dict, List

# Load environment variables from .env file if present
try:
    from dotenv import load_dotenv
    load_dotenv()  # Load from .env in current directory
    # Also try parent directories and dictionary-app
    load_dotenv(Path(__file__).parent / '.env')
    load_dotenv(Path(__file__).parent.parent / '.env')
    load_dotenv(Path(__file__).parent.parent / 'dictionary-app' / '.env.local')
except ImportError:
    pass  # python-dotenv not installed, rely on system env vars

# Fix Windows console encoding
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'ignore')

# Paths - Use indices/ subfolder (as per README instructions)
BIBLE_DATA_DIR = Path(r"C:\Projects\Language builder\files\bible_data")
INDICES_DIR = BIBLE_DATA_DIR / "indices"
INDICES_FILE = INDICES_DIR / "word_index_motu.json"
COLLOCATIONS_FILE = INDICES_DIR / "collocation_motu.json"
VERSES_FILE = INDICES_DIR / "verses.json"

class BibleContextAnalyzer:
    """Loads Bible corpus data and provides context for words"""

    def __init__(self):
        print("Loading Bible corpus indices...")
        with open(INDICES_FILE, 'r', encoding='utf-8') as f:
            self.word_index = json.load(f)
        with open(COLLOCATIONS_FILE, 'r', encoding='utf-8') as f:
            self.collocations = json.load(f)
        with open(VERSES_FILE, 'r', encoding='utf-8') as f:
            self.verses = json.load(f)
        print(f"Loaded {len(self.word_index)} words, {len(self.verses)} verses")

    def get_word_context(self, word: str, max_examples: int = 10) -> Dict:
        """Get all context for a word (like Claude Desktop sees)"""
        word_lower = word.lower()

        # Get occurrences
        refs = self.word_index.get(word_lower, [])
        frequency = len(refs)

        # Get example verses
        examples = []
        for ref in refs[:max_examples]:
            verse_data = self.verses.get(ref, {})
            if verse_data:
                examples.append({
                    'ref': ref,
                    'motu': verse_data.get('motu', ''),
                    'english': verse_data.get('english', '')
                })

        # Get collocations
        coll_data = self.collocations.get(word_lower, {})

        return {
            'word': word,
            'frequency': frequency,
            'examples': examples,
            'collocations': coll_data
        }

    def format_context_for_claude(self, context: Dict) -> str:
        """Format context into the prompt Claude Desktop would see"""
        word = context['word']
        freq = context['frequency']
        examples = context['examples']
        coll = context['collocations']

        # Build context string - focus on verse alignment
        parts = [
            f"# Word: {word}",
            f"Frequency: {freq} occurrences in Bible corpus",
            "",
            "## Example Verses (study the word alignment in translations):",
        ]

        # Show verses with clear word highlighting
        for i, ex in enumerate(examples[:10], 1):
            motu = ex['motu']
            english = ex['english']

            # Highlight the word in context
            # Find where the word appears in the Motu text
            word_lower = word.lower()
            motu_words = motu.split()
            highlighted_motu = []
            for w in motu_words:
                if word_lower in w.lower():
                    highlighted_motu.append(f"**{w}**")
                else:
                    highlighted_motu.append(w)

            parts.append(f"\n{i}. {ex['ref']}")
            parts.append(f"   Motu:    {' '.join(highlighted_motu[:50])}")
            parts.append(f"   English: {english[:200]}")

        # Add collocation data
        if coll and 'bigrams_right' in coll:
            parts.append("\n## Common Phrases:")
            top_bigrams = sorted(coll['bigrams_right'].items(), key=lambda x: -x[1])[:10]
            parts.append("  " + ', '.join([f'"{word} {phrase}" ({c}×)' for phrase, c in top_bigrams]))

        return '\n'.join(parts)


def call_claude_for_translation(word_context: str, word: str) -> Dict:
    """Call Claude API with Bible context (mimicking Claude Desktop)"""

    client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

    prompt = f"""You are a linguistic expert analyzing True Motu (Motu korikori), an endangered Austronesian language from Papua New Guinea.

You have access to a Bible corpus with 31,116 parallel verses. Study the Motu examples alongside their English translations to understand the word's meaning and grammatical function.

{word_context}

**Analysis Method:**

1. **Study the English translations carefully** - Look at where the bolded Motu word appears and how it's reflected in English
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

**Note on Polysemy**: Some words have different meanings in spoken vs. Biblical contexts. Check both!

**Your task:**
Provide:
1. **Translation**: Precise English gloss (if polysemous, use format: "meaning1; meaning2")
2. **Notes**: Include:
   - Grammatical category (verb marker, particle, pronoun, noun, etc.)
   - Common collocations with frequencies
   - If part of a paradigm, mention related forms
   - Usage examples from the verses
3. **Confidence**: high (matches known pattern/paradigm), medium (clear from verses), or low (uncertain)
4. **Polysemous flag**: If word has multiple distinct meanings in different contexts

Format as JSON:
{{
  "translation": "precise English gloss",
  "notes": "detailed linguistic analysis",
  "confidence": "high|medium|low",
  "polysemous": false,
  "meanings": []
}}

**If polysemous** (like "io" = yes/spear or "ai" = locative/pronoun):
{{
  "translation": "primary meaning; secondary meaning",
  "notes": "detailed analysis noting both contexts",
  "confidence": "high|medium|low",
  "polysemous": true,
  "meanings": [
    {{"context": "spoken/everyday", "gloss": "yes"}},
    {{"context": "biblical/formal", "gloss": "spear"}}
  ]
}}

**CRITICAL**:
- Base translation primarily on English verses, verify with collocations
- Flag polysemous words when verse contexts show multiple distinct meanings
- Set confidence based on: high = matches known paradigm, medium = clear from data, low = ambiguous"""

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        messages=[{
            "role": "user",
            "content": prompt
        }]
    )

    # Parse response
    response_text = message.content[0].text

    # Try to extract JSON
    try:
        # Look for JSON in response
        start = response_text.find('{')
        end = response_text.rfind('}') + 1
        if start != -1 and end > start:
            json_str = response_text[start:end]
            result = json.loads(json_str)

            # Ensure all expected fields exist
            if 'confidence' not in result:
                result['confidence'] = 'medium'
            if 'polysemous' not in result:
                result['polysemous'] = False
            if 'meanings' not in result:
                result['meanings'] = []

            return result
        else:
            # Fallback: treat whole response as notes
            return {
                "translation": "[see notes]",
                "notes": response_text,
                "confidence": "low",
                "polysemous": False,
                "meanings": []
            }
    except json.JSONDecodeError:
        return {
            "translation": "[see notes]",
            "notes": response_text,
            "confidence": "low",
            "polysemous": False,
            "meanings": []
        }


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Automate Bible-context translation')
    parser.add_argument('--word', help='Process single word')
    parser.add_argument('--batch', type=int, help='Process N words from database')
    parser.add_argument('--update-db', action='store_true', help='Update database (requires Supabase env vars)')
    parser.add_argument('--output', help='Save results to JSON file')
    parser.add_argument('--force', action='store_true', help='Reprocess words even if they already have translations')
    parser.add_argument('--offset', type=int, default=0, help='Skip first N words (for testing middle-frequency words)')

    args = parser.parse_args()

    # Check API key
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("ERROR: ANTHROPIC_API_KEY environment variable not set")
        return

    # Initialize analyzer
    analyzer = BibleContextAnalyzer()

    results = []

    if args.word:
        # Single word mode
        print(f"\n{'='*60}")
        print(f"Analyzing: {args.word}")
        print(f"{'='*60}\n")

        context = analyzer.get_word_context(args.word)
        context_str = analyzer.format_context_for_claude(context)

        print("Calling Claude API...")
        result = call_claude_for_translation(context_str, args.word)

        print(f"\n✓ Translation: {result['translation']}")
        print(f"  Confidence: {result.get('confidence', 'medium')}")
        if result.get('polysemous'):
            print(f"  ⚠️  Polysemous word - multiple meanings:")
            for meaning in result.get('meanings', []):
                print(f"     • {meaning.get('context', '?')}: {meaning.get('gloss', '?')}")

        print(f"\nNotes:\n{result['notes']}\n")

        results.append({
            'word': args.word,
            'frequency': context['frequency'],
            'translation': result['translation'],
            'notes': result['notes'],
            'confidence': result.get('confidence', 'medium'),
            'polysemous': result.get('polysemous', False),
            'meanings': result.get('meanings', [])
        })

    elif args.batch:
        # Batch mode - need database connection
        if not args.update_db:
            print("ERROR: --batch requires --update-db to connect to database")
            return

        try:
            from supabase import create_client
            # Try both SUPABASE_URL and NEXT_PUBLIC_SUPABASE_URL
            supabase_url = os.environ.get('SUPABASE_URL') or os.environ.get('NEXT_PUBLIC_SUPABASE_URL')
            supabase_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')

            if not supabase_url or not supabase_key:
                print("ERROR: Need SUPABASE_URL (or NEXT_PUBLIC_SUPABASE_URL) and SUPABASE_SERVICE_ROLE_KEY env vars")
                print(f"  Found URL: {bool(supabase_url)}")
                print(f"  Found KEY: {bool(supabase_key)}")
                return

            supabase = create_client(supabase_url, supabase_key)

            # Build query
            query = supabase.table('words')\
                .select('id, motu_word, frequency')\
                .order('frequency', desc=True)

            # Apply offset if specified
            if args.offset > 0:
                query = query.range(args.offset, args.offset + args.batch - 1)
            else:
                query = query.limit(args.batch)

            # Filter by translation status unless --force
            if not args.force:
                query = query.or_('suggested_translations.is.null,suggested_translations.eq.{}')

            response = query.execute()
            words = response.data

            if args.offset > 0:
                print(f"\nSkipping first {args.offset} words (offset)")
            print(f"Found {len(words)} words to process")
            if args.force:
                print("(--force: reprocessing words with existing translations)\n")
            else:
                print("(processing only words without translations)\n")

            # Timing
            batch_start = time.time()
            word_times = []

            for i, word_data in enumerate(words, 1):
                word = word_data['motu_word']
                freq = word_data['frequency']

                word_start = time.time()
                print(f"\n[{i}/{len(words)}] Analyzing: {word} (freq: {freq})")

                context = analyzer.get_word_context(word)
                context_str = analyzer.format_context_for_claude(context)

                result = call_claude_for_translation(context_str, word)

                word_time = time.time() - word_start
                word_times.append(word_time)

                confidence = result.get('confidence', 'medium')
                polysemous = result.get('polysemous', False)

                print(f"  ✓ {result['translation']}")
                print(f"    Confidence: {confidence}")
                if polysemous:
                    print(f"    ⚠️  Polysemous")
                print(f"    Time: {word_time:.1f}s")

                # Show progress estimate
                avg_time = sum(word_times) / len(word_times)
                remaining = len(words) - i
                est_remaining = avg_time * remaining
                print(f"    Progress: {i}/{len(words)} | Avg: {avg_time:.1f}s/word | ETA: {est_remaining/60:.1f}min")

                # Update database
                update_data = {
                    'suggested_translations': [result['translation']]
                }

                # Add optional fields if they exist in schema
                # Note: ai_notes and ai_confidence columns may not exist yet
                # The update will succeed with just suggested_translations

                supabase.table('words').update(update_data).eq('id', word_data['id']).execute()

                results.append({
                    'word': word,
                    'frequency': context['frequency'],
                    'translation': result['translation'],
                    'notes': result['notes'],
                    'confidence': confidence,
                    'polysemous': polysemous,
                    'meanings': result.get('meanings', [])
                })

            # Final summary
            batch_time = time.time() - batch_start
            print(f"\n{'='*60}")
            print(f"BATCH COMPLETE")
            print(f"{'='*60}")
            print(f"Total words processed: {len(words)}")
            print(f"Total time: {batch_time/60:.1f} minutes ({batch_time:.0f}s)")
            print(f"Average time per word: {sum(word_times)/len(word_times):.1f}s")
            print(f"Fastest: {min(word_times):.1f}s | Slowest: {max(word_times):.1f}s")

            # Confidence breakdown
            high_conf = sum(1 for r in results if r['confidence'] == 'high')
            med_conf = sum(1 for r in results if r['confidence'] == 'medium')
            low_conf = sum(1 for r in results if r['confidence'] == 'low')
            polysemous_count = sum(1 for r in results if r['polysemous'])

            print(f"\nConfidence breakdown:")
            print(f"  High: {high_conf} ({high_conf/len(results)*100:.0f}%)")
            print(f"  Medium: {med_conf} ({med_conf/len(results)*100:.0f}%)")
            print(f"  Low: {low_conf} ({low_conf/len(results)*100:.0f}%)")
            print(f"  Polysemous words: {polysemous_count}")

        except ImportError:
            print("ERROR: supabase-py not installed. Install with: pip install supabase")
            return

    else:
        parser.print_help()
        return

    # Save output if requested
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"\n✓ Saved results to {args.output}")


if __name__ == '__main__':
    main()
