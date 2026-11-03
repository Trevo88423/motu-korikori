// Credit the Motu Bible text wherever a verse is shown (#67). The licence is
// CC BY-NC-ND 4.0: attribution is required and the verse text is never edited.
// If truemotu.org ever charges money, see docs/DECISIONS.md first.

export const BIBLE_CREDIT = {
  motu: 'Motu Bible text © 1959–1973 Bible Society of Papua New Guinea',
  licence: 'CC BY-NC-ND 4.0',
  licenceUrl: 'https://creativecommons.org/licenses/by-nc-nd/4.0/',
  source: 'eBible.org',
  sourceUrl: 'https://ebible.org/meu/',
  english: 'English text: World English Bible (public domain)',
} as const

// The full credit as one line, for plain text (API responses, metadata)
export const BIBLE_CREDIT_TEXT =
  `${BIBLE_CREDIT.motu}, ${BIBLE_CREDIT.licence}, via ${BIBLE_CREDIT.source}. ${BIBLE_CREDIT.english}.`
