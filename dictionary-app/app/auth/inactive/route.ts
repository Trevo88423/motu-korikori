import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import type { CookieOptions } from '@supabase/ssr'
import { isInactiveStatus } from '@/lib/auth'

// requireActiveUser() sends suspended and banned members here: Server
// Components can't clear cookies, a route handler can. It only signs out a
// member who really is inactive, so a link to it can't log anyone else out.
export async function GET(request: NextRequest) {
  const origin = new URL(request.url).origin
  const pendingCookies: { name: string; value: string; options: CookieOptions }[] = []

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          pendingCookies.push(...cookiesToSet)
        },
      },
    }
  )

  const redirectTo = (path: string) => {
    const res = NextResponse.redirect(new URL(path, origin))
    pendingCookies.forEach(({ name, value, options }) => res.cookies.set(name, value, options))
    return res
  }

  const { data: { user }, error } = await supabase.auth.getUser()
  // Supabase Auth refuses a blocked member's token outright.
  const blocked = error?.code === 'user_banned'
  if (!user && !blocked) return redirectTo('/login')

  if (!blocked) {
    const { data: profile } = await supabase.rpc('get_my_profile')
    if (!isInactiveStatus(profile?.status)) return redirectTo('/')
  }

  // Global scope: ends every session this member has, not just this browser's.
  await supabase.auth.signOut()
  return redirectTo('/login?error=account_inactive')
}
