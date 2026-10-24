/**
 * Clean the text in data/bible-indices/verses.json (the source for
 * /api/bible/random-verse) with the same rules as the words examples.
 *
 * The rules live in one place: public.clean_scripture_text(), created by
 * supabase/migrations/20261024150000_clean_scripture_examples.sql. This script
 * runs every verse through that function on the local database, so start the
 * local stack first (npm run db:start) and make sure the migration is applied.
 *
 * Usage (from dictionary-app/):
 *   node scripts/clean-bible-indices.mjs
 *   DATABASE_URL=postgresql://... node scripts/clean-bible-indices.mjs
 *
 * Safe to re-run: clean text comes back unchanged.
 */
import { readFileSync, writeFileSync } from 'fs'
import { join } from 'path'
import pg from 'pg'

const DATABASE_URL =
  process.env.DATABASE_URL || 'postgresql://postgres:postgres@127.0.0.1:54322/postgres'
const versesPath = join(process.cwd(), 'data', 'bible-indices', 'verses.json')

const verses = JSON.parse(readFileSync(versesPath, 'utf-8'))
const refs = Object.keys(verses)

const client = new pg.Client({ connectionString: DATABASE_URL })
await client.connect()

async function cleanAll(texts) {
  const { rows } = await client.query(
    `SELECT public.clean_scripture_text(t) AS t
     FROM unnest($1::text[]) WITH ORDINALITY AS u(t, i)
     ORDER BY i`,
    [texts]
  )
  return rows.map((r) => r.t)
}

let changed = 0
for (const field of ['english', 'motu']) {
  const before = refs.map((ref) => verses[ref][field] ?? null)
  const after = await cleanAll(before)
  refs.forEach((ref, i) => {
    if (before[i] !== null && after[i] !== before[i]) {
      verses[ref][field] = after[i]
      changed++
    }
  })
}
await client.end()

writeFileSync(versesPath, JSON.stringify(verses, null, 2))
console.log(`Cleaned ${changed} fields across ${refs.length} verses`)
