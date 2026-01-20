'use server'

import { revalidatePath } from 'next/cache'
import { createServerComponentClient } from '@/lib/supabase'
import type { ContributionFormData } from '@/lib/types'

export async function saveContribution(data: ContributionFormData) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    throw new Error('Not authenticated')
  }

  // Check user status
  const { data: profile } = await supabase
    .from('profiles')
    .select('status')
    .eq('id', user.id)
    .single()

  if (profile?.status === 'suspended' || profile?.status === 'banned') {
    throw new Error('Your account has been suspended')
  }

  // Upsert contribution (insert or update if exists)
  const { error } = await supabase
    .from('contributions')
    .upsert({
      word_id: data.word_id,
      user_id: user.id,
      english_gloss: data.english_gloss,
      audio_url: data.audio_url || null,
      confidence: data.confidence,
      notes: data.notes || null,
    }, {
      onConflict: 'word_id,user_id'
    })

  if (error) {
    console.error('Error saving contribution:', error)
    throw new Error('Failed to save contribution')
  }

  // Revalidate the contribute page to show next word
  revalidatePath('/contribute')
}
