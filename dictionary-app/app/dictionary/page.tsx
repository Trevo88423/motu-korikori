import { createServerComponentClient, getTotalWordCount, getWordInitials } from '@/lib/supabase'
import Link from 'next/link'
import type { Word, WordType } from '@/lib/types'

export const dynamic = 'force-dynamic'

interface SearchParams {
  search?: string
  englishSearch?: string
  letter?: string
  status?: string
  type?: string
  page?: string
}

// Builds a /dictionary link, leaving out empty values (and the defaults
// status=all, type=vocabulary and page=1) so a search containing & or #
// survives paging.
function dictionaryHref(params: Record<string, string | number | undefined>) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === '') continue
    if (key === 'status' && value === 'all') continue
    if (key === 'type' && value === 'vocabulary') continue
    if (key === 'page' && Number(value) === 1) continue
    query.set(key, String(value))
  }
  const qs = query.toString()
  return qs ? `/dictionary?${qs}` : '/dictionary'
}

export default async function DictionaryPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const params = await searchParams
  const search = params.search || ''
  const englishSearch = params.englishSearch || ''
  const letter = params.letter || ''
  const status = params.status || 'all'
  // Vocabulary by default; Bible names and places are a separate list (#75)
  const type: WordType = params.type === 'name' ? 'name' : 'vocabulary'
  const page = Math.max(1, parseInt(params.page || '1') || 1)
  const perPage = 50

  const supabase = await createServerComponentClient()
  const hasFilters = Boolean(search || englishSearch || letter || status !== 'all')

  // Unfiltered, the match count is just the (cached) count for the type, so
  // only count when filters are applied. Filters go to search_words as parameters, which
  // escapes them; nothing the user types is put into a PostgREST filter.
  const query = hasFilters
    ? supabase.rpc(
        'search_words',
        {
          p_motu: search || null,
          p_english: englishSearch || null,
          p_letter: letter || null,
          p_status: status !== 'all' ? status : null,
          p_word_type: type,
        },
        { count: 'exact' }
      )
    : supabase.from('words').select('*').eq('word_type', type)

  // Apply pagination
  const from = (page - 1) * perPage
  const to = from + perPage - 1

  // Same order as Prev/Next on the word page (word_neighbors)
  const [wordCounts, letters, { data, count: filteredCount, error }] = await Promise.all([
    getTotalWordCount(),
    getWordInitials(type),
    query
      .order('frequency', { ascending: false, nullsFirst: false })
      .order('motu_word', { ascending: true })
      .range(from, to),
  ])
  const words = data as Word[] | null
  const typeTotal = type === 'name' ? wordCounts.names : wordCounts.vocabulary
  const count = hasFilters ? filteredCount : typeTotal
  const noun = type === 'name' ? 'names and places' : 'words'

  // getTotalWordCount returns zeros when it fails
  const loadError = Boolean(error) || wordCounts.total === 0
  if (error) {
    console.error('Error fetching words:', error)
  }

  // Fetch top comments for displayed words
  const wordIds = words?.map(w => w.id) || []
  let topCommentsByWordId = new Map<string, { comment_text: string; net_votes: number; connection_type: string }>()

  if (wordIds.length > 0) {
    const { data: comments } = await supabase
      .from('comments')
      .select('word_id, comment_text, net_votes, profile:profiles(connection_type)')
      .in('word_id', wordIds)
      .gte('net_votes', 0)
      .order('net_votes', { ascending: false })

    // Group by word_id and take the top one for each
    comments?.forEach(comment => {
      if (!topCommentsByWordId.has(comment.word_id)) {
        topCommentsByWordId.set(comment.word_id, {
          comment_text: comment.comment_text,
          net_votes: comment.net_votes,
          connection_type: (comment.profile as any)?.connection_type || 'other'
        })
      }
    })
  }

  const totalPages = count ? Math.ceil(count / perPage) : 0

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-6 sm:mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-2">True Motu Dictionary</h1>
        <p className="text-sm sm:text-base text-gray-600">
          {loadError
            ? 'Search and browse the Motu dictionary'
            : hasFilters
            ? `Showing ${(count || 0).toLocaleString()} of ${typeTotal.toLocaleString()} ${noun}`
            : type === 'name'
            ? `Browse ${typeTotal.toLocaleString()} personal and place names from the Motu Bible`
            : `Browse all ${typeTotal.toLocaleString()} words in the dictionary`}
        </p>
      </div>

      {/* Words or names and places */}
      <div className="flex gap-2 mb-4" role="tablist" aria-label="Word type">
        {([
          ['vocabulary', 'Words', wordCounts.vocabulary],
          ['name', 'Names and places', wordCounts.names],
        ] as const).map(([value, label, n]) => (
          <Link
            key={value}
            role="tab"
            aria-selected={type === value}
            href={dictionaryHref({ search, englishSearch, status, type: value })}
            className={`px-3 sm:px-4 py-2 text-sm font-medium rounded transition ${
              type === value ? 'bg-primary-600 text-white' : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
            }`}
          >
            {label}
            {!loadError && <span className="ml-1 opacity-80">({n.toLocaleString()})</span>}
          </Link>
        ))}
      </div>

      {/* Alphabet Filter */}
      <div className="card mb-4 overflow-x-auto">
        <div className="flex flex-wrap gap-1 sm:gap-2">
          <Link
            href={dictionaryHref({ search, englishSearch, status, type })}
            className={`px-2 sm:px-3 py-1 text-sm rounded transition ${
              !letter ? 'bg-primary-600 text-white' : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
            }`}
          >
            All
          </Link>
          {letters.map((l) => (
            <Link
              key={l}
              href={dictionaryHref({ search, englishSearch, letter: l, status, type })}
              className={`px-2 sm:px-3 py-1 text-sm rounded transition ${
                letter === l ? 'bg-primary-600 text-white' : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
              }`}
            >
              {l}
            </Link>
          ))}
        </div>
      </div>

      {/* Search and Filters */}
      <div className="card mb-6">
        <form className="flex flex-col gap-4">
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="search-motu" className="block text-sm font-medium text-gray-700 mb-1">
                Search Motu Word
              </label>
              <input
                id="search-motu"
                type="text"
                name="search"
                defaultValue={search}
                placeholder="e.g., hanua, lau..."
                className="input"
              />
            </div>

            <div>
              <label htmlFor="search-english" className="block text-sm font-medium text-gray-700 mb-1">
                Search English Translation
              </label>
              <input
                id="search-english"
                type="text"
                name="englishSearch"
                defaultValue={englishSearch}
                placeholder="e.g., house, good..."
                className="input"
              />
            </div>
          </div>

          <div className="flex flex-col md:flex-row gap-4">
            <select
              name="status"
              aria-label="Filter by status"
              defaultValue={status}
              className="input md:w-48"
            >
              <option value="all">All Words</option>
              <option value="pending">Pending</option>
              <option value="consensus">Consensus Reached</option>
              <option value="verified">Verified</option>
              <option value="flagged">Flagged</option>
            </select>

            {letter && <input type="hidden" name="letter" value={letter} />}
            {type !== 'vocabulary' && <input type="hidden" name="type" value={type} />}

            <button type="submit" className="btn btn-primary">
              Search
            </button>

            {(search || englishSearch || letter || status !== 'all') && (
              <Link href={dictionaryHref({ type })} className="btn btn-ghost">
                Clear Filters
              </Link>
            )}
          </div>
        </form>
      </div>

      {/* Results */}
      {loadError ? (
        <div className="card text-center py-12">
          <p className="text-gray-700 font-medium">Couldn&apos;t load words, try again.</p>
          <Link href={dictionaryHref({ search, englishSearch, letter, status, type, page })} className="btn btn-primary mt-4">
            Try again
          </Link>
        </div>
      ) : words && words.length > 0 ? (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {words.map((word: Word) => {
              const topComment = topCommentsByWordId.get(word.id)
              return (
                <div key={word.id} className="card hover:shadow-lg transition-shadow relative">
                  <Link href={`/dictionary/${word.id}`} className="block">
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
                        {word.status.charAt(0).toUpperCase() + word.status.slice(1)}
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

                    {topComment && (
                      <div className="mt-3 pt-2 border-t border-gray-100">
                        <p className="text-sm text-gray-600 line-clamp-2">
                          💬 {topComment.comment_text}
                        </p>
                        {topComment.net_votes > 0 && (
                          <span className="text-xs text-green-600">▲ {topComment.net_votes}</span>
                        )}
                      </div>
                    )}
                  </Link>

                  <div className="mt-3 pt-3 border-t">
                    <Link
                      href={`/contribute?word=${word.id}`}
                      className="text-sm text-primary-600 hover:text-primary-800 font-medium"
                    >
                      ➕ Contribute Translation
                    </Link>
                  </div>
                </div>
              )
            })}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="mt-8 flex flex-col items-center gap-4">
              <div className="flex items-center gap-2 flex-wrap justify-center">
                <Link
                  href={dictionaryHref({ search, englishSearch, letter, status, type, page: Math.max(1, page - 1) })}
                  className={`btn btn-ghost ${page === 1 ? 'opacity-50 pointer-events-none' : ''}`}
                >
                  ← Previous
                </Link>

                {/* Page numbers */}
                {Array.from({ length: Math.min(10, totalPages) }, (_, i) => {
                  // Show first 5, last 5, or pages around current
                  let pageNum
                  if (totalPages <= 10) {
                    pageNum = i + 1
                  } else if (page <= 6) {
                    pageNum = i + 1
                  } else if (page >= totalPages - 5) {
                    pageNum = totalPages - 9 + i
                  } else {
                    pageNum = page - 5 + i
                  }

                  if (pageNum < 1 || pageNum > totalPages) return null

                  return (
                    <Link
                      key={pageNum}
                      href={dictionaryHref({ search, englishSearch, letter, status, type, page: pageNum })}
                      className={`px-3 py-1 rounded transition ${
                        page === pageNum
                          ? 'bg-primary-600 text-white'
                          : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                      }`}
                    >
                      {pageNum}
                    </Link>
                  )
                })}

                {totalPages > 10 && page < totalPages - 5 && (
                  <>
                    <span className="text-gray-400">...</span>
                    <Link
                      href={dictionaryHref({ search, englishSearch, letter, status, type, page: totalPages })}
                      className="px-3 py-1 rounded bg-gray-100 hover:bg-gray-200 text-gray-700"
                    >
                      {totalPages}
                    </Link>
                  </>
                )}

                <Link
                  href={dictionaryHref({ search, englishSearch, letter, status, type, page: Math.min(totalPages, page + 1) })}
                  className={`btn btn-ghost ${page === totalPages ? 'opacity-50 pointer-events-none' : ''}`}
                >
                  Next →
                </Link>
              </div>

              <div className="text-sm text-gray-600">
                Page {page} of {totalPages} ({count?.toLocaleString()} {noun})
              </div>
            </div>
          )}
        </>
      ) : (
        <div className="card text-center py-12">
          <p className="text-gray-500">No {noun} found matching your search.</p>
        </div>
      )}
    </div>
  )
}
