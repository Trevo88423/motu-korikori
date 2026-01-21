# Quick Start - Manual Translation Batches

Use this when you want to manually run AI translations for specific words or batches.

## Location
```
C:\Projects\Language builder\files\ai_classify_with_bible_context.py
```

## Quick Commands

### Test Single Word
```bash
cd "C:\Projects\Language builder\files"
python ai_classify_with_bible_context.py --word "bena"
```

### Small Batch (10 words)
```bash
python ai_classify_with_bible_context.py --batch 10 --force --update-db
```

### Medium Batch (100 words from middle frequency)
```bash
python ai_classify_with_bible_context.py --batch 100 --offset 1000 --force --update-db
```

### Large Batch (500 words)
```bash
python ai_classify_with_bible_context.py --batch 500 --force --update-db
```

## Parameters

- `--word "xyz"` - Test single word
- `--batch N` - Process N words
- `--offset N` - Skip first N words (useful for middle/low frequency words)
- `--force` - Reprocess even if translation exists (improves quality)
- `--update-db` - Save to database (without this, just shows results)

## What It Does

✅ Loads Bible corpus (31,116 verses)
✅ Shows word in context with **bolded** highlighting
✅ Analyzes collocations and patterns
✅ Generates translation with confidence (high/medium/low)
✅ Detects polysemous words (multiple meanings)
✅ Includes detailed linguistic notes
✅ Shows timing and progress

## Output Example

```
[1/10] Analyzing: bena (freq: 8760)
  ✓ and; and then
    Confidence: high
    Time: 12.3s
    Progress: 1/10 | Avg: 12.3s/word | ETA: 1.8min

[Complete batch shows:]
- Total time
- Average time per word
- Confidence breakdown (High/Med/Low %)
- Polysemous word count
```

## Performance

- **Speed:** ~12.5 seconds per word
- **Cost:** ~$0.01 per 100 words (Sonnet 4.5)
- **Quality:** 80% high confidence (from tests)

## When to Use

**Good times to run batches:**
- After users contribute to words - verify/improve with AI
- When adding new words to dictionary
- To seed common words before launch
- To improve existing translations

**Let community handle:**
- Cultural context and nuance
- Spoken vs. formal usage differences
- Regional variations
- Everyday vocabulary not in Bible

## Notes

- Script auto-loads API key from `dictionary-app/.env.local`
- Only updates `suggested_translations` (not ai_notes/ai_confidence - those columns don't exist yet)
- Use `--force` to reprocess words with better quality
- Bible corpus best for grammatical words, less good for modern vocabulary

---

**Philosophy:** AI provides initial suggestions, community validates and improves them. This is a tool to help, not replace community knowledge!
