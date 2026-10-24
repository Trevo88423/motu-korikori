'use server'

import { revalidatePath } from 'next/cache'
import { createAdminClient } from '@/lib/supabase'
import { requireActiveUserForAction, AccessDeniedError } from '@/lib/auth'
import { calculateConsensus, recalculateAllConsensus } from '@/lib/consensus'

async function requireAdmin() {
  const { profile } = await requireActiveUserForAction({ requireAdmin: true })
  return profile
}

// Moderation writes go through the service-role client. `authenticated` no
// longer holds UPDATE on profiles' privileged columns (status, is_admin,
// trust_score, ...) — see supabase/migrations/20260803_01_lock_down_profile_updates.sql.
// Authorisation is enforced by requireAdmin() above, which every action calls first.
async function adminDb() {
  return createAdminClient()
}

// profiles.status is what the app checks on every request; this mirrors it
// into Supabase Auth so a suspended or banned member can't sign in or refresh
// a session either, and ends the sessions they have. 'none' undoes the block.
async function setSignInBlocked(
  supabase: ReturnType<typeof createAdminClient>,
  userId: string,
  blocked: boolean
) {
  const { error } = await supabase.auth.admin.updateUserById(userId, {
    ban_duration: blocked ? '876000h' : 'none',
  })
  if (error) {
    console.error('Error updating sign-in block:', error)
    throw new Error('Status saved, but sign-in could not be updated. Try again.')
  }

  if (blocked) {
    // The block above already refuses their tokens, so a failure here is logged
    // rather than fatal.
    const { error: revokeError } = await supabase.rpc('revoke_user_sessions', { target_user_id: userId })
    if (revokeError) console.error('Error revoking sessions:', revokeError)
  }
}

// Word Moderation Actions

export async function verifyWord(formData: FormData) {
  const admin = await requireAdmin()
  const wordId = formData.get('wordId') as string

  const supabase = await adminDb()

  // Update word status
  await supabase
    .from('words')
    .update({ status: 'verified' })
    .eq('id', wordId)

  // Fill in the gloss from the leading contribution (status stays verified)
  await calculateConsensus(wordId)

  // Log action
  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_word_id: wordId,
      action: 'verify_word',
      reason: 'Manually verified by admin',
    })

  revalidatePath('/admin')
  revalidatePath(`/dictionary/${wordId}`)
}

export async function flagWord(formData: FormData) {
  const admin = await requireAdmin()
  const wordId = formData.get('wordId') as string

  const supabase = await adminDb()

  await supabase
    .from('words')
    .update({ status: 'flagged' })
    .eq('id', wordId)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_word_id: wordId,
      action: 'flag_word',
      reason: 'Flagged for review by admin',
    })

  revalidatePath('/admin')
  revalidatePath(`/dictionary/${wordId}`)
}

export async function unflagWord(formData: FormData) {
  const admin = await requireAdmin()
  const wordId = formData.get('wordId') as string

  const supabase = await adminDb()

  await supabase
    .from('words')
    .update({ status: 'pending' })
    .eq('id', wordId)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_word_id: wordId,
      action: 'unflag_word',
      reason: 'Unflagged by admin',
    })

  revalidatePath('/admin')
  revalidatePath(`/dictionary/${wordId}`)
}

// User Moderation Actions

export async function warnUser(formData: FormData) {
  const admin = await requireAdmin()
  const userId = formData.get('userId') as string

  const supabase = await adminDb()

  await supabase
    .from('profiles')
    .update({ status: 'warned' })
    .eq('id', userId)

  await setSignInBlocked(supabase, userId, false)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: userId,
      action: 'warn',
      reason: 'User warned by admin',
    })

  revalidatePath('/admin')
}

export async function suspendUser(formData: FormData) {
  const admin = await requireAdmin()
  const userId = formData.get('userId') as string

  const supabase = await adminDb()

  await supabase
    .from('profiles')
    .update({ status: 'suspended' })
    .eq('id', userId)

  await setSignInBlocked(supabase, userId, true)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: userId,
      action: 'suspend',
      reason: 'User suspended by admin',
    })

  revalidatePath('/admin')
}

export async function banUser(formData: FormData) {
  const admin = await requireAdmin()
  const userId = formData.get('userId') as string

  const supabase = await adminDb()

  await supabase
    .from('profiles')
    .update({ status: 'banned' })
    .eq('id', userId)

  await setSignInBlocked(supabase, userId, true)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: userId,
      action: 'ban',
      reason: 'User banned by admin',
    })

  revalidatePath('/admin')
}

export async function reinstateUser(formData: FormData) {
  const admin = await requireAdmin()
  const userId = formData.get('userId') as string

  const supabase = await adminDb()

  await supabase
    .from('profiles')
    .update({ status: 'active' })
    .eq('id', userId)

  await setSignInBlocked(supabase, userId, false)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: userId,
      action: 'reinstate',
      reason: 'User reinstated by admin',
    })

  revalidatePath('/admin')
}

