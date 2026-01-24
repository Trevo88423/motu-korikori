import Link from 'next/link'
import { createServerComponentClient } from '@/lib/supabase'

export default async function Home() {
  const supabase = await createServerComponentClient()
  const { data: { user } } = await supabase.auth.getUser()

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
      <div className="text-center">
        <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold text-primary-900 mb-4">
          Preserve True Motu
        </h1>
        <p className="text-base sm:text-lg md:text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
          Help document and preserve Motu korikori, an endangered language of Papua New Guinea.
          Contribute translations, pronunciations, and help build the world's most comprehensive
          True Motu dictionary.
        </p>

        <div className="flex flex-col sm:flex-row justify-center gap-3 sm:gap-4 mb-12 sm:mb-16">
          <Link
            href={user ? "/contribute" : "/signup"}
            className="btn btn-primary text-base sm:text-lg px-6 sm:px-8 py-3"
          >
            {user ? "Start Contributing" : "Get Started"}
          </Link>
          <Link href="/dictionary" className="btn btn-ghost text-base sm:text-lg px-6 sm:px-8 py-3">
            Browse Dictionary
          </Link>
        </div>

        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-4 sm:gap-6 md:gap-8 mt-12 sm:mt-16">
          <div className="card">
            <div className="text-3xl sm:text-4xl mb-3 sm:mb-4">🗣️</div>
            <h3 className="text-lg sm:text-xl font-semibold mb-2">Contribute Knowledge</h3>
            <p className="text-gray-600">
              Share your knowledge of True Motu. Add translations, record pronunciations,
              and help document this precious language.
            </p>
          </div>

          <div className="card">
            <div className="text-3xl sm:text-4xl mb-3 sm:mb-4">🤝</div>
            <h3 className="text-lg sm:text-xl font-semibold mb-2">Community Consensus</h3>
            <p className="text-gray-600">
              Our algorithm builds consensus from multiple contributors, giving more weight
              to native speakers and heritage speakers.
            </p>
          </div>

          <div className="card">
            <div className="text-3xl sm:text-4xl mb-3 sm:mb-4">📚</div>
            <h3 className="text-lg sm:text-xl font-semibold mb-2">15,610 Words</h3>
            <p className="text-gray-600">
              Comprehensive vocabulary sourced from Bible translations and linguistic research.
              Help us add translations for all of them.
            </p>
          </div>
        </div>

        <div className="mt-12 sm:mt-16 p-4 sm:p-6 md:p-8 bg-primary-50 rounded-lg">
          <h2 className="text-xl sm:text-2xl font-bold text-primary-900 mb-3 sm:mb-4">
            About True Motu (Motu Korikori)
          </h2>
          <p className="text-gray-700 max-w-3xl mx-auto">
            True Motu, or Motu korikori, is the indigenous language of the Motu people of Papua New Guinea.
            Unlike the simplified trade language Hiri Motu, True Motu retains the full complexity and
            richness of the original language. This project aims to preserve it through community-driven
            documentation and modern technology.
          </p>
        </div>
      </div>
    </div>
  )
}
