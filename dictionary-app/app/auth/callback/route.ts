import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import type { CookieOptions } from '@supabase/ssr'

// Only allow same-site relative paths as a post-auth destination, so a crafted
// ?next=https://evil.example cannot turn this route into an open redirect.
function safeNext(next: string | null): string | null {
  if (!next) return null
  if (!next.startsWith('/') || next.startsWith('//')) return null
  return next
}

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')
  const token_hash = requestUrl.searchParams.get('token_hash')
  const type = requestUrl.searchParams.get('type')
  const next = safeNext(requestUrl.searchParams.get('next'))

  const successPath = next ?? (type === 'recovery' ? '/reset-password' : '/')

  // Cookies are collected here rather than written straight onto a response.
  // The response cannot be built until the exchange has finished — see the
  // comment on the `code` branch below.
  const pendingCookies: { name: string; value: string; options: CookieOptions }[] = []

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        // Previously `return []`. The PKCE code verifier lives in a cookie on
        // this request, and @supabase/ssr reads it through getAll — returning
        // an empty array made exchangeCodeForSession throw
        // AuthPKCECodeVerifierMissingError before it made any network call,
        // which meant the `code` branch could never succeed.
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
    const res = NextResponse.redirect(new URL(path, requestUrl.origin))
    pendingCookies.forEach(({ name, value, options }) => {
      res.cookies.set(name, value, options)
    })
    return res
  }

  const failure = (reason: string, err: unknown) => {
    // Log the provider's text server-side; show the user something meaningful
    // rather than a raw GoTrue string.
    console.error(`Auth callback error (${reason}):`, err)
    return NextResponse.redirect(
      new URL('/login?error=link_invalid', requestUrl.origin)
    )
  }

  // token_hash flow — from email templates using {{ .TokenHash }}
  if (token_hash) {
    const otpType =
      type === 'recovery' ? 'recovery' : type === 'signup' ? 'signup' : 'email'

    const { error } = await supabase.auth.verifyOtp({
      token_hash,
      type: otpType as 'recovery' | 'email' | 'signup',
    })

    if (error) return failure('token_hash', error)

    return redirectTo(successPath)
  }

  // PKCE flow — from email templates using {{ .ConfirmationURL }}
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)

    if (error) return failure('code', error)

    // auth-js defers the SIGNED_IN notification with setTimeout(..., 0), and
    // @supabase/ssr only writes cookies from that notification. Yield the
    // macrotask queue once so the write lands in `pendingCookies` before the
    // response is built — otherwise the session cookie is silently dropped and
    // the user arrives logged out. (verifyOtp awaits its notification, so the
    // token_hash branch above does not need this.)
    await new Promise((resolve) => setTimeout(resolve, 0))

    return redirectTo(successPath)
  }

  return NextResponse.redirect(
    new URL('/login?error=link_invalid', requestUrl.origin)
  )
}
