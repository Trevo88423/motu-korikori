'use server'

import { revalidatePath, revalidateTag } from 'next/cache'
import { headers } from 'next/headers'
import { createAdminClient } from '@/lib/supabase'
import { requireActiveUserForAction, AccessDeniedError } from '@/lib/auth'
import { calculateConsensus, recalculateAllConsensus } from '@/lib/consensus'
import { sendEmail, escapeHtml } from '@/lib/email'
import type { WordType } from '@/lib/types'

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

export type WordTypeResult =
  | { ok: true; wordType: WordType }
  | { ok: false; error: string }

// Mark as name / Mark as vocabulary on the word page (#75). Corrects the tag
// set from the Bible text; the migration that set it skips any word with a
// set_word_type entry in moderation_log, so a correction is never undone.
export async function setWordType(wordId: string, wordType: WordType): Promise<WordTypeResult> {
  let admin: Awaited<ReturnType<typeof requireAdmin>>
  try {
    admin = await requireAdmin()
  } catch (error) {
    if (error instanceof AccessDeniedError) return { ok: false, error: error.message }
    throw error
  }
  if (typeof wordId !== 'string' || !wordId) return { ok: false, error: 'Word not found.' }
  if (wordType !== 'name' && wordType !== 'vocabulary') return { ok: false, error: 'Unknown word type.' }

  const supabase = await adminDb()

  const { data: word, error } = await supabase
    .from('words')
    .update({ word_type: wordType })
    .eq('id', wordId)
    .select('motu_word')
    .single()
  if (error || !word) {
    if (error) console.error('Error setting word type:', error)
    return { ok: false, error: "That didn't work. Try again." }
  }

  const { error: logError } = await supabase
    .from('moderation_log')
    .insert({
      admin_id: admin.id,
      target_word_id: wordId,
      action: 'set_word_type',
      reason: wordType === 'name' ? 'Marked as name / place' : 'Marked as vocabulary',
    })
  if (logError) console.error('Error logging word type change:', logError)

  // Counts and alphabet bars are cached per type
  revalidateTag('word-counts')
  revalidateTag('word-initials')
  revalidatePath('/dictionary')
  revalidatePath(`/dictionary/${wordId}`)

  return { ok: true, wordType }
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

  const { error } = await supabase
    .from('profiles')
    .update({ status: 'suspended' })
    .eq('id', userId)

  // e.g. the last active admin (guard_admin_membership); don't block sign-in
  if (error) throw new Error(error.message)

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

  const { error } = await supabase
    .from('profiles')
    .update({ status: 'banned' })
    .eq('id', userId)

  // e.g. the last active admin (guard_admin_membership); don't block sign-in
  if (error) throw new Error(error.message)

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

// Admin appointments (#64)
//
// grant_admin() / revoke_admin() make the change and write moderation_log in
// one transaction. The database refuses removing the last active admin and
// appointing an inactive or unconfirmed member, whoever calls it; the messages
// it raises for those are written to be shown to the admin.

export type AdminRoleResult =
  | { ok: true; message: string }
  | { ok: false; error: string }

// check_violation (the safeguards) and insufficient_privilege / no_data_found
// (the functions' own checks) carry messages meant for the UI.
const SHOWN_DB_ERRORS = new Set(['23514', '42501', 'P0002'])

function adminRoleError(error: { code?: string; message: string }): AdminRoleResult {
  if (error.code && SHOWN_DB_ERRORS.has(error.code)) return { ok: false, error: error.message }
  console.error('Admin role change failed:', error)
  return { ok: false, error: "That didn't work. Try again." }
}

async function adminRoleActor(): Promise<{ id: string; display_name: string } | AdminRoleResult> {
  try {
    return await requireAdmin()
  } catch (error) {
    if (error instanceof AccessDeniedError) return { ok: false, error: error.message }
    throw error
  }
}

export async function makeAdmin(userId: string): Promise<AdminRoleResult> {
  const actor = await adminRoleActor()
  if ('ok' in actor) return actor
  if (typeof userId !== 'string' || !userId) return { ok: false, error: 'Member not found.' }

  const supabase = await adminDb()
  const { data: appointed, error } = await supabase.rpc('grant_admin', {
    p_target: userId,
    p_actor: actor.id,
  })
  if (error) return adminRoleError(error)

  const { data: target } = await supabase
    .from('profiles')
    .select('display_name')
    .eq('id', userId)
    .single()
  const name = target?.display_name ?? 'They'

  revalidatePath('/admin')
  if (!appointed) return { ok: true, message: `${name} is already an admin.` }

  const email = await emailNewAdmin(supabase, userId, name, actor.display_name)
  const emailNote =
    email === 'sent' ? " We've emailed them." :
    email === 'skipped' ? " (Email isn't set up, so they weren't emailed.)" :
    " The email to them didn't go through, so let them know yourself."
  return { ok: true, message: `${name} is now an admin.${emailNote}` }
}

export async function removeAdmin(userId: string): Promise<AdminRoleResult> {
  const actor = await adminRoleActor()
  if ('ok' in actor) return actor
  if (typeof userId !== 'string' || !userId) return { ok: false, error: 'Member not found.' }

  const supabase = await adminDb()
  const { data: removed, error } = await supabase.rpc('revoke_admin', {
    p_target: userId,
    p_actor: actor.id,
  })
  if (error) return adminRoleError(error)

  revalidatePath('/admin')
  if (userId === actor.id) return { ok: true, message: "You're no longer an admin." }
  return { ok: true, message: removed ? 'Admin removed.' : "They weren't an admin." }
}

async function emailNewAdmin(
  supabase: ReturnType<typeof createAdminClient>,
  userId: string,
  name: string,
  appointedBy: string
) {
  const { data, error } = await supabase.auth.admin.getUserById(userId)
  const to = data?.user?.email
  if (error || !to) {
    console.error('New admin email: no address for', userId, error)
    return 'failed' as const
  }

  // The site this was done on (production, a preview or local dev)
  const origin = (await headers()).get('origin') || 'https://truemotu.org'
  const link = `${origin}/admin`

  return sendEmail({
    to,
    subject: "You're now an admin of True Motu Dictionary",
    text:
      `Hi ${name},

` +
      `You've been made an admin of True Motu Dictionary by ${appointedBy}.

` +
      `Admins look after the dictionary for the community: they can verify and unflag words, ` +
      `warn, suspend and ban members, and appoint other admins.

` +
      `Open the admin page: ${link}
`,
    html:
      `<p>Hi ${escapeHtml(name)},</p>` +
      `<p>You've been made an admin of True Motu Dictionary by ${escapeHtml(appointedBy)}.</p>` +
      `<p>Admins look after the dictionary for the community: they can verify and unflag words, ` +
      `warn, suspend and ban members, and appoint other admins.</p>` +
      `<p><a href="${escapeHtml(link)}">Open the admin page</a></p>`,
  })
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
