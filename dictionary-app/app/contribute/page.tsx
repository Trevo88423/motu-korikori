import { redirect } from 'next/navigation'
import { createServerComponentClient, getCurrentUserProfile, getTotalWordCount } from '@/lib/supabase'
import ContributeClient from '@/components/ContributeClient'
import { saveContribution } from './actions'
import { markWordComplete } from './completion-actions'
import type { Word, Contribution, ContributionWithProfile } from '@/lib/types'

export const dynamic = 'force-dynamic'
export const revalidate = 0 // Disable caching completely

interface SearchParams {
  word?: string
  skip?: string
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const MAX_SKIPPED = 50

// Recently skipped word ids arrive as ?skip=id1,id2,... (see ContributeClient)
function parseSkipped(skip?: string): string[] {
  if (!skip) return []
  return skip.split(',').filter((id) => UUID_RE.test(id)).slice(0, MAX_SKIPPED)
}

export default async function ContributePage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const params = await searchParams
  const supabase = await createServerComponentClient()

  // Either a specific word by ID, or the next word for the signed-in user (the
  // function uses auth.uid()), leaving out words they skipped recently.
  // Fetched alongside the profile; it's only used once the profile checks pass.
  const loadWords = async () => {
    if (params.word) {
      const result = await supabase
        .from('words')
        .select('*')
        .eq('id', params.word)
        .single()
      return { words: result.data ? [result.data] : null, wordsError: result.error }
    }
    const result = await supabase
      .rpc('get_next_word_for_user', { exclude_ids: parseSkipped(params.skip) })
    return { words: result.data, wordsError: result.error }
  }

  const [profile, totalWords, { words, wordsError }] = await Promise.all([
    getCurrentUserProfile(),
    getTotalWordCount(),
    loadWords(),
  ])

  if (!profile) {
    redirect('/login')
  }

  // Check if user is suspended/banned
  if (profile.status === 'suspended' || profile.status === 'banned') {
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-red-600 mb-4">
          Account {profile.status === 'suspended' ? 'Suspended' : 'Banned'}
        </h1>
        <p className="text-gray-600">
          Your account has been {profile.status}. Please contact support for more information.
        </p>
      </div>
    )
  }

  if (wordsError) {
    console.error('Error fetching next word:', wordsError)
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold text-red-600 mb-4">Error Loading Word</h1>
        <p className="text-gray-600">{wordsError.message}</p>
      </div>
    )
  }

  if (!words || words.length === 0) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <div className="card">
          <h1 className="text-4xl font-bold text-primary-900 mb-4">Congratulations!</h1>
          <p className="text-xl text-gray-700 mb-4">
            You've contributed to all {totalWords.toLocaleString()} words in the dictionary!
          </p>
          <p className="text-gray-600 mb-8">
            Thank you for your incredible dedication to preserving True Motu.
          </p>
          <div className="flex justify-center space-x-4">
            <a href="/dashboard" className="btn btn-primary">
              View Your Stats
            </a>
            <a href="/dictionary" className="btn btn-ghost">
              Browse Dictionary
            </a>
          </div>
        </div>
      </div>
    )
  }

  const word = words[0] as Word

  const [
    // Has the user already contributed to this word?
    // maybeSingle() handles the case where the contribution was deleted
    { data: userContribution },
    // All contributions for this word (for consensus display)
    { data: allContributions },
    { data: comments },
  ] = await Promise.all([
    supabase
      .from('contributions')
      .select('*')
      .eq('word_id', word.id)
      .eq('user_id', profile.id)
      .maybeSingle(),
    supabase
      .from('contributions')
      .select(`
        *,
        profile:profiles(display_name, connection_type, trust_score)
      `)
      .eq('word_id', word.id)
      .order('created_at', { ascending: false }),
    supabase
      .from('comments')
      .select(`
        *,
        profile:profiles(display_name, connection_type, trust_score)
      `)
      .eq('word_id', word.id)
      .order('net_votes', { ascending: false }),
  ])

  // The user's votes on those comments, in one query
  const commentIds = (comments || []).map((c) => c.id)
  const { data: votes } = commentIds.length > 0
    ? await supabase
        .from('comment_votes')
        .select('comment_id, vote_type')
        .eq('user_id', profile.id)
        .in('comment_id', commentIds)
    : { data: [] as { comment_id: string; vote_type: string }[] }

  const voteByComment = new Map((votes || []).map((v) => [v.comment_id, v.vote_type]))
  const commentsWithVotes = (comments || []).map((comment) => ({
    ...comment,
    user_vote: voteByComment.get(comment.id) || null,
  }))

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Progress indicator */}
      <div className="mb-6">
        <div className="flex justify-between text-sm text-gray-600 mb-2">
          <span>Your Progress</span>
          <span>
            {profile.contribution_count.toLocaleString()} / {totalWords.toLocaleString()} words
          </span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-primary-600 h-2 rounded-full transition-all"
            style={{ width: `${totalWords > 0 ? (profile.contribution_count / totalWords) * 100 : 0}%` }}
          />
        </div>
      </div>

      <ContributeClient
        word={word}
        userContribution={userContribution as Contribution}
        allContributions={(allContributions || []) as ContributionWithProfile[]}
        comments={commentsWithVotes}
        currentUserId={profile.id}
        onSubmit={saveContribution}
        onComplete={markWordComplete}
      />
    </div>
  )
}