export async function excludeFromAI(formData: FormData) {
  const admin = await requireAdmin()
  const userId = formData.get('userId') as string

  const supabase = await adminDb()

  await supabase
    .from('profiles')
    .update({ excluded_from_ai: true })
    .eq('id', userId)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: userId,
      action: 'exclude_from_ai',
      reason: 'User excluded from AI training by admin',
    })

  revalidatePath('/admin')
}

export async function excludeAllContributions(formData: FormData) {
  const admin = await requireAdmin()
  const userId = formData.get('userId') as string

  const supabase = await adminDb()

  // Mark all contributions as excluded
  const { data: excluded } = await supabase
    .from('contributions')
    .update({ is_excluded: true })
    .eq('user_id', userId)
    .select('word_id')

  // Update user profile
  await supabase
    .from('profiles')
    .update({ contributions_excluded: true })
    .eq('id', userId)

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: userId,
      action: 'exclude_contributions',
      reason: 'All contributions excluded by admin',
    })

  // Their glosses no longer count, so every word they contributed to changes
  for (const { word_id } of excluded || []) {
    await calculateConsensus(word_id)
  }

  revalidatePath('/admin')
  revalidatePath('/dictionary')
}

// Consensus backfill

export type RecalculateConsensusResult =
  | { ok: true; total: number; changed: number; failed: number }
  | { ok: false; error: string }

export async function recalculateConsensusForAllWords(): Promise<RecalculateConsensusResult> {
  // Same server-side check as every admin action (active, verified admin);
  // the service-role writes below are only reachable by an admin session
  try {
    await requireAdmin()
  } catch (error) {
    if (error instanceof AccessDeniedError) return { ok: false, error: error.message }
    throw error
  }

  try {
    const { total, changed, failed } = await recalculateAllConsensus()

    revalidatePath('/admin')
    revalidatePath('/dictionary')

    return { ok: true, total, changed, failed }
  } catch (error) {
    console.error('Error recalculating consensus:', error)
    return { ok: false, error: 'Recalculation failed. Check the server logs.' }
  }
}

// Items hidden by flags (#56)

type FlagDecision = 'restore' | 'confirm'

async function resolveHidden(formData: FormData, decision: FlagDecision) {
  const admin = await requireAdmin()
  const kind = formData.get('kind') as string
  const targetId = formData.get('targetId') as string

  if (kind !== 'contribution' && kind !== 'comment') {
    throw new Error('Unknown item')
  }

  const supabase = await adminDb()

  // Restoring overturns the pending flags, which lowers each flagger's future
  // flag weight (flag_weight() in the database); confirming upholds them.
  const { data, error } = await supabase.rpc('resolve_flags', {
    target_kind: kind,
    target_id: targetId,
    decision,
  })

  if (error) {
    console.error('Error resolving flags:', error)
    throw new Error('Could not update the item. It may already have been decided.')
  }

  const result = data as { author_id: string; word_id: string; summary: string; flaggers: number }
  const label = kind === 'contribution' ? 'translation' : 'comment'
  const flaggers = `${result.flaggers} ${result.flaggers === 1 ? 'flag' : 'flags'}`

  await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_user_id: result.author_id,
      target_word_id: result.word_id,
      target_kind: kind,
      target_id: targetId,
      action: decision === 'restore' ? 'restore_content' : 'confirm_hide',
      reason: decision === 'restore'
        ? `Restored ${label} "${result.summary}" (${flaggers} overturned)`
        : `Kept ${label} "${result.summary}" hidden (${flaggers} upheld)`,
    })

  // A restored translation counts towards consensus again
  if (kind === 'contribution' && decision === 'restore') {
    await calculateConsensus(result.word_id)
  }

  revalidatePath('/admin')
  revalidatePath(`/dictionary/${result.word_id}`)
}

export async function restoreHidden(formData: FormData) {
  await resolveHidden(formData, 'restore')
}

export async function confirmHidden(formData: FormData) {
  await resolveHidden(formData, 'confirm')
}

const MODERATION_SETTING_KEYS = [
  'flag_hide_threshold',
  'flag_weight_member',
  'flag_weight_trusted',
  'flag_trusted_min_trust',
  'flag_overturn_penalty',
]

export async function updateModerationSetting(formData: FormData) {
  await requireAdmin()
  const key = formData.get('key') as string
  const value = Number(formData.get('value'))

  if (!MODERATION_SETTING_KEYS.includes(key) || !Number.isFinite(value) || value < 0 || value > 100) {
    throw new Error('Invalid setting')
  }

  const supabase = await adminDb()
  const { error } = await supabase
    .from('moderation_settings')
    .update({ value, updated_at: new Date().toISOString() })
    .eq('key', key)

  if (error) {
    console.error('Error updating moderation setting:', error)
    throw new Error('Could not save the setting')
  }

  revalidatePath('/admin')
}
