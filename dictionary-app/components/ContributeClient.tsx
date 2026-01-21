'use client'

import { useRouter } from 'next/navigation'
import WordCard from './WordCard'
import type { Word, Contribution, ContributionFormData, ContributionWithProfile } from '@/lib/types'

interface ContributeClientProps {
  word: Word
  userContribution?: Contribution
  allContributions: ContributionWithProfile[]
  onSubmit: (data: ContributionFormData) => Promise<void>
}

export default function ContributeClient({
  word,
  userContribution,
  allContributions,
  onSubmit
}: ContributeClientProps) {
  const router = useRouter()

  const handleSkip = () => {
    // Just refresh to get the next word
    router.push('/contribute')
    router.refresh()
  }

  const handleSubmit = async (data: ContributionFormData) => {
    await onSubmit(data)
    // Navigate to next word after successful submission
    router.push('/contribute')
    router.refresh()
  }

  return (
    <WordCard
      word={word}
      userContribution={userContribution}
      allContributions={allContributions}
      onSubmit={handleSubmit}
      onSkip={handleSkip}
    />
  )
}
