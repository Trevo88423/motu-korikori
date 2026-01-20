'use client'

import type { ContributionGroup } from '@/lib/types'

interface ConsensusBarProps {
  contributions: ContributionGroup[]
  currentConsensus: string | null
}

export default function ConsensusBar({ contributions, currentConsensus }: ConsensusBarProps) {
  if (contributions.length === 0) {
    return (
      <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
        <p className="text-sm text-gray-600 text-center">
          No contributions yet. Be the first to contribute!
        </p>
      </div>
    )
  }

  // Calculate total weighted votes
  const totalWeightedVotes = contributions.reduce((sum, group) => sum + group.weighted_count, 0)

  // Sort by weighted count
  const sortedContributions = [...contributions].sort((a, b) => b.weighted_count - a.weighted_count)

  // Check if there's a clear consensus (>60% of weighted votes)
  const hasConsensus = sortedContributions[0]?.weighted_count / totalWeightedVotes > 0.6

  // Check if it's flagged (top 2 within 10%)
  const isFlagged = sortedContributions.length >= 2 &&
    Math.abs(sortedContributions[0].weighted_count - sortedContributions[1].weighted_count) / totalWeightedVotes < 0.1

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h4 className="font-medium text-gray-900">Community Translations</h4>
        {hasConsensus && (
          <span className="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded">
            Consensus Reached
          </span>
        )}
        {isFlagged && (
          <span className="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-700 rounded">
            Needs Review
          </span>
        )}
      </div>

      <div className="space-y-3">
        {sortedContributions.map((group, index) => {
          const percentage = (group.weighted_count / totalWeightedVotes) * 100
          const isConsensus = group.gloss === currentConsensus

          return (
            <div key={index} className="space-y-1">
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center space-x-2">
                  <span className={`font-medium ${isConsensus ? 'text-green-700' : 'text-gray-900'}`}>
                    {group.gloss}
                  </span>
                  {isConsensus && (
                    <svg className="w-4 h-4 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  )}
                </div>
                <div className="text-gray-500 text-xs space-x-2">
                  <span>{group.count} {group.count === 1 ? 'contributor' : 'contributors'}</span>
                  <span className="font-medium">{percentage.toFixed(1)}%</span>
                </div>
              </div>

              {/* Progress bar */}
              <div className="w-full bg-gray-200 rounded-full h-2 overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all ${
                    isConsensus ? 'bg-green-500' :
                    index === 0 ? 'bg-primary-500' :
                    index === 1 ? 'bg-secondary-400' :
                    'bg-gray-400'
                  }`}
                  style={{ width: `${percentage}%` }}
                />
              </div>

              {/* Contributors breakdown */}
              {group.contributors.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-1">
                  {(() => {
                    const nativeSpeakers = group.contributors.filter(c => c.connection_type === 'native_speaker').length
                    const heritageSpeakers = group.contributors.filter(c => c.connection_type === 'heritage_speaker').length
                    const secondLanguage = group.contributors.filter(c => c.connection_type === 'second_language').length
                    const others = group.contributors.length - nativeSpeakers - heritageSpeakers - secondLanguage

                    return (
                      <>
                        {nativeSpeakers > 0 && (
                          <span className="text-xs px-2 py-0.5 bg-primary-100 text-primary-700 rounded">
                            {nativeSpeakers} native
                          </span>
                        )}
                        {heritageSpeakers > 0 && (
                          <span className="text-xs px-2 py-0.5 bg-purple-100 text-purple-700 rounded">
                            {heritageSpeakers} heritage
                          </span>
                        )}
                        {secondLanguage > 0 && (
                          <span className="text-xs px-2 py-0.5 bg-blue-100 text-blue-700 rounded">
                            {secondLanguage} L2
                          </span>
                        )}
                        {others > 0 && (
                          <span className="text-xs px-2 py-0.5 bg-gray-100 text-gray-700 rounded">
                            {others} other
                          </span>
                        )}
                      </>
                    )
                  })()}
                </div>
              )}
            </div>
          )
        })}
      </div>

      <div className="text-xs text-gray-500 border-t pt-2 mt-2">
        Contributions are weighted by speaker type: Native speakers (2.0x), Heritage speakers (1.5x),
        Second language (1.0x), Learners (0.5x), Researchers (1.0x)
      </div>
    </div>
  )
}
