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

  // Check if there's a clear consensus (>60% of weighted votes)
  if (topPercentage > 0.6) {
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

  // No clear consensus, but has contributions
  return {
    status: 'pending',
    consensusGloss: topGroup.gloss,
    consensusConfidence: topPercentage,
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

/**
 * Calculate consensus for a specific word
 *
 * @param wordId - The UUID of the word to calculate consensus for
 * @returns Whether consensus was successfully calculated
 */
export async function calculateConsensus(wordId: string): Promise<boolean> {
  const supabase = createAdminClient()

  try {
    // Fetch all contributions for this word
    const { data: contributions, error: contributionsError } = await supabase
      .from('contributions')
      .select(`
        id,
        english_gloss,
        audio_url,
        is_excluded,
        user_id,
        profile:profiles(connection_type, trust_score)
      `)
      .eq('word_id', wordId)

    if (contributionsError) {
      console.error('Error fetching contributions:', contributionsError)
      return false
    }

    if (!contributions || contributions.length === 0) {
      // No contributions yet
      await supabase
        .from('words')
        .update({
          status: 'pending',
          consensus_gloss: null,
          consensus_audio_url: null,
          consensus_confidence: 0,
        })
        .eq('id', wordId)

      return true
    }

    // Group and analyze contributions
    const groups = groupContributions(contributions as any)
    const { status, consensusGloss, consensusConfidence } = determineConsensusStatus(groups)

    // Select consensus audio
    const consensusAudioUrl = selectConsensusAudio(consensusGloss, contributions as any)

    // Update word status
    const { error: updateError } = await supabase
      .from('words')
      .update({
        status,
        consensus_gloss: consensusGloss,
        consensus_audio_url: consensusAudioUrl,
        consensus_confidence: consensusConfidence,
      })
      .eq('id', wordId)

    if (updateError) {
      console.error('Error updating word:', updateError)
      return false
    }

    // Update each contribution's matches_consensus flag
    for (const contrib of contributions as any) {
      if (!contrib.is_excluded) {
        const matchesConsensus = consensusGloss !== null && contrib.english_gloss === consensusGloss

        await supabase
          .from('contributions')
          .update({ matches_consensus: matchesConsensus })
          .eq('id', contrib.id)
      }
    }

    return true
  } catch (error) {
    console.error('Error calculating consensus:', error)
    return false
  }
}

/**
 * Recalculate consensus for all words
 * This can be run as a periodic job
 */
export async function recalculateAllConsensus(): Promise<{
  success: number
  failed: number
  total: number
}> {
  const supabase = createAdminClient()

  // Fetch all word IDs
  const { data: words } = await supabase.from('words').select('id')

  if (!words) {
    return { success: 0, failed: 0, total: 0 }
  }

  let success = 0
  let failed = 0

  for (const word of words) {
    const result = await calculateConsensus(word.id)
    if (result) {
      success++
    } else {
      failed++
    }
  }

  return { success, failed, total: words.length }
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
