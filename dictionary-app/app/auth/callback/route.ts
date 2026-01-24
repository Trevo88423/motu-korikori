import { NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')
  const token_hash = requestUrl.searchParams.get('token_hash')
  const type = requestUrl.searchParams.get('type')
  const next = requestUrl.searchParams.get('next') || '/contribute'

  // Determine redirect based on type
  const getSuccessRedirect = (authType: string | null) => {
    if (authType === 'recovery') {
      return '/reset-password'
    }
    // After email verification, go to home page
    return '/'
  }

  const successRedirect = getSuccessRedirect(type)
  const response = NextResponse.redirect(new URL(successRedirect, requestUrl.origin))

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
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

  // Handle token_hash approach (from email templates with {{ .TokenHash }})
  if (token_hash) {
    const otpType = type === 'recovery' ? 'recovery' :
                    type === 'email' ? 'email' :
                    type === 'signup' ? 'signup' : 'email'

    const { error } = await supabase.auth.verifyOtp({
      token_hash,
      type: otpType as 'recovery' | 'email' | 'signup',
    })

    if (error) {
      console.error('Auth callback error (token_hash):', error)
      return NextResponse.redirect(
        new URL(`/login?error=${encodeURIComponent(error.message)}`, requestUrl.origin)
      )
    }

    return response
  }

  // Handle code approach (from PKCE flow with emailRedirectTo)
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)

    if (error) {
      console.error('Auth callback error (code):', error)
      return NextResponse.redirect(
        new URL(`/login?error=${encodeURIComponent(error.message)}`, requestUrl.origin)
      )
    }

    return response
  }

  // No code or token_hash provided - redirect to login
  return NextResponse.redirect(
    new URL('/login?error=Invalid authentication link', requestUrl.origin)
  )
}
