'use server'

import { revalidatePath } from 'next/cache'
import { createServerComponentClient } from '@/lib/supabase'

/**
 * Mark a word as complete for the current user
 * This means "I'm done with this word, don't show it to me again"
 */
export async function markWordComplete(wordId: string) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    throw new Error('Not authenticated')
  }

  // Insert completion record (or update if exists)
  const { error } = await supabase
    .from('user_word_completion')
    .upsert({
      user_id: user.id,
      word_id: wordId,
      completed_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id,word_id'
    })

  if (error) {
    console.error('Error marking word complete:', error)
    throw new Error('Failed to mark word as complete')
  }

  // Revalidate to get next word
  revalidatePath('/contribute')
}
