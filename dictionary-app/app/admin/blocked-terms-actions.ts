'use server'

import { revalidatePath } from 'next/cache'
import { requireActiveUserForAction } from '@/lib/auth'

// Blocked-terms list (#54). These use the admin's own client: RLS on
// blocked_terms lets only admins read, add, approve and remove terms.

const LANGUAGES = ['en', 'tpi', 'meu'] as const
const CATEGORIES = ['profanity', 'slur', 'sexual', 'abuse'] as const

function pick<T extends string>(value: FormDataEntryValue | null, allowed: readonly T[], fallback: T): T {
  return allowed.includes(value as T) ? (value as T) : fallback
}

export async function addBlockedTerm(formData: FormData) {
  const { supabase, profile } = await requireActiveUserForAction({ requireAdmin: true })
  const term = String(formData.get('term') ?? '').trim()
  if (term.length < 2 || term.length > 60) return

  const { error } = await supabase.from('blocked_terms').insert({
    term,
    language: pick(formData.get('language'), LANGUAGES, 'en'),
    category: pick(formData.get('category'), CATEGORIES, 'profanity'),
    approved: true,
    added_by: profile.id,
  })

  // 23505: already on the list (perhaps as a suggestion, which can be approved below).
  if (error && error.code !== '23505') {
    console.error('Error adding blocked term:', error)
    throw new Error('Failed to add term')
  }

  revalidatePath('/admin')
}

export async function approveBlockedTerm(formData: FormData) {
  const { supabase } = await requireActiveUserForAction({ requireAdmin: true })

  const { error } = await supabase
    .from('blocked_terms')
    .update({ approved: true })
    .eq('id', String(formData.get('termId')))

  if (error) {
    console.error('Error approving blocked term:', error)
    throw new Error('Failed to approve term')
  }

  revalidatePath('/admin')
}

export async function removeBlockedTerm(formData: FormData) {
  const { supabase } = await requireActiveUserForAction({ requireAdmin: true })

  const { error } = await supabase
    .from('blocked_terms')
    .delete()
    .eq('id', String(formData.get('termId')))

  if (error) {
    console.error('Error removing blocked term:', error)
    throw new Error('Failed to remove term')
  }

  revalidatePath('/admin')
}
