'use server'

import { revalidatePath } from 'next/cache'
import { createServerComponentClient } from '@/lib/supabase'
import type { CommentFormData, VoteAction } from '@/lib/types'

// ============================================================================
// COMMENT ACTIONS
// ============================================================================

export async function addComment(data: CommentFormData) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    throw new Error('Not authenticated')
  }

  // Validate comment length
  if (data.comment_text.length < 20 || data.comment_text.length > 500) {
    throw new Error('Comment must be between 20 and 500 characters')
  }

  // Check user status
  const { data: profile } = await supabase
    .from('profiles')
    .select('status, trust_score')
    .eq('id', user.id)
    .single()

  if (profile?.status === 'suspended' || profile?.status === 'banned') {
    throw new Error('Your account has been suspended')
  }

  // Insert comment (unique constraint prevents duplicate)
  const { error } = await supabase
    .from('comments')
    .insert({
      word_id: data.word_id,
      user_id: user.id,
      comment_text: data.comment_text,
    })

  if (error) {
    if (error.code === '23505') { // Unique constraint violation
      throw new Error('You have already commented on this word. You can edit your existing comment.')
    }
    console.error('Error adding comment:', error)
    throw new Error('Failed to add comment')
  }

  revalidatePath('/dictionary/[id]', 'page')
  revalidatePath('/contribute')
}

export async function updateComment(commentId: string, commentText: string) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    throw new Error('Not authenticated')
  }

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

  if (error) {
    console.error('Error updating comment:', error)
    throw new Error('Failed to update comment')
  }

  revalidatePath('/dictionary/[id]', 'page')
  revalidatePath('/contribute')
}

export async function deleteComment(commentId: string) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    throw new Error('Not authenticated')
  }

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
  revalidatePath('/contribute')
}

export async function flagComment(commentId: string) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    throw new Error('Not authenticated')
  }

  // Increment flag count
  const { error } = await supabase.rpc('increment_comment_flags', {
    comment_uuid: commentId
  })

  if (error) {
    console.error('Error flagging comment:', error)
    throw new Error('Failed to flag comment')
  }

  revalidatePath('/dictionary/[id]', 'page')
  revalidatePath('/contribute')
}

// ============================================================================
// VOTING ACTIONS
// ============================================================================

export async function voteOnComment(action: VoteAction) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    throw new Error('Not authenticated')
  }

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

    if (error) {
      if (error.message.includes('violates row-level security')) {
        throw new Error('You cannot vote on your own comment')
      }
      console.error('Error voting on comment:', error)
      throw new Error('Failed to vote on comment')
    }
  }

  // Update user's trust score based on vote weight
  await updateTrustScoreForVote(user.id, action.vote_type, 'comment')

  revalidatePath('/dictionary/[id]', 'page')
  revalidatePath('/contribute')
}

export async function voteOnContribution(contributionId: string) {
  const supabase = await createServerComponentClient()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    throw new Error('Not authenticated')
  }

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

    if (error) {
      console.error('Error voting on contribution:', error)
      throw new Error('Failed to vote on contribution')
    }

    // Update trust score of contribution author
    await updateTrustScoreForVote(user.id, 1, 'contribution')
  }

  revalidatePath('/dictionary/[id]', 'page')
  revalidatePath('/contribute')
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

async function updateTrustScoreForVote(
  userId: string,
  voteType: 1 | -1,
  targetType: 'comment' | 'contribution'
) {
  const supabase = await createServerComponentClient()

  // Get voter's trust score for weighting
  const { data: voter } = await supabase
    .from('profiles')
    .select('trust_score, connection_type')
    .eq('id', userId)
    .single()

  if (!voter) return

  // Calculate vote weight based on connection type and trust score
  const typeWeight = {
    native_speaker: 2.0,
    heritage_speaker: 1.5,
    second_language: 1.0,
    learning_now: 0.5,
    researcher: 1.0,
    other: 0.5,
  }[voter.connection_type] || 1.0

  const trustMultiplier = voter.trust_score >= 1.0 ? 1.0 :
                         voter.trust_score >= 0.5 ? 0.75 :
                         voter.trust_score >= 0.2 ? 0.25 : 0.1

  const voteWeight = typeWeight * trustMultiplier

  // Update target author's trust score
  const scoreChange = voteType === 1 ? 0.1 * voteWeight : -0.2 * voteWeight

  // Note: This would need to query the target to find the author
  // For now, we'll implement this in a database trigger or separate function
  // This is just a placeholder for the logic
}

// Note: Add this SQL function to your migration for automatic trust score updates
/*
CREATE OR REPLACE FUNCTION update_author_trust_score()
RETURNS TRIGGER AS $$
BEGIN
  -- Implementation to update trust_score of contribution/comment author
  -- based on vote_type and voter's trust_score
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
*/
