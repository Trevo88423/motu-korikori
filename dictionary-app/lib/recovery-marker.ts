// Server-only. Marks a session as having just come through a password-recovery
// link, so /reset-password can't be used to change the password of whoever
// happens to be signed in (issue #15).
//
// Supabase's own `amr` claim can't do this: a recovery link and any other
// email-link sign-in both record `otp`, and the claim stays on the session
// after the password has been changed.
//
// The marker is an httpOnly cookie holding `<user id>.<session id>.<expiry>`
// plus an HMAC over it. It's only honoured for the same user *and* the same
// Supabase session that verified the recovery link, and only until it expires.

import { createHmac, timingSafeEqual } from 'crypto'

export const RECOVERY_COOKIE = 'tm_recovery'
export const RECOVERY_MAX_AGE_SECONDS = 15 * 60

// The service-role key is server-only and already required in production;
// keying the HMAC off it (with a fixed label) avoids a new secret to manage.
function sign(payload: string): string {
  const secret = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!secret) throw new Error('SUPABASE_SERVICE_ROLE_KEY is not set')
  const key = createHmac('sha256', secret).update('truemotu-recovery-marker-v1').digest()
  return createHmac('sha256', key).update(payload).digest('base64url')
}

export function createRecoveryMarker(userId: string, sessionId: string): string {
  const expires = Math.floor(Date.now() / 1000) + RECOVERY_MAX_AGE_SECONDS
  const payload = `${userId}.${sessionId}.${expires}`
  return `${payload}.${sign(payload)}`
}

export function isValidRecoveryMarker(
  marker: string | undefined,
  userId: string,
  sessionId: string
): boolean {
  if (!marker) return false

  const parts = marker.split('.')
  if (parts.length !== 4) return false
  const [markerUser, markerSession, expires, signature] = parts

  const expected = Buffer.from(sign(`${markerUser}.${markerSession}.${expires}`))
  const given = Buffer.from(signature)
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return false

  if (markerUser !== userId || markerSession !== sessionId) return false

  return Number(expires) > Math.floor(Date.now() / 1000)
}

export const recoveryCookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax' as const,
  // Only the reset page (and its server action, which posts to the same path)
  // ever needs to see it.
  path: '/reset-password',
  maxAge: RECOVERY_MAX_AGE_SECONDS,
}
