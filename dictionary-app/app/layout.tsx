import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import Navigation from '@/components/Navigation'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'True Motu Dictionary | Motu Korikori',
  description: 'Crowdsourced dictionary for documenting True Motu (Motu korikori), an endangered language of Papua New Guinea',
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

  // Get user profile for name
  let userData = null
  if (user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('name')
      .eq('id', user.id)
      .single()

    userData = {
      id: user.id,
      email: user.email || '',
      name: profile?.name,
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
              &copy; 2024 True Motu Dictionary Project. Preserving Motu korikori for future generations.
            </p>
          </div>
        </footer>
      </body>
    </html>
  )
}
