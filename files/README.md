# True Motu Bible Aligner

Tools to extract and align the 1973 True Motu Bible with an English Bible for language preservation.

## Purpose

Clare speaks True Motu (Motu korikori) - an endangered language from Papua New Guinea. This toolkit:

1. **Downloads** the True Motu Bible (1973) and World English Bible
2. **Aligns** verses side-by-side (Motu ↔ English)  
3. **Extracts** vocabulary for dictionary building
4. **Formats** data for Living Dictionaries import

## Quick Start

```bash
# 1. Install Python 3 if needed
# 2. Run the alignment script
python align_bibles.py

# 3. Convert to Living Dictionaries format
python convert_for_living_dict.py
```

## What You Get

| File | Description |
|------|-------------|
| `aligned_verses.csv` | Every verse with Motu and English side by side |
| `aligned_verses.json` | Same data in JSON format |
| `motu_vocabulary.csv` | Every unique Motu word with frequency |
| `living_dict_import.csv` | Living Dictionaries import format |
| `starter_200_words.csv` | Top 200 words for Clare to start with |

## Clare's Workflow

### Phase 1: Start with 200 high-frequency words
1. Open `starter_200_words.csv`
2. For each word:
   - Record herself saying it (Living Dictionaries has built-in recording)
   - Add English translation
   - Note if different from how it's written in 1973 bible

### Phase 2: Import to Living Dictionaries
1. Go to https://livingdictionaries.app
2. Create new dictionary "True Motu (Motu korikori)"
3. Import `living_dict_import.csv`
4. Add audio recordings directly in the app

### Phase 3: Document Differences
The 1973 bible represents "frozen" True Motu. Clare's living language may differ:
- **Pronunciation** - sounds that have shifted
- **Vocabulary** - new words, obsolete words
- **Grammar** - simplified constructions
- **Idioms** - phrases not in formal bible language

Use `aligned_verses.csv` to compare Clare's version with 1973 text.

## Data Sources

- **True Motu Bible**: https://ebible.org/meu/
  - Copyright © 1959-1973 Bible Society of Papua New Guinea
  - License: CC BY-NC-ND 4.0

- **World English Bible**: https://ebible.org/eng-web/
  - Public Domain

## Technical Details

### USFM Format
The bibles are in USFM (Unified Standard Format Markers) which looks like:
```
\c 1
\v 1 In the beginning God created the heavens and the earth.
\v 2 The earth was formless and empty...
```

The scripts parse this and extract chapter:verse → text mappings.

### Verse Alignment
Bibles follow standard versification, so Genesis 1:1 in Motu aligns with Genesis 1:1 in English. Some edge cases:
- Verse ranges (e.g., "1-2") are attributed to first verse
- Missing verses in one translation are noted

## Future: Speech-to-Text Training

Once Clare has recorded 5-8+ hours of audio with transcriptions:

1. Audio files + corrected transcripts = training data
2. Fine-tune OpenAI Whisper on this data
3. Result: Custom True Motu speech-to-text model

See: https://huggingface.co/blog/fine-tune-whisper

## Language Info

- **Language**: True Motu (Motu korikori)
- **ISO 639-3**: meu
- **Region**: Port Moresby area, Papua New Guinea
- **Status**: Endangered
- **NOT**: Hiri Motu (Police Motu) which is a simplified pidgin (ISO: hmo)

## Credits

Created for the Clare/Trevor True Motu language preservation project.
