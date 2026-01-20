import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet: { name: string; value: string; options?: any }[]) {
          cookiesToSet.forEach(({ name, value, options }) =>
            request.cookies.set(name, value)
          )
          response = NextResponse.next({
            request,
          })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // Refresh session if expired
  const {
    data: { user },
  } = await supabase.auth.getUser()

  // Define protected routes
  const protectedRoutes = ['/contribute', '/dashboard']
  const adminRoutes = ['/admin']

  const pathname = request.nextUrl.pathname

  // Check if current route is protected
  const isProtectedRoute = protectedRoutes.some(route => pathname.startsWith(route))
  const isAdminRoute = adminRoutes.some(route => pathname.startsWith(route))

  // Redirect to login if accessing protected route without authentication
  if (isProtectedRoute && !user) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Check admin access
  if (isAdminRoute && user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin, status')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin || profile.status === 'banned') {
      return NextResponse.redirect(new URL('/', request.url))
    }
  } else if (isAdminRoute && !user) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Check if user is banned
  if (user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('status')
      .eq('id', user.id)
      .single()

    if (profile?.status === 'banned' && pathname !== '/') {
      await supabase.auth.signOut()
      return NextResponse.redirect(new URL('/', request.url))
    }
  }

  return response
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
