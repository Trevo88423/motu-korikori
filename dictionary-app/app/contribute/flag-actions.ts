'use server'

import { requireActiveUserForAction } from '@/lib/auth'
import { calculateConsensus } from '@/lib/consensus'
import { FLAG_REASONS, type FlagKind, type FlagReason } from '@/lib/flags'

interface FlagResult {
  status: 'flagged' | 'already_flagged'
  hidden: boolean
  hidden_now: boolean
  word_id: string
}

// Flags a translation or comment. flag_content() refuses anon, inactive
// members, unknown reasons and the caller's own items, and decides the hide.
export async function flagContent(kind: FlagKind, targetId: string, reason: FlagReason) {
  const { supabase } = await requireActiveUserForAction()

  if (!FLAG_REASONS[kind]?.some((r) => r.value === reason)) {
    throw new Error('Please choose a reason')
  }

  const { data, error } = await supabase.rpc('flag_content', {
    target_kind: kind,
    target_id: targetId,
    reason,
  })

  if (error) {
    console.error('Error flagging content:', error)
    if (error.message.includes('your own')) {
      throw new Error(error.message)
    }
    throw new Error('Could not send the flag. Please try again.')
  }

  const result = data as FlagResult

  // A hidden translation no longer counts towards consensus. calculateConsensus()
  // writes with the service role, but derives everything from stored rows, and
  // only runs after the database accepted this member's flag.
  if (kind === 'contribution' && result.hidden_now) {
    await calculateConsensus(result.word_id)
  }

  // No revalidatePath: refreshing now would remove a just-hidden item before
  // the flagger sees "Thanks". The hide applies from the next page load.
  return { alreadyFlagged: result.status === 'already_flagged' }
}
