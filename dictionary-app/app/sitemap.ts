import type { MetadataRoute } from 'next'
import { createClient } from '@supabase/supabase-js'
import { SITE_URL } from '@/lib/seo'

// Built at most once an hour (ISR), not on every crawler hit. If a rebuild
// fails, the last good sitemap keeps being served.
export const revalidate = 3600

// PostgREST returns at most 1,000 rows per request
const PAGE_SIZE = 1000

async function listWords(): Promise<{ id: string; updated_at: string }[]> {
  // Words are public: the anon key, no user cookies
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  )

  const page = (from: number) =>
    supabase
      .from('words')
      .select('id, updated_at', from === 0 ? { count: 'exact' } : undefined)
      .order('id')
      .range(from, from + PAGE_SIZE - 1)

  const first = await page(0)
  if (first.error || first.count === null) throw new Error(first.error?.message || 'No word count')

  const rest = await Promise.all(
    Array.from({ length: Math.ceil(first.count / PAGE_SIZE) - 1 }, (_, i) => page((i + 1) * PAGE_SIZE))
  )
  const failed = rest.find((r) => r.error)
  if (failed) throw new Error(failed.error!.message)

  return [first, ...rest].flatMap((r) => r.data || [])
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  let words: { id: string; updated_at: string }[] = []
  try {
    words = await listWords()
  } catch (error) {
    // CI builds with placeholder Supabase keys; ship the static pages and let
    // the first revalidation fill in the words. At runtime, throw so a failed
    // rebuild never replaces a good sitemap.
    if (process.env.NEXT_PHASE !== 'phase-production-build') throw error
    console.warn('sitemap: words unavailable at build time:', (error as Error).message)
  }

  const latest = words.reduce<string | undefined>(
    (max, w) => (!max || w.updated_at > max ? w.updated_at : max),
    undefined
  )
  const lastModified = latest ? new Date(latest) : undefined

  return [
    { url: SITE_URL, lastModified, changeFrequency: 'daily', priority: 1 },
    { url: `${SITE_URL}/dictionary`, lastModified, changeFrequency: 'daily', priority: 0.9 },
    { url: `${SITE_URL}/leaderboard`, changeFrequency: 'daily', priority: 0.3 },
    ...words.map((w) => ({
      url: `${SITE_URL}/dictionary/${w.id}`,
      lastModified: new Date(w.updated_at),
      changeFrequency: 'weekly' as const,
      priority: 0.7,
    })),
  ]
}
