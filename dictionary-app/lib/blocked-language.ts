import type { SupabaseClient } from '@supabase/supabase-js'

// The database refuses free text containing a blocked term (#54) with this
// SQLSTATE; see supabase/migrations/20261024174154_bad_language_filter.sql.
export const BLOCKED_LANGUAGE_CODE = 'TMBLK'

// Always this fixed text, never the database's error or the matched term.
export const BLOCKED_LANGUAGE_MESSAGE =
  "That text includes language we don't allow on True Motu. Please rephrase."

export type BlockedLanguageTable = 'contributions' | 'comments' | 'profiles'

export function isBlockedLanguageError(error: { code?: string } | null | undefined): boolean {
  return error?.code === BLOCKED_LANGUAGE_CODE
}

// The refused statement rolled back, so the attempt is logged with a separate
// call. The database re-checks the text and stores only who, where and when.
export async function logBlockedLanguageAttempt(
  supabase: SupabaseClient,
  table: BlockedLanguageTable,
  text: string
) {
  const { error } = await supabase.rpc('log_blocked_language_attempt', {
    p_table: table,
    p_text: text,
  })
  if (error) console.error('Error logging blocked language attempt:', error)
}
