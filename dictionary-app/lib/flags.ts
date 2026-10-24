// Flag reasons (#56). Must match flag_reason_allowed() in
// supabase/migrations/20261024151000_weighted_flags.sql.
//
// There is no "I disagree" reason on purpose: a different translation can be a
// real regional or family variant (docs/PHILOSOPHY.md, principle 3). Members
// who disagree add their own translation or agree with another one.

export type FlagKind = 'contribution' | 'comment'

export type FlagReason = 'offensive' | 'spam' | 'deliberately_wrong' | 'not_true_motu' | 'off_topic'

export const FLAG_REASONS: Record<FlagKind, { value: FlagReason; label: string }[]> = {
  contribution: [
    { value: 'offensive', label: 'Offensive or rude' },
    { value: 'spam', label: 'Spam or junk' },
    { value: 'deliberately_wrong', label: 'Deliberately wrong (a joke or sabotage)' },
    { value: 'not_true_motu', label: 'Not True Motu (English, Tok Pisin or Hiri Motu)' },
  ],
  comment: [
    { value: 'offensive', label: 'Offensive or rude' },
    { value: 'spam', label: 'Spam or junk' },
    { value: 'off_topic', label: 'Off-topic' },
  ],
}

export function flagReasonLabel(reason: string | null): string {
  if (!reason) return 'No reason (older flag)'
  for (const list of Object.values(FLAG_REASONS)) {
    const found = list.find((r) => r.value === reason)
    if (found) return found.label
  }
  return reason
}
