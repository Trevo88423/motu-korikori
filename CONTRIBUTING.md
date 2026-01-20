# Contributing to True Motu Dictionary

First off, thank you for considering contributing! 🙏

This project exists because of community effort. Whether you're a native speaker, a developer, a linguist, or just someone who cares about language preservation — there's a way for you to help.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Ways to Contribute](#ways-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guide](#style-guide)

---

## Code of Conduct

This project is dedicated to language preservation — a cause that brings together people from many cultures and backgrounds. Please be respectful and inclusive.

- Be welcoming to newcomers
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

---

## Ways to Contribute

### 🗣️ Native Speakers & Heritage Speakers

**Your contributions are the most valuable!**

1. Create an account at [website URL]
2. Contribute translations for Motu words
3. Record audio pronunciations
4. Flag words that seem incorrect
5. Add notes about regional variations or context

Even 10 minutes a day makes a difference.

### 👨‍💻 Developers

Check our [GitHub Issues](https://github.com/YOUR_USERNAME/true-motu-dictionary/issues) for:

- `good first issue` — Great for newcomers
- `help wanted` — We need extra hands
- `bug` — Something's broken
- `enhancement` — New features

Before starting major work, please open an issue to discuss your approach.

### 🎨 Designers

- Improve the UI/UX
- Create illustrations or graphics
- Help with accessibility
- Design marketing materials

### 📚 Linguists & Researchers

- Help verify translations
- Review flagged words
- Analyze patterns in the data
- Write documentation about the language
- Suggest improvements to our methodology

### 🌍 Other Languages

Want to use this for another endangered language? 

See [docs/SELF_HOSTING.md](docs/SELF_HOSTING.md) — we'd love to see forks for other languages and are happy to help you get started.

---

## Development Setup

### Prerequisites

- Node.js 18+
- npm or yarn
- Git

### Local Development

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/true-motu-dictionary.git
cd true-motu-dictionary

# Install dependencies
npm install

# Copy environment template
cp .env.example .env.local

# Start development server
npm run dev
```

For full setup including Supabase and Cloudflare, see the main [README.md](README.md).

### Running Tests

```bash
npm run test        # Unit tests
npm run test:e2e    # End-to-end tests
npm run lint        # Linting
```

---

## Pull Request Process

### 1. Fork & Branch

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/true-motu-dictionary.git
cd true-motu-dictionary
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

- Write clean, readable code
- Add tests if applicable
- Update documentation if needed

### 3. Commit

We use conventional commits:

```bash
git commit -m "feat: add audio playback speed control"
git commit -m "fix: resolve recording timeout on mobile"
git commit -m "docs: update self-hosting guide"
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 4. Push & Create PR

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub.

### 5. Review Process

- A maintainer will review your PR
- Address any feedback
- Once approved, it will be merged

---

## Style Guide

### Code Style

- **TypeScript** for type safety
- **Prettier** for formatting (runs on commit)
- **ESLint** for linting

```bash
npm run lint        # Check for issues
npm run lint:fix    # Auto-fix issues
```

### Component Structure

```tsx
// components/ExampleComponent.tsx

interface ExampleComponentProps {
  title: string;
  onAction: () => void;
}

export function ExampleComponent({ title, onAction }: ExampleComponentProps) {
  return (
    <div className="...">
      {/* Component content */}
    </div>
  );
}
```

### File Naming

- **Components:** PascalCase (`WordCard.tsx`)
- **Utilities:** camelCase (`uploadAudio.ts`)
- **Pages:** lowercase with hyphens (`/contribute/page.tsx`)

---

## Questions?

- **General questions:** [GitHub Discussions](https://github.com/YOUR_USERNAME/true-motu-dictionary/discussions)
- **Bug reports:** [GitHub Issues](https://github.com/YOUR_USERNAME/true-motu-dictionary/issues)
- **Security issues:** Email [your-email] directly

---

Thank you for helping preserve endangered languages! 🌏
