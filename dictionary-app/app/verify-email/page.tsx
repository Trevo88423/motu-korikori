'use client'

import { useState, useMemo, useEffect, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { createClientComponentClient } from '@/lib/supabase-client'

function VerifyEmailContent() {
  const searchParams = useSearchParams()
  const email = searchParams.get('email') || ''

  const supabase = useMemo(() => createClientComponentClient(), [])
  const [loading, setLoading] = useState(false)
  const [resendSuccess, setResendSuccess] = useState(false)
  const [error, setError] = useState('')
  const [cooldown, setCooldown] = useState(0)

  // Cooldown timer for resend button
  useEffect(() => {
    if (cooldown > 0) {
      const timer = setTimeout(() => setCooldown(cooldown - 1), 1000)
      return () => clearTimeout(timer)
    }
  }, [cooldown])

  const handleResend = async () => {
    if (cooldown > 0 || !email) return

    setError('')
    setResendSuccess(false)
    setLoading(true)

    try {
      const { error } = await supabase.auth.resend({
        type: 'signup',
        email: email,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback?type=signup`,
        },
      })

      if (error) throw error

      setResendSuccess(true)
      setCooldown(60) // 60 second cooldown
    } catch (error: any) {
      setError(error.message || 'Failed to resend verification email.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-md mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="card text-center">
        <div className="mb-4">
          <svg
            className="mx-auto h-16 w-16 text-primary-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
            />
          </svg>
        </div>

        <h1 className="text-2xl font-bold mb-2">Verify Your Email</h1>

        <p className="text-gray-600 mb-4">
          We've sent a verification email to:
        </p>

        {email && (
          <p className="font-semibold text-lg mb-6">{email}</p>
        )}

        <div className="bg-gray-50 rounded-lg p-4 mb-6 text-left">
          <h3 className="font-semibold mb-2">Next steps:</h3>
          <ol className="list-decimal list-inside text-sm text-gray-600 space-y-2">
            <li>Check your email inbox</li>
            <li>Click the verification link in the email</li>
            <li>You'll be redirected to start contributing!</li>
          </ol>
        </div>

        <p className="text-sm text-gray-500 mb-6">
          Can't find the email? Check your spam folder or request a new one below.
        </p>

        {resendSuccess && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-md">
            <p className="text-sm text-green-600">
              Verification email sent! Check your inbox.
            </p>
          </div>
        )}

        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md">
            <p className="text-sm text-red-600">{error}</p>
          </div>
        )}

        <div className="space-y-3">
          {email && (
            <button
              onClick={handleResend}
              disabled={loading || cooldown > 0}
              className="btn btn-secondary w-full"
            >
              {loading
                ? 'Sending...'
                : cooldown > 0
                ? `Resend in ${cooldown}s`
                : 'Resend Verification Email'}
            </button>
          )}

          <Link href="/login" className="btn btn-ghost w-full block">
            Back to Login
          </Link>
        </div>
      </div>
    </div>
  )
}

export default function VerifyEmailPage() {
  return (
    <Suspense fallback={
      <div className="max-w-md mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="card text-center">
          <p>Loading...</p>
        </div>
      </div>
    }>
      <VerifyEmailContent />
    </Suspense>
  )
}
