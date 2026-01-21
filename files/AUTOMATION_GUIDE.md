# Automating Bible-Context Translations

This guide explains how to automate what you've been doing manually with Claude Desktop.

## What This Does

Replicates your manual process:
1. ✓ Loads Bible corpus indices (word_index, collocations, verses)
2. ✓ For each word, provides rich context to Claude API
3. ✓ Gets high-quality translation + notes (same quality as Desktop)
4. ✓ Optionally updates database automatically

## Setup

### 1. Install Dependencies

```bash
cd "C:\Projects\Language builder\files"
pip install anthropic supabase
```

### 2. Set Environment Variables

Create a `.env` file or set these in your terminal:

```bash
# Required
ANTHROPIC_API_KEY=your_api_key_here

# Only needed for --update-db
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## Usage Examples

### Test Single Word (Like Claude Desktop)

```bash
python ai_classify_with_bible_context.py --word "baina"
```

Output:
```
Analyzing: baina
Frequency: 1941 occurrences

✓ Translation: I will; I shall (1st person singular irrealis marker)

Notes:
First person singular irrealis/future verb marker. Used for promises...
```

### Process 10 Words (Review Before Updating DB)

```bash
python ai_classify_with_bible_context.py --batch 10 --update-db
```

This will:
1. Find 10 words without translations (highest frequency first)
2. Process each with full Bible context
3. Automatically update database
4. Show progress

### Save Results to File (For Review)

```bash
python ai_classify_with_bible_context.py --word "baina" --output test_results.json
```

Review `test_results.json` before updating database.

## How It Compares to Manual Process

| Manual (Claude Desktop) | Automated (This Script) |
|------------------------|-------------------------|
| One word at a time | Batch processing available |
| You copy context manually | Loads Bible indices automatically |
| You copy/paste to DB | `--update-db` updates automatically |
| Uses Opus | Uses Sonnet 4.5 (similar quality, cheaper) |
| Perfect quality | Should match quality (test first!) |

## Recommended Workflow

### Step 1: Test on Known Words

Test with words you've already done to verify quality:

```bash
python ai_classify_with_bible_context.py --word "baina"
python ai_classify_with_bible_context.py --word "na"
python ai_classify_with_bible_context.py --word "ese"
```

Compare output to your manual translations. If quality matches → proceed.

### Step 2: Small Batch Test

```bash
python ai_classify_with_bible_context.py --batch 5 --update-db
```

Check database to verify updates look good.

### Step 3: Full Automation

Once confident:

```bash
# Process 50 words at a time
python ai_classify_with_bible_context.py --batch 50 --update-db
```

Run this repeatedly until all words are done.

## Cost Estimate

- **Claude Desktop (Opus)**: $15 per 1M input tokens, $75 per 1M output tokens
- **This Script (Sonnet 4.5)**: $3 per 1M input tokens, $15 per 1M output tokens

For 15,610 words:
- Estimated total cost: ~$50-100 (vs $250-500 with Opus)
- Processing time: ~4-5 hours for all words (vs weeks of manual work)

## Troubleshooting

### "Module not found: anthropic"
```bash
pip install anthropic
```

### "ANTHROPIC_API_KEY not set"
```bash
# Windows PowerShell
$env:ANTHROPIC_API_KEY="your_key"

# Windows CMD
set ANTHROPIC_API_KEY=your_key
```

### "Cannot find Bible data files"
Check that these files exist:
- `C:\Projects\Language builder\files\bible_data\word_index_motu.json`
- `C:\Projects\Language builder\files\bible_data\collocation_motu.json`
- `C:\Projects\Language builder\files\bible_data\verses.json`

### Quality doesn't match Claude Desktop
- Try with more examples: Edit `max_examples` in script (currently 10)
- Switch to Opus model: Change `claude-sonnet-4-20250514` to `claude-opus-4-20250514` in script

## Next Steps

1. **Test** with "baina" to verify it matches your manual translation
2. **Compare** quality on 5-10 words you've already done
3. **Run batch** processing if quality is good
4. **Monitor** first batch carefully, then increase batch size

Questions? The script is well-commented - read `ai_classify_with_bible_context.py` to understand how it works.
