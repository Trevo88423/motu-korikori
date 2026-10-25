'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { setWordType } from '@/app/admin/actions'
import type { WordType } from '@/lib/types'

interface Props {
  wordId: string
  wordType: WordType
}

// Admin only: corrects the name / vocabulary tag set from the Bible text (#75).
// The server action checks the caller is an admin and logs the change.
export default function WordTypeButton({ wordId, wordType }: Props) {
  const router = useRouter()
  const [isPending, startTransition] = useTransition()
  const [error, setError] = useState<string | null>(null)

  const next: WordType = wordType === 'name' ? 'vocabulary' : 'name'

  return (
    <div className="flex flex-col items-center gap-1">
      <button
        type="button"
        className="btn btn-ghost text-sm"
        disabled={isPending}
        onClick={() => {
          setError(null)
          startTransition(async () => {
            const result = await setWordType(wordId, next)
            if (result.ok) router.refresh()
            else setError(result.error)
          })
        }}
      >
        {isPending ? 'Saving…' : next === 'name' ? 'Mark as name / place' : 'Mark as vocabulary'}
      </button>
      {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
    </div>
  )
}
