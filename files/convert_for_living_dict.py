#!/usr/bin/env python3
"""
Living Dictionaries Import Converter
====================================
Converts the motu_vocabulary.csv to Living Dictionaries import format.

Living Dictionaries CSV format:
- lexeme (required): The word/phrase in the language
- phonetic: IPA pronunciation (optional, Clare can add audio instead)
- gloss_en: English translation
- part_of_speech: noun, verb, adj, etc.
- example_sentence: Example usage
- semantic_domain: Category like "body", "food", "nature"
- notes: Additional notes

Usage:
    python convert_for_living_dict.py

Run this AFTER running align_bibles.py
"""

import csv
import json
from pathlib import Path


def convert_to_living_dict_format(vocab_csv, output_csv):
    """Convert vocabulary CSV to Living Dictionaries import format."""
    
    rows = []
    with open(vocab_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "lexeme": row["motu_word"],
                "phonetic": "",  # Clare adds audio instead
                "gloss_en": row.get("english_gloss", ""),
                "part_of_speech": "",  # To be filled in
                "example_sentence": "",  # Could pull from verse
                "semantic_domain": "",  # To be categorized
                "notes": f"Freq: {row['frequency']}. Example: {row['example_reference']}. {row.get('notes', '')}"
            })
    
    # Save Living Dictionaries format
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ["lexeme", "phonetic", "gloss_en", "part_of_speech", 
                      "example_sentence", "semantic_domain", "notes"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"Converted {len(rows)} words to Living Dictionaries format")
    print(f"Output: {output_csv}")
    return len(rows)


def create_starter_categories():
    """
    Create a starter list of semantic domains for categorization.
    Based on common linguistic categories.
    """
    domains = {
        "body": "Body parts, physical states, health",
        "food": "Food, drink, eating, cooking",
        "nature": "Animals, plants, weather, landscape",
        "family": "Kinship terms, relationships",
        "house": "Home, buildings, furniture",
        "tools": "Tools, implements, technology",
        "clothing": "Clothes, adornments",
        "time": "Time expressions, seasons, calendar",
        "number": "Numbers, quantities",
        "action": "Common verbs, actions",
        "emotion": "Feelings, states of mind",
        "religion": "Religious/spiritual terms",
        "social": "Social interactions, community",
        "color": "Colors, visual descriptions",
        "direction": "Directions, locations",
        "question": "Question words",
        "grammar": "Grammatical particles, connectors"
    }
    
    with open("semantic_domains.json", 'w', encoding='utf-8') as f:
        json.dump(domains, f, indent=2, ensure_ascii=False)
    
    print(f"Created semantic_domains.json with {len(domains)} categories")


def create_high_frequency_starter(vocab_csv, output_csv, top_n=200):
    """
    Create a starter set of the most frequent words.
    This is a good starting point for Clare to begin documenting.
    """
    rows = []
    with open(vocab_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            if i >= top_n:
                break
            rows.append({
                "lexeme": row["motu_word"],
                "frequency": row["frequency"],
                "example_verse": row["example_reference"],
                "english_gloss": "",  # Clare fills this
                "clare_pronunciation": "",  # Different from 1973?
                "notes": ""
            })
    
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ["lexeme", "frequency", "example_verse", 
                      "english_gloss", "clare_pronunciation", "notes"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"Created starter set with top {len(rows)} most frequent words")
    print(f"Output: {output_csv}")


def main():
    vocab_file = Path("motu_vocabulary.csv")
    
    if not vocab_file.exists():
        print("Error: motu_vocabulary.csv not found!")
        print("Run align_bibles.py first to generate the vocabulary file.")
        return
    
    # Convert to Living Dictionaries format
    convert_to_living_dict_format(
        "motu_vocabulary.csv", 
        "living_dict_import.csv"
    )
    
    # Create semantic domains reference
    create_starter_categories()
    
    # Create high-frequency starter set
    create_high_frequency_starter(
        "motu_vocabulary.csv",
        "starter_200_words.csv",
        top_n=200
    )
    
    print("\n=== Files Created ===")
    print("1. living_dict_import.csv - Full vocabulary for Living Dictionaries import")
    print("2. semantic_domains.json - Categories for organizing words")
    print("3. starter_200_words.csv - Top 200 words for Clare to start with")
    print("\n=== Recommended Workflow ===")
    print("1. Start with starter_200_words.csv")
    print("2. Clare records audio pronunciation for each word")
    print("3. Clare adds English gloss (translation)")
    print("4. Note if her pronunciation differs from 1973 written form")
    print("5. Import batches into Living Dictionaries")
    print("6. Gradually work through full vocabulary")


if __name__ == "__main__":
    main()
