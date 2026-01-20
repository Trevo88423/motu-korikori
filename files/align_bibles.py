#!/usr/bin/env python3
"""
True Motu Bible Aligner
=======================
Downloads and aligns True Motu (meu) and World English Bible (eng-web) verse by verse.
Outputs CSV and JSON files suitable for Living Dictionaries import.

Usage:
    python align_bibles.py

Output:
    - aligned_verses.csv    (Living Dictionaries compatible)
    - aligned_verses.json   (Full structured data)
    - motu_vocabulary.csv   (Unique Motu words for dictionary building)

Copyright note: True Motu Bible (1959-1973) is CC BY-NC-ND 4.0
World English Bible is Public Domain.
"""

import os
import re
import csv
import json
import zipfile
import urllib.request
from pathlib import Path
from collections import Counter

# Download URLs
MOTU_USFM_URL = "https://eBible.org/Scriptures/meu_usfm.zip"
ENGLISH_USFM_URL = "https://eBible.org/Scriptures/eng-web_usfm.zip"

# Standard book codes (66 books, Protestant canon)
BOOK_CODES = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA",
    "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO",
    "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
    "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
    "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH",
    "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS",
    "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"
]

BOOK_NAMES = {
    "GEN": "Genesis", "EXO": "Exodus", "LEV": "Leviticus", "NUM": "Numbers",
    "DEU": "Deuteronomy", "JOS": "Joshua", "JDG": "Judges", "RUT": "Ruth",
    "1SA": "1 Samuel", "2SA": "2 Samuel", "1KI": "1 Kings", "2KI": "2 Kings",
    "1CH": "1 Chronicles", "2CH": "2 Chronicles", "EZR": "Ezra", "NEH": "Nehemiah",
    "EST": "Esther", "JOB": "Job", "PSA": "Psalms", "PRO": "Proverbs",
    "ECC": "Ecclesiastes", "SNG": "Song of Solomon", "ISA": "Isaiah", "JER": "Jeremiah",
    "LAM": "Lamentations", "EZK": "Ezekiel", "DAN": "Daniel", "HOS": "Hosea",
    "JOL": "Joel", "AMO": "Amos", "OBA": "Obadiah", "JON": "Jonah",
    "MIC": "Micah", "NAM": "Nahum", "HAB": "Habakkuk", "ZEP": "Zephaniah",
    "HAG": "Haggai", "ZEC": "Zechariah", "MAL": "Malachi",
    "MAT": "Matthew", "MRK": "Mark", "LUK": "Luke", "JHN": "John",
    "ACT": "Acts", "ROM": "Romans", "1CO": "1 Corinthians", "2CO": "2 Corinthians",
    "GAL": "Galatians", "EPH": "Ephesians", "PHP": "Philippians", "COL": "Colossians",
    "1TH": "1 Thessalonians", "2TH": "2 Thessalonians", "1TI": "1 Timothy", "2TI": "2 Timothy",
    "TIT": "Titus", "PHM": "Philemon", "HEB": "Hebrews", "JAS": "James",
    "1PE": "1 Peter", "2PE": "2 Peter", "1JN": "1 John", "2JN": "2 John",
    "3JN": "3 John", "JUD": "Jude", "REV": "Revelation"
}


def download_file(url, dest_path):
    """Download a file with progress indicator."""
    print(f"Downloading {url}...")
    try:
        urllib.request.urlretrieve(url, dest_path)
        print(f"  Saved to {dest_path}")
        return True
    except Exception as e:
        print(f"  Error: {e}")
        return False


def extract_zip(zip_path, extract_dir):
    """Extract zip file to directory."""
    print(f"Extracting {zip_path}...")
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(extract_dir)
    print(f"  Extracted to {extract_dir}")


