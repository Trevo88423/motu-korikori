import { NextRequest, NextResponse } from 'next/server'
import BibleQuery from '@/lib/bible-query'

export const dynamic = 'force-dynamic'

/**
 * API endpoint to get a random verse containing a specific Motu word
 *
 * Query params:
 * - word: The Motu word to search for (required)
 * - exclude: Verse reference to exclude (optional, e.g., "GEN.1.1")
 *
 * Example: /api/bible/random-verse?word=lohia&exclude=GEN.1.1
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const word = searchParams.get('word')
    const exclude = searchParams.get('exclude')

    if (!word) {
      return NextResponse.json(
        { error: 'Missing required parameter: word' },
        { status: 400 }
      )
    }

    // Get Bible query instance
    const bibleQuery = BibleQuery.getInstance()

    // Get random verse
    const verse = bibleQuery.getRandomVerse(word, exclude || undefined)

    if (!verse) {
      return NextResponse.json(
        { error: 'No verses found containing this word' },
        { status: 404 }
      )
    }

    return NextResponse.json({
      ref: verse.ref,
      motu: verse.motu,
      english: verse.english
    })
  } catch (error: any) {
    console.error('Error in random-verse API:', error)
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    )
  }
}
