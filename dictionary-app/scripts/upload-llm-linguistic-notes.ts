/**
 * Upload LLM-generated linguistic notes to Supabase
 *
 * This script uploads ai_morphology, ai_patterns, and ai_notes fields
 */

import { createClient } from '@supabase/supabase-js'
import * as fs from 'fs'
import * as path from 'path'
import * as dotenv from 'dotenv'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config({ path: path.join(__dirname, '../.env.local') })

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing required environment variables')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

const DICTIONARY_PATH = path.join(__dirname, '../../../Kindred/Developer version/llm_dictionary_full.json')

interface ParsedEntry {
  translation: string
  type: string
  confidence: string
  morphology: string
  patterns: string
  notes: string
}

/**
 * Parse an LLM dictionary entry to extract structured fields
 */
function parseLLMEntry(text: string): ParsedEntry {
  const result: ParsedEntry = {
    translation: '',
    type: '',
    confidence: '',
    morphology: '',
    patterns: '',
    notes: ''
  }

  const patterns: Record<keyof ParsedEntry, RegExp> = {
    translation: /\*?\*?TRANSLATION:?\*?\*?\s*(.+?)(?=\n\*?\*?[A-Z]|\Z)/is,
    type: /\*?\*?TYPE:?\*?\*?\s*(.+?)(?=\n\*?\*?[A-Z]|\Z)/is,
    confidence: /\*?\*?CONFIDENCE:?\*?\*?\s*(.+?)(?=\n\*?\*?[A-Z]|\Z)/is,
    morphology: /\*?\*?MORPHOLOGY:?\*?\*?\s*(.+?)(?=\n\*?\*?[A-Z]|\Z)/is,
    patterns: /\*?\*?PATTERNS:?\*?\*?\s*(.+?)(?=\n\*?\*?[A-Z]|\Z)/is,
    notes: /\*?\*?NOTES:?\*?\*?\s*(.+?)(?=\n\*?\*?[A-Z]|\Z)/is,
  }

  for (const [field, pattern] of Object.entries(patterns)) {
    const match = text.match(pattern)
    if (match) {
      let value = match[1].trim()
      value = value.replace(/\*\*/g, '')
      value = value.replace(/\n+/g, ' ')
      result[field as keyof ParsedEntry] = value
    }
  }

  return result
}

/**
 * Clean up morphology field - skip useless values
 */
function cleanMorphology(value: string): string | null {
  const skipValues = [
    'not decomposable',
    'not applicable',
    'simple',
    'simple stem',
    'simple root',
    'base form',
    'base word',
    'none detected',
    'n/a',
    '-',
    '—'
  ]

  const lower = value.toLowerCase().trim()
  if (skipValues.some(skip => lower === skip || lower.startsWith(skip))) {
    return null
  }

  return value
}

/**
 * Update database with linguistic notes
 */
async function updateWord(
  word: string,
  morphology: string | null,
  patterns: string | null,
  notes: string | null
): Promise<boolean> {
  const updates: Record<string, string | null> = {}

  if (morphology) updates.ai_morphology = morphology
  if (patterns) updates.ai_patterns = patterns
  if (notes) updates.ai_notes = notes

  if (Object.keys(updates).length === 0) {
    return true // Nothing to update
  }

  const { error } = await supabase
    .from('words')
    .update(updates)
    .eq('motu_word', word)

  if (error) {
    if (error.code !== 'PGRST116') {
      console.error(`Error updating ${word}:`, error.message)
    }
    return false
  }
  return true
}

async function main() {
  console.log('LLM Linguistic Notes Upload')
  console.log('='.repeat(50))

  console.log(`\nLoading dictionary from ${DICTIONARY_PATH}...`)

  if (!fs.existsSync(DICTIONARY_PATH)) {
    console.error(`Dictionary file not found: ${DICTIONARY_PATH}`)
    process.exit(1)
  }

  const dictionary: Record<string, string> = JSON.parse(
    fs.readFileSync(DICTIONARY_PATH, 'utf-8')
  )

  const words = Object.keys(dictionary)
  console.log(`Loaded ${words.length} dictionary entries`)

  console.log('\nParsing entries...')

  const updates: Array<{
    word: string
    morphology: string | null
    patterns: string | null
    notes: string | null
  }> = []

  let morphCount = 0
  let patternCount = 0
  let notesCount = 0

  for (const word of words) {
    const entry = parseLLMEntry(dictionary[word])

    const morphology = cleanMorphology(entry.morphology)
    const patterns = entry.patterns || null
    const notes = entry.notes || null

    if (morphology) morphCount++
    if (patterns) patternCount++
    if (notes) notesCount++

    if (morphology || patterns || notes) {
      updates.push({ word, morphology, patterns, notes })
    }
  }

  console.log(`  Words with morphology: ${morphCount}`)
  console.log(`  Words with patterns: ${patternCount}`)
  console.log(`  Words with notes: ${notesCount}`)
  console.log(`  Total to update: ${updates.length}`)

  console.log('\nUploading to Supabase...')

  const batchSize = 100
  let successCount = 0
  let failCount = 0

  for (let i = 0; i < updates.length; i += batchSize) {
    const batch = updates.slice(i, i + batchSize)
    const batchNum = Math.floor(i / batchSize) + 1
    const totalBatches = Math.ceil(updates.length / batchSize)

    process.stdout.write(`\rBatch ${batchNum}/${totalBatches} (${i + batch.length}/${updates.length} words)...`)

    const results = await Promise.all(
      batch.map(({ word, morphology, patterns, notes }) =>
        updateWord(word, morphology, patterns, notes)
      )
    )

    successCount += results.filter(r => r).length
    failCount += results.filter(r => !r).length
  }

  console.log(`\n\nComplete!`)
  console.log(`  Updated: ${successCount} words`)
  console.log(`  Failed/Not found: ${failCount} words`)
}

main().catch(console.error)
