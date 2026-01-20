# Self-Hosting Guide: Fork for Your Language

This guide explains how to adapt the True Motu Dictionary platform for **any endangered language**.

## Overview

The platform is designed to be language-agnostic. You'll need:

1. A word list for your language
2. (Optional) A parallel text corpus for AI-suggested translations
3. Basic technical setup (Supabase, Cloudflare, Vercel)

---

## Step 1: Fork the Repository

```bash
# Fork on GitHub, then clone
git clone https://github.com/YOUR_USERNAME/your-language-dictionary.git
cd your-language-dictionary
```

---

## Step 2: Prepare Your Word List

You need a CSV file with your language's vocabulary:

```csv
word,frequency,example_sentence,example_translation
taonga,1523,"Ko tēnei taonga nō ōku tūpuna","This treasure is from my ancestors"
whānau,892,"Kei te pai taku whānau","My family is well"
...
```

### Option A: From a Bible Translation

If your language has a Bible translation on [ebible.org](https://ebible.org), you can use our alignment script:

```bash
cd scripts

# Edit align_bibles.py to use your language code
# Find your code at: https://ebible.org/find/

# Example for Māori:
MOTU_USFM_URL = "https://eBible.org/Scriptures/mri_usfm.zip"

python align_bibles.py
```

This will:
- Download your language's Bible
- Download an English Bible
- Align verses
- Extract vocabulary with frequency counts
- Generate example sentences with translations

### Option B: From a Dictionary

If you have an existing dictionary (PDF, spreadsheet, etc.):

1. Convert to CSV format
2. Include at minimum: `word`, `frequency` (or estimate), `example_sentence`
3. Place in `scripts/data/vocabulary.csv`

### Option C: From Scratch

Start with a basic word list and let your community build it:

```csv
word,frequency,example_sentence,example_translation
hello,100,"","" 
goodbye,100,"",""
water,100,"",""
...
```

---

## Step 3: Update Branding

### App Name & Copy

Edit these files:

```
app/layout.tsx          # Site title, metadata
app/page.tsx            # Landing page content
components/Header.tsx   # Logo, navigation
```

Search and replace:
- "True Motu" → "Your Language Name"
- "Motu korikori" → "Your language's native name"
- "Papua New Guinea" → "Your region"

### Language Code

Update the ISO 639-3 code in:

```
lib/constants.ts

export const LANGUAGE = {
  name: "Your Language",
  nativeName: "Native Name",
  iso639_3: "xxx",  // Your language code
  region: "Your Region",
};
```

---

## Step 4: Set Up Infrastructure

### Supabase

1. Create account at [supabase.com](https://supabase.com)
2. Create new project (choose region closest to your users)
3. Run the schema from `docs/SCHEMA.sql`
4. Copy URL and anon key

### Cloudflare R2

1. Create account at [cloudflare.com](https://cloudflare.com)
2. Go to R2 → Create bucket
3. Name it: `your-language-audio`
4. Deploy the Worker from `worker/audio-upload/`

### Vercel

1. Create account at [vercel.com](https://vercel.com)
2. Import your GitHub repo
3. Add environment variables:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `NEXT_PUBLIC_R2_UPLOAD_URL`
4. Deploy

---

## Step 5: Seed the Database

```bash
# Set your Supabase credentials
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_KEY="your-service-key"

# Run the seeder
npm run seed
```

This loads your vocabulary into the `words` table.

---

## Step 6: Customize (Optional)

### Add Language-Specific Fields

Your language might need additional data:

```sql
-- Example: Add tone markers for tonal languages
ALTER TABLE words ADD COLUMN tone_pattern TEXT;

-- Example: Add dialect field for languages with regional variants
ALTER TABLE contributions ADD COLUMN dialect TEXT;
```

### Modify the Consent Flow

Edit `app/signup/page.tsx` to match your community's needs and local laws.

### Add Language-Specific Features

Some ideas:
- **Tone languages:** Add tone recording/display
- **Sign languages:** Add video upload instead of audio
- **Written scripts:** Add character input tools

---

## Step 7: Build Your Community

The platform is only as good as its contributors.

### Find Native Speakers

- Local cultural organizations
- Universities with linguistics programs
- Diaspora communities on social media
- Churches/religious organizations (often have language programs)
- Elders' groups and cultural preservation societies

### Spread the Word

- Create a Facebook group/page
- Post in relevant subreddits
- Contact linguistics departments
- Reach out to language activists

### Incentivize Contributions

- Leaderboards (built-in)
- Community recognition
- Certificates for major contributors
- Partner with schools/universities

---

## Step 8: Maintain & Grow

### Regular Tasks

- Review flagged words weekly
- Check for bad actors/spam
- Celebrate milestones (1000 words defined, etc.)
- Export data backups

### Growing the Platform

- Add more word sources (songs, stories, conversations)
- Partner with linguists for verification
- Apply for grants (many exist for language preservation)
- Train AI models as you collect more data

---

## Need Help?

- Open an issue on the [main repository](https://github.com/ORIGINAL_REPO/issues)
- Join our [Discussions](https://github.com/ORIGINAL_REPO/discussions)
- Check if others have forked for similar languages

---

## Languages Using This Platform

*Want to be listed here? Open a PR!*

| Language | Region | Repository | Status |
|----------|--------|------------|--------|
| True Motu | Papua New Guinea | [Link](#) | Active |
| *Your language* | *Your region* | *Your repo* | *Your status* |

---

## License

This platform is MIT licensed. You're free to:
- Use it commercially or non-commercially
- Modify it however you need
- Keep your fork private or make it public

We just ask that you preserve the license notice and, if possible, let us know you're using it!

---

*Preserving languages, one word at a time.* 🌏
