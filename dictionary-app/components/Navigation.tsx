'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

interface NavigationProps {
  user: {
    id: string
    email: string
    name?: string
  } | null
}

export default function Navigation({ user }: NavigationProps) {
  const router = useRouter()
  const [isLoggingOut, setIsLoggingOut] = useState(false)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)

  const handleLogout = async () => {
    setIsLoggingOut(true)

    try {
      const res = await fetch('/api/auth/logout', {
        method: 'POST',
      })

      if (res.ok) {
        window.location.href = '/'
      }
    } catch (error) {
      console.error('Logout error:', error)
      setIsLoggingOut(false)
    }
  }

  const navLinks = [
    { href: '/', label: 'Home', public: true },
    { href: '/dictionary', label: 'Dictionary', public: true },
    { href: '/leaderboard', label: 'Leaderboard', public: true },
    { href: '/contribute', label: 'Contribute', public: false },
    { href: '/my-contributions', label: 'My Contributions', public: false },
    { href: '/dashboard', label: 'Dashboard', public: false },
  ]

  const visibleLinks = navLinks.filter(link => link.public || user)

  return (
    <nav className="bg-primary-700 text-white shadow-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-14 sm:h-16 items-center">
          {/* Logo */}
          <Link href="/" className="flex-shrink-0">
            <h1 className="text-lg sm:text-xl font-bold whitespace-nowrap">True Motu Dictionary</h1>
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden lg:flex items-center space-x-1 xl:space-x-2">
            {visibleLinks.map(link => (
              <Link
                key={link.href}
                href={link.href}
                className="px-2 xl:px-3 py-2 text-sm hover:bg-primary-600 rounded-md transition"
              >
                {link.label}
              </Link>
            ))}

            {user ? (
              <div className="flex items-center ml-2 pl-2 border-l border-primary-500">
                {user.name && (
                  <span className="text-secondary-300 text-sm px-2 hidden xl:block">
                    {user.name}
                  </span>
                )}
                <button
                  onClick={handleLogout}
                  disabled={isLoggingOut}
                  className="px-3 py-2 text-sm hover:bg-primary-600 rounded-md transition disabled:opacity-50"
                >
                  {isLoggingOut ? '...' : 'Logout'}
                </button>
              </div>
            ) : (
              <Link
                href="/login"
                className="ml-2 px-4 py-2 text-sm bg-secondary-500 hover:bg-secondary-600 rounded-md transition"
              >
                Login
              </Link>
            )}
          </div>

          {/* Mobile menu button */}
          <div className="flex lg:hidden items-center space-x-2">
            {user && (
              <span className="text-secondary-300 text-xs sm:text-sm truncate max-w-[80px] sm:max-w-[120px]">
                {user.name}
              </span>
            )}
            <button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="p-2 rounded-md hover:bg-primary-600 transition"
              aria-label="Toggle menu"
            >
              {isMobileMenuOpen ? (
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              ) : (
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Navigation */}
      {isMobileMenuOpen && (
        <div className="lg:hidden border-t border-primary-600">
          <div className="px-4 py-3 space-y-1">
            {visibleLinks.map(link => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setIsMobileMenuOpen(false)}
                className="block px-3 py-2 text-base hover:bg-primary-600 rounded-md transition"
              >
                {link.label}
              </Link>
            ))}

            <div className="pt-2 mt-2 border-t border-primary-600">
              {user ? (
                <button
                  onClick={handleLogout}
                  disabled={isLoggingOut}
                  className="w-full text-left px-3 py-2 text-base hover:bg-primary-600 rounded-md transition disabled:opacity-50"
                >
                  {isLoggingOut ? 'Logging out...' : 'Logout'}
                </button>
              ) : (
                <Link
                  href="/login"
                  onClick={() => setIsMobileMenuOpen(false)}
                  className="block px-3 py-2 text-base bg-secondary-500 hover:bg-secondary-600 rounded-md transition text-center"
                >
                  Login
                </Link>
              )}
            </div>
          </div>
        </div>
      )}
    </nav>
  )
}
