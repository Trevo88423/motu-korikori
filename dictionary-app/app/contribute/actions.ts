'use server'

import { revalidatePath } from 'next/cache'
import { requireActiveUserForAction } from '@/lib/auth'
import { calculateConsensus } from '@/lib/consensus'
import type { ContributionFormData } from '@/lib/types'

// calculateConsensus() writes with the service-role client. Each action below
// only calls it after the signed-in member's own contribution write (checked by
// RLS) has succeeded, and the result is derived purely from stored rows.

export async function agreeWithTranslation(wordId: string, englishGloss: string) {
  const { supabase, user } = await requireActiveUserForAction()

  // Check if user already contributed to this word
  const { data: existing } = await supabase
    .from('contributions')
    .select('id, english_gloss, agreement_type')
    .eq('word_id', wordId)
    .eq('user_id', user.id)
    .single()

  if (existing) {
    // If already agreed or contributed with same translation, toggle it off (remove)
    if (existing.english_gloss === englishGloss) {
      const { error } = await supabase
        .from('contributions')
        .delete()
        .eq('id', existing.id)

      if (error) {
        console.error('Error removing agreement:', error)
        throw new Error('Failed to remove agreement')
      }

      await calculateConsensus(wordId)

      // Force revalidation of both paths
      revalidatePath('/contribute', 'page')
      revalidatePath(`/contribute?word=${wordId}`, 'page')

      return { removed: true }
    }

    // If contributed with different translation, update to new agreement
    // Keep their existing confidence level
    const { error } = await supabase
      .from('contributions')
      .update({
        english_gloss: englishGloss,
        agreement_type: 'agree',
        audio_url: null,
        notes: null,
        // Don't update confidence - keep whatever they had
      })
      .eq('id', existing.id)

    if (error) {
      console.error('Error updating agreement:', error)
      throw new Error('Failed to update agreement')
    }
  } else {
    // Insert new agreement - default to 'somewhat_certain' since they didn't provide their own translation
    const { error } = await supabase
      .from('contributions')
      .insert({
        word_id: wordId,
        user_id: user.id,
        english_gloss: englishGloss,
        agreement_type: 'agree',
        confidence: 'somewhat_certain'
      })

    if (error) {
      console.error('Error adding agreement:', error)
      throw new Error('Failed to add agreement')
    }
  }

  await calculateConsensus(wordId)

  // Revalidate the contribute page to show updated consensus
  revalidatePath('/contribute')
  return { removed: false }
}

export async function saveContribution(data: ContributionFormData) {
  const { supabase, user } = await requireActiveUserForAction()

  // Check if user already has a contribution for this word
  const { data: existing } = await supabase
    .from('contributions')
    .select('agreement_type')
    .eq('word_id', data.word_id)
    .eq('user_id', user.id)
    .single()

  // Determine agreement_type:
  // - If they already agreed, keep it as 'agree' (they're just adding audio)
  // - Otherwise, it's a full contribution
  const agreementType = existing?.agreement_type === 'agree' ? 'agree' : 'full'

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
      agreement_type: agreementType,
    }, {
      onConflict: 'word_id,user_id'
    })

  if (error) {
    console.error('Error saving contribution:', error)
    throw new Error('Failed to save contribution')
  }

  await calculateConsensus(data.word_id)

  // Revalidate the contribute page to show next word
  revalidatePath('/contribute')
}
