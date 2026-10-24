'use server'

import { revalidatePath } from 'next/cache'
import { createServerComponentClient } from '@/lib/supabase'

// The name shown on the leaderboard and in the nav (#13). The database trims
// it, caps it at 40 characters, falls back to the first name when it's blank,
// and won't let an under-18 use their full name.
export async function updateDisplayName(
  displayName: string
): Promise<{ error?: string; displayName?: string }> {
  if (typeof displayName !== 'string' || displayName.trim().length > 40) {
    return { error: 'Display name must be 40 characters or fewer' }
  }

  const supabase = await createServerComponentClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: 'Not authenticated' }

  const { data, error } = await supabase
    .from('profiles')
    .update({ display_name: displayName.trim() })
    .eq('id', user.id)
    .select('display_name')
    .single()

  if (error || !data) return { error: 'Could not save your display name. Please try again.' }

  revalidatePath('/', 'layout')
  return { displayName: data.display_name }
}
