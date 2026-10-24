/**
 * Consensus Calculation Algorithm
 *
 * This module calculates consensus translations for words based on community contributions.
 * It applies weighting based on contributor connection type and trust score.
 */

import { createAdminClient } from './supabase'
import type { ConnectionType, WordStatus, ContributionGroup } from './types'

interface ContributionData {
  id: string
  english_gloss: string
  audio_url: string | null
  is_excluded: boolean
  user_id: string
  agreement_type: 'full' | 'agree'
  profile: {
    connection_type: ConnectionType
    trust_score: number
  }
}

/**
 * Weight multipliers for different connection types
 */
const CONNECTION_WEIGHTS: Record<ConnectionType, number> = {
  native_speaker: 2.0,
  heritage_speaker: 1.5,
  second_language: 1.0,
  learning_now: 0.5,
  researcher: 1.0,
  other: 0.5,
}

/**
 * A gloss needs at least this many (non-excluded) contributors before it can
 * reach consensus. Each member has at most one contribution per word, so this
 * is a count of distinct people. Without it a single contribution has 100% of
 * the weighted votes and would count as consensus on its own.
 */
export const MIN_CONSENSUS_CONTRIBUTORS = 2

/**
 * Calculate weighted vote for a contribution
 */
function calculateWeight(connectionType: ConnectionType, trustScore: number): number {
  const connectionWeight = CONNECTION_WEIGHTS[connectionType]
  return connectionWeight * trustScore
}

/**
 * Group contributions by gloss and calculate weighted counts
 */
function groupContributions(contributions: ContributionData[]): ContributionGroup[] {
  const grouped = new Map<string, ContributionData[]>()

  // Group by gloss
  contributions.forEach((contrib) => {
    if (!contrib.is_excluded) {
      const existing = grouped.get(contrib.english_gloss) || []
      grouped.set(contrib.english_gloss, [...existing, contrib])
    }
  })

  // Calculate weighted counts
  const groups: ContributionGroup[] = []

  grouped.forEach((contribs, gloss) => {
    const weightedCount = contribs.reduce((sum, contrib) => {
      return sum + calculateWeight(
        contrib.profile.connection_type,
        contrib.profile.trust_score
      )
    }, 0)

    groups.push({
      gloss,
      count: contribs.length,
      full_count: contribs.filter((c) => c.agreement_type === 'full').length,
      agree_count: contribs.filter((c) => c.agreement_type === 'agree').length,
      weighted_count: weightedCount,
      contributors: contribs.map((c) => ({
        connection_type: c.profile.connection_type,
        trust_score: c.profile.trust_score,
        agreement_type: c.agreement_type,
      })),
      audio_urls: contribs
        .filter((c) => c.audio_url !== null)
        .map((c) => ({ url: c.audio_url!, user_id: c.user_id })),
    })
  })

  return groups.sort((a, b) => b.weighted_count - a.weighted_count)
}

/**
 * Determine consensus status based on contribution groups
 */
function determineConsensusStatus(groups: ContributionGroup[]): {
  status: WordStatus
  consensusGloss: string | null
  consensusConfidence: number
} {
  if (groups.length === 0) {
    return {
      status: 'pending',
      consensusGloss: null,
      consensusConfidence: 0,
    }
  }

  // Calculate total weighted votes
  const totalWeightedVotes = groups.reduce((sum, g) => sum + g.weighted_count, 0)

  // Top group
  const topGroup = groups[0]
  const topPercentage = topGroup.weighted_count / totalWeightedVotes

  // Check if there's a clear consensus (>60% of weighted votes, from enough people)
  if (topPercentage > 0.6 && topGroup.count >= MIN_CONSENSUS_CONTRIBUTORS) {
    return {
      status: 'consensus',
      consensusGloss: topGroup.gloss,
      consensusConfidence: topPercentage,
    }
  }

  // Check if it's flagged (top 2 within 10% of each other)
  if (groups.length >= 2) {
    const secondGroup = groups[1]
    const secondPercentage = secondGroup.weighted_count / totalWeightedVotes
    const difference = topPercentage - secondPercentage

    if (difference < 0.1) {
      return {
        status: 'flagged',
        consensusGloss: null,
        consensusConfidence: 0,
      }
    }
  }

  // No clear consensus, but has contributions. consensus_gloss stays empty:
  // the UI treats a stored gloss as "the consensus", so a leading but
  // unconfirmed gloss mustn't be stored there.
  return {
    status: 'pending',
    consensusGloss: null,
    consensusConfidence: 0,
  }
}

