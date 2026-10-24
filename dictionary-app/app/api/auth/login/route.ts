import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import { isInactiveStatus } from '@/lib/auth'

const ACCOUNT_INACTIVE = 'This account has been suspended or banned. If you think this is a mistake, please contact the Truemotu team.'

export async function POST(req: NextRequest) {
  const { email, password } = await req.json()

  const response = NextResponse.json({ ok: true })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          // Pass existing cookies so @supabase/ssr can clear stale auth chunks
          return req.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options)
          })
        },
      },
    }
  )

  const { data, error } = await supabase.auth.signInWithPassword({ email, password })

  // Suspended and banned members are blocked in Supabase Auth too (see
  // setSignInBlocked in app/admin/actions.ts).
  if (error?.code === 'user_banned') {
    return NextResponse.json({ ok: false, error: ACCOUNT_INACTIVE }, { status: 403 })
  }

  if (error || !data.session) {
    // Handle email not confirmed error
    if (error?.message?.toLowerCase().includes('email not confirmed')) {
      return NextResponse.json(
        { ok: false, error: 'Please verify your email before logging in. Check your inbox for the verification link.', needsVerification: true, email },
        { status: 401 }
      )
    }
    return NextResponse.json({ ok: false, error: error?.message ?? 'No session' }, { status: 401 })
  }

  // profiles.status is the source of truth, so check it even if the Auth
  // block above is missing (e.g. members banned before it existed).
  const { data: profile } = await supabase.rpc('get_my_profile')

  if (isInactiveStatus(profile?.status)) {
    await supabase.auth.signOut()
    return NextResponse.json({ ok: false, error: ACCOUNT_INACTIVE }, { status: 403 })
  }

  return response
}
