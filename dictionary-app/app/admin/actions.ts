'use server'

import { revalidatePath } from 'next/cache'
import { createAdminClient } from '@/lib/supabase'
import { requireActiveUserForAction } from '@/lib/auth'

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
  await supabase
    .from('contributions')
    .update({ is_excluded: true })
    .eq('user_id', userId)

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

  revalidatePath('/admin')
}
