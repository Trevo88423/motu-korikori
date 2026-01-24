/**
 * Bible Query System - Loads indices and provides verse lookup
 *
 * This is a singleton that loads the Bible indices once and caches them in memory
 */

import { readFileSync } from 'fs'
import { join } from 'path'

/**
 * Convert database reference format to Bible index format
 * Database: "GEN 1:1" or "MAT 5:3"
 * Index: "GEN.1.1" or "MAT.5.3"
 */
function normalizeReference(ref: string): string {
  return ref.replace(/\s+/g, '.').replace(':', '.')
}

interface VerseData {
  motu: string
  english: string
  strongs?: string[]
}

interface BibleIndices {
  verses: Record<string, VerseData>
  wordIndexMotu: Record<string, string[]>
}

class BibleQuery {
  private static instance: BibleQuery | null = null
  private indices: BibleIndices | null = null
  private indicesPath: string

  private constructor() {
    // Path to indices directory
    this.indicesPath = join(process.cwd(), '..', 'files', 'bible_data', 'indices')
  }

  static getInstance(): BibleQuery {
    if (!BibleQuery.instance) {
      BibleQuery.instance = new BibleQuery()
    }
    return BibleQuery.instance
  }

  private loadIndices(): BibleIndices | null {
    if (this.indices) {
      return this.indices
    }

    console.log('Loading Bible indices...')
    const start = Date.now()

    try {
      // Load verses and word index
      const versesPath = join(this.indicesPath, 'verses.json')
      const wordIndexPath = join(this.indicesPath, 'word_index_motu.json')

      const verses = JSON.parse(readFileSync(versesPath, 'utf-8'))
      const wordIndexMotu = JSON.parse(readFileSync(wordIndexPath, 'utf-8'))

      this.indices = { verses, wordIndexMotu }

      const elapsed = Date.now() - start
      console.log(`Bible indices loaded in ${elapsed}ms`)

      return this.indices
    } catch (error) {
      // Indices not available (e.g., on Vercel deployment)
      console.warn('Bible indices not available:', error)
      return null
    }
  }

  /**
   * Search for verses containing a specific Motu word
   *
   * @param word - The Motu word to search for
   * @param excludeRef - Optional verse reference to exclude (e.g., the current example)
   * @param limit - Maximum number of verses to return
   * @returns Array of verse data with references
   */
  searchWord(word: string, excludeRef?: string, limit: number = 50): Array<{ ref: string; motu: string; english: string }> {
    const indices = this.loadIndices()
    if (!indices) {
      return [] // Indices not available
    }
    const { verses, wordIndexMotu } = indices
    const wordLower = word.toLowerCase()

    // Get all verse references containing this word
    const verseRefs = wordIndexMotu[wordLower] || []

    // Normalize the exclude reference to match index format
    const normalizedExclude = excludeRef ? normalizeReference(excludeRef) : null

    // Filter out the excluded reference
    const filteredRefs = normalizedExclude
      ? verseRefs.filter(ref => ref !== normalizedExclude)
      : verseRefs

    // Limit results
    const limitedRefs = filteredRefs.slice(0, limit)

    // Get full verse data
    return limitedRefs.map(ref => ({
      ref,
      motu: verses[ref]?.motu || '',
      english: verses[ref]?.english || ''
    }))
  }

  /**
   * Get a random verse containing a specific word
   *
   * @param word - The Motu word to search for
   * @param excludeRef - Optional verse reference to exclude
   * @returns Random verse data with reference, or null if not found
   */
  getRandomVerse(word: string, excludeRef?: string): { ref: string; motu: string; english: string } | null {
    const results = this.searchWord(word, excludeRef, 1000) // Get up to 1000 to choose from

    if (results.length === 0) {
      return null
    }

    // Pick a random verse
    const randomIndex = Math.floor(Math.random() * results.length)
    return results[randomIndex]
  }
}

export default BibleQuery
