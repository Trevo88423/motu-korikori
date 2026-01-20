import Link from 'next/link'

export default function Home() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
      <div className="text-center">
        <h1 className="text-5xl font-bold text-primary-900 mb-4">
          Preserve True Motu
        </h1>
        <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
          Help document and preserve Motu korikori, an endangered language of Papua New Guinea.
          Contribute translations, pronunciations, and help build the world's most comprehensive
          True Motu dictionary.
        </p>

        <div className="flex justify-center space-x-4 mb-16">
          <Link href="/signup" className="btn btn-primary text-lg px-8 py-3">
            Get Started
          </Link>
          <Link href="/dictionary" className="btn btn-ghost text-lg px-8 py-3">
            Browse Dictionary
          </Link>
        </div>

        <div className="grid md:grid-cols-3 gap-8 mt-16">
          <div className="card">
            <div className="text-4xl mb-4">🗣️</div>
            <h3 className="text-xl font-semibold mb-2">Contribute Knowledge</h3>
            <p className="text-gray-600">
              Share your knowledge of True Motu. Add translations, record pronunciations,
              and help document this precious language.
            </p>
          </div>

          <div className="card">
            <div className="text-4xl mb-4">🤝</div>
            <h3 className="text-xl font-semibold mb-2">Community Consensus</h3>
            <p className="text-gray-600">
              Our algorithm builds consensus from multiple contributors, giving more weight
              to native speakers and heritage speakers.
            </p>
          </div>

          <div className="card">
            <div className="text-4xl mb-4">📚</div>
            <h3 className="text-xl font-semibold mb-2">15,610 Words</h3>
            <p className="text-gray-600">
              Comprehensive vocabulary sourced from Bible translations and linguistic research.
              Help us add translations for all of them.
            </p>
          </div>
        </div>

        <div className="mt-16 p-8 bg-primary-50 rounded-lg">
          <h2 className="text-2xl font-bold text-primary-900 mb-4">
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
