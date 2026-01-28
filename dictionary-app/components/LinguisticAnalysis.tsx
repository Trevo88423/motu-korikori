'use client'

import { useState } from 'react'

interface LinguisticAnalysisProps {
  morphology: string | null
  patterns: string | null
  notes: string | null
}

export default function LinguisticAnalysis({ morphology, patterns, notes }: LinguisticAnalysisProps) {
  const [isOpen, setIsOpen] = useState(false)

  // Don't render if no data
  if (!morphology && !patterns && !notes) {
    return null
  }

  return (
    <div className="mb-8">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center justify-between p-4 bg-purple-50 border border-purple-200 rounded-lg hover:bg-purple-100 transition-colors"
      >
        <div className="flex items-center gap-2">
          <svg
            className="w-5 h-5 text-purple-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
            />
          </svg>
          <span className="font-medium text-purple-900">Linguistic Analysis</span>
          <span className="text-xs text-purple-600 bg-purple-100 px-2 py-0.5 rounded">AI Generated</span>
        </div>
        <svg
          className={`w-5 h-5 text-purple-600 transition-transform ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div className="mt-2 p-4 bg-purple-50 border border-purple-200 border-t-0 rounded-b-lg space-y-4">
          {morphology && (
            <div>
              <h4 className="text-sm font-medium text-purple-800 mb-1">Morphology</h4>
              <p className="text-sm text-gray-700 bg-white p-3 rounded border border-purple-100">
                {morphology}
              </p>
            </div>
          )}

          {patterns && (
            <div>
              <h4 className="text-sm font-medium text-purple-800 mb-1">Usage Patterns</h4>
              <p className="text-sm text-gray-700 bg-white p-3 rounded border border-purple-100">
                {patterns}
              </p>
            </div>
          )}

          {notes && (
            <div>
              <h4 className="text-sm font-medium text-purple-800 mb-1">Notes</h4>
              <p className="text-sm text-gray-700 bg-white p-3 rounded border border-purple-100">
                {notes}
              </p>
            </div>
          )}

          <p className="text-xs text-purple-600 italic">
            This analysis was automatically generated from statistical patterns in parallel Bible texts.
          </p>
        </div>
      )}
    </div>
  )
}
