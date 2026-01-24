// Client-side Supabase utilities (safe to import in Client Components)

import { createBrowserClient } from '@supabase/ssr'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

// Browser client for Client Components
// Let Supabase handle cookies automatically (including chunking)
export function createClientComponentClient() {
  return createBrowserClient(supabaseUrl, supabaseAnonKey)
}
