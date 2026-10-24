'use server'

import { revalidatePath } from 'next/cache'
import { AccessDeniedError, requireActiveUserForAction } from '@/lib/auth'
import {
  BLOCKED_LANGUAGE_MESSAGE,
  isBlockedLanguageError,
  logBlockedLanguageAttempt,
} from '@/lib/blocked-language'

// The name shown on the leaderboard and in the nav (#13). The database trims
// it, caps it at 40 characters, falls back to the first name when it's blank,
// and won't let an under-18 use their full name.
export async function updateDisplayName(
  displayName: string
): Promise<{ error?: string; displayName?: string }> {
  if (typeof displayName !== 'string' || displayName.trim().length > 40) {
    return { error: 'Display name must be 40 characters or fewer' }
  }

  let account
  try {
    account = await requireActiveUserForAction()
  } catch (e) {
    if (e instanceof AccessDeniedError) return { error: e.message }
    throw e
  }
  const { supabase, user } = account

  const { data, error } = await supabase
    .from('profiles')
    .update({ display_name: displayName.trim() })
    .eq('id', user.id)
    .select('display_name')
    .single()

  if (isBlockedLanguageError(error)) {
    await logBlockedLanguageAttempt(supabase, 'profiles', displayName)
    return { error: BLOCKED_LANGUAGE_MESSAGE }
  }
  if (error || !data) return { error: 'Could not save your display name. Please try again.' }

  revalidatePath('/', 'layout')
  return { displayName: data.display_name }
}

// Native and heritage speakers can suggest a word for the bad-language filter
// (#54). It waits for an admin to approve it; the database checks who may
// suggest. A term already on the list gets the same answer, so the list isn't
// revealed.
export async function suggestBlockedTerm(
  term: string,
  language: string
): Promise<{ error?: string; message?: string }> {
  const trimmed = typeof term === 'string' ? term.trim() : ''
  if (trimmed.length < 2 || trimmed.length > 60) {
    return { error: 'Please enter a word or phrase (2 to 60 characters).' }
  }
  if (!['en', 'tpi', 'meu'].includes(language)) {
    return { error: 'Please choose a language.' }
  }

  let account
  try {
    account = await requireActiveUserForAction()
  } catch (e) {
    if (e instanceof AccessDeniedError) return { error: e.message }
    throw e
  }
  const { supabase, user } = account

  const { error } = await supabase
    .from('blocked_terms')
    .insert({ term: trimmed, language, approved: false, added_by: user.id })

  if (error && error.code !== '23505') {
    if (error.code === '42501') return { error: 'Only native and heritage speakers can suggest words.' }
    console.error('Error suggesting blocked term:', error)
    return { error: 'Could not send your suggestion. Please try again.' }
  }

  return { message: 'Thank you. An admin will review it.' }
}
