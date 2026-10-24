'use client'

import { useState, useTransition } from 'react'
import { makeAdmin, removeAdmin, type AdminRoleResult } from './actions'

interface Props {
  mode: 'grant' | 'revoke'
  userId: string
  displayName: string
  isSelf?: boolean
  // Grant only: already an admin, so there's nothing to do
  isAdmin?: boolean
}

// Make admin / Remove admin, with a confirm step that names the person and
// says what the role means. The server action and the database do the checks.
export default function AdminRoleButton({ mode, userId, displayName, isSelf = false, isAdmin = false }: Props) {
  const [confirming, setConfirming] = useState(false)
  const [isPending, startTransition] = useTransition()
  const [result, setResult] = useState<AdminRoleResult | null>(null)

  const question =
    mode === 'grant'
      ? `Make ${displayName} an admin? They'll be able to ban members and appoint other admins.`
      : isSelf
        ? 'Remove yourself as an admin? You will lose access to this page straight away.'
        : `Remove ${displayName} as an admin? They'll lose access to this page straight away.`

  const label = mode === 'grant' ? 'Make admin' : isSelf ? 'Step down' : 'Remove admin'

  // Rendered in the same place before and after the page refreshes, so the
  // outcome (including whether the email went) stays on screen
  if (result?.ok) {
    return <p role="status" className="text-sm text-gray-700">{result.message}</p>
  }
  if (mode === 'grant' && isAdmin) {
    return <p className="text-sm text-gray-500">Already an admin</p>
  }

  return (
    <div className="space-y-2">
      {confirming ? (
        <div className="p-3 bg-white border border-gray-300 rounded-lg space-y-3">
          <p className="text-sm text-gray-900">{question}</p>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              className={`btn text-sm ${mode === 'grant' ? 'btn-primary' : 'btn-ghost text-red-600'}`}
              disabled={isPending}
              onClick={() => {
                setResult(null)
                startTransition(async () => {
                  const next = await (mode === 'grant' ? makeAdmin(userId) : removeAdmin(userId))
                  setResult(next)
                  if (!next.ok) setConfirming(false)
                })
              }}
            >
              {isPending ? 'Saving…' : mode === 'grant' ? 'Yes, make admin' : 'Yes, remove'}
            </button>
            <button
              type="button"
              className="btn btn-ghost text-sm"
              disabled={isPending}
              onClick={() => setConfirming(false)}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <button
          type="button"
          className={`btn text-sm ${mode === 'grant' ? 'btn-primary' : 'btn-ghost text-red-600'}`}
          onClick={() => {
            setResult(null)
            setConfirming(true)
          }}
        >
          {label}
        </button>
      )}

      {result && !result.ok && (
        <p role="alert" className="text-sm text-red-600">{result.error}</p>
      )}
    </div>
  )
}