def parse_usfm_file(filepath):
    """
    Parse a USFM file and extract verses.
    Returns dict: {chapter_num: {verse_num: verse_text}}
    """
    verses = {}
    current_chapter = 0
    current_verse = 0
    verse_text = []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        with open(filepath, 'r', encoding='latin-1') as f:
            content = f.read()
    
    lines = content.split('\n')
    
    for line in lines:
        line = line.strip()
        
        # Chapter marker: \c 1
        if line.startswith('\\c '):
            # Save previous verse if any
            if current_verse > 0 and verse_text:
                if current_chapter not in verses:
                    verses[current_chapter] = {}
                verses[current_chapter][current_verse] = clean_verse(' '.join(verse_text))
            
            try:
                current_chapter = int(line.split()[1])
            except (IndexError, ValueError):
                continue
            current_verse = 0
            verse_text = []
        
        # Verse marker: \v 1 text...
        elif line.startswith('\\v '):
            # Save previous verse
            if current_verse > 0 and verse_text:
                if current_chapter not in verses:
                    verses[current_chapter] = {}
                verses[current_chapter][current_verse] = clean_verse(' '.join(verse_text))
            
            # Parse new verse
            parts = line[3:].split(None, 1)
            if parts:
                try:
                    # Handle verse ranges like "1-2"
                    verse_str = parts[0].split('-')[0]
                    current_verse = int(verse_str)
                except ValueError:
                    continue
                
                verse_text = [parts[1]] if len(parts) > 1 else []
        
        # Continuation of verse text (various markers)
        elif current_verse > 0:
            # Skip marker-only lines
            if line.startswith('\\') and ' ' not in line:
                continue
            # Extract text after markers
            text = re.sub(r'\\[a-z]+\d*\s*', ' ', line)
            text = re.sub(r'\\[a-z]+\d*\*', '', text)  # Remove end markers
            text = text.strip()
            if text:
                verse_text.append(text)
    
    # Don't forget the last verse!
    if current_verse > 0 and verse_text:
        if current_chapter not in verses:
            verses[current_chapter] = {}
        verses[current_chapter][current_verse] = clean_verse(' '.join(verse_text))
    
    return verses


def clean_verse(text):
    """Clean up verse text by removing USFM markers and extra whitespace."""
    # Remove footnotes entirely (e.g., \f + \fr 1:1 \ft text\f*)
    text = re.sub(r'\\f\s+\+[^\\]*(?:\\[^f][^\\]*)*\\f\*', '', text)

    # Remove word markup but keep the word (e.g., \w word|strong="H123"\w* → word)
    text = re.sub(r'\\w\s+([^\\|]+)\|[^\\]*\\w\*', r'\1', text)
    text = re.sub(r'\\w\s+([^\\]+?)\\w\*', r'\1', text)

    # Remove other markers like \+wh and \+wh*
    text = re.sub(r'\\\+wh[^\\]*\\\+wh\*', '', text)

    # Remove remaining USFM markers
    text = re.sub(r'\\[a-z]+\d*\s*', ' ', text)
    text = re.sub(r'\\[a-z]+\d*\*', '', text)

    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def find_usfm_files(directory):
    """Find all USFM files in directory, mapped by book code."""
    files = {}
    for filename in os.listdir(directory):
        if filename.endswith('.usfm') or filename.endswith('.SFM'):
            # Extract book code from filename (e.g., "01-GEN.usfm" or "GEN.usfm")
            base = filename.replace('.usfm', '').replace('.SFM', '')
            base_upper = base.upper()
            for code in BOOK_CODES:
                # Match book code with word boundaries (dash, start, or end of string)
                # This prevents "GEN" from matching "DAGeng-web"
                if (f'-{code}-' in base_upper or
                    f'-{code}' in base_upper or
                    base_upper.startswith(f'{code}-') or
                    base_upper == code):
                    files[code] = os.path.join(directory, filename)
                    break
    return files


def align_bibles(motu_dir, english_dir):
    """
    Align Motu and English bibles verse by verse.
    Returns list of aligned verse dicts.
    """
    motu_files = find_usfm_files(motu_dir)
    english_files = find_usfm_files(english_dir)
    
    aligned = []
    
    for book_code in BOOK_CODES:
        if book_code not in motu_files:
            print(f"  Skipping {book_code} - not in Motu")
            continue
        if book_code not in english_files:
            print(f"  Skipping {book_code} - not in English")
            continue
        
        print(f"  Processing {book_code}...")
        
        motu_verses = parse_usfm_file(motu_files[book_code])
        english_verses = parse_usfm_file(english_files[book_code])
        
        # Align by chapter and verse
        all_chapters = set(motu_verses.keys()) | set(english_verses.keys())
        
        for chapter in sorted(all_chapters):
            motu_ch = motu_verses.get(chapter, {})
            english_ch = english_verses.get(chapter, {})
            all_verses = set(motu_ch.keys()) | set(english_ch.keys())
            
            for verse in sorted(all_verses):
                motu_text = motu_ch.get(verse, "")
                english_text = english_ch.get(verse, "")
                
                if motu_text or english_text:  # At least one has text
                    aligned.append({
                        "book_code": book_code,
                        "book_name": BOOK_NAMES.get(book_code, book_code),
                        "chapter": chapter,
                        "verse": verse,
                        "reference": f"{book_code} {chapter}:{verse}",
                        "motu": motu_text,
                        "english": english_text
                    })
    
    return aligned


