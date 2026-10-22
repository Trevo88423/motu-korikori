# Truemotu (motu-korikori)

Community Motu-language dictionary, live at https://truemotu.org.
Repo: `Trevo88423/motu-korikori`. Owner: Trevor.

## Layout

- `dictionary-app/` — the Next.js 15 app (App Router, Tailwind, Supabase). All app commands run from here.
  - `app/` routes, `components/`, `lib/` (Supabase clients, consensus logic), `middleware.ts`
  - `supabase/migrations/` — the **only** source of schema changes (see below)
  - `supabase/schema.sql`, `migration-voting-system.sql` — historical, already applied; never replay
  - `cloudflare-worker/`, `workers/` — separate Cloudflare worker code, not part of the Next build
- Root `*.md` audit/notes files (`SIGNUP_AUDIT*.md`) are working documents, not docs.

## Infrastructure

- **Hosting:** Vercel. Pushing to `main` deploys production; every PR gets a preview URL.
- **Database/Auth:** Supabase project `motu-korikori`, ref `mwygcqumpjswovyukcct` (ap-south-1).
- **Env:** `dictionary-app/.env.local` (gitignored; template in `.env.example`). Signup needs
  `SUPABASE_SERVICE_ROLE_KEY`; login works on the anon key alone.

## Workflow

1. Branch off `main`: `feat/…`, `fix/…`, `chore/…`. Don't commit to `main` directly.
2. Before pushing: `npm run typecheck` and `npm run build` (from `dictionary-app/`).
3. Open a PR. CI (`.github/workflows/ci.yml`) runs typecheck + build; Vercel posts a preview.
4. Check the preview, then merge. Merge to `main` = production deploy.

## Database changes

- Never hand-edit the production schema or give Trevor SQL to paste into the dashboard.
  Every change is a migration file, applied automatically.
- New migration: `npm run db:new <name>` → write SQL → test locally with `npm run db:reset`.
- Make migrations idempotent (`IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP … IF EXISTS`).
- On merge to `main`, `.github/workflows/db-migrate.yml` runs `supabase db push` against prod.
  Vercel deploys the app from the same push — if new code depends on new schema, the
  migration must be backward-compatible or land in an earlier PR.
- File versions must match prod's `supabase_migrations.schema_migrations`. **Never rename
  a migration that has been applied.**

## Local dev

```
cd dictionary-app
npm install
npm run dev          # http://localhost:3000, against whatever .env.local points at
npm run db:start     # local Supabase in Docker (needs Docker Desktop)
npm run db:reset     # rebuild local DB from migrations/
```

Point `.env.local` at the local stack (URL/keys printed by `db:start`) when testing schema
or signup changes, so tests never touch production data.

## Conventions

- TypeScript strict; path alias `@/*` → `dictionary-app/*`.
- Supabase access goes through the helpers in `lib/`; RLS + column grants are the security
  boundary because the anon key ships in the client bundle.
- The service-role key can't be rotated without a full legacy-key migration; don't suggest it.
