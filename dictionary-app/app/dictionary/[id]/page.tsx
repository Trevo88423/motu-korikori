import { createServerComponentClient } from '@/lib/supabase'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import ConsensusBar from '@/components/ConsensusBar'
import CommentSection from '@/components/CommentSection'
import type { Word, ContributionWithProfile, ContributionGroup } from '@/lib/types'

export const dynamic = 'force-dynamic'

export default async function WordDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createServerComponentClient()

  // Fetch word details
  const { data: word, error: wordError } = await supabase
    .from('words')
    .select('*')
    .eq('id', id)
    .single()

  if (wordError || !word) {
    notFound()
  }

  // Get previous and next words (by frequency for logical ordering)
  const { data: prevWord } = await supabase
    .from('words')
    .select('id, motu_word')
    .lt('frequency', word.frequency)
    .order('frequency', { ascending: false })
    .limit(1)
    .single()

  const { data: nextWord } = await supabase
    .from('words')
    .select('id, motu_word')
    .gt('frequency', word.frequency)
    .order('frequency', { ascending: true })
    .limit(1)
    .single()

  // Get current user
  const { data: { user } } = await supabase.auth.getUser()

  // Fetch all contributions with profile info
  const { data: contributions } = await supabase
    .from('contributions')
    .select(`
      *,
      profile:profiles(name, connection_type, trust_score)
    `)
    .eq('word_id', id)
    .order('created_at', { ascending: false })

  // Fetch comments for this word
  const { data: comments } = await supabase
    .from('comments')
    .select(`
      *,
      profile:profiles(name, connection_type, trust_score)
    `)
    .eq('word_id', id)
    .order('net_votes', { ascending: false })

  // Get user's vote on each comment
  const commentsWithVotes = comments ? await Promise.all(
    comments.map(async (comment) => {
      if (!user) return { ...comment, user_vote: null }

      const { data: vote } = await supabase
        .from('comment_votes')
        .select('vote_type')
        .eq('comment_id', comment.id)
        .eq('user_id', user.id)
        .single()

      return { ...comment, user_vote: vote?.vote_type || null }
    })
  ) : []

  // Find user's own comment
  const userComment = commentsWithVotes.find(c => c.user_id === user?.id)

  // Group contributions for consensus display
  const contributionGroups: ContributionGroup[] = []

  if (contributions && contributions.length > 0) {
    const grouped = new Map<string, ContributionWithProfile[]>()

    contributions.forEach((contrib: any) => {
      if (!contrib.is_excluded) {
        const existing = grouped.get(contrib.english_gloss) || []
        grouped.set(contrib.english_gloss, [...existing, contrib])
      }
    })

    grouped.forEach((contribs, gloss) => {
      const weightedCount = contribs.reduce((sum, c: any) => {
        const typeWeight: Record<string, number> = {
          native_speaker: 2.0,
          heritage_speaker: 1.5,
          second_language: 1.0,
          learning_now: 0.5,
          researcher: 1.0,
          other: 0.5,
        }
        const weight = typeWeight[c.profile?.connection_type || 'other']

        const trustWeight = c.profile?.trust_score || 1.0

        return sum + (weight * trustWeight)
      }, 0)

      contributionGroups.push({
        gloss,
        count: contribs.length,
        weighted_count: weightedCount,
        contributors: contribs.map((c: any) => ({
          connection_type: c.profile?.connection_type || 'other',
          trust_score: c.profile?.trust_score || 1.0,
        })),
        audio_urls: contribs.map((c: any) => c.audio_url).filter(Boolean) as string[],
      })
    })
  }

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-6 flex items-center justify-between">
        <Link href="/dictionary" className="text-primary-600 hover:underline text-sm">
          ← Back to Dictionary
        </Link>

        <div className="flex items-center gap-2">
          {prevWord && (
            <Link
              href={`/dictionary/${prevWord.id}`}
              className="btn btn-ghost text-sm"
              title={`Previous: ${prevWord.motu_word}`}
            >
              ← Prev
            </Link>
          )}
          {nextWord && (
            <Link
              href={`/dictionary/${nextWord.id}`}
              className="btn btn-ghost text-sm"
              title={`Next: ${nextWord.motu_word}`}
            >
              Next →
            </Link>
          )}
        </div>
      </div>

      <div className="card">
        {/* Word Header */}
        <div className="text-center mb-8 pb-8 border-b">
          <h1 className="text-5xl font-bold text-primary-900 mb-4">
            {word.motu_word}
          </h1>

          <div className="flex items-center justify-center space-x-4 text-sm text-gray-600 mb-4">
            <span>Frequency: {word.frequency.toLocaleString()}</span>
            <span>•</span>
            <span>{word.total_contributions} contributions</span>
            <span>•</span>
            <span>{word.unique_contributors} contributors</span>
          </div>

          <span className={`inline-block px-3 py-1 text-sm font-medium rounded ${
            word.status === 'verified' ? 'bg-green-100 text-green-700' :
            word.status === 'consensus' ? 'bg-blue-100 text-blue-700' :
            word.status === 'flagged' ? 'bg-yellow-100 text-yellow-700' :
            'bg-gray-100 text-gray-700'
          }`}>
            {word.status.charAt(0).toUpperCase() + word.status.slice(1)}
          </span>
        </div>

        {/* Consensus Translation */}
        {word.consensus_gloss && (
          <div className="mb-8 p-6 bg-green-50 border border-green-200 rounded-lg">
            <h2 className="text-sm font-medium text-green-800 mb-2">
              Community Consensus Translation
            </h2>
            <p className="text-2xl font-semibold text-green-900">
              {word.consensus_gloss}
            </p>
            {word.consensus_confidence && (
              <p className="text-sm text-green-700 mt-2">
                Confidence: {(word.consensus_confidence * 100).toFixed(0)}%
              </p>
            )}
          </div>
        )}

        {/* Consensus Audio */}
        {word.consensus_audio_url && (
          <div className="mb-8">
            <h3 className="font-medium text-gray-900 mb-2">Community Pronunciation</h3>
            <audio src={word.consensus_audio_url} controls className="w-full" />
          </div>
        )}

        {/* Example Verse */}
        {word.example_motu && (
          <div className="mb-8">
            <h3 className="font-medium text-gray-900 mb-4">Example from Scripture</h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div className="bg-primary-50 rounded-lg p-4">
                <div className="text-xs font-medium text-primary-700 mb-2">
                  {word.example_reference}
                </div>
                <p className="text-gray-800 italic">{word.example_motu}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <div className="text-xs font-medium text-gray-500 mb-2">
                  English Translation
                </div>
                <p className="text-gray-700">{word.example_english}</p>
              </div>
            </div>
          </div>
        )}

        {/* Consensus Bar */}
        {contributionGroups.length > 0 && (
          <div className="mb-8">
            <ConsensusBar
              contributions={contributionGroups}
              currentConsensus={word.consensus_gloss}
            />
          </div>
        )}

        {/* All Contributions */}
        {contributions && contributions.length > 0 && (
          <div>
            <h3 className="font-medium text-gray-900 mb-4">
              All Contributions ({contributions.length})
            </h3>
            <div className="space-y-3">
              {contributions.map((contrib: any) => (
                <div
                  key={contrib.id}
                  className={`p-4 rounded-lg ${
                    contrib.is_excluded ? 'bg-red-50 border border-red-200' :
                    contrib.english_gloss === word.consensus_gloss ? 'bg-green-50 border border-green-200' :
                    'bg-gray-50'
                  }`}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-2 mb-1">
                        <span className="font-medium text-gray-900">
                          {contrib.english_gloss}
                        </span>
                        {contrib.is_excluded && (
                          <span className="px-2 py-0.5 bg-red-100 text-red-700 text-xs rounded">
                            Excluded
                          </span>
                        )}
                        {contrib.english_gloss === word.consensus_gloss && !contrib.is_excluded && (
                          <svg className="w-4 h-4 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                          </svg>
                        )}
                      </div>

                      <div className="flex items-center space-x-3 text-xs text-gray-500">
                        <span className="capitalize">
                          {contrib.profile?.connection_type?.replace('_', ' ')}
                        </span>
                        <span>•</span>
                        <span className="capitalize">{contrib.confidence.replace('_', ' ')}</span>
                        <span>•</span>
                        <span>{new Date(contrib.created_at).toLocaleDateString()}</span>
                      </div>

                      {contrib.notes && (
                        <p className="text-sm text-gray-600 mt-2 italic">
                          Note: {contrib.notes}
                        </p>
                      )}

                      {contrib.audio_url && (
                        <audio src={contrib.audio_url} controls className="mt-2 h-8" />
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {(!contributions || contributions.length === 0) && (
          <div className="text-center py-8 text-gray-500">
            <p>No contributions yet for this word.</p>
            <Link href={`/contribute?word=${word.id}`} className="btn btn-primary mt-4">
              Be the First to Contribute
            </Link>
          </div>
        )}

        {/* Community Comments & Context */}
        <div className="border-t mt-8 pt-8">
          <CommentSection
            wordId={word.id}
            comments={commentsWithVotes}
            userComment={userComment}
            currentUserId={user?.id}
          />
        </div>

        {/* Contribute Button - always show */}
        <div className="border-t mt-8 pt-6 text-center">
          <Link href={`/contribute?word=${word.id}`} className="btn btn-primary">
            ➕ Add Your Translation
          </Link>
        </div>
      </div>
    </div>
  )
}
