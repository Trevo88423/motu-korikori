import { NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function POST(req: Request) {
  const { email, password } = await req.json()

  const response = NextResponse.json({ ok: true })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          // no incoming cookies needed for sign-in
          return []
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

  // Check if user is banned
  const { data: profile } = await supabase
    .from('profiles')
    .select('status')
    .eq('id', data.user.id)
    .single()

  if (profile?.status === 'banned') {
    return NextResponse.json({ ok: false, error: 'Account suspended' }, { status: 403 })
  }

  return response
}
