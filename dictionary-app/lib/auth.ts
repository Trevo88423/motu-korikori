// One access check for every protected page, layout and server action (#14).
// Server-only: import from Server Components, Server Actions and route handlers.

import { redirect } from 'next/navigation'
import type { SupabaseClient, User } from '@supabase/supabase-js'
import { createServerComponentClient } from './supabase'
import type { Profile, UserStatus } from './types'

export interface RequireActiveUserOptions {
  // Only admins get through; everyone else is sent home.
  requireAdmin?: boolean
  // Defaults to true. Signup already needs a confirmed email to sign in, so
  // this only matters if confirmations are ever switched off.
  requireVerified?: boolean
}

export interface ActiveUser {
  supabase: SupabaseClient
  user: User
  profile: Profile
}

export type AccessDeniedReason = 'unauthenticated' | 'unverified' | 'inactive' | 'forbidden'

// Thrown by requireActiveUserForAction. The message is fixed per reason, so
// it is safe to show in the UI.
export class AccessDeniedError extends Error {
  readonly reason: AccessDeniedReason

  constructor(reason: AccessDeniedReason) {
    super(ACCESS_DENIED_MESSAGES[reason])
    this.name = 'AccessDeniedError'
    this.reason = reason
  }
}

const ACCESS_DENIED_MESSAGES: Record<AccessDeniedReason, string> = {
  unauthenticated: 'Please log in to continue.',
  unverified: 'Please verify your email before contributing.',
  inactive: 'This account is suspended or banned.',
  forbidden: 'Admin access required.',
}

const INACTIVE_STATUSES: UserStatus[] = ['suspended', 'banned']

export function isInactiveStatus(status: UserStatus | null | undefined): boolean {
  return !!status && INACTIVE_STATUSES.includes(status)
}

type CheckResult =
  | { ok: true; account: ActiveUser }
  | { ok: false; reason: AccessDeniedReason; supabase: SupabaseClient }

async function checkActiveUser(options: RequireActiveUserOptions): Promise<CheckResult> {
  const { requireAdmin = false, requireVerified = true } = options
  const supabase = await createServerComponentClient()

  const { data: { user }, error: userError } = await supabase.auth.getUser()
  // Supabase Auth refuses a blocked member's token outright (see
  // setSignInBlocked in app/admin/actions.ts), even before it expires.
  if (userError?.code === 'user_banned') return { ok: false, reason: 'inactive', supabase }
  if (!user) return { ok: false, reason: 'unauthenticated', supabase }

  // profiles.status is the source of truth. Private columns aren't readable
  // through the table, so this goes through get_my_profile().
  const { data: profile, error } = await supabase.rpc('get_my_profile')
  if (error || !profile?.id) return { ok: false, reason: 'unauthenticated', supabase }

  if (isInactiveStatus(profile.status)) return { ok: false, reason: 'inactive', supabase }
  if (requireVerified && !user.email_confirmed_at) return { ok: false, reason: 'unverified', supabase }
  if (requireAdmin && !profile.is_admin) return { ok: false, reason: 'forbidden', supabase }

  return { ok: true, account: { supabase, user, profile: profile as Profile } }
}

// For pages and layouts: returns the signed-in, active member or redirects.
// Pages and layouts render in parallel, so a page must call this too even
// when its layout already does.
export async function requireActiveUser(options: RequireActiveUserOptions = {}): Promise<ActiveUser> {
  const result = await checkActiveUser(options)
  if (result.ok) return result.account

  switch (result.reason) {
    case 'unauthenticated':
      redirect('/login')
    case 'unverified':
      // The verify page reads the address from the session; never put it in the URL.
      redirect('/verify-email')
    case 'inactive':
      // Server Components can't clear cookies, so a route handler signs the
      // member out and sends them to /login?error=account_inactive.
      redirect('/auth/inactive')
    case 'forbidden':
      redirect('/')
  }
}

// For server actions: returns the signed-in, active member or throws
// AccessDeniedError. An inactive member is signed out on the way.
export async function requireActiveUserForAction(options: RequireActiveUserOptions = {}): Promise<ActiveUser> {
  const result = await checkActiveUser(options)
  if (result.ok) return result.account

  if (result.reason === 'inactive') {
    await result.supabase.auth.signOut()
  }
  throw new AccessDeniedError(result.reason)
}
