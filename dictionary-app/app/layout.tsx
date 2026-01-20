import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'True Motu Dictionary | Motu Korikori',
  description: 'Crowdsourced dictionary for documenting True Motu (Motu korikori), an endangered language of Papua New Guinea',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <nav className="bg-primary-700 text-white shadow-md">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between h-16 items-center">
              <div className="flex items-center">
                <h1 className="text-xl font-bold">True Motu Dictionary</h1>
              </div>
              <div className="flex space-x-4">
                <a href="/" className="hover:text-secondary-300 transition">Home</a>
                <a href="/dictionary" className="hover:text-secondary-300 transition">Dictionary</a>
                <a href="/contribute" className="hover:text-secondary-300 transition">Contribute</a>
                <a href="/dashboard" className="hover:text-secondary-300 transition">Dashboard</a>
                <a href="/login" className="hover:text-secondary-300 transition">Login</a>
              </div>
            </div>
          </div>
        </nav>
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
