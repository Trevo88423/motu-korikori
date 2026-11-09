'use server'

import { revalidatePath } from 'next/cache'
import { requireActiveUserForAction } from '@/lib/auth'
import type { CommentFormData, VoteAction } from '@/lib/types'
import {
  BLOCKED_LANGUAGE_MESSAGE,
  isBlockedLanguageError,
  logBlockedLanguageAttempt,
} from '@/lib/blocked-language'
import { isRateLimitError, rateLimitMessage } from '@/lib/rate-limits'

// ============================================================================
// COMMENT ACTIONS
// ============================================================================

export async function addComment(data: CommentFormData): Promise<{ error?: string }> {
  const { supabase, user } = await requireActiveUserForAction()

  // Validate comment length
  if (data.comment_text.length < 20 || data.comment_text.length > 500) {
    throw new Error('Comment must be between 20 and 500 characters')
  }

  // Insert comment (unique constraint prevents duplicate)
  const { error } = await supabase
    .from('comments')
    .insert({
      word_id: data.word_id,
      user_id: user.id,
      comment_text: data.comment_text,
    })

  if (isBlockedLanguageError(error)) {
    await logBlockedLanguageAttempt(supabase, 'comments', data.comment_text)
    return { error: BLOCKED_LANGUAGE_MESSAGE }
  }
  if (error && isRateLimitError(error)) return { error: rateLimitMessage(error, 'comments') }
  if (error) {
    if (error.code === '23505') { // Unique constraint violation
      throw new Error('You have already commented on this word. You can edit your existing comment.')
    }
    console.error('Error adding comment:', error)
    throw new Error('Failed to add comment')
  }

  revalidatePath('/dictionary/[id]', 'page')
  revalidatePath(`/contribute?word=${data.word_id}`, 'page')
  return {}
}

export async function updateComment(commentId: string, commentText: string, wordId?: string): Promise<{ error?: string }> {
  const { supabase, user } = await requireActiveUserForAction()

  // Validate comment length
  if (commentText.length < 20 || commentText.length > 500) {
    throw new Error('Comment must be between 20 and 500 characters')
  }

  // Update comment (RLS ensures user owns it)
  // Note: Trigger will reset votes automatically
  const { error } = await supabase
    .from('comments')
    .update({ comment_text: commentText })
    .eq('id', commentId)
    .eq('user_id', user.id)

  if (isBlockedLanguageError(error)) {
    await logBlockedLanguageAttempt(supabase, 'comments', commentText)
    return { error: BLOCKED_LANGUAGE_MESSAGE }
  }
  if (error && isRateLimitError(error)) return { error: rateLimitMessage(error, 'comments') }
  if (error) {
    console.error('Error updating comment:', error)
    throw new Error('Failed to update comment')
  }

  revalidatePath('/dictionary/[id]', 'page')
  if (wordId) {
    revalidatePath(`/contribute?word=${wordId}`, 'page')
  }
  return {}
}

export async function deleteComment(commentId: string, wordId?: string) {
  const { supabase, user } = await requireActiveUserForAction()

  // Delete comment (RLS ensures user owns it)
  const { error } = await supabase
    .from('comments')
    .delete()
    .eq('id', commentId)
    .eq('user_id', user.id)

  if (error) {
    console.error('Error deleting comment:', error)
    throw new Error('Failed to delete comment')
  }

  revalidatePath('/dictionary/[id]', 'page')
  if (wordId) {
    revalidatePath(`/contribute?word=${wordId}`, 'page')
  }
}

// ============================================================================
// VOTING ACTIONS
// ============================================================================

export async function voteOnComment(action: VoteAction, wordId?: string): Promise<{ error?: string }> {
  const { supabase, user } = await requireActiveUserForAction()

  if (!action.vote_type || (action.vote_type !== 1 && action.vote_type !== -1)) {
    throw new Error('Invalid vote type')
  }

  // Check if user already voted
  const { data: existingVote } = await supabase
    .from('comment_votes')
    .select('id, vote_type')
    .eq('comment_id', action.target_id)
    .eq('user_id', user.id)
    .single()

  if (existingVote) {
    // If same vote, remove it (toggle off)
    if (existingVote.vote_type === action.vote_type) {
      const { error } = await supabase
        .from('comment_votes')
        .delete()
        .eq('id', existingVote.id)

      if (error) {
        throw new Error('Failed to remove vote')
      }
    } else {
      // If different vote, update it
      const { error } = await supabase
        .from('comment_votes')
        .update({ vote_type: action.vote_type })
        .eq('id', existingVote.id)

      if (error && isRateLimitError(error)) return { error: rateLimitMessage(error, 'votes') }
      if (error) {
        throw new Error('Failed to update vote')
      }
    }
  } else {
    // Insert new vote (RLS prevents voting on own comment)
    const { error } = await supabase
      .from('comment_votes')
      .insert({
        comment_id: action.target_id,
        user_id: user.id,
        vote_type: action.vote_type,
      })

    if (error && isRateLimitError(error)) return { error: rateLimitMessage(error, 'votes') }
    if (error) {
      if (error.message.includes('violates row-level security')) {
        throw new Error('You cannot vote on your own comment')
      }
      console.error('Error voting on comment:', error)
      throw new Error('Failed to vote on comment')
    }
  }

  // Trust isn't touched here: the database recomputes the author's trust
  // from the votes they currently hold (#53)

  revalidatePath('/dictionary/[id]', 'page')
  if (wordId) {
    revalidatePath(`/contribute?word=${wordId}`, 'page')
  }
  return {}
}

export async function voteOnContribution(contributionId: string, wordId?: string): Promise<{ error?: string }> {
  const { supabase, user } = await requireActiveUserForAction()

  // Check if user has already submitted a translation for this word
  const { data: contribution } = await supabase
    .from('contributions')
    .select('word_id')
    .eq('id', contributionId)
    .single()

  if (!contribution) {
    throw new Error('Contribution not found')
  }

  const { data: userContribution } = await supabase
    .from('contributions')
    .select('id')
    .eq('word_id', contribution.word_id)
    .eq('user_id', user.id)
    .single()

  if (userContribution) {
    throw new Error('You cannot vote on translations when you have submitted your own. You can only have one translation per word.')
  }

  // Check if already voted
  const { data: existingVote } = await supabase
    .from('contribution_votes')
    .select('id')
    .eq('contribution_id', contributionId)
    .eq('user_id', user.id)
    .single()

  if (existingVote) {
    // Remove vote (toggle off)
    const { error } = await supabase
      .from('contribution_votes')
      .delete()
      .eq('id', existingVote.id)

    if (error) {
      throw new Error('Failed to remove vote')
    }
  } else {
    // Add vote
    const { error } = await supabase
      .from('contribution_votes')
      .insert({
        contribution_id: contributionId,
        user_id: user.id,
      })

    if (error && isRateLimitError(error)) return { error: rateLimitMessage(error, 'votes') }
    if (error) {
      console.error('Error voting on contribution:', error)
      throw new Error('Failed to vote on contribution')
    }
  }

  revalidatePath('/dictionary/[id]', 'page')
  if (wordId) {
    revalidatePath(`/contribute?word=${wordId}`, 'page')
  }
  return {}
}
