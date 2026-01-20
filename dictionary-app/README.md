# True Motu Dictionary (Motu Korikori)

A crowdsourced dictionary application for documenting and preserving True Motu, an endangered language of Papua New Guinea.

## Overview

This application enables community-driven documentation of Motu korikori through:
- **Crowdsourced Translations**: Users contribute English translations for 15,610 Motu words
- **Audio Pronunciations**: Record and share native pronunciations
- **Consensus Algorithm**: Automatically determines consensus translations with weighted voting
- **Trust System**: Weights contributions based on speaker type and community accuracy
- **Gamification**: Track progress, streaks, and contribution stats

## Features

### For Contributors
- 📝 **Flashcard Interface**: Learn and contribute one word at a time
- 🎙️ **Audio Recording**: Capture native pronunciations directly in browser
- 📊 **Progress Tracking**: See your impact with detailed statistics
- 🏆 **Achievements**: Build streaks and earn trust score

### For Language Learners
- 📖 **Browse Dictionary**: Search and explore all 15,610 words
- 🗣️ **Community Pronunciations**: Listen to audio from native speakers
- 📚 **Example Sentences**: See words in context from scripture
- ✅ **Consensus Translations**: View community-agreed definitions

### For Researchers
- 🔍 **Contribution Tracking**: Full history of all translations
- 📈 **Consensus Data**: Weighted voting results and confidence scores
- 👥 **Speaker Metadata**: Connection type, locations, transmission patterns
- 🎯 **Quality Metrics**: Trust scores and consensus rates

### For Admins
- 🛡️ **Moderation Tools**: Flag words, warn/suspend users
- 📋 **Audit Log**: Complete moderation history
- ⚖️ **Trust Management**: Adjust user trust scores
- 🚫 **Content Control**: Exclude contributions from consensus or AI training

## Tech Stack

- **Frontend**: Next.js 15, React 18, TypeScript, Tailwind CSS
- **Backend**: Supabase (PostgreSQL, Auth, RLS)
- **Audio Storage**: Cloudflare R2 + Worker
- **Deployment**: Vercel

## Project Structure

```
dictionary-app/
├── app/                      # Next.js app router pages
│   ├── page.tsx              # Landing page
│   ├── login/                # Authentication
│   ├── signup/               # Multi-step signup
│   ├── contribute/           # Flashcard contribution interface
│   ├── dashboard/            # User stats
│   ├── dictionary/           # Browse and search
│   └── admin/                # Moderation panel
├── components/               # Reusable React components
│   ├── WordCard.tsx          # Main contribution interface
│   ├── AudioRecorder.tsx     # Browser audio recording
│   ├── ConsensusBar.tsx      # Visualize community consensus
│   ├── SignupForm.tsx        # Multi-step signup form
│   └── ConsentForm.tsx       # Consent collection
├── lib/                      # Utilities and business logic
│   ├── supabase.ts           # Database client
│   ├── types.ts              # TypeScript definitions
│   ├── consensus.ts          # Consensus calculation algorithm
│   └── uploadAudio.ts        # R2 audio upload
├── supabase/                 # Database configuration
│   ├── schema.sql            # Complete database schema
│   ├── seed-words.ts         # CSV import script
│   └── seed.sql              # Generated seed data
├── cloudflare-worker/        # Audio upload worker
│   ├── audio-upload.js       # R2 upload handler
│   ├── wrangler.toml         # Worker configuration
│   └── README.md             # Setup instructions
└── middleware.ts             # Route protection

```

## Quick Start

### Prerequisites
- Node.js 18+
- npm or pnpm

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/motu-dictionary.git
cd motu-dictionary/dictionary-app

# Install dependencies
npm install

# Copy environment template
cp .env.local.example .env.local

# Edit .env.local with your credentials
# (See DEPLOYMENT.md for full setup)

# Generate seed data
npm run seed:generate

# Run development server
npm run dev
```

Visit `http://localhost:3000`

## Database Schema

### Key Tables

**profiles** - Extended user information
- Demographics (age, locations, connection to language)
- Consents (ToS, dictionary use, AI training)
- Trust metrics (score, consensus rate, streak)
- Status (active, warned, suspended, banned)

**words** - 15,610 Motu words
- Word data (motu_word, frequency, examples)
- Consensus (gloss, audio, confidence, status)
- Stats (total contributions, unique contributors)

**contributions** - User translations
- Translation (english_gloss, audio_url, confidence)
- Metadata (is_excluded, matches_consensus)
- Foreign keys (word_id, user_id)

**moderation_log** - Admin actions
- Action type (warn, suspend, flag, verify, etc.)
- Target (user or word)
- Reason and timestamp

### Row Level Security

All tables use RLS policies:
- Users can only view/edit their own profile
- Anyone can view words (public dictionary)
- Authenticated users can contribute
- Only admins can moderate

## Consensus Algorithm

The system automatically calculates consensus using weighted voting:

### Weighting Factors

**Connection Type Weights:**
- Native Speaker: 2.0x
- Heritage Speaker: 1.5x
- Second Language Learner: 1.0x
- Currently Learning: 0.5x
- Researcher: 1.0x

**Trust Score Multiplier:**
- Ranges from 0.0 to 2.0
- Based on consensus rate and admin adjustments
- Defaults to 1.0 for new users

### Consensus Criteria

- **Consensus Reached**: Single gloss has >60% of weighted votes
- **Flagged**: Top 2 glosses within 10% of each other
- **Pending**: Contributions exist but no clear consensus

### Audio Selection

Consensus audio is selected from the highest-weighted contributor who provided the consensus gloss.

## Development

### Running Tests

```bash
npm run test
```

### Linting

```bash
npm run lint
```

### Type Checking

```bash
npm run type-check
```

### Building for Production

```bash
npm run build
npm run start
```

## Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete deployment instructions to:
- Supabase (database)
- Cloudflare R2 (audio storage)
- Vercel (hosting)

## Data Sources

- **Vocabulary**: 15,610 words from Bible translation corpus
- **Examples**: Aligned verses from Motu and English Bibles
- **Frequency**: Occurrence counts from corpus analysis

## Privacy & Ethics

This project handles sensitive data about an endangered language community:

- **Informed Consent**: Multi-step signup with explicit consents
- **Age Verification**: Guardian consent for users under 18
- **Opt-outs**: Users can exclude contributions from AI training
- **Moderation**: Admins can remove problematic content
- **Transparency**: Full contribution history and audit logs

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](./LICENSE)

## Acknowledgments

- Motu language community
- Bible translation organizations
- Linguistic researchers
- Open source contributors

## Contact

For questions or support, please open an issue on GitHub.

---

**Status**: ✅ Ready for deployment

**Version**: 1.0.0

**Last Updated**: January 2026
