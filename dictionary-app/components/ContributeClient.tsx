'use client'

import { useRouter } from 'next/navigation'
import WordCard from './WordCard'
import type { Word, Contribution, ContributionFormData, ContributionWithProfile, CommentWithProfile } from '@/lib/types'
import type { ContributionResult } from '@/app/contribute/actions'

const SKIPPED_KEY = 'truemotu:skipped-words'
const MAX_SKIPPED = 50

// Words skipped this session, most recent first. Session storage can be
// unavailable (private mode, blocked storage); then there's just no list.
function readSkipped(): string[] {
  try {
    const ids: unknown = JSON.parse(sessionStorage.getItem(SKIPPED_KEY) || '[]')
    return Array.isArray(ids) ? ids.filter((id): id is string => typeof id === 'string') : []
  } catch {
    return []
  }
}

function writeSkipped(ids: string[]) {
  try {
    sessionStorage.setItem(SKIPPED_KEY, JSON.stringify(ids))
  } catch {
    // ignore
  }
}

// /contribute URL asking for a word other than the recently skipped ones
function nextWordUrl(skipped: string[]) {
  return skipped.length > 0 ? `/contribute?skip=${skipped.join(',')}` : '/contribute'
}

interface ContributeClientProps {
  word: Word
  userContribution?: Contribution
  allContributions: ContributionWithProfile[]
  comments: CommentWithProfile[]
  currentUserId: string
  onSubmit: (data: ContributionFormData) => Promise<ContributionResult>
  onComplete: (wordId: string) => Promise<void>
}

export default function ContributeClient({
  word,
  userContribution,
  allContributions,
  comments,
  currentUserId,
  onSubmit,
  onComplete
}: ContributeClientProps) {
  const router = useRouter()

  const handleSkip = () => {
    // Remember this word so the next pick leaves it out
    const skipped = [word.id, ...readSkipped().filter((id) => id !== word.id)].slice(0, MAX_SKIPPED)
    writeSkipped(skipped)
    router.push(nextWordUrl(skipped))
    router.refresh()
  }

  const handleSubmit = async (data: ContributionFormData) => {
    const result = await onSubmit(data)
    if (result.error) return result
    // Stay on the same word after saving - let user add comments
    // They can use the bottom buttons to navigate when ready
    router.push(`/contribute?word=${word.id}`)
    router.refresh()
    return result
  }

  const handleComplete = async () => {
    await onComplete(word.id)
    // Navigate to next word after marking complete
    router.push(nextWordUrl(readSkipped()))
    router.refresh()
  }

  return (
    <WordCard
      word={word}
      userContribution={userContribution}
      allContributions={allContributions}
      comments={comments}
      currentUserId={currentUserId}
      onSubmit={handleSubmit}
      onSkip={handleSkip}
      onComplete={handleComplete}
    />
  )
}
