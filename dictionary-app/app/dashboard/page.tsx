import { redirect } from 'next/navigation'
import { createServerComponentClient, getCurrentUserProfile, getTotalWordCount } from '@/lib/supabase'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function DashboardPage() {
  const supabase = await createServerComponentClient()
  const profile = await getCurrentUserProfile()

  if (!profile) {
    redirect('/login')
  }

  // Fetch user's recent contributions with word details
  const { data: recentContributions } = await supabase
    .from('contributions')
    .select(`
      id,
      english_gloss,
      confidence,
      created_at,
      matches_consensus,
      word:words(motu_word, consensus_gloss)
    `)
    .eq('user_id', profile.id)
    .order('created_at', { ascending: false })
    .limit(10)

  // Calculate consensus rate
  const matchingContributions = recentContributions?.filter(c => c.matches_consensus === true).length || 0
  const totalContributions = profile.contribution_count
  const consensusRate = totalContributions > 0 ? (matchingContributions / totalContributions) * 100 : 0

  // Calculate progress percentage
  const totalWords = await getTotalWordCount()
  const progressPercentage = totalWords > 0 ? (totalContributions / totalWords) * 100 : 0

  // Get streak information
  const streakDays = profile.streak_days

  // Connection type display name
  const connectionTypeLabels: Record<string, string> = {
    native_speaker: 'Native Speaker',
    heritage_speaker: 'Heritage Speaker',
    second_language: 'Second Language Learner',
    learning_now: 'Currently Learning',
    researcher: 'Researcher/Linguist',
    other: 'Other',
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Welcome back, {profile.name}!</h1>
        <p className="text-gray-600 mt-2">
          {connectionTypeLabels[profile.connection_type]} • Trust Score: {profile.trust_score.toFixed(2)}
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {/* Total Contributions */}
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Total Contributions</p>
              <p className="text-3xl font-bold text-primary-900 mt-1">
                {totalContributions.toLocaleString()}
              </p>
            </div>
            <div className="w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
          </div>
        </div>

        {/* Progress */}
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Progress</p>
              <p className="text-3xl font-bold text-secondary-900 mt-1">
                {progressPercentage.toFixed(1)}%
              </p>
              <p className="text-xs text-gray-500 mt-1">
                {Math.max(0, totalWords - totalContributions).toLocaleString()} words remaining
              </p>
            </div>
            <div className="w-12 h-12 bg-secondary-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-secondary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
        </div>

        {/* Streak */}
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Current Streak</p>
              <p className="text-3xl font-bold text-orange-900 mt-1">
                {streakDays}
              </p>
              <p className="text-xs text-gray-500 mt-1">
                {streakDays === 1 ? 'day' : 'days'}
              </p>
            </div>
            <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-orange-600" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M12.395 2.553a1 1 0 00-1.45-.385c-.345.23-.614.558-.822.88-.214.33-.403.713-.57 1.116-.334.804-.614 1.768-.84 2.734a31.365 31.365 0 00-.613 3.58 2.64 2.64 0 01-.945-1.067c-.328-.68-.398-1.534-.398-2.654A1 1 0 005.05 6.05 6.981 6.981 0 003 11a7 7 0 1011.95-4.95c-.592-.591-.98-.985-1.348-1.467-.363-.476-.724-1.063-1.207-2.03zM12.12 15.12A3 3 0 017 13s.879.5 2.5.5c0-1 .5-4 1.25-4.5.5 1 .786 1.293 1.371 1.879A2.99 2.99 0 0113 13a2.99 2.99 0 01-.879 2.121z" clipRule="evenodd" />
              </svg>
            </div>
          </div>
        </div>

        {/* Consensus Rate */}
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Consensus Rate</p>
              <p className="text-3xl font-bold text-green-900 mt-1">
                {consensusRate.toFixed(0)}%
              </p>
              <p className="text-xs text-gray-500 mt-1">
                matching community
              </p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="card mb-8">
        <div className="flex justify-between items-center mb-2">
          <h3 className="font-semibold text-gray-900">Dictionary Progress</h3>
          <span className="text-sm text-gray-600">
            {totalContributions.toLocaleString()} / {totalWords.toLocaleString()}
          </span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-4">
          <div
            className="bg-gradient-to-r from-primary-500 to-secondary-500 h-4 rounded-full transition-all"
            style={{ width: `${progressPercentage}%` }}
          />
        </div>
      </div>

      {/* Recent Contributions */}
      <div className="card">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-bold text-gray-900">Recent Contributions</h2>
          <Link href="/contribute" className="btn btn-primary">
            Continue Contributing
          </Link>
        </div>

        {recentContributions && recentContributions.length > 0 ? (
          <div className="space-y-4">
            {recentContributions.map((contribution: any) => (
              <div
                key={contribution.id}
                className="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition"
              >
                <div className="flex-1">
                  <div className="flex items-center space-x-3">
                    <h4 className="font-semibold text-lg text-gray-900">
                      {contribution.word.motu_word}
                    </h4>
                    <span className="text-gray-400">→</span>
                    <span className="text-gray-700">{contribution.english_gloss}</span>
                  </div>
                  <div className="flex items-center space-x-4 mt-2 text-sm text-gray-500">
                    <span>{new Date(contribution.created_at).toLocaleDateString()}</span>
                    <span className="capitalize">{contribution.confidence.replace('_', ' ')}</span>
                    {contribution.word.consensus_gloss && (
                      <span className="text-xs">
                        Consensus: {contribution.word.consensus_gloss}
                      </span>
                    )}
                  </div>
                </div>
                <div>
                  {contribution.matches_consensus === true && (
                    <span className="px-3 py-1 bg-green-100 text-green-700 text-xs font-medium rounded-full">
                      Matches Consensus
                    </span>
                  )}
                  {contribution.matches_consensus === false && (
                    <span className="px-3 py-1 bg-yellow-100 text-yellow-700 text-xs font-medium rounded-full">
                      Different
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-12 text-gray-500">
            <p>No contributions yet.</p>
            <Link href="/contribute" className="btn btn-primary mt-4">
              Start Contributing
            </Link>
          </div>
        )}
      </div>
    </div>
  )
}
