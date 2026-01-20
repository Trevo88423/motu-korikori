import { createServerComponentClient } from '@/lib/supabase'
import Link from 'next/link'
import type { Word } from '@/lib/types'

export const dynamic = 'force-dynamic'

interface SearchParams {
  search?: string
  status?: string
  page?: string
}

export default async function DictionaryPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const params = await searchParams
  const search = params.search || ''
  const status = params.status || 'all'
  const page = parseInt(params.page || '1')
  const perPage = 50

  const supabase = await createServerComponentClient()

  // Build query
  let query = supabase
    .from('words')
    .select('*', { count: 'exact' })

  // Apply search filter
  if (search) {
    query = query.ilike('motu_word', `%${search}%`)
  }

  // Apply status filter
  if (status && status !== 'all') {
    query = query.eq('status', status)
  }

  // Apply pagination
  const from = (page - 1) * perPage
  const to = from + perPage - 1

  const { data: words, count, error } = await query
    .order('frequency', { ascending: false })
    .range(from, to)

  if (error) {
    console.error('Error fetching words:', error)
  }

  const totalPages = count ? Math.ceil(count / perPage) : 0

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">True Motu Dictionary</h1>
        <p className="text-gray-600">
          Browse all {count?.toLocaleString() || '15,610'} words in the dictionary
        </p>
      </div>

      {/* Search and Filters */}
      <div className="card mb-6">
        <form className="flex flex-col md:flex-row gap-4">
          <div className="flex-1">
            <input
              type="text"
              name="search"
              defaultValue={search}
              placeholder="Search Motu words..."
              className="input"
            />
          </div>

          <select
            name="status"
            defaultValue={status}
            className="input md:w-48"
          >
            <option value="all">All Words</option>
            <option value="pending">Pending</option>
            <option value="consensus">Consensus Reached</option>
            <option value="verified">Verified</option>
            <option value="flagged">Flagged</option>
          </select>

          <button type="submit" className="btn btn-primary">
            Search
          </button>
        </form>
      </div>

      {/* Results */}
      {words && words.length > 0 ? (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {words.map((word: Word) => (
              <Link
                key={word.id}
                href={`/dictionary/${word.id}`}
                className="card hover:shadow-lg transition-shadow"
              >
                <div className="flex items-start justify-between mb-2">
                  <h3 className="text-xl font-bold text-primary-900">
                    {word.motu_word}
                  </h3>
                  <span className={`px-2 py-1 text-xs font-medium rounded ${
                    word.status === 'verified' ? 'bg-green-100 text-green-700' :
                    word.status === 'consensus' ? 'bg-blue-100 text-blue-700' :
                    word.status === 'flagged' ? 'bg-yellow-100 text-yellow-700' :
                    'bg-gray-100 text-gray-700'
                  }`}>
                    {word.status}
                  </span>
                </div>

                {word.consensus_gloss && (
                  <p className="text-gray-700 mb-2">
                    {word.consensus_gloss}
                  </p>
                )}

                <div className="flex items-center space-x-4 text-xs text-gray-500">
                  <span>Frequency: {word.frequency.toLocaleString()}</span>
                  <span>
                    {word.total_contributions} {word.total_contributions === 1 ? 'contribution' : 'contributions'}
                  </span>
                </div>

                {word.example_reference && (
                  <p className="text-xs text-gray-500 mt-2 truncate">
                    Example: {word.example_reference}
                  </p>
                )}
              </Link>
            ))}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="mt-8 flex justify-center items-center space-x-2">
              <Link
                href={`/dictionary?search=${search}&status=${status}&page=${Math.max(1, page - 1)}`}
                className={`btn btn-ghost ${page === 1 ? 'opacity-50 pointer-events-none' : ''}`}
              >
                Previous
              </Link>

              <span className="text-sm text-gray-600">
                Page {page} of {totalPages}
              </span>

              <Link
                href={`/dictionary?search=${search}&status=${status}&page=${Math.min(totalPages, page + 1)}`}
                className={`btn btn-ghost ${page === totalPages ? 'opacity-50 pointer-events-none' : ''}`}
              >
                Next
              </Link>
            </div>
          )}
        </>
      ) : (
        <div className="card text-center py-12">
          <p className="text-gray-500">No words found matching your search.</p>
        </div>
      )}
    </div>
  )
}
