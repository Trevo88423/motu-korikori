import { redirect } from 'next/navigation'
import { createServerComponentClient, getCurrentUserProfile } from '@/lib/supabase'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function MyContributionsPage() {
  const supabase = await createServerComponentClient()
  const profile = await getCurrentUserProfile()

  if (!profile) {
    redirect('/login')
  }

  // Get user's contributions with word details
  const { data: contributions } = await supabase
    .from('contributions')
    .select(`
      *,
      word:words(motu_word, consensus_gloss, frequency)
    `)
    .eq('user_id', profile.id)
    .order('created_at', { ascending: false })

  // Get user's comments
  const { data: comments } = await supabase
    .from('comments')
    .select(`
      *,
      word:words(motu_word)
    `)
    .eq('user_id', profile.id)
    .order('created_at', { ascending: false })

  // Calculate stats
  const fullContributions = contributions?.filter(c => c.agreement_type === 'full').length || 0
  const agreements = contributions?.filter(c => c.agreement_type === 'agree').length || 0
  const withAudio = contributions?.filter(c => c.audio_url).length || 0
  const commentsCount = comments?.length || 0

  const connectionTypeLabels: Record<string, string> = {
    native_speaker: 'Native Speaker',
    heritage_speaker: 'Heritage Speaker',
    second_language: 'Second Language',
    learning_now: 'Learning Now',
    researcher: 'Researcher',
    other: 'Other',
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-6 sm:mb-8">
        <h1 className="text-2xl sm:text-3xl md:text-4xl font-bold text-primary-900 mb-2">My Contributions</h1>
        <p className="text-sm sm:text-base text-gray-600">
          Your impact on preserving True Motu
        </p>
      </div>

      {/* Profile Stats */}
      <div className="card mb-6 sm:mb-8">
        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 mb-4">
          <div>
            <h2 className="text-xl sm:text-2xl font-bold text-gray-900">{profile.name}</h2>
            <p className="text-sm sm:text-base text-gray-600">{connectionTypeLabels[profile.connection_type]}</p>
          </div>
          <div className="sm:text-right">
            <div className="text-2xl sm:text-3xl font-bold text-primary-600">
              {profile.contribution_count.toLocaleString()}
            </div>
            <div className="text-xs sm:text-sm text-gray-600">Total Contributions</div>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 sm:gap-4 mt-4 sm:mt-6 pt-4 sm:pt-6 border-t">
          <div>
            <div className="text-xl sm:text-2xl font-bold text-gray-900">{fullContributions}</div>
            <div className="text-xs text-gray-600">Full Translations</div>
          </div>
          <div>
            <div className="text-xl sm:text-2xl font-bold text-gray-900">{agreements}</div>
            <div className="text-xs text-gray-600">Agreements</div>
          </div>
          <div>
            <div className="text-xl sm:text-2xl font-bold text-gray-900">{withAudio}</div>
            <div className="text-xs text-gray-600">With Audio</div>
          </div>
          <div>
            <div className="text-xl sm:text-2xl font-bold text-gray-900">{commentsCount}</div>
            <div className="text-xs text-gray-600">Comments</div>
          </div>
        </div>

        <div className="mt-6 pt-6 border-t">
          <div className="text-sm text-gray-600">
            <strong>Trust Score:</strong> {profile.trust_score.toFixed(1)}x
            <span className="ml-4">
              <strong>Progress:</strong> {((profile.contribution_count / 15610) * 100).toFixed(1)}% of dictionary
            </span>
          </div>
        </div>
      </div>

      {/* Recent Contributions */}
      <div className="card mb-8">
        <h3 className="text-xl font-bold text-gray-900 mb-4">Recent Contributions</h3>

        {contributions && contributions.length > 0 ? (
          <div className="space-y-3">
            {contributions.slice(0, 20).map((contribution: any) => (
              <div
                key={contribution.id}
                className="flex flex-col sm:flex-row sm:items-start sm:justify-between p-3 sm:p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition gap-2"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex flex-wrap items-center gap-1 sm:gap-2 mb-1">
                    <span className="font-medium text-base sm:text-lg text-primary-900">
                      {contribution.word?.motu_word}
                    </span>
                    <span className="text-gray-400">→</span>
                    <span className="text-gray-900 text-sm sm:text-base break-words">{contribution.english_gloss}</span>
                  </div>
                  <div className="flex flex-wrap items-center gap-2 sm:gap-3 text-xs text-gray-500">
                    <span>
                      {new Date(contribution.created_at).toLocaleDateString()}
                    </span>
                    <span className={`px-2 py-0.5 rounded ${
                      contribution.agreement_type === 'full'
                        ? 'bg-green-100 text-green-700'
                        : 'bg-blue-100 text-blue-700'
                    }`}>
                      {contribution.agreement_type === 'full' ? 'Full' : 'Agreement'}
                    </span>
                    {contribution.audio_url && (
                      <span className="px-2 py-0.5 rounded bg-purple-100 text-purple-700">
                        🎤 Audio
                      </span>
                    )}
                    <span className="capitalize">{contribution.confidence.replace('_', ' ')}</span>
                  </div>
                  {contribution.notes && (
                    <p className="text-sm text-gray-600 mt-2">{contribution.notes}</p>
                  )}
                </div>
                {contribution.word?.consensus_gloss === contribution.english_gloss && (
                  <span className="sm:ml-4 text-green-600 font-medium text-xs sm:text-sm self-start sm:self-auto">
                    ✓ Consensus
                  </span>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-12 text-gray-500">
            <p className="mb-4">You haven't made any contributions yet.</p>
            <Link href="/contribute" className="btn btn-primary">
              Start Contributing
            </Link>
          </div>
        )}
      </div>

      {/* Recent Comments */}
      {comments && comments.length > 0 && (
        <div className="card">
          <h3 className="text-xl font-bold text-gray-900 mb-4">Recent Comments</h3>
          <div className="space-y-3">
            {comments.slice(0, 10).map((comment: any) => (
              <div
                key={comment.id}
                className="p-4 bg-gray-50 rounded-lg"
              >
                <div className="flex items-center gap-2 mb-2">
                  <span className="font-medium text-primary-900">
                    {comment.word?.motu_word}
                  </span>
                  <span className="text-xs text-gray-500">
                    {new Date(comment.created_at).toLocaleDateString()}
                  </span>
                  {comment.net_votes > 0 && (
                    <span className="text-xs text-green-600">
                      ▲ {comment.net_votes}
                    </span>
                  )}
                </div>
                <p className="text-gray-700">{comment.comment_text}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Quick Actions */}
      <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row justify-center gap-3 sm:gap-4">
        <Link href="/contribute" className="btn btn-primary text-center">
          Continue Contributing
        </Link>
        <Link href="/leaderboard" className="btn btn-ghost text-center">
          View Leaderboard
        </Link>
      </div>
    </div>
  )
}
