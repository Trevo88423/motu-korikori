import { redirect } from 'next/navigation'
import { createServerComponentClient, getCurrentUserProfile } from '@/lib/supabase'
import WordCard from '@/components/WordCard'
import { saveContribution } from './actions'
import type { Word, Contribution, ContributionWithProfile } from '@/lib/types'

export const dynamic = 'force-dynamic'

export default async function ContributePage() {
  const supabase = await createServerComponentClient()
  const profile = await getCurrentUserProfile()

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

  // Get next word for user using the database function
  const { data: words, error: wordsError } = await supabase
    .rpc('get_next_word_for_user', { user_uuid: profile.id })

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
            You've contributed to all {15610} words in the dictionary!
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

  // Check if user already contributed to this word
  const { data: userContribution } = await supabase
    .from('contributions')
    .select('*')
    .eq('word_id', word.id)
    .eq('user_id', profile.id)
    .single()

  // Get all contributions for this word (for consensus display)
  const { data: allContributions } = await supabase
    .from('contributions')
    .select(`
      *,
      profile:profiles(name, connection_type, trust_score)
    `)
    .eq('word_id', word.id)
    .order('created_at', { ascending: false })

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Progress indicator */}
      <div className="mb-6">
        <div className="flex justify-between text-sm text-gray-600 mb-2">
          <span>Your Progress</span>
          <span>
            {profile.contribution_count.toLocaleString()} / 15,610 words
          </span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-primary-600 h-2 rounded-full transition-all"
            style={{ width: `${(profile.contribution_count / 15610) * 100}%` }}
          />
        </div>
      </div>

      <WordCard
        word={word}
        userContribution={userContribution as Contribution}
        allContributions={(allContributions || []) as ContributionWithProfile[]}
        onSubmit={saveContribution}
      />
    </div>
  )
}
