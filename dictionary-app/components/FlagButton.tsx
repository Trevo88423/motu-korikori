'use client'

import { useState } from 'react'
import { flagContent } from '@/app/contribute/flag-actions'
import { FLAG_REASONS, type FlagKind, type FlagReason } from '@/lib/flags'

interface FlagButtonProps {
  kind: FlagKind
  targetId: string
}

// A small 🚩 Flag control with a reason picker. Callers don't render it on the
// member's own items; the database refuses those anyway.
export default function FlagButton({ kind, targetId }: FlagButtonProps) {
  const [open, setOpen] = useState(false)
  const [reason, setReason] = useState<FlagReason | null>(null)
  const [sending, setSending] = useState(false)
  const [done, setDone] = useState<null | 'thanks' | 'already'>(null)
  const [error, setError] = useState('')

  if (done) {
    return (
      <p className="text-xs text-gray-600" role="status">
        {done === 'thanks'
          ? 'Thanks, the community will review it.'
          : 'You have already flagged this. Thanks, the community will review it.'}
      </p>
    )
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="text-xs text-gray-500 hover:text-red-600 transition py-1"
      >
        🚩 Flag
      </button>
    )
  }

  const handleSend = async () => {
    if (!reason) return
    setSending(true)
    setError('')
    try {
      const { alreadyFlagged } = await flagContent(kind, targetId, reason)
      setDone(alreadyFlagged ? 'already' : 'thanks')
    } catch (err: any) {
      setError(err.message || 'Could not send the flag')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="mt-2 w-full p-3 bg-white border border-gray-300 rounded-lg text-sm">
      <p className="font-medium text-gray-900 mb-1">What's wrong with it?</p>
      {kind === 'contribution' && (
        <p className="text-xs text-gray-600 mb-2">
          Flags are for abuse and junk. If you'd just say it differently, don't flag it: add your
          own translation or agree with another. Families and villages can say things differently.
        </p>
      )}
      <fieldset className="space-y-1">
        <legend className="sr-only">Reason</legend>
        {FLAG_REASONS[kind].map((r) => (
          <label key={r.value} className="flex items-center gap-2 py-1.5 cursor-pointer">
            <input
              type="radio"
              name={`flag-${targetId}`}
              value={r.value}
              checked={reason === r.value}
              onChange={() => setReason(r.value)}
              className="w-4 h-4"
            />
            <span>{r.label}</span>
          </label>
        ))}
      </fieldset>
      {error && <p className="text-xs text-red-600 mt-2">{error}</p>}
      <div className="flex gap-2 mt-3">
        <button
          type="button"
          onClick={handleSend}
          disabled={!reason || sending}
          className="btn btn-primary text-sm"
        >
          {sending ? 'Sending...' : 'Send flag'}
        </button>
        <button
          type="button"
          onClick={() => {
            setOpen(false)
            setReason(null)
            setError('')
          }}
          className="btn btn-ghost text-sm"
        >
          Cancel
        </button>
      </div>
    </div>
  )
}
