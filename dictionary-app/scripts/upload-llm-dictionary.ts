/**
 * Upload LLM-generated dictionary entries to Supabase
 *
 * This script:
 * 1. Reads the llm_dictionary_full.json file
 * 2. Parses each entry to extract the translation
 * 3. Updates the suggested_translations field in Supabase
 */

import { createClient } from '@supabase/supabase-js'
import * as fs from 'fs'
import * as path from 'path'
import * as dotenv from 'dotenv'
import { fileURLToPath } from 'url'

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Load environment variables from .env.local
dotenv.config({ path: path.join(__dirname, '../.env.local') })

// Environment variables
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing required environment variables:')
  console.error('   - NEXT_PUBLIC_SUPABASE_URL')
  console.error('   - SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// Path to the LLM dictionary
const DICTIONARY_PATH = path.join(__dirname, '../../../Kindred/Developer version/llm_dictionary_full.json')

interface DictionaryEntry {
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
function parseLLMEntry(text: string): DictionaryEntry {
  const result: DictionaryEntry = {
    translation: '',
    type: '',
    confidence: '',
    morphology: '',
    patterns: '',
    notes: ''
  }

  // Match patterns like **TRANSLATION:** or TRANSLATION:
  const patterns: Record<keyof DictionaryEntry, RegExp> = {
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
      // Clean up markdown artifacts
      value = value.replace(/\*\*/g, '')
      value = value.replace(/\n+/g, ' ')
      result[field as keyof DictionaryEntry] = value
    }
  }

  return result
}

/**
 * Extract a clean, concise translation for the suggestion button
 */
function extractSuggestion(entry: DictionaryEntry): string {
  let translation = entry.translation

  // For grammatical particles, extract the label and brief description
  // e.g., "TAM (past/realis tense-aspect marker)" -> "TAM - past tense marker"
  // e.g., "ERG (ergative/agent marker)" -> "ERG - agent marker"

  const gramMatch = translation.match(/^([A-Z]{2,5})\s*[-\u2013]?\s*\(?([^)]+)\)?/)
  if (gramMatch) {
    const abbrev = gramMatch[1]
    let desc = gramMatch[2]
    // Shorten the description
    desc = desc.replace(/tense-aspect/gi, 'tense')
    desc = desc.replace(/ergative\/agent/gi, 'agent')
    desc = desc.replace(/third person singular/gi, '3SG')
    desc = desc.replace(/second person singular/gi, '2SG')
    desc = desc.replace(/first person singular/gi, '1SG')
    desc = desc.replace(/\s+marker$/i, '')
    return `${abbrev} (${desc})`
  }

  // For content words, just use the translation (possibly truncated)
  // e.g., "people, persons (plural)" -> "people, persons"
  translation = translation.replace(/\s*\([^)]*plural[^)]*\)/gi, '')

  // Truncate if too long
  if (translation.length > 50) {
    translation = translation.substring(0, 47) + '...'
  }

  return translation
}

/**
 * Update database with LLM-generated suggestion
 */
async function updateWordSuggestion(word: string, suggestions: string[]): Promise<boolean> {
  const { error } = await supabase
    .from('words')
    .update({ suggested_translations: suggestions })
    .eq('motu_word', word)

  if (error) {
    // Word might not exist in database, that's okay
    if (error.code !== 'PGRST116') {
      console.error(`Error updating ${word}:`, error.message)
    }
    return false
  }
  return true
}

// Main execution
async function main() {
  console.log('LLM Dictionary Upload to Supabase')
  console.log('='.repeat(50))

  // Load the LLM dictionary
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

  // Process entries and prepare updates
  console.log('\nParsing entries and preparing updates...')

  const updates: Array<{ word: string; suggestions: string[] }> = []

  for (const word of words) {
    const entry = parseLLMEntry(dictionary[word])
    const suggestion = extractSuggestion(entry)

    if (suggestion) {
      // Create array with LLM suggestion as first item
      // Keep it as single suggestion since it's the analyzed result
      updates.push({
        word,
        suggestions: [suggestion]
      })
    }
  }

  console.log(`Prepared ${updates.length} updates`)

  // Upload in batches
  console.log('\nUploading to Supabase...')

  const batchSize = 100
  let successCount = 0
  let failCount = 0

  for (let i = 0; i < updates.length; i += batchSize) {
    const batch = updates.slice(i, i + batchSize)
    const batchNum = Math.floor(i / batchSize) + 1
    const totalBatches = Math.ceil(updates.length / batchSize)

    process.stdout.write(`\rBatch ${batchNum}/${totalBatches} (${i + batch.length}/${updates.length} words)...`)

    // Process batch concurrently with limit
    const results = await Promise.all(
      batch.map(({ word, suggestions }) => updateWordSuggestion(word, suggestions))
    )

    successCount += results.filter(r => r).length
    failCount += results.filter(r => !r).length
  }

  console.log(`\n\nComplete!`)
  console.log(`  Updated: ${successCount} words`)
  console.log(`  Failed/Not found: ${failCount} words`)
  console.log(`\nThe suggested_translations field has been updated in the database.`)
}

main().catch(console.error)
