'use client'

import { useState } from 'react'
import { suggestBlockedTerm } from './actions'

// Shown to native and heritage speakers (#54): suggest a word the
// bad-language filter should block. An admin approves it.
export default function SuggestBlockedTermForm() {
  const [term, setTerm] = useState('')
  const [language, setLanguage] = useState('meu')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setMessage('')
    setSaving(true)

    const result = await suggestBlockedTerm(term, language)

    setSaving(false)
    if (result.error) {
      setError(result.error)
      return
    }
    setTerm('')
    setMessage(result.message ?? 'Thank you.')
  }

  return (
    <form onSubmit={handleSubmit} className="card mb-8">
      <label htmlFor="blocked-term-suggestion" className="label">
        Suggest a word to block
      </label>
      <p id="blocked-term-help" className="text-sm text-gray-600 mb-2">
        A rude or abusive word that shouldn&apos;t appear on True Motu. An admin will check it.
      </p>
      <div className="flex flex-col sm:flex-row gap-2">
        <input
          id="blocked-term-suggestion"
          type="text"
          className="input sm:flex-1"
          value={term}
          onChange={(e) => setTerm(e.target.value)}
          maxLength={60}
          autoComplete="off"
          aria-describedby="blocked-term-help"
          aria-invalid={!!error}
        />
        <label htmlFor="blocked-term-language" className="sr-only">Language</label>
        <select
          id="blocked-term-language"
          className="input sm:w-36"
          value={language}
          onChange={(e) => setLanguage(e.target.value)}
        >
          <option value="meu">Motu</option>
          <option value="tpi">Tok Pisin</option>
          <option value="en">English</option>
        </select>
        <button type="submit" className="btn btn-primary" disabled={saving || term.trim().length < 2}>
          {saving ? 'Sending...' : 'Suggest'}
        </button>
      </div>
      {error && <p className="text-sm text-red-600 mt-2">{error}</p>}
      {message && <p className="text-sm text-green-600 mt-2" role="status">{message}</p>}
    </form>
  )
}
