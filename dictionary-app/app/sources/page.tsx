import type { Metadata } from 'next'
import { BIBLE_CREDIT } from '@/lib/bible-credit'

export const metadata: Metadata = {
  title: 'Sources and credits',
  description: 'Where the True Motu Dictionary’s word list and example verses come from, and their licences.',
  alternates: { canonical: '/sources' },
}

export default function SourcesPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
      <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-6">Sources and credits</h1>

      <section className="bg-white rounded-lg shadow-sm p-5 sm:p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Motu Bible</h2>
        <p className="text-gray-700 mb-3">
          The word list and the example verses come from the 1973 True Motu Bible.
        </p>
        <p className="text-gray-700 mb-3">
          {BIBLE_CREDIT.motu}. Licensed under{' '}
          <a href={BIBLE_CREDIT.licenceUrl} target="_blank" rel="noopener noreferrer license" className="text-primary-600 underline">
            Creative Commons {BIBLE_CREDIT.licence}
          </a>
          , obtained via{' '}
          <a href={BIBLE_CREDIT.sourceUrl} target="_blank" rel="noopener noreferrer" className="text-primary-600 underline">
            {BIBLE_CREDIT.source}
          </a>
          .
        </p>
        <p className="text-gray-700">
          Verses are shown exactly as published, without changes to their words or punctuation.
          The Motu Bible text is not part of the community’s open data, and may not be sold or
          used commercially.
        </p>
      </section>

      <section className="bg-white rounded-lg shadow-sm p-5 sm:p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-3">English translation</h2>
        <p className="text-gray-700">
          English verses are from the World English Bible, which is in the public domain.
        </p>
      </section>
    </div>
  )
}
