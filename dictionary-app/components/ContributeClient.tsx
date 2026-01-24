'use client'

import { useRouter } from 'next/navigation'
import WordCard from './WordCard'
import type { Word, Contribution, ContributionFormData, ContributionWithProfile, CommentWithProfile } from '@/lib/types'

interface ContributeClientProps {
  word: Word
  userContribution?: Contribution
  allContributions: ContributionWithProfile[]
  comments: CommentWithProfile[]
  currentUserId: string
  onSubmit: (data: ContributionFormData) => Promise<void>
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
    // Just refresh to get the next word
    router.push('/contribute')
    router.refresh()
  }

  const handleSubmit = async (data: ContributionFormData) => {
    await onSubmit(data)
    // Stay on the same word after saving - let user add comments
    // They can use the bottom buttons to navigate when ready
    router.push(`/contribute?word=${word.id}`)
    router.refresh()
  }

  const handleComplete = async () => {
    await onComplete(word.id)
    // Navigate to next word after marking complete
    router.push('/contribute')
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
