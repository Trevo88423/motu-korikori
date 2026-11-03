import type { TrustLevel } from './types'

/**
 * The trust ladder (#53). Levels and trust_score are recomputed in the
 * database from each member's record (recompute_trust() in
 * supabase/migrations/20261103075931_trust_ladder.sql); the app only reads them.
 */
export const TRUST_LEVEL_LABELS: Record<TrustLevel, string> = {
  new: 'New contributor',
  member: 'Member',
  trusted_speaker: 'Trusted speaker',
  restricted: 'Restricted',
}

export const TRUST_LEVEL_HINTS: Record<TrustLevel, string> = {
  new: 'Your translations count once some of them match what other speakers agree on.',
  member: 'Your translations count fully.',
  trusted_speaker: 'Your translations and flags carry extra weight.',
  restricted: 'Your contributions are paused for now.',
}

/** Settings the admin page can change, grouped for display. */
export const TRUST_SETTING_KEYS = [
  'trust_base',
  'trust_per_match',
  'trust_match_cap',
  'trust_per_vote',
  'trust_vote_cap',
  'trust_per_hidden_item',
  'trust_max',
  'member_min_matches',
  'member_min_trust',
  'trusted_min_trust',
  'trust_level_weight_new',
  'trust_level_weight_member',
  'trust_level_weight_trusted_speaker',
  'trust_level_weight_restricted',
]
