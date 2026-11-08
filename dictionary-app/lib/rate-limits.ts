import type { SupabaseClient } from '@supabase/supabase-js'

// The database refuses a write past the member's daily limit (#55) with this
// SQLSTATE, the thing in `details` and the limit in `hint`; see
// supabase/migrations/20261108104508_daily_rate_limits.sql.
export const RATE_LIMIT_CODE = 'TMRAT'

export type RateLimitedThing = 'translations' | 'comments' | 'votes' | 'flags'

const NOUN: Record<RateLimitedThing, [singular: string, plural: string]> = {
  translations: ['translation', 'translations'],
  comments: ['comment', 'comments'],
  votes: ['vote', 'votes'],
  flags: ['flag', 'flags'],
}

const LEVELS = ['new', 'member', 'trusted_speaker', 'restricted'] as const

/** The daily caps the admin page can change: rate_<thing>_<level>. */
export const RATE_LIMIT_SETTING_KEYS = (Object.keys(NOUN) as RateLimitedThing[]).flatMap((thing) =>
  LEVELS.map((level) => `rate_${thing}_${level}`)
)

export const RATE_LIMIT_MAX = 10000

type DbError = { code?: string; details?: string | null; hint?: string | null }

export function isRateLimitError(error: DbError | null | undefined): boolean {
  return error?.code === RATE_LIMIT_CODE
}

function noun(thing: RateLimitedThing, n: number) {
  return NOUN[thing][n === 1 ? 0 : 1]
}

// Plain words for an elder on a phone: what happened, and when it's back.
export function rateLimitMessage(error: DbError, fallback: RateLimitedThing): string {
  const thing = (error.details && error.details in NOUN ? error.details : fallback) as RateLimitedThing
  const limit = error.hint ? Number(error.hint) : NaN

  if (limit <= 0) {
    const plural = noun(thing, 2)
    return `${plural[0].toUpperCase()}${plural.slice(1)} are paused on your account for now.`
  }
  const reached = Number.isFinite(limit)
    ? `You've reached today's limit of ${limit} ${noun(thing, limit)}.`
    : `You've reached today's limit for ${noun(thing, 2)}.`
  return `${reached} Thank you for all your help! You can carry on tomorrow.`
}

export interface DailyLimit {
  thing: RateLimitedThing
  limit_per_day: number | null
  used: number
  remaining: number | null
}

// The signed-in member's limits for today, by thing. Empty if not signed in
// or the call fails; the database still enforces the limits either way.
export async function getMyDailyLimits(
  supabase: SupabaseClient
): Promise<Partial<Record<RateLimitedThing, DailyLimit>>> {
  const { data, error } = await supabase.rpc('my_daily_limits')
  if (error) {
    console.error('Error loading daily limits:', error)
    return {}
  }
  return Object.fromEntries(((data ?? []) as DailyLimit[]).map((row) => [row.thing, row]))
}
