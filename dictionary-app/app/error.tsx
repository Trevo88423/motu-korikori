'use client'

import { useEffect } from 'react'
import Link from 'next/link'

// Shown instead of Next's bare "Application error" screen when a page or
// server action throws (e.g. the database is unreachable).
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="max-w-md mx-auto px-4 sm:px-6 lg:px-8 py-16">
      <div className="card text-center">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-2">Something went wrong</h1>
        <p className="text-gray-600 mb-8">
          This page couldn&apos;t load just now. Please try again in a moment.
        </p>
        <div className="flex flex-col sm:flex-row justify-center gap-3">
          <button type="button" onClick={reset} className="btn btn-primary">
            Try Again
          </button>
          <Link href="/" className="btn btn-ghost">
            Go Home
          </Link>
        </div>
        {error.digest && (
          <p className="text-xs text-gray-400 mt-6">Reference: {error.digest}</p>
        )}
      </div>
    </div>
  )
}
