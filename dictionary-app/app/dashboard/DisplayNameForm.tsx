'use client'

import { useState } from 'react'
import { updateDisplayName } from './actions'

export default function DisplayNameForm({ initial }: { initial: string }) {
  const [value, setValue] = useState(initial)
  const [saved, setSaved] = useState(initial)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setMessage('')
    setSaving(true)

    const result = await updateDisplayName(value)

    setSaving(false)
    if (result.error) {
      setError(result.error)
      return
    }

    const name = result.displayName ?? value
    setValue(name)
    setSaved(name)
    setMessage(name === value.trim() ? 'Saved.' : `Saved as "${name}".`)
  }

  return (
    <form onSubmit={handleSubmit} className="card mb-8">
      <label htmlFor="display-name" className="label">
        Display Name
      </label>
      <p id="display-name-help" className="text-sm text-gray-600 mb-2">
        How you appear on the leaderboard. Your full name is never shown on the site.
      </p>
      <div className="flex flex-col sm:flex-row gap-2">
        <input
          id="display-name"
          type="text"
          className="input sm:flex-1"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          maxLength={40}
          autoComplete="nickname"
          aria-describedby="display-name-help"
          aria-invalid={!!error}
        />
        <button
          type="submit"
          className="btn btn-primary"
          disabled={saving || value.trim() === saved}
        >
          {saving ? 'Saving...' : 'Save'}
        </button>
      </div>
      {error && <p className="text-sm text-red-600 mt-2">{error}</p>}
      {message && <p className="text-sm text-green-600 mt-2" role="status">{message}</p>}
    </form>
  )
}
