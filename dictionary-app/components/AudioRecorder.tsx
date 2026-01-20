'use client'

import { useState, useRef } from 'react'

interface AudioRecorderProps {
  onRecordingComplete: (blob: Blob) => void
  onAudioUrlChange: (url: string | null) => void
}

type RecordingState = 'idle' | 'recording' | 'recorded' | 'uploading'

export default function AudioRecorder({ onRecordingComplete, onAudioUrlChange }: AudioRecorderProps) {
  const [state, setState] = useState<RecordingState>('idle')
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [error, setError] = useState('')

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const chunksRef = useRef<Blob[]>([])

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
    <div className="border border-gray-300 rounded-lg p-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-3">
          {state === 'idle' && (
            <button
              type="button"
              onClick={startRecording}
              className="flex items-center space-x-2 px-4 py-2 bg-red-500 text-white rounded-md hover:bg-red-600 transition"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M7 4a3 3 0 016 0v4a3 3 0 11-6 0V4zm4 10.93A7.001 7.001 0 0017 8a1 1 0 10-2 0A5 5 0 015 8a1 1 0 00-2 0 7.001 7.001 0 006 6.93V17H6a1 1 0 100 2h8a1 1 0 100-2h-3v-2.07z" clipRule="evenodd" />
              </svg>
              <span>Record</span>
            </button>
          )}

          {state === 'recording' && (
            <>
              <button
                type="button"
                onClick={stopRecording}
                className="flex items-center space-x-2 px-4 py-2 bg-gray-800 text-white rounded-md hover:bg-gray-900 transition"
              >
                <div className="w-3 h-3 bg-white rounded-sm"></div>
                <span>Stop</span>
              </button>
              <div className="flex items-center space-x-2 text-red-600">
                <div className="w-2 h-2 bg-red-600 rounded-full animate-pulse"></div>
                <span className="text-sm font-medium">Recording...</span>
              </div>
            </>
          )}

          {state === 'recorded' && audioUrl && (
            <>
              <audio src={audioUrl} controls className="h-10" />
              <button
                type="button"
                onClick={reset}
                className="px-3 py-2 text-sm text-red-600 hover:text-red-700 transition"
              >
                Re-record
              </button>
            </>
          )}
        </div>
      </div>

      {error && (
        <div className="mt-2 text-sm text-red-600">
          {error}
        </div>
      )}

      {state === 'idle' && (
        <p className="mt-2 text-xs text-gray-500">
          Click Record to capture your pronunciation of this word
        </p>
      )}
    </div>
  )
}
