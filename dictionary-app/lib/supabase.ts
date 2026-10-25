// Server-side Supabase utilities (only import in Server Components and Server Actions)

import { createClient } from '@supabase/supabase-js'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { unstable_cache } from 'next/cache'
import { cache } from 'react'
import type { WordType } from './types'

// Environment variables
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
// Supabase keys never contain whitespace. The production value was pasted into
// Vercel with line breaks in it, which made every service-role request fail
// with "invalid header value"; stripping whitespace makes a mangled paste harmless.
const supabaseServiceKey = (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').replace(/\s+/g, '')

// Re-export client function for convenience (but prefer importing from supabase-client.ts in Client Components)
export { createClientComponentClient } from './supabase-client'

// Server client for Server Components and Server Actions
export async function createServerComponentClient() {
  const cookieStore = await cookies()

  return createServerClient(
    supabaseUrl,
    supabaseAnonKey,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet: { name: string; value: string; options?: any }[]) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // The `setAll` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
      },
      db: {
        schema: 'public',
      },
      global: {
        // Disable all caching for Supabase queries
        headers: {
          'cache-control': 'no-store, no-cache, must-revalidate, max-age=0',
        },
      },
    }
  )
}

// Admin client with service role key (use carefully, only in Server Actions)
export function createAdminClient() {
  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  })
}

// Number of words in the dictionary, vocabulary and names separately (#75):
// about 12,900 Motu words and 2,700 Bible names and places, which are counted
// apart so the headline isn't inflated by names.
// It rarely changes, so it's cached across requests for an hour rather than
// counted on every page load. Words are public, so the anon key without the
// user's cookies is enough (cookies can't be read inside unstable_cache).
export interface WordCounts {
  vocabulary: number
  names: number
  total: number
}

const countWords = unstable_cache(
  async (): Promise<WordCounts> => {
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const countType = (type: WordType) =>
      supabase.from('words').select('*', { count: 'exact', head: true }).eq('word_type', type)

    const [vocabulary, names] = await Promise.all([countType('vocabulary'), countType('name')])

    // Throwing keeps a failed count out of the cache
    for (const { count, error } of [vocabulary, names]) {
      if (error || count === null) throw new Error(error?.message || 'No word count')
    }

    return {
      vocabulary: vocabulary.count!,
      names: names.count!,
      total: vocabulary.count! + names.count!,
    }
  },
  ['word-counts'],
  { revalidate: 3600, tags: ['word-counts'] }
)

const NO_COUNTS: WordCounts = { vocabulary: 0, names: 0, total: 0 }

// All zero when the count fails
export const getTotalWordCount = cache(async (): Promise<WordCounts> => {
  try {
    return await countWords()
  } catch {
    return NO_COUNTS
  }
})

// First letters of one type's words (upper-cased, as search_words matches
// them), for the alphabet bar. Built from the data so letters with no words
// are left out and Ḡ is included; cached like the counts.
const listWordInitials = unstable_cache(
  async (wordType: WordType): Promise<string[]> => {
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data, error } = await supabase.rpc('word_initials', { p_word_type: wordType })

    if (error || !data) throw new Error(error?.message || 'No word initials')

    // Alphabetical with Ḡ straight after G; anything that isn't a letter
    // (the suffixes starting with "-") goes last.
    const isLetter = (s: string) => /\p{L}/u.test(s)
    return (data as { letter: string }[])
      .map((row) => row.letter)
      .filter(Boolean)
      .sort((a, b) =>
        isLetter(a) !== isLetter(b) ? (isLetter(a) ? -1 : 1) : a.localeCompare(b, 'en')
      )
  },
  ['word-initials'],
  { revalidate: 3600, tags: ['word-initials'] }
)

export const getWordInitials = cache(async (wordType: WordType): Promise<string[]> => {
  try {
    return await listWordInitials(wordType)
  } catch {
    return []
  }
})

// Helper function to check if the current user is admin.
// is_admin isn't readable through the profiles table (column grants), so this
// goes through the SECURITY DEFINER helper, which only answers for the caller.
export async function isUserAdmin(): Promise<boolean> {
  const supabase = await createServerComponentClient()

  const { data, error } = await supabase.rpc('is_current_user_admin')

  if (error) return false

  return data === true
}

// Helper function to get current user profile
export async function getCurrentUserProfile() {
  const supabase = await createServerComponentClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return null

  // Private columns (email, guardian details, is_admin...) aren't readable
  // through the profiles table; get_my_profile() returns only the caller's row.
  const { data: profile, error } = await supabase.rpc('get_my_profile')

  if (error || !profile?.id) return null

  return profile
}
