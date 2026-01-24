'use client'

import { useState, useRef, useEffect } from 'react'

interface AudioRecorderProps {
  onRecordingComplete: (blob: Blob) => void
  onAudioUrlChange: (url: string | null) => void
  existingAudioUrl?: string | null
}

type RecordingState = 'idle' | 'recording' | 'recorded' | 'uploading'

export default function AudioRecorder({ onRecordingComplete, onAudioUrlChange, existingAudioUrl }: AudioRecorderProps) {
  const [state, setState] = useState<RecordingState>(existingAudioUrl ? 'recorded' : 'idle')
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null)
  const [audioUrl, setAudioUrl] = useState<string | null>(existingAudioUrl || null)
  const [error, setError] = useState('')

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const chunksRef = useRef<Blob[]>([])

  // Update state when existingAudioUrl changes
  useEffect(() => {
    if (existingAudioUrl) {
      setAudioUrl(existingAudioUrl)
      setState('recorded')
    }
  }, [existingAudioUrl])

  const startRecording = async () => {
    try {
      setError('')
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })

      const mediaRecorder = new MediaRecorder(stream, {
        mimeType: 'audio/webm;codecs=opus'
      })

      chunksRef.current = []

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: 'audio/webm;codecs=opus' })
        const url = URL.createObjectURL(blob)

        setAudioBlob(blob)
        setAudioUrl(url)
        setState('recorded')

        onRecordingComplete(blob)
        onAudioUrlChange(url)

        // Stop all tracks
        stream.getTracks().forEach(track => track.stop())
      }

      mediaRecorderRef.current = mediaRecorder
      mediaRecorder.start()
      setState('recording')

    } catch (err: any) {
      console.error('Recording error:', err)
      setError('Failed to access microphone. Please check permissions.')
      setState('idle')
    }
  }

  const stopRecording = () => {
    if (mediaRecorderRef.current && state === 'recording') {
      mediaRecorderRef.current.stop()
    }
  }

  const reset = () => {
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl)
    }
    setAudioBlob(null)
    setAudioUrl(null)
    setState('idle')
    onAudioUrlChange(null)
  }

  return (
    <div className="border border-gray-300 rounded-lg p-3 sm:p-4">
      {state === 'idle' && (
        <div className="flex flex-col sm:flex-row sm:items-center gap-3">
          <button
            type="button"
            onClick={startRecording}
            className="flex items-center justify-center space-x-2 px-4 py-2 bg-red-500 text-white rounded-md hover:bg-red-600 transition"
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M7 4a3 3 0 016 0v4a3 3 0 11-6 0V4zm4 10.93A7.001 7.001 0 0017 8a1 1 0 10-2 0A5 5 0 015 8a1 1 0 00-2 0 7.001 7.001 0 006 6.93V17H6a1 1 0 100 2h8a1 1 0 100-2h-3v-2.07z" clipRule="evenodd" />
            </svg>
            <span>Record</span>
          </button>
          <p className="text-xs text-gray-500">
            Click Record to capture your pronunciation
          </p>
        </div>
      )}

      {state === 'recording' && (
        <div className="flex flex-col sm:flex-row sm:items-center gap-3">
          <button
            type="button"
            onClick={stopRecording}
            className="flex items-center justify-center space-x-2 px-4 py-2 bg-gray-800 text-white rounded-md hover:bg-gray-900 transition"
          >
            <div className="w-3 h-3 bg-white rounded-sm"></div>
            <span>Stop</span>
          </button>
          <div className="flex items-center space-x-2 text-red-600">
            <div className="w-2 h-2 bg-red-600 rounded-full animate-pulse"></div>
            <span className="text-sm font-medium">Recording...</span>
          </div>
        </div>
      )}

      {state === 'recorded' && audioUrl && (
        <div className="space-y-3">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="flex items-center space-x-2 bg-green-50 px-2 sm:px-3 py-1.5 sm:py-2 rounded-md">
              <svg className="w-4 h-4 text-green-600 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span className="text-xs sm:text-sm font-medium text-green-700">Recorded</span>
            </div>
          </div>

          <audio src={audioUrl} controls className="w-full h-10" />

          <div className="flex gap-2">
            <button
              type="button"
              onClick={reset}
              className="flex-1 sm:flex-none px-3 py-2 text-sm bg-red-50 text-red-600 hover:bg-red-100 rounded-md transition"
            >
              Re-record
            </button>
            <button
              type="button"
              onClick={reset}
              className="flex-1 sm:flex-none px-3 py-2 text-sm text-gray-600 hover:text-gray-800 hover:bg-gray-100 rounded-md transition"
            >
              Delete
            </button>
          </div>
        </div>
      )}

      {error && (
        <div className="mt-2 text-sm text-red-600">
          {error}
        </div>
      )}
    </div>
  )
}
