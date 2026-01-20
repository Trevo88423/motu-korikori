# Project Structure

This repository contains the True Motu Dictionary platform with the following structure:

```
true-motu-dictionary/
├── README.md                    # Project overview (you are here)
├── CONTRIBUTING.md              # Contribution guidelines
├── LICENSE                      # MIT License
├── SELF_HOSTING.md              # Guide for forking to other languages
├── .gitignore                   # Git ignore rules
├── .env.example                 # Environment variables template
│
├── files/                       # Source data
│   ├── motu_vocabulary.csv      # 15,610 Motu words with frequency
│   └── aligned_verses.csv       # Bible verses (Motu ↔ English)
│
├── align_bibles.py              # Python script for Bible text alignment
│
└── dictionary-app/              # Main Next.js application
    ├── app/                     # Next.js pages (App Router)
    │   ├── page.tsx             # Landing page
    │   ├── login/               # Login page
    │   ├── signup/              # Multi-step signup
    │   ├── contribute/          # Flashcard interface
    │   ├── dashboard/           # User stats
    │   ├── dictionary/          # Browse & word details
    │   └── admin/               # Moderation panel
    │
    ├── components/              # React components
    │   ├── WordCard.tsx         # Flashcard display
    │   ├── AudioRecorder.tsx    # Browser audio recording
    │   ├── ConsensusBar.tsx     # Consensus visualization
    │   ├── SignupForm.tsx       # Signup form
    │   └── ConsentForm.tsx      # Consent collection
    │
    ├── lib/                     # Utilities & business logic
    │   ├── supabase.ts          # Server Supabase client
    │   ├── supabase-client.ts   # Browser Supabase client
    │   ├── types.ts             # TypeScript types
    │   ├── consensus.ts         # Consensus algorithm
    │   └── uploadAudio.ts       # R2 audio upload
    │
    ├── supabase/                # Database configuration
    │   ├── schema.sql           # Complete database schema
    │   ├── seed-words.ts        # CSV to SQL converter
    │   └── seed.sql             # Generated (run npm run seed:generate)
    │
    ├── cloudflare-worker/       # Audio upload worker
    │   ├── audio-upload.js      # R2 upload handler
    │   ├── wrangler.toml        # Cloudflare configuration
    │   └── README.md            # Worker setup guide
    │
    ├── middleware.ts            # Route protection
    ├── package.json             # Dependencies
    ├── tsconfig.json            # TypeScript config
    ├── tailwind.config.ts       # Tailwind CSS config
    ├── next.config.js           # Next.js config
    │
    ├── DEPLOYMENT.md            # Step-by-step deployment guide
    ├── IMPLEMENTATION_SUMMARY.md # Feature breakdown
    ├── BUILD_SUCCESS.md         # Build verification
    └── README.md                # App-specific README
```

## Quick Reference

### Setup & Development
- **Installation**: See `dictionary-app/README.md`
- **Deployment**: See `dictionary-app/DEPLOYMENT.md`
- **Contributing**: See `CONTRIBUTING.md`
- **Fork for another language**: See `SELF_HOSTING.md`

### Key Files
- **Database schema**: `dictionary-app/supabase/schema.sql`
- **Source data**: `files/motu_vocabulary.csv` and `files/aligned_verses.csv`
- **Main app**: `dictionary-app/app/`
- **Cloudflare Worker**: `dictionary-app/cloudflare-worker/`

### Scripts
- `npm install` - Install dependencies (run in `dictionary-app/`)
- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run seed:generate` - Generate seed.sql from CSV files

## Data Flow

1. **Source Data** (`files/*.csv`)
   → 2. **Seed Script** (`dictionary-app/supabase/seed-words.ts`)
   → 3. **Generated SQL** (`dictionary-app/supabase/seed.sql`)
   → 4. **Supabase Database**
   → 5. **Next.js App** displays and collects contributions

## Size Notes

- The `seed.sql` file (~6.5MB) is excluded from Git
- Generate it locally with: `npm run seed:generate`
- Source CSV files (~2MB) are included in the repository
