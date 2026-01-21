'use client'

import { useState, useEffect } from 'react'
import type { Word, Contribution, ContributionFormData, ContributionWithProfile, ContributionGroup } from '@/lib/types'
import ConsensusBar from './ConsensusBar'
import AudioRecorder from './AudioRecorder'

interface WordCardProps {
  word: Word
  userContribution?: Contribution
  allContributions: ContributionWithProfile[]
  onSubmit: (data: ContributionFormData) => Promise<void>
  onSkip?: () => void
}

export default function WordCard({ word, userContribution, allContributions, onSubmit, onSkip }: WordCardProps) {
  const [englishGloss, setEnglishGloss] = useState(userContribution?.english_gloss || '')
  const [audioUrl, setAudioUrl] = useState<string | null>(userContribution?.audio_url || null)
  const [confidence, setConfidence] = useState(userContribution?.confidence || 'certain')
  const [notes, setNotes] = useState(userContribution?.notes || '')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  // Reset form when word changes
  useEffect(() => {
    setEnglishGloss(userContribution?.english_gloss || '')
    setAudioUrl(userContribution?.audio_url || null)
    setConfidence(userContribution?.confidence || 'certain')
    setNotes(userContribution?.notes || '')
    setError('')
  }, [word.id, userContribution])

  // Group contributions for consensus display
  const contributionGroups: ContributionGroup[] = []

  if (allContributions.length > 0) {
    const grouped = new Map<string, ContributionWithProfile[]>()

    allContributions.forEach(contrib => {
      if (!contrib.is_excluded) {
        const existing = grouped.get(contrib.english_gloss) || []
        grouped.set(contrib.english_gloss, [...existing, contrib])
      }
    })

    grouped.forEach((contribs, gloss) => {
      const weightedCount = contribs.reduce((sum, c) => {
        const typeWeight = {
          native_speaker: 2.0,
          heritage_speaker: 1.5,
          second_language: 1.0,
          learning_now: 0.5,
          researcher: 1.0,
          other: 0.5,
        }[c.profile?.connection_type || 'other']

        const trustWeight = c.profile?.trust_score || 1.0

        return sum + (typeWeight * trustWeight)
      }, 0)

      contributionGroups.push({
        gloss,
        count: contribs.length,
        weighted_count: weightedCount,
        contributors: contribs.map(c => ({
          connection_type: c.profile?.connection_type || 'other',
          trust_score: c.profile?.trust_score || 1.0,
        })),
        audio_urls: contribs.map(c => c.audio_url).filter(Boolean) as string[],
      })
    })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!englishGloss.trim()) {
      setError('Please provide an English translation')
      return
    }

    setLoading(true)

    try {
      await onSubmit({
        word_id: word.id,
        english_gloss: englishGloss.trim(),
        audio_url: audioUrl || undefined,
        confidence,
        notes: notes.trim() || undefined,
      })

      // Success! The parent component will handle navigation
    } catch (err: any) {
      setError(err.message || 'Failed to save contribution')
    } finally {
      setLoading(false)
    }
  }

  const handleSuggestedClick = (suggestion: string) => {
    setEnglishGloss(suggestion)
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="card">
        {/* Motu Word - Large and prominent */}
        <div className="text-center mb-8">
          <h1 className="text-5xl font-bold text-primary-900 mb-2">
            {word.motu_word}
          </h1>
          <p className="text-sm text-gray-500">
            Frequency: {word.frequency.toLocaleString()}
          </p>
        </div>

        {/* Example Verse */}
        {word.example_motu && (
          <div className="mb-8 grid md:grid-cols-2 gap-4">
            <div className="bg-primary-50 rounded-lg p-4">
              <div className="text-xs font-medium text-primary-700 mb-2">
                {word.example_reference}
              </div>
              <p className="text-gray-800 italic">{word.example_motu}</p>
            </div>
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="text-xs font-medium text-gray-500 mb-2">
                English Translation
              </div>
              <p className="text-gray-700">{word.example_english}</p>
            </div>
          </div>
        )}

        {/* Suggested Translations */}
        {word.suggested_translations.length > 0 && (
          <div className="mb-6">
            <label className="label">Suggested translations (click to use)</label>
            <div className="flex flex-wrap gap-2">
              {word.suggested_translations.map((suggestion, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => handleSuggestedClick(suggestion)}
                  className="px-3 py-1 bg-secondary-100 text-secondary-700 rounded-full text-sm hover:bg-secondary-200 transition"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Contribution Form */}
        <form onSubmit={handleSubmit} className="space-y-6 border-t pt-6">
          <div>
            <label className="label">
              Your English Translation<span className="text-red-500"> *</span>
            </label>
            <input
              type="text"
              value={englishGloss}
              onChange={(e) => setEnglishGloss(e.target.value)}
              placeholder="e.g., house, dwelling, home"
              className="input text-lg"
              required
              disabled={loading}
            />
            <p className="text-xs text-gray-500 mt-1">
              Provide the most accurate English translation for this word
            </p>
          </div>

          <div>
            <label className="label">Audio Pronunciation (optional)</label>
            <AudioRecorder
              key={word.id} // Force remount when word changes
              onRecordingComplete={(blob) => {
                // Will be uploaded on submit
                console.log('Recording complete:', blob)
              }}
              onAudioUrlChange={(url) => setAudioUrl(url)}
            />
          </div>

          <div>
            <label className="label">
              Confidence Level<span className="text-red-500"> *</span>
            </label>
            <div className="flex space-x-4">
              {[
                { value: 'certain', label: 'Certain', color: 'green' },
                { value: 'somewhat_certain', label: 'Somewhat Certain', color: 'yellow' },
                { value: 'unsure', label: 'Unsure', color: 'gray' },
              ].map((option) => (
                <label key={option.value} className="flex items-center space-x-2 cursor-pointer">
                  <input
                    type="radio"
                    name="confidence"
                    value={option.value}
                    checked={confidence === option.value}
                    onChange={(e) => setConfidence(e.target.value as any)}
                    className={`h-4 w-4 text-${option.color}-600 focus:ring-${option.color}-500 border-gray-300`}
                    disabled={loading}
                  />
                  <span className="text-sm text-gray-700">{option.label}</span>
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="label">Additional Notes (optional)</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Any context, regional variations, or additional information..."
              rows={3}
              className="input"
              disabled={loading}
            />
          </div>

          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          <div className="flex gap-3">
            {onSkip && !userContribution && (
              <button
                type="button"
                onClick={onSkip}
                className="btn btn-ghost flex-1 text-lg py-3"
                disabled={loading}
              >
                Skip for Now
              </button>
            )}

            <button
              type="submit"
              className={`btn btn-primary text-lg py-3 ${onSkip && !userContribution ? 'flex-1' : 'w-full'}`}
              disabled={loading}
            >
              {loading ? 'Saving...' : userContribution ? 'Update & Next' : 'Save & Next'}
            </button>
          </div>
        </form>

        {/* Show existing contributions */}
        {allContributions.length > 0 && (
          <div className="border-t mt-8 pt-8">
            <ConsensusBar
              contributions={contributionGroups}
              currentConsensus={word.consensus_gloss}
            />
          </div>
        )}
      </div>
    </div>
  )
}
