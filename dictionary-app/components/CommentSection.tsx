'use client'

import { useState } from 'react'
import { addComment, updateComment, deleteComment, flagComment, voteOnComment } from '@/app/contribute/comment-actions'
import type { CommentWithProfile } from '@/lib/types'

interface CommentSectionProps {
  wordId: string
  comments: CommentWithProfile[]
  userComment?: CommentWithProfile // User's own comment if exists
  currentUserId?: string
}

export default function CommentSection({ wordId, comments, userComment, currentUserId }: CommentSectionProps) {
  const [commentText, setCommentText] = useState(userComment?.comment_text || '')
  const [isEditing, setIsEditing] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState('')
  const [showLowScored, setShowLowScored] = useState(false)
  const [showGuidelines, setShowGuidelines] = useState(false)

  const characterCount = commentText.length
  const isValid = characterCount >= 20 && characterCount <= 500

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!isValid) {
      setError('Comment must be between 20 and 500 characters')
      return
    }

    setIsSubmitting(true)

    try {
      if (userComment) {
        await updateComment(userComment.id, commentText, wordId)
      } else {
        await addComment({ word_id: wordId, comment_text: commentText })
      }
      setIsEditing(false)
      setCommentText('')
    } catch (err: any) {
      setError(err.message || 'Failed to save comment')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleDelete = async () => {
    if (!userComment || !confirm('Delete your comment? This cannot be undone.')) return

    setIsSubmitting(true)
    try {
      await deleteComment(userComment.id, wordId)
      setCommentText('')
    } catch (err: any) {
      setError(err.message || 'Failed to delete comment')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleVote = async (commentId: string, voteType: 1 | -1) => {
    try {
      await voteOnComment({ target_id: commentId, vote_type: voteType }, wordId)
    } catch (err: any) {
      setError(err.message || 'Failed to vote')
    }
  }

  const handleFlag = async (commentId: string) => {
    try {
      await flagComment(commentId, wordId)
    } catch (err: any) {
      setError(err.message || 'Failed to flag comment')
    }
  }

  // Sort comments: highest votes first, collapse low-scored
  const sortedComments = [...comments].sort((a, b) => b.net_votes - a.net_votes)
  const visibleComments = sortedComments.filter(c => showLowScored || c.net_votes >= -5)
  const hiddenCount = sortedComments.length - visibleComments.length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="font-medium text-gray-900">Community Context & Notes</h3>
        <span className="text-sm text-gray-500">{comments.length} {comments.length === 1 ? 'comment' : 'comments'}</span>
      </div>

      {/* User's comment form */}
      {currentUserId && (
        <div className="border border-gray-300 rounded-lg p-4 bg-gray-50">
          {/* Guidelines toggle */}
          <button
            type="button"
            onClick={() => setShowGuidelines(!showGuidelines)}
            className="text-sm text-primary-600 hover:text-primary-700 mb-3 flex items-center gap-1"
          >
            {showGuidelines ? '▼' : '▶'} Comment Guidelines & Examples
          </button>

          {/* Collapsible guidelines */}
          {showGuidelines && (
            <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg text-sm space-y-2">
              <p className="font-medium text-blue-900">Helpful comments:</p>
              <ul className="list-none text-blue-800 space-y-1 ml-2">
                <li>✓ "My family says it like..."</li>
                <li>✓ "We also use this to mean..."</li>
                <li>✓ "Old people say [X], young people say [Y]"</li>
                <li>✓ "In my village we say..."</li>
                <li>✓ "Example: [how you'd use it in a sentence]"</li>
                <li>✓ "My mum/bubu still uses this word for..."</li>
                <li>✓ "This is an old/archaic word - we don't use it anymore"</li>
                <li>✓ "Only used in ceremonies/special occasions"</li>
              </ul>
              <p className="text-xs text-blue-700 italic mt-2">
                Share your personal knowledge and family usage - that's what makes this dictionary special!
              </p>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-3">
            <div>
              <label className="label text-sm">
                {userComment ? 'Your Comment' : 'Add Linguistic Context'}
                <span className="text-red-500"> *</span>
              </label>
              <textarea
                value={commentText}
                onChange={(e) => setCommentText(e.target.value)}
                placeholder="e.g., 'My bubu uses this word for...' or 'Old people say [X], young people say [Y]' or 'In my village we say...' (20-500 characters)"
                rows={4}
                className={`input ${!isValid && commentText.length > 0 ? 'border-red-500' : ''}`}
                disabled={isSubmitting || (userComment && !isEditing)}
              />
              <div className="flex items-center justify-between mt-1">
                <span className={`text-xs ${characterCount < 20 ? 'text-red-600' : characterCount > 500 ? 'text-red-600' : 'text-gray-500'}`}>
                  {characterCount}/500 {characterCount < 20 ? `(${20 - characterCount} more needed)` : ''}
                </span>
                {userComment && !isEditing && (
                  <span className="text-xs text-amber-600 italic">
                    ⚠️ Editing will reset all votes
                  </span>
                )}
              </div>
            </div>

            {error && (
              <div className="p-2 bg-red-50 border border-red-200 rounded text-sm text-red-600">
                {error}
              </div>
            )}

            <div className="flex flex-wrap gap-2">
              {userComment ? (
                <>
                  {!isEditing ? (
                    <>
                      <button
                        type="button"
                        onClick={() => setIsEditing(true)}
                        className="btn btn-ghost text-sm"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={handleDelete}
                        className="btn btn-ghost text-sm text-red-600 hover:text-red-700"
                        disabled={isSubmitting}
                      >
                        Delete
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        type="submit"
                        className="btn btn-primary text-sm"
                        disabled={!isValid || isSubmitting}
                      >
                        {isSubmitting ? 'Saving...' : 'Save Changes (resets votes)'}
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setIsEditing(false)
                          setCommentText(userComment.comment_text)
                        }}
                        className="btn btn-ghost text-sm"
                      >
                        Cancel
                      </button>
                    </>
                  )}
                </>
              ) : (
                <button
                  type="submit"
                  className="btn btn-primary text-sm"
                  disabled={!isValid || isSubmitting}
                >
                  {isSubmitting ? 'Posting...' : 'Post Comment'}
                </button>
              )}
            </div>
          </form>
        </div>
      )}

      {/* Display comments */}
      {visibleComments.length > 0 ? (
        <div className="space-y-3">
          {visibleComments.map((comment) => {
            const isOwnComment = comment.user_id === currentUserId
            const userVote = comment.user_vote

            return (
              <div
                key={comment.id}
                className={`p-4 rounded-lg border ${
                  comment.net_votes < -5 ? 'bg-gray-100 border-gray-300' :
                  isOwnComment ? 'bg-primary-50 border-primary-200' :
                  'bg-white border-gray-200'
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1">
                    <p className="text-gray-800">{comment.comment_text}</p>

                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-2 text-xs text-gray-500">
                      <span className="capitalize">
                        {comment.profile?.connection_type?.replace('_', ' ')}
                      </span>
                      <span className="hidden sm:inline">•</span>
                      <span>{new Date(comment.created_at).toLocaleDateString()}</span>
                      {comment.updated_at !== comment.created_at && (
                        <>
                          <span className="hidden sm:inline">•</span>
                          <span className="italic">edited</span>
                        </>
                      )}
                      {isOwnComment && (
                        <>
                          <span className="hidden sm:inline">•</span>
                          <span className="text-primary-600 font-medium">Your comment</span>
                        </>
                      )}
                    </div>
                  </div>

                  {/* Voting buttons */}
                  {!isOwnComment && currentUserId && (
                    <div className="flex flex-col items-center gap-1">
                      <button
                        onClick={() => handleVote(comment.id, 1)}
                        className={`p-1 rounded hover:bg-gray-200 transition ${
                          userVote === 1 ? 'text-green-600' : 'text-gray-400'
                        }`}
                        title="Upvote"
                      >
                        ▲
                      </button>
                      <span className={`text-sm font-medium ${
                        comment.net_votes > 0 ? 'text-green-600' :
                        comment.net_votes < 0 ? 'text-red-600' :
                        'text-gray-600'
                      }`}>
                        {comment.net_votes}
                      </span>
                      <button
                        onClick={() => handleVote(comment.id, -1)}
                        className={`p-1 rounded hover:bg-gray-200 transition ${
                          userVote === -1 ? 'text-red-600' : 'text-gray-400'
                        }`}
                        title="Downvote"
                      >
                        ▼
                      </button>
                    </div>
                  )}
                </div>

                {/* Flag button */}
                {!isOwnComment && currentUserId && (
                  <div className="mt-2 pt-2 border-t border-gray-200">
                    <button
                      onClick={() => handleFlag(comment.id)}
                      className="text-xs text-gray-500 hover:text-red-600 transition"
                    >
                      🚩 Flag as irrelevant
                    </button>
                  </div>
                )}
              </div>
            )
          })}

          {hiddenCount > 0 && (
            <button
              onClick={() => setShowLowScored(!showLowScored)}
              className="text-sm text-gray-600 hover:text-gray-800"
            >
              {showLowScored ? 'Hide' : 'Show'} {hiddenCount} low-scored {hiddenCount === 1 ? 'comment' : 'comments'}
            </button>
          )}
        </div>
      ) : (
        <div className="text-center py-8 text-gray-500 border border-gray-200 rounded-lg">
          <p className="text-sm">No comments yet. Be the first to add context!</p>
        </div>
      )}

      <div className="text-xs text-gray-500 border-t pt-3 space-y-2">
        <p><strong>💡 Comment Purpose:</strong> Share how your family uses this word, regional differences, generational changes, or cultural context.</p>
        <p className="leading-relaxed"><strong>✅ Good:</strong> "My mum says..." <span className="hidden sm:inline">•</span><br className="sm:hidden" /> "Old people say X, young say Y" <span className="hidden sm:inline">•</span><br className="sm:hidden" /> "In my village..." <span className="hidden sm:inline">•</span><br className="sm:hidden" /> "Example: [sentence]"</p>
        <p><strong>❌ Avoid:</strong> Arguing about translations <span className="hidden sm:inline">•</span><br className="sm:hidden" /> Vague comments <span className="hidden sm:inline">•</span><br className="sm:hidden" /> Off-topic discussion</p>
      </div>
    </div>
  )
}
