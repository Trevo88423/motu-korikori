import { createServerComponentClient } from '@/lib/supabase'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function LeaderboardPage() {
  const supabase = await createServerComponentClient()

  // Get top contributors
  const { data: topContributors } = await supabase
    .from('profiles')
    .select('id, name, contribution_count, connection_type, trust_score, status')
    .order('contribution_count', { ascending: false })
    .limit(100)

  // Get current user to highlight their position
  const { data: { user } } = await supabase.auth.getUser()

  // If user is logged in but not in top 100, get their rank
  let currentUserRank = null
  if (user && !topContributors?.find(c => c.id === user.id)) {
    const { count } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gt('contribution_count', topContributors?.[topContributors.length - 1]?.contribution_count || 0)

    if (count !== null) {
      currentUserRank = count + 1
    }
  }

  const connectionTypeLabels: Record<string, { label: string; color: string }> = {
    native_speaker: { label: 'Native', color: 'bg-primary-100 text-primary-700' },
    heritage_speaker: { label: 'Heritage', color: 'bg-purple-100 text-purple-700' },
    second_language: { label: 'L2', color: 'bg-blue-100 text-blue-700' },
    learning_now: { label: 'Learning', color: 'bg-yellow-100 text-yellow-700' },
    researcher: { label: 'Researcher', color: 'bg-green-100 text-green-700' },
    other: { label: 'Other', color: 'bg-gray-100 text-gray-700' },
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-6 sm:mb-8">
        <h1 className="text-2xl sm:text-3xl md:text-4xl font-bold text-primary-900 mb-2">Leaderboard</h1>
        <p className="text-sm sm:text-base text-gray-600">
          Top contributors helping preserve True Motu
        </p>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-3 gap-2 sm:gap-4 mb-6 sm:mb-8">
        <div className="card text-center">
          <div className="text-xl sm:text-2xl md:text-3xl font-bold text-primary-600">
            {topContributors?.[0]?.contribution_count.toLocaleString() || 0}
          </div>
          <div className="text-xs sm:text-sm text-gray-600">Top Contributor</div>
        </div>
        <div className="card text-center">
          <div className="text-xl sm:text-2xl md:text-3xl font-bold text-primary-600">
            {topContributors?.length || 0}
          </div>
          <div className="text-xs sm:text-sm text-gray-600">Contributors</div>
        </div>
        <div className="card text-center">
          <div className="text-xl sm:text-2xl md:text-3xl font-bold text-primary-600">
            {topContributors?.reduce((sum, c) => sum + c.contribution_count, 0).toLocaleString() || 0}
          </div>
          <div className="text-xs sm:text-sm text-gray-600">Total</div>
        </div>
      </div>

      {/* Leaderboard Table */}
      <div className="card">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-200">
                <th className="text-left py-2 sm:py-3 px-2 sm:px-4 font-medium text-gray-700 text-sm">#</th>
                <th className="text-left py-2 sm:py-3 px-2 sm:px-4 font-medium text-gray-700 text-sm">Contributor</th>
                <th className="text-left py-2 sm:py-3 px-2 sm:px-4 font-medium text-gray-700 text-sm hidden sm:table-cell">Type</th>
                <th className="text-right py-2 sm:py-3 px-2 sm:px-4 font-medium text-gray-700 text-sm">Count</th>
                <th className="text-right py-2 sm:py-3 px-2 sm:px-4 font-medium text-gray-700 text-sm hidden md:table-cell">Trust</th>
              </tr>
            </thead>
            <tbody>
              {topContributors?.map((contributor, index) => {
                const isCurrentUser = user?.id === contributor.id
                const typeInfo = connectionTypeLabels[contributor.connection_type] || connectionTypeLabels.other

                return (
                  <tr
                    key={contributor.id}
                    className={`border-b border-gray-100 hover:bg-gray-50 ${
                      isCurrentUser ? 'bg-primary-50' : ''
                    }`}
                  >
                    <td className="py-2 sm:py-3 px-2 sm:px-4">
                      <div className="flex items-center">
                        {index === 0 && <span className="text-lg sm:text-2xl mr-1 sm:mr-2">🥇</span>}
                        {index === 1 && <span className="text-lg sm:text-2xl mr-1 sm:mr-2">🥈</span>}
                        {index === 2 && <span className="text-lg sm:text-2xl mr-1 sm:mr-2">🥉</span>}
                        <span className="font-medium text-sm sm:text-base">{index + 1}</span>
                      </div>
                    </td>
                    <td className="py-2 sm:py-3 px-2 sm:px-4">
                      <div className="font-medium text-gray-900 text-sm sm:text-base truncate max-w-[120px] sm:max-w-none">
                        {contributor.name}
                        {isCurrentUser && (
                          <span className="ml-1 sm:ml-2 text-xs text-primary-600 font-normal">(You)</span>
                        )}
                      </div>
                      {/* Show type badge on mobile under the name */}
                      <span className={`inline-block px-1.5 py-0.5 text-xs rounded mt-1 sm:hidden ${typeInfo.color}`}>
                        {typeInfo.label}
                      </span>
                    </td>
                    <td className="py-2 sm:py-3 px-2 sm:px-4 hidden sm:table-cell">
                      <span className={`inline-block px-2 py-1 text-xs rounded ${typeInfo.color}`}>
                        {typeInfo.label}
                      </span>
                    </td>
                    <td className="py-2 sm:py-3 px-2 sm:px-4 text-right font-medium text-gray-900 text-sm sm:text-base">
                      {contributor.contribution_count.toLocaleString()}
                    </td>
                    <td className="py-2 sm:py-3 px-2 sm:px-4 text-right text-gray-600 hidden md:table-cell">
                      {contributor.trust_score.toFixed(1)}x
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>

        {currentUserRank && (
          <div className="mt-4 p-4 bg-primary-50 rounded-lg border border-primary-200">
            <p className="text-sm text-gray-700">
              You're currently ranked <strong>#{currentUserRank}</strong>.
              Keep contributing to climb the leaderboard!
            </p>
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row justify-center gap-3 sm:gap-4">
        <Link href="/contribute" className="btn btn-primary text-center">
          Start Contributing
        </Link>
        <Link href="/my-contributions" className="btn btn-ghost text-center">
          View My Contributions
        </Link>
      </div>
    </div>
  )
}
