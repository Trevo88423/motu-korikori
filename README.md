[README.md](https://github.com/user-attachments/files/24736196/README.md)
# True Motu Dictionary Builder

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

🌏 **Languages Documented:** 1 (True Motu)  
👥 **Contributors:** –  
📝 **Words Defined:** – / 15,611  
🎤 **Audio Recordings:** –  

---

## What is this?

A **crowdsourced dictionary platform** for documenting endangered languages, starting with **True Motu (Motu korikori)** — an Austronesian language spoken in the Port Moresby region of Papua New Guinea.

Community members contribute:
- **Translations** — what does each word mean in English?
- **Audio recordings** — how is it actually pronounced?
- **Context** — regional variations, generational differences, usage notes

The platform tracks **consensus** across contributors, flags disagreements for review, and builds a living dictionary that captures the language as it's actually spoken today.

> ⚠️ **Not Hiri Motu**: True Motu (ISO 639-3: `meu`) is the original, complex Austronesian language — not to be confused with Hiri Motu/Police Motu (`hmo`), which is a simplified pidgin trade language.

---

## Why does this matter?

**True Motu is endangered.** 

Most fluent speakers are elderly. Younger generations often understand it but can't speak it fluently. Without documentation, the language — and the culture embedded within it — will be lost.

This project aims to:

1. **Preserve** the language before fluent speakers are gone
2. **Document** how the living language differs from historical texts (like the 1973 Bible translation)
3. **Enable** future generations to learn their ancestral language
4. **Train AI** speech recognition so technology can support the language
5. **Provide infrastructure** other endangered languages can reuse

---

## Features

### For Contributors

- 📝 **Flashcard interface** — one word at a time, low friction
- 🎤 **Audio recording** — record pronunciation directly in browser
- 💡 **AI-suggested translations** — based on aligned Bible verses
- 📊 **Progress tracking** — see your contribution streak and stats
- 👥 **Community consensus** — see what others have said

### For Researchers

- 🔬 **Demographic data** — analyze by age, region, speaker type
- 📈 **Generational analysis** — which words are young people losing?
- 🗺️ **Regional variants** — track dialect differences
- 📤 **Data export** — full dataset available for research

### For Admins

- 🛡️ **Moderation tools** — flag, warn, suspend, ban bad actors
- 📊 **Trust scores** — algorithmic quality detection
- ✅ **Consensus review** — resolve disputed translations

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Next.js 14, React, Tailwind CSS |
| **Auth & Database** | Supabase (PostgreSQL + Auth + RLS) |
| **Audio Storage** | Cloudflare R2 |
| **Upload Handler** | Cloudflare Worker |
| **Hosting** | Vercel |
| **Cost** | **$0/month** on free tiers |

---

## Quick Start

### Prerequisites

- Node.js 18+
- A Supabase account (free tier works)
- A Cloudflare account (free tier works)
- A Vercel account (free tier works)

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/true-motu-dictionary.git
cd true-motu-dictionary
npm install
```

### 2. Set up Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to SQL Editor and run the schema from `/docs/SCHEMA.sql`
3. Copy your project URL and anon key

### 3. Set up Cloudflare R2

1. Create an R2 bucket called `motu-audio`
2. Deploy the Worker from `/worker/audio-upload`
3. Note your Worker URL

### 4. Configure environment

```bash
cp .env.example .env.local
```

Edit `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_R2_UPLOAD_URL=https://your-worker.workers.dev
```

### 5. Seed the database

```bash
# Download and align the Bible texts
cd scripts
python align_bibles.py

# Seed words into Supabase
npm run seed
```

### 6. Run locally

```bash
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000)

---

## Project Structure

```
├── app/
│   ├── page.tsx              # Landing page
│   ├── login/page.tsx        # Login
│   ├── signup/page.tsx       # Signup with consent
│   ├── contribute/page.tsx   # Main flashcard interface
│   ├── dashboard/page.tsx    # User stats
│   ├── dictionary/page.tsx   # Browse all words
│   └── admin/page.tsx        # Moderation panel
├── components/
│   ├── WordCard.tsx          # Flashcard display
│   ├── AudioRecorder.tsx     # Browser recording
│   ├── ConsensusBar.tsx      # Community agreement viz
│   └── ConsentForm.tsx       # Signup consent flow
├── lib/
│   ├── supabase.ts           # Database client
│   └── uploadAudio.ts        # R2 upload helper
├── scripts/
│   ├── align_bibles.py       # Bible text alignment
│   └── seed_words.ts         # Database seeder
├── worker/
│   └── audio-upload/         # Cloudflare Worker
└── docs/
    ├── SCHEMA.sql            # Full database schema
    ├── API.md                # API documentation
    └── SELF_HOSTING.md       # Fork for your language
```

---

## Data Sources

The initial word list comes from the **1973 True Motu Bible** (Buk Baibel long tokples Motu):

- **Source:** [ebible.org/meu](https://ebible.org/meu/)
- **License:** CC BY-NC-ND 4.0 (Bible Society of Papua New Guinea)
- **Words extracted:** 15,611 unique words
- **Verses aligned:** ~31,000 (Motu ↔ English parallel corpus)

This gives us:
- Every word with frequency count
- Example verse in Motu
- Aligned English translation for context

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Ways to help

| Type | How |
|------|-----|
| **🗣️ Native speaker?** | Sign up and contribute translations + audio |
| **👨‍💻 Developer?** | Check the issues, submit PRs |
| **🎨 Designer?** | Help improve the UI/UX |
| **📚 Linguist?** | Help with quality review and verification |
| **🌍 Have another language?** | Fork this for your community! |

---

## Fork for Your Language

This project is designed to be **reusable for any endangered language**.

See [docs/SELF_HOSTING.md](docs/SELF_HOSTING.md) for a complete guide, but the basic steps are:

1. Fork this repo
2. Replace the word list with your language's data
3. Update branding/copy
4. Deploy your own instance
5. Build your community

If you have a parallel text corpus (like a Bible translation), you can use our `align_bibles.py` script to bootstrap your word list.

**Languages that could use this:**
- Māori (New Zealand)
- Cree, Ojibwe, Inuktitut (Canada)
- Hawaiian (USA)
- Welsh (UK)
- Aboriginal Australian languages
- Any of the 7,000+ languages worldwide

---

## Privacy & Data

- **We collect:** Name, email, age range, location, language background
- **We use it for:** Understanding regional/generational language patterns
- **We never:** Sell your data
- **You can:** Export or delete your data anytime
- **Audio recordings:** Used for dictionary and AI training (with consent)

See [PRIVACY.md](PRIVACY.md) for the full privacy policy.

---

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

The True Motu Bible text is licensed under CC BY-NC-ND 4.0 by the Bible Society of Papua New Guinea.

---

## Acknowledgments

- **Clare** — Native True Motu speaker and the inspiration for this project
- **Bible Society of Papua New Guinea** — For making the 1973 Bible translation available
- **Living Tongues Institute** — For [Living Dictionaries](https://livingdictionaries.app), which inspired this project
- **eBible.org** — For hosting freely accessible Bible translations

---

## Contact

- **Project Owner:** Trevor
- **Issues:** [GitHub Issues](https://github.com/YOUR_USERNAME/true-motu-dictionary/issues)
- **Discussions:** [GitHub Discussions](https://github.com/YOUR_USERNAME/true-motu-dictionary/discussions)

---

<p align="center">
  <i>Preserving languages, one word at a time.</i>
</p>
