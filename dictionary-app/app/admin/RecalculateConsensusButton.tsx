'use client'

import { useState, useTransition } from 'react'
import { recalculateConsensusForAllWords, type RecalculateConsensusResult } from './actions'

export default function RecalculateConsensusButton() {
  const [isPending, startTransition] = useTransition()
  const [result, setResult] = useState<RecalculateConsensusResult | null>(null)

  return (
    <div className="space-y-3">
      <button
        type="button"
        className="btn btn-primary text-sm"
        disabled={isPending}
        onClick={() => {
          setResult(null)
          startTransition(async () => {
            setResult(await recalculateConsensusForAllWords())
          })
        }}
      >
        {isPending ? 'Recalculating…' : 'Recalculate consensus for all words'}
      </button>

      {result && (
        <p role="status" className={`text-sm ${result.ok ? 'text-gray-700' : 'text-red-600'}`}>
          {result.ok
            ? `Checked ${result.total.toLocaleString()} ${result.total === 1 ? 'word' : 'words'} with contributions: ${result.changed.toLocaleString()} changed${result.failed > 0 ? `, ${result.failed.toLocaleString()} failed (see server logs)` : ''}.`
            : result.error}
        </p>
      )}
    </div>
  )
}
