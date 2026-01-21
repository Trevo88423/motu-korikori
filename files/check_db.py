#!/usr/bin/env python3
"""Quick script to check database translation status"""

import os
from dotenv import load_dotenv
from pathlib import Path
from supabase import create_client

# Load environment variables
load_dotenv(Path(__file__).parent.parent / 'dictionary-app' / '.env.local')

supabase_url = os.environ.get('NEXT_PUBLIC_SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')

supabase = create_client(supabase_url, supabase_key)

# Get sample words to check status
sample = supabase.table('words')\
    .select('motu_word, suggested_translations')\
    .order('frequency', desc=True)\
    .limit(100)\
    .execute()

words = sample.data
total = len(words)
with_trans = sum(1 for w in words if w['suggested_translations'] and len(w['suggested_translations']) > 0)
without_trans = total - with_trans

print(f"Checked top 100 most frequent words:")
print(f"  With translations: {with_trans}")
print(f"  Without translations: {without_trans}")

print(f"\nTop 10 most frequent words:")
for word in sample.data[:10]:
    trans = word['suggested_translations'] if word['suggested_translations'] else 'null'
    print(f"  {word['motu_word']}: {trans}")