/**
 * Select consensus audio from the highest-weighted contributor
 * who provided the consensus gloss
 */
function selectConsensusAudio(
  consensusGloss: string | null,
  contributions: ContributionData[]
): string | null {
  if (!consensusGloss) return null

  // Filter contributions matching consensus gloss with audio
  const matchingWithAudio = contributions.filter(
    (c) => !c.is_excluded && c.english_gloss === consensusGloss && c.audio_url
  )

  if (matchingWithAudio.length === 0) return null

  // Sort by weight (highest first)
  const sorted = matchingWithAudio.sort((a, b) => {
    const weightA = calculateWeight(a.profile.connection_type, a.profile.trust_score)
    const weightB = calculateWeight(b.profile.connection_type, b.profile.trust_score)
    return weightB - weightA
  })

  return sorted[0].audio_url
}

type WordConsensusState = {
  status: WordStatus
  consensus_gloss: string | null
  consensus_audio_url: string | null
  consensus_confidence: number
}

/**
 * Recalculate one word and report whether its stored consensus changed.
 * Returns null on error.
 */
async function recalculateWord(wordId: string): Promise<{ changed: boolean } | null> {
  const supabase = createAdminClient()

  try {
    const { data: word, error: wordError } = await supabase
      .from('words')
      .select('status, consensus_gloss, consensus_audio_url, consensus_confidence')
      .eq('id', wordId)
      .single()

    if (wordError || !word) {
      console.error('Error fetching word:', wordError)
      return null
    }

    // Fetch all contributions for this word
    const { data: contributions, error: contributionsError } = await supabase
      .from('contributions')
      .select(`
        id,
        english_gloss,
        audio_url,
        is_excluded,
        user_id,
        agreement_type,
        matches_consensus,
        profile:profiles(connection_type, trust_score)
      `)
      .eq('word_id', wordId)

    if (contributionsError) {
      console.error('Error fetching contributions:', contributionsError)
      return null
    }

    const rows = (contributions || []) as any[]

    // Group and analyze contributions
    const groups = groupContributions(rows)
    let { status, consensusGloss, consensusConfidence } = determineConsensusStatus(groups)

    // An admin's "verified" stands until an admin changes it; the stored gloss
    // still follows the leading contribution so the word shows a translation.
    if (word.status === 'verified') {
      status = 'verified'
      if (groups.length > 0) {
        const total = groups.reduce((sum, g) => sum + g.weighted_count, 0)
        consensusGloss = groups[0].gloss
        consensusConfidence = groups[0].weighted_count / total
      } else {
        consensusGloss = word.consensus_gloss
        consensusConfidence = Number(word.consensus_confidence ?? 0)
      }
    }

    const next: WordConsensusState = {
      status,
      consensus_gloss: consensusGloss,
      consensus_audio_url: selectConsensusAudio(consensusGloss, rows),
      consensus_confidence: consensusConfidence,
    }

    const changed =
      word.status !== next.status ||
      word.consensus_gloss !== next.consensus_gloss ||
      word.consensus_audio_url !== next.consensus_audio_url ||
      Math.abs(Number(word.consensus_confidence ?? 0) - next.consensus_confidence) > 1e-6

    if (changed) {
      const { error: updateError } = await supabase
        .from('words')
        .update(next)
        .eq('id', wordId)

      if (updateError) {
        console.error('Error updating word:', updateError)
        return null
      }
    }

    // Update each contribution's matches_consensus flag (only the ones that differ).
    // An excluded contribution doesn't count towards consensus, so it never matches.
    const toTrue: string[] = []
    const toFalse: string[] = []
    for (const contrib of rows) {
      const matchesConsensus =
        !contrib.is_excluded && consensusGloss !== null && contrib.english_gloss === consensusGloss
      if (contrib.matches_consensus === matchesConsensus) continue
      if (matchesConsensus) toTrue.push(contrib.id)
      else toFalse.push(contrib.id)
    }

    for (const [ids, value] of [[toTrue, true], [toFalse, false]] as const) {
      if (ids.length === 0) continue
      const { error } = await supabase
        .from('contributions')
        .update({ matches_consensus: value })
        .in('id', ids)
      if (error) {
        console.error('Error updating matches_consensus:', error)
        return null
      }
    }

    return { changed }
  } catch (error) {
    console.error('Error calculating consensus:', error)
    return null
  }
}

