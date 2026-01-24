'use client'

import { useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import SignupForm from '@/components/SignupForm'
import ConsentForm from '@/components/ConsentForm'
import { createClientComponentClient } from '@/lib/supabase-client'
import { createUserProfile } from './actions'
import type { SignupFormData, AgeRange, ConnectionType } from '@/lib/types'

export const dynamic = 'force-dynamic'

export default function SignupPage() {
  const router = useRouter()
  const supabase = useMemo(() => createClientComponentClient(), [])

  const [step, setStep] = useState(1)
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const [formData, setFormData] = useState({
    email: '',
    password: '',
    confirmPassword: '',
    name: '',
    age_range: '' as AgeRange | '',
    locations: [] as string[],
    connection_type: '' as ConnectionType | '',
    who_taught: '',
    consent_tos: false,
    consent_dictionary: false,
    consent_ai_training: false,
    is_18_or_older: false,
    guardian_name: '',
    guardian_email: '',
    guardian_consent: false,
  })

  const handleChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    // Clear error when user starts typing
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }))
    }
  }

  const validateStep1 = () => {
    const newErrors: Record<string, string> = {}

    if (!formData.email) {
      newErrors.email = 'Email is required'
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Invalid email address'
    }

    if (!formData.password) {
      newErrors.password = 'Password is required'
    } else if (formData.password.length < 8) {
      newErrors.password = 'Password must be at least 8 characters'
    }

    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match'
    }

    if (!formData.name) {
      newErrors.name = 'Name is required'
    }

    if (!formData.age_range) {
      newErrors.age_range = 'Age range is required'
    }

    if (!formData.connection_type) {
      newErrors.connection_type = 'Connection type is required'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const validateStep2 = () => {
    const newErrors: Record<string, string> = {}

    if (!formData.consent_tos) {
      newErrors.consent_tos = 'You must accept the Terms of Service'
    }

    if (!formData.consent_dictionary) {
      newErrors.consent_dictionary = 'You must consent to dictionary usage'
    }

    if (!formData.consent_ai_training) {
      newErrors.consent_ai_training = 'You must consent to AI training usage'
    }

    if (!formData.is_18_or_older && (!formData.guardian_name || !formData.guardian_email)) {
      newErrors.guardian = 'Guardian information is required for users under 18'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleNext = () => {
    if (step === 1 && validateStep1()) {
      setStep(2)
    }
  }

  const handleBack = () => {
    setStep(step - 1)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateStep2()) {
      return
    }

    setLoading(true)

    try {
      // 1. Sign up the user with email verification
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: formData.email,
        password: formData.password,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback?type=signup`,
        },
      })

      if (authError) throw authError

      if (!authData.user) {
        throw new Error('User creation failed')
      }

      // 2. Create profile with extended data using Server Action
      const profileResult = await createUserProfile({
        userId: authData.user.id,
        email: formData.email,
        name: formData.name,
        age_range: formData.age_range,
        locations: formData.locations,
        connection_type: formData.connection_type,
        who_taught: formData.who_taught || '',
        consent_tos: formData.consent_tos,
        consent_dictionary: formData.consent_dictionary,
        consent_ai_training: formData.consent_ai_training,
        is_18_or_older: formData.is_18_or_older,
        guardian_name: formData.guardian_name,
        guardian_email: formData.guardian_email,
        guardian_consent: formData.guardian_consent,
      })

      if (!profileResult.success) {
        throw new Error(profileResult.error || 'Failed to create profile')
      }

      // Success! Redirect to verify email page
      router.push(`/verify-email?email=${encodeURIComponent(formData.email)}`)

    } catch (error: any) {
      console.error('Signup error:', error)
      setErrors({
        submit: error.message || 'An error occurred during signup. Please try again.',
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="card">
        <h1 className="text-2xl sm:text-3xl font-bold text-center mb-2">Join the True Motu Dictionary</h1>
        <p className="text-sm sm:text-base text-gray-600 text-center mb-6 sm:mb-8">
          Help preserve Motu korikori for future generations
        </p>

        {/* Progress indicator */}
        <div className="flex items-center justify-center mb-8">
          <div className="flex items-center space-x-4">
            <div className={`flex items-center justify-center w-8 h-8 rounded-full ${
              step >= 1 ? 'bg-primary-600 text-white' : 'bg-gray-200 text-gray-500'
            }`}>
              1
            </div>
            <div className={`w-16 h-1 ${step >= 2 ? 'bg-primary-600' : 'bg-gray-200'}`}></div>
            <div className={`flex items-center justify-center w-8 h-8 rounded-full ${
              step >= 2 ? 'bg-primary-600 text-white' : 'bg-gray-200 text-gray-500'
            }`}>
              2
            </div>
          </div>
        </div>

        <form onSubmit={handleSubmit}>
          {step === 1 && (
            <>
              <SignupForm
                formData={formData}
                onChange={handleChange}
                errors={errors}
              />

              <div className="mt-6 sm:mt-8 flex justify-end">
                <button
                  type="button"
                  onClick={handleNext}
                  className="btn btn-primary w-full sm:w-auto"
                >
                  Next: Consent & Permissions
                </button>
              </div>
            </>
          )}

          {step === 2 && (
            <>
              <ConsentForm
                formData={formData}
                onChange={handleChange}
              />

              {errors.submit && (
                <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-md">
                  <p className="text-sm text-red-600">{errors.submit}</p>
                </div>
              )}

              {Object.keys(errors).some(key => key.startsWith('consent') || key === 'guardian') && (
                <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-md">
                  <p className="text-sm text-red-600">Please complete all required consents</p>
                </div>
              )}

              <div className="mt-6 sm:mt-8 flex flex-col-reverse sm:flex-row sm:justify-between gap-3">
                <button
                  type="button"
                  onClick={handleBack}
                  className="btn btn-ghost"
                  disabled={loading}
                >
                  Back
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={loading}
                >
                  {loading ? 'Creating Account...' : 'Create Account'}
                </button>
              </div>
            </>
          )}
        </form>

        <div className="mt-6 text-center text-sm text-gray-600">
          Already have an account?{' '}
          <a href="/login" className="text-primary-600 hover:underline">
            Log in
          </a>
        </div>
      </div>
    </div>
  )
}