def extract_vocabulary(aligned_verses):
    """
    Extract unique Motu words with frequency counts.
    Returns list of (word, count, example_verse) tuples.
    """
    word_counts = Counter()
    word_examples = {}
    
    for entry in aligned_verses:
        motu_text = entry["motu"]
        if not motu_text:
            continue
        
        # Simple word extraction (could be improved with proper tokenization)
        words = re.findall(r'[a-zA-ZÀ-ÿ\-ḡḻṉṣṭẓ]+', motu_text.lower())
        
        for word in words:
            word_counts[word] += 1
            if word not in word_examples:
                word_examples[word] = entry["reference"]
    
    # Sort by frequency
    vocab = []
    for word, count in word_counts.most_common():
        vocab.append({
            "motu_word": word,
            "frequency": count,
            "example_reference": word_examples[word],
            "english_gloss": "",  # To be filled in by Clare
            "notes": ""
        })
    
    return vocab


def save_csv(data, filepath, fieldnames):
    """Save data to CSV file."""
    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    print(f"Saved {len(data)} rows to {filepath}")


def save_json(data, filepath):
    """Save data to JSON file."""
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Saved to {filepath}")


def main():
    # Setup directories
    work_dir = Path("bible_data")
    work_dir.mkdir(exist_ok=True)
    
    motu_zip = work_dir / "meu_usfm.zip"
    english_zip = work_dir / "eng-web_usfm.zip"
    motu_dir = work_dir / "motu"
    english_dir = work_dir / "english"
    
    # Download if needed
    if not motu_zip.exists():
        if not download_file(MOTU_USFM_URL, motu_zip):
            print("Failed to download Motu Bible. Please download manually from:")
            print(f"  {MOTU_USFM_URL}")
            print(f"  Save to: {motu_zip}")
            return
    
    if not english_zip.exists():
        if not download_file(ENGLISH_USFM_URL, english_zip):
            print("Failed to download English Bible. Please download manually from:")
            print(f"  {ENGLISH_USFM_URL}")
            print(f"  Save to: {english_zip}")
            return
    
    # Extract
    if not motu_dir.exists():
        motu_dir.mkdir()
        extract_zip(motu_zip, motu_dir)
    
    if not english_dir.exists():
        english_dir.mkdir()
        extract_zip(english_zip, english_dir)
    
    # Find actual USFM directory (may be nested)
    for subdir in motu_dir.iterdir():
        if subdir.is_dir():
            motu_dir = subdir
            break
    
    for subdir in english_dir.iterdir():
        if subdir.is_dir():
            english_dir = subdir
            break
    
    # Align verses
    print("\nAligning verses...")
    aligned = align_bibles(motu_dir, english_dir)
    print(f"\nTotal aligned verses: {len(aligned)}")
    
    # Save aligned verses
    save_csv(aligned, "aligned_verses.csv", 
             ["book_code", "book_name", "chapter", "verse", "reference", "motu", "english"])
    save_json(aligned, "aligned_verses.json")
    
    # Extract vocabulary
    print("\nExtracting vocabulary...")
    vocab = extract_vocabulary(aligned)
    print(f"Unique Motu words: {len(vocab)}")
    
    save_csv(vocab, "motu_vocabulary.csv",
             ["motu_word", "frequency", "example_reference", "english_gloss", "notes"])
    
    # Summary stats
    motu_only = sum(1 for v in aligned if v["motu"] and not v["english"])
    english_only = sum(1 for v in aligned if v["english"] and not v["motu"])
    both = sum(1 for v in aligned if v["motu"] and v["english"])
    
    print(f"\n=== Summary ===")
    print(f"Verses with both Motu and English: {both}")
    print(f"Verses with Motu only: {motu_only}")
    print(f"Verses with English only: {english_only}")
    print(f"Unique Motu vocabulary: {len(vocab)} words")
    print(f"\nOutput files:")
    print(f"  - aligned_verses.csv (for parallel text reference)")
    print(f"  - aligned_verses.json (full structured data)")
    print(f"  - motu_vocabulary.csv (word list for Living Dictionaries)")
    print(f"\nNext steps:")
    print(f"  1. Import motu_vocabulary.csv into Living Dictionaries")
    print(f"  2. Have Clare add audio recordings for each word")
    print(f"  3. Use aligned_verses.csv to compare her pronunciation with 1973 text")
    print(f"  4. Flag differences between written and spoken True Motu")


if __name__ == "__main__":
    main()
