'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { agreeWithTranslation } from '@/app/contribute/actions'
import { uploadAudio } from '@/lib/uploadAudio'
import { createClientComponentClient } from '@/lib/supabase-client'
import type { Word, Contribution, ContributionFormData, ContributionWithProfile, ContributionGroup, CommentWithProfile } from '@/lib/types'
import ConsensusBar from './ConsensusBar'
import AudioRecorder from './AudioRecorder'
import CommentSection from './CommentSection'

interface AdditionalVerse {
  ref: string
  motu: string
  english: string
}

interface WordCardProps {
  word: Word
  userContribution?: Contribution
  allContributions: ContributionWithProfile[]
  comments?: CommentWithProfile[]
  currentUserId?: string
  onSubmit: (data: ContributionFormData) => Promise<void>
  onSkip?: () => void
  onComplete?: () => Promise<void>
}

export default function WordCard({ word, userContribution, allContributions, comments, currentUserId, onSubmit, onSkip, onComplete }: WordCardProps) {
  const router = useRouter()
  const [englishGloss, setEnglishGloss] = useState(userContribution?.english_gloss || '')
  const [audioUrl, setAudioUrl] = useState<string | null>(userContribution?.audio_url || null)
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null)
  const [confidence, setConfidence] = useState(userContribution?.confidence || '')
  const [notes, setNotes] = useState(userContribution?.notes || '')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [additionalVerses, setAdditionalVerses] = useState<AdditionalVerse[]>([])
  const [loadingVerse, setLoadingVerse] = useState(false)
  const [completingWord, setCompletingWord] = useState(false)

  // Reset form when word changes
  useEffect(() => {
    setEnglishGloss(userContribution?.english_gloss || '')
    setAudioUrl(userContribution?.audio_url || null)
    setAudioBlob(null)
    setConfidence(userContribution?.confidence || '')
    setNotes(userContribution?.notes || '')
    setError('')
    setAdditionalVerses([]) // Clear additional verses when word changes
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
      // Separate full contributions from agreements
      const fullContribs = contribs.filter(c => c.agreement_type === 'full')
      const agreeContribs = contribs.filter(c => c.agreement_type === 'agree')

      // Calculate weighted count with agreement multiplier
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
        const agreementMultiplier = c.agreement_type === 'full' ? 1.0 : 0.5

        return sum + (typeWeight * trustWeight * agreementMultiplier)
      }, 0)

      // Check if current user agreed with this gloss
      const userAgreed = userContribution?.english_gloss === gloss

      contributionGroups.push({
        gloss,
        count: contribs.length,
        full_count: fullContribs.length,
        agree_count: agreeContribs.length,
        weighted_count: weightedCount,
        contributors: contribs.map(c => ({
          connection_type: c.profile?.connection_type || 'other',
          trust_score: c.profile?.trust_score || 1.0,
          agreement_type: c.agreement_type,
        })),
        audio_urls: contribs
          .filter(c => c.audio_url)
          .map(c => ({ url: c.audio_url!, user_id: c.user_id })),
        user_agreed: userAgreed,
      })
    })
  }

  const handleAgree = async (gloss: string) => {
    console.log('handleAgree clicked for:', gloss)
    console.log('Current userContribution:', userContribution)

    setLoading(true)
    setError('')

    try {
      const result = await agreeWithTranslation(word.id, gloss)
      console.log('agreeWithTranslation result:', result)

      // Wait a moment for the database to fully commit
      await new Promise(resolve => setTimeout(resolve, 100))

      // Force a complete page reload - no cache
      window.location.replace(`/contribute?word=${word.id}&_=${Date.now()}`)
    } catch (error: any) {
      console.error('Agreement error:', error)
      setError(error.message || 'Failed to agree with translation')
      setLoading(false)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    // Helper function to upload audio if there's a new recording
    const getUploadedAudioUrl = async (): Promise<string | undefined> => {
      // If no new audio blob, return existing URL (if it's already an R2 URL) or undefined
      if (!audioBlob) {
        // If audioUrl is a blob URL, don't use it
        if (audioUrl?.startsWith('blob:')) {
          return undefined
        }
        return audioUrl || undefined
      }

      // Upload new audio to R2
      const supabase = createClientComponentClient()
      const { data: { session } } = await supabase.auth.getSession()

      if (!session?.access_token) {
        throw new Error('Not authenticated')
      }

      const uploadedUrl = await uploadAudio(
        audioBlob,
        word.id,
        session.user.id,
        session.access_token
      )

      return uploadedUrl
    }

    // If user has agreed, they're just adding audio to their agreement
    if (userContribution?.agreement_type === 'agree') {
      if (!audioUrl && !audioBlob) {
        setError('Please record audio pronunciation')
        return
      }

      setLoading(true)
      try {
        const uploadedAudioUrl = await getUploadedAudioUrl()

        await onSubmit({
          word_id: word.id,
          english_gloss: userContribution.english_gloss, // Keep their agreed translation
          audio_url: uploadedAudioUrl,
          confidence: userContribution.confidence,
        })
      } catch (err: any) {
        setError(err.message || 'Failed to save audio')
      } finally {
        setLoading(false)
      }
      return
    }

    // Normal contribution flow - require translation
    if (!englishGloss.trim()) {
      setError('Please provide an English translation')
      return
    }

    // Require confidence level selection
    if (!confidence) {
      setError('Please select a confidence level')
      return
    }

    setLoading(true)

    try {
      const uploadedAudioUrl = await getUploadedAudioUrl()

      await onSubmit({
        word_id: word.id,
        english_gloss: englishGloss.trim(),
        audio_url: uploadedAudioUrl,
        confidence,
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

  const handleLoadAnotherExample = async () => {
    setLoadingVerse(true)
    setError('')

    try {
      // Get all verse refs to exclude (current + already loaded)
      const excludeRefs = [
        word.example_reference,
        ...additionalVerses.map(v => v.ref)
      ].filter(Boolean)

      // Build query params
      const params = new URLSearchParams({
        word: word.motu_word,
      })

      // Add first exclude ref (the current example)
      if (excludeRefs.length > 0 && excludeRefs[0]) {
        params.append('exclude', excludeRefs[0])
      }

      const response = await fetch(`/api/bible/random-verse?${params}`)

      if (!response.ok) {
        if (response.status === 404) {
          setError('No more verses found with this word')
        } else {
          setError('Failed to load another example')
        }
        return
      }

      const verse: AdditionalVerse = await response.json()

      // Check if we already have this verse (shouldn't happen, but be safe)
      if (additionalVerses.some(v => v.ref === verse.ref)) {
        setError('No more unique verses available')
        return
      }

      setAdditionalVerses(prev => [...prev, verse])
    } catch (err: any) {
      console.error('Error loading verse:', err)
      setError('Failed to load another example')
    } finally {
      setLoadingVerse(false)
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="card">
        {/* Motu Word - Large and prominent */}
        <div className="text-center mb-6 sm:mb-8">
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold text-primary-900 mb-2 break-words">
            {word.motu_word}
          </h1>
          <p className="text-sm text-gray-500">
            Frequency: {word.frequency.toLocaleString()}
          </p>
        </div>

        {/* Example Verse */}
        {word.example_motu && (
          <div className="mb-8">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-3">
              <h3 className="text-sm font-medium text-gray-700">Example from Scripture</h3>
              <button
                type="button"
                onClick={handleLoadAnotherExample}
                disabled={loadingVerse}
                className="text-sm text-primary-600 hover:text-primary-700 font-medium disabled:text-gray-400 self-start sm:self-auto"
              >
                {loadingVerse ? 'Loading...' : '+ See another example'}
              </button>
            </div>

            <div className="grid md:grid-cols-2 gap-4 mb-4">
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

            {/* Additional verses */}
            {additionalVerses.map((verse, index) => (
              <div key={verse.ref} className="grid md:grid-cols-2 gap-4 mb-4">
                <div className="bg-primary-50 rounded-lg p-4">
                  <div className="text-xs font-medium text-primary-700 mb-2">
                    {verse.ref}
                  </div>
                  <p className="text-gray-800 italic">{verse.motu}</p>
                </div>
                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="text-xs font-medium text-gray-500 mb-2">
                    English Translation
                  </div>
                  <p className="text-gray-700">{verse.english}</p>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Show existing contributions */}
        {allContributions.length > 0 && (
          <div className="border-t pt-8 mb-8">
            <ConsensusBar
              contributions={contributionGroups}
              currentConsensus={word.consensus_gloss}
              wordId={word.id}
              onAgree={handleAgree}
              currentUserId={currentUserId}
            />
          </div>
        )}

        {/* Contribution Form */}
        <div className="border-t pt-6">
          {/* Show message if user has agreed */}
          {userContribution?.agreement_type === 'agree' && (
            <div className="mb-6">
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <div className="flex items-start gap-3">
                  <div className="text-green-600 text-2xl">✓</div>
                  <div className="flex-1">
                    <h3 className="font-medium text-green-900 mb-1">
                      You've agreed with "{userContribution.english_gloss}"
                    </h3>
                    <p className="text-sm text-green-700">
                      Your agreement is contributing to the consensus. You can still add an audio pronunciation below! Click the <strong>[✓ Agreed]</strong> button above to remove your agreement if you'd like to add your own translation instead.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
          {/* Translation input - Only show if NOT agreed */}
          {(!userContribution || userContribution.agreement_type === 'full') && (
          <>
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

            {/* AI Generated Suggestions - Right below translation input */}
            {word.suggested_translations.length > 0 && (
              <div className="mt-3">
                <label className="text-xs text-gray-600 font-medium">AI Generated Suggestions (click to use)</label>
                <div className="flex flex-wrap gap-2 mt-1">
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
          </div>
          </>
          )}

          {/* Audio Recording - Always visible */}
          <div>
            <label className="label">
              Audio Pronunciation{userContribution?.agreement_type === 'agree' ? '' : ' (optional)'}
            </label>
            <AudioRecorder
              key={word.id} // Force remount when word changes
              existingAudioUrl={userContribution?.audio_url}
              onRecordingComplete={(blob) => {
                // Store blob for upload on submit
                setAudioBlob(blob)
              }}
              onAudioUrlChange={(url) => setAudioUrl(url)}
            />
          </div>

          {/* Confidence level - Only show if NOT agreed */}
          {(!userContribution || userContribution.agreement_type === 'full') && (
          <div>
            <label className="label">
              Confidence Level<span className="text-red-500"> *</span>
            </label>
            <div className="flex flex-wrap gap-3 sm:gap-4">
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
          )}

          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          {/* Submit button for saving changes */}
          {userContribution?.agreement_type === 'agree' ? (
            // User has agreed - show button to add audio only
            audioUrl && (
              <button
                onClick={handleSubmit}
                type="button"
                className="btn btn-primary w-full text-lg py-3"
                disabled={loading}
              >
                {loading ? 'Saving...' : 'Save Audio'}
              </button>
            )
          ) : (
            // Normal contribution flow - show save button
            <div>
              <button
                type="submit"
                className="btn btn-primary w-full text-lg py-3"
                disabled={loading}
              >
                {loading ? 'Saving...' : userContribution ? 'Update Contribution' : 'Save Contribution'}
              </button>
              <p className="text-xs text-gray-500 text-center mt-2">
                After saving, you can add comments below before moving to the next word
              </p>
            </div>
          )}
        </form>
        </div>

        {/* Comments section */}
        {comments && (
          <div className="border-t mt-8 pt-8">
            <CommentSection
              wordId={word.id}
              comments={comments}
              userComment={comments.find(c => c.user_id === currentUserId)}
              currentUserId={currentUserId}
            />
          </div>
        )}

        {/* Action buttons at the bottom */}
        <div className="border-t mt-8 pt-6 flex flex-col sm:flex-row gap-3">
          {onSkip && (
            <button
              type="button"
              onClick={onSkip}
              className="btn btn-ghost flex-1 text-base sm:text-lg py-3 order-2 sm:order-1"
              disabled={loading || completingWord}
            >
              Skip
            </button>
          )}

          {onComplete && (
            <button
              type="button"
              onClick={async () => {
                setCompletingWord(true)
                try {
                  await onComplete()
                } catch (error: any) {
                  setError(error.message || 'Failed to mark as complete')
                } finally {
                  setCompletingWord(false)
                }
              }}
              className="btn btn-primary flex-1 text-base sm:text-lg py-3 order-1 sm:order-2"
              disabled={loading || completingWord}
            >
              {completingWord ? 'Moving...' : "I'm Done, Next Word"}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