/**
 * Calculate consensus for a specific word
 *
 * Uses the service-role client, so callers must authorise the request first
 * (a signed-in member whose own contribution write just succeeded, or an admin).
 * The result depends only on the stored contributions, so running it again is harmless.
 *
 * @param wordId - The UUID of the word to calculate consensus for
 * @returns Whether consensus was successfully calculated
 */
export async function calculateConsensus(wordId: string): Promise<boolean> {
  // Callers run this after the member's own write has already succeeded, so a
  // failure here must not surface as "your contribution failed". Log it and
  // report false; the admin "Recalculate consensus" backfill catches up.
  try {
    return (await recalculateWord(wordId)) !== null
  } catch (error) {
    console.error(`Consensus recalculation failed for word ${wordId}:`, error)
    return false
  }
}

/**
 * Recalculate consensus for every word that has at least one contribution.
 * Run from the admin panel (backfill, or after trust scores have moved).
 */
export async function recalculateAllConsensus(): Promise<{
  success: number
  failed: number
  changed: number
  total: number
}> {
  const supabase = createAdminClient()
  const PAGE = 1000
  const wordIds = new Set<string>()

  // PostgREST caps each response, so page through the contributions
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await supabase
      .from('contributions')
      .select('word_id')
      .order('id')
      .range(from, from + PAGE - 1)
    if (error) throw new Error(`Failed to list contributions: ${error.message}`)
    data.forEach((row) => wordIds.add(row.word_id))
    if (data.length < PAGE) break
  }

  const ids = Array.from(wordIds)
  let success = 0
  let failed = 0
  let changed = 0

  // Small batches keep the database load modest while finishing well inside
  // the function time limit
  const BATCH = 10
  for (let i = 0; i < ids.length; i += BATCH) {
    const results = await Promise.all(ids.slice(i, i + BATCH).map(recalculateWord))
    for (const result of results) {
      if (result === null) {
        failed++
      } else {
        success++
        if (result.changed) changed++
      }
    }
  }

  return { success, failed, changed, total: ids.length }
}

/**
 * Update user consensus rates
 * This can be run as a periodic job
 */
export async function updateUserConsensusRates(): Promise<number> {
  const supabase = createAdminClient()

  // Fetch all user IDs
  const { data: profiles } = await supabase.from('profiles').select('id, contribution_count')

  if (!profiles) return 0

  let updated = 0

  for (const profile of profiles) {
    if (profile.contribution_count === 0) continue

    // Count contributions matching consensus
    const { count: matchingCount } = await supabase
      .from('contributions')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', profile.id)
      .eq('matches_consensus', true)

    const consensusRate = matchingCount ? (matchingCount / profile.contribution_count) * 100 : 0

    await supabase
      .from('profiles')
      .update({ consensus_rate: consensusRate })
      .eq('id', profile.id)

    updated++
  }

  return updated
}
