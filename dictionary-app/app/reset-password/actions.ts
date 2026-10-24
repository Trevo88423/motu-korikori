'use server'

import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { RECOVERY_COOKIE, recoveryCookieOptions } from '@/lib/recovery-marker'
import { hasRecoverySession } from './recovery'

export async function updatePassword(password: string): Promise<{ error?: string }> {
  if (typeof password !== 'string' || password.length < 8) {
    return { error: 'Password must be at least 8 characters' }
  }

  const { supabase, ok } = await hasRecoverySession()
  if (!ok) {
    return {
      error: 'This reset link has expired. Request a new one from the Forgot Password page.',
    }
  }

  const { error } = await supabase.auth.updateUser({ password })
  if (error) return { error: error.message || 'Failed to reset password. Please try again.' }

  // One use per recovery link.
  ;(await cookies()).set(RECOVERY_COOKIE, '', { ...recoveryCookieOptions, maxAge: 0 })

  // Redirect from here rather than the client: clearing the cookie re-renders
  // /reset-password, which (correctly) no longer lets this session in.
  redirect('/login?message=password_updated')
}
