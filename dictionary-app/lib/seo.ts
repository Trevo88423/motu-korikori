// What search engines and AI see (#65, decision 2026-10-24 in docs/DECISIONS.md).
// Only consensus or verified meanings are published as "the" meaning. Pending
// community suggestions and the AI suggested_translations never are.

import { isName } from './types'
import type { Word } from './types'

export const SITE_URL = 'https://truemotu.org'
export const SITE_NAME = 'True Motu Dictionary'

// Every page names the language this way: True Motu, not Hiri Motu (principle 2)
export const LANGUAGE_NAME = 'True Motu (Motu korikori)'
export const LANGUAGE_CODE = 'meu'

export const SITE_DESCRIPTION =
  'A community-built dictionary of True Motu (Motu korikori, ISO 639-3 meu), the language of the ' +
  'Port Moresby region of Papua New Guinea. Not Hiri Motu. Meanings are agreed by fluent speakers.'

export const DICTIONARY_SET_ID = `${SITE_URL}/dictionary`

// The meaning speakers agreed on, or null while the word is pending or flagged
export function agreedMeaning(word: Pick<Word, 'status' | 'consensus_gloss'>): string | null {
  if (word.status !== 'consensus' && word.status !== 'verified') return null
  return word.consensus_gloss?.trim() || null
}

// Bible personal and place names (words.word_type = 'name', #75) get no
// structured data: they aren't Motu vocabulary
export { isName }

export function wordUrl(id: string): string {
  return `${SITE_URL}/dictionary/${id}`
}

export function wordTitle(motuWord: string): string {
  return `${motuWord}: ${LANGUAGE_NAME} → English`
}

export function wordDescription(word: Pick<Word, 'motu_word' | 'status' | 'consensus_gloss'>): string {
  const meaning = agreedMeaning(word)
  if (!meaning) {
    return (
      `Help translate ${word.motu_word}, a True Motu word. Not yet confirmed by speakers. ` +
      'True Motu (Motu korikori, ISO 639-3 meu) is not Hiri Motu.'
    )
  }
  const agreedBy = word.status === 'verified' ? 'verified by speakers' : 'agreed by the community of speakers'
  return (
    `${word.motu_word} means "${meaning}" in True Motu (Motu korikori, ISO 639-3 meu), ${agreedBy}. ` +
    'Not Hiri Motu.'
  )
}

// schema.org DefinedTerm for an agreed vocabulary word; null for pending words
// and names, which get no structured data
export function definedTermJsonLd(word: Word): Record<string, unknown> | null {
  const meaning = agreedMeaning(word)
  if (!meaning || isName(word)) return null

  return {
    '@context': 'https://schema.org',
    '@type': 'DefinedTerm',
    '@id': wordUrl(word.id),
    name: word.motu_word,
    description: meaning,
    inLanguage: LANGUAGE_CODE,
    url: wordUrl(word.id),
    inDefinedTermSet: {
      '@type': 'DefinedTermSet',
      '@id': DICTIONARY_SET_ID,
      name: SITE_NAME,
    },
  }
}

export function definedTermSetJsonLd(): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'DefinedTermSet',
    '@id': DICTIONARY_SET_ID,
    name: SITE_NAME,
    description: SITE_DESCRIPTION,
    url: DICTIONARY_SET_ID,
    inLanguage: LANGUAGE_CODE,
  }
}

// For <script type="application/ld+json">: escapes "<" so a word or gloss
// can't close the script tag
export function jsonLdScript(data: Record<string, unknown>): string {
  return JSON.stringify(data).replace(/</g, '\\u003c')
}
