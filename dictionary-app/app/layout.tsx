import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import Navigation from '@/components/Navigation'
import { SITE_DESCRIPTION, SITE_NAME, SITE_URL } from '@/lib/seo'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

// Pages set their own title (filled into the template), description and canonical URL
export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${SITE_NAME}: True Motu (Motu korikori), not Hiri Motu`,
    template: `%s | ${SITE_NAME}`,
  },
  description: SITE_DESCRIPTION,
  applicationName: SITE_NAME,
  openGraph: {
    type: 'website',
    siteName: SITE_NAME,
    title: SITE_NAME,
    description: SITE_DESCRIPTION,
    locale: 'en',
  },
  twitter: { card: 'summary', title: SITE_NAME, description: SITE_DESCRIPTION },
}

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const cookieStore = await cookies()

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Ignore - called from Server Component
          }
        },
      },
    }
  )

  // Get current user (if any)
  const {
    data: { user },
  } = await supabase.auth.getUser()

  // Get user profile for the display name shown in the nav
  let userData = null
  if (user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('id', user.id)
      .single()

    userData = {
      id: user.id,
      email: user.email || '',
      name: profile?.display_name,
    }
  }

  return (
    <html lang="en">
      <body className={inter.className}>
        <Navigation user={userData} />
        <main className="min-h-screen bg-gray-50">
          {children}
        </main>
        <footer className="bg-gray-800 text-white py-8 mt-16">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <p className="text-center text-gray-400">
              &copy; {new Date().getFullYear()} True Motu Dictionary Project. Preserving Motu korikori for future generations.
            </p>
          </div>
        </footer>
      </body>
    </html>
  )
}
