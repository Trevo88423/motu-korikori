// Server-side Supabase utilities (only import in Server Components and Server Actions)

import { createClient } from '@supabase/supabase-js'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { cache } from 'react'

// Environment variables
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

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

// Total number of words in the dictionary.
// Cached per-request so several components can call it without repeat queries.
export const getTotalWordCount = cache(async (): Promise<number> => {
  const supabase = await createServerComponentClient()

  const { count, error } = await supabase
    .from('words')
    .select('*', { count: 'exact', head: true })

  if (error || count === null) return 0

  return count
})

// Helper function to check if user is admin
export async function isUserAdmin(userId: string): Promise<boolean> {
  const supabase = await createServerComponentClient()

  const { data, error } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', userId)
    .single()

  if (error || !data) return false

  return data.is_admin
}

// Helper function to get current user profile
export async function getCurrentUserProfile() {
  const supabase = await createServerComponentClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return null

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  if (error) return null

  return profile
}
