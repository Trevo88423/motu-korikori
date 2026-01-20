'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClientComponentClient } from '@/lib/supabase-client'

export const dynamic = 'force-dynamic'

export default function LoginPage() {
  const router = useRouter()
  const supabase = createClientComponentClient()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const { data, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (authError) throw authError

      if (data.user) {
        // Check user status
        const { data: profile } = await supabase
          .from('profiles')
          .select('status')
          .eq('id', data.user.id)
          .single()

        if (profile?.status === 'banned') {
          await supabase.auth.signOut()
          throw new Error('Your account has been suspended. Please contact support.')
        }

        // Successful login
        router.push('/contribute')
      }
    } catch (error: any) {
      console.error('Login error:', error)
      setError(error.message || 'Invalid email or password')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-md mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="card">
        <h1 className="text-3xl font-bold text-center mb-2">Welcome Back</h1>
        <p className="text-gray-600 text-center mb-8">
          Log in to continue contributing to the True Motu dictionary
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="label">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="input"
              required
              autoComplete="email"
            />
          </div>

          <div>
            <label className="label">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="input"
              required
              autoComplete="current-password"
            />
          </div>

          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          <button
            type="submit"
            className="btn btn-primary w-full"
            disabled={loading}
          >
            {loading ? 'Logging in...' : 'Log In'}
          </button>
        </form>

        <div className="mt-6 text-center space-y-2">
          <div className="text-sm text-gray-600">
            Don't have an account?{' '}
            <a href="/signup" className="text-primary-600 hover:underline">
              Sign up
            </a>
          </div>
          <div className="text-sm">
            <a href="#" className="text-gray-500 hover:text-primary-600">
              Forgot password?
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}
