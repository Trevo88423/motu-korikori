// Enums matching database types
export type ConnectionType =
  | 'native_speaker'
  | 'heritage_speaker'
  | 'second_language'
  | 'learning_now'
  | 'researcher'
  | 'other';

export type AgeRange =
  | 'under_18'
  | '18_24'
  | '25_34'
  | '35_44'
  | '45_54'
  | '55_64'
  | '65_plus'
  | 'prefer_not_to_say';

export type UserStatus = 'active' | 'warned' | 'suspended' | 'banned';

export type WordStatus = 'pending' | 'consensus' | 'verified' | 'flagged';

// 'name' is a personal or place name (mostly from the Bible), not Motu
// vocabulary: kept out of Contribute and counted separately (#75)
export type WordType = 'vocabulary' | 'name';

export type ConfidenceLevel = 'certain' | 'somewhat_certain' | 'unsure';

export type ModerationAction =
  | 'warn'
  | 'suspend'
  | 'ban'
  | 'reinstate'
  | 'exclude_from_ai'
  | 'exclude_contributions'
  | 'verify_word'
  | 'flag_word'
  | 'unflag_word'
  | 'restore_content'
  | 'confirm_hide'
  | 'grant_admin'
  | 'revoke_admin'
  | 'set_word_type';

// Database table types
export interface Profile {
  id: string;
  name: string;
  display_name: string; // shown publicly; name is private (#13)
  email: string;
  age_range: AgeRange;
  locations: string[];
  connection_type: ConnectionType;
  who_taught: string | null;
  consent_tos: boolean;
  consent_dictionary: boolean;
  consent_ai_training: boolean;
  is_18_or_older: boolean;
  guardian_name: string | null;
  guardian_email: string | null;
  trust_score: number;
  contribution_count: number;
  consensus_rate: number;
  streak_days: number;
  last_contribution_date: string | null;
  status: UserStatus;
  is_admin: boolean;
  contributions_excluded: boolean;
  excluded_from_ai: boolean;
  created_at: string;
  updated_at: string;
}

export interface Word {
  id: string;
  motu_word: string;
  frequency: number;
  example_reference: string | null;
  example_motu: string | null;
  example_english: string | null;
  suggested_translations: string[];
  status: WordStatus;
  word_type: WordType;
  consensus_gloss: string | null;
  consensus_audio_url: string | null;
  consensus_confidence: number;
  total_contributions: number;
  unique_contributors: number;
  ai_morphology: string | null;
  ai_patterns: string | null;
  ai_notes: string | null;
  created_at: string;
  updated_at: string;
}

// True for a personal or place name. Use this (not the raw column) wherever
// vocabulary and names are treated differently, e.g. leaving names out of
// structured data that presents words as Motu vocabulary (#65).
export function isName(word: Pick<Word, 'word_type'>): boolean {
  return word.word_type === 'name';
}

export interface Contribution {
  id: string;
  word_id: string;
  user_id: string;
  english_gloss: string;
  audio_url: string | null;
  confidence: ConfidenceLevel;
  notes: string | null;
  is_excluded: boolean;
  // Hidden by weighted flags (#56); only the author and admins can see it
  is_hidden: boolean;
  flag_count: number;
  flag_weight: number;
  hidden_at: string | null;
  hide_confirmed_at: string | null;
  matches_consensus: boolean | null;
  upvote_count: number;
  net_votes: number;
  agreement_type: 'full' | 'agree'; // full = complete contribution, agree = lightweight agreement
  created_at: string;
  updated_at: string;
}

export interface Comment {
  id: string;
  word_id: string;
  user_id: string;
  comment_text: string;
  // Hidden by weighted flags; only the author and admins can see it
  is_flagged: boolean;
  flag_count: number;
  flag_weight: number;
  hidden_at: string | null;
  hide_confirmed_at: string | null;
  upvote_count: number;
  downvote_count: number;
  net_votes: number;
  created_at: string;
  updated_at: string;
}

export interface CommentVote {
  id: string;
  comment_id: string;
  user_id: string;
  vote_type: 1 | -1; // 1 = upvote, -1 = downvote
  created_at: string;
}

export interface ContributionVote {
  id: string;
  contribution_id: string;
  user_id: string;
  created_at: string;
}

export interface ModerationLog {
  id: string;
  admin_id: string;
  target_user_id: string | null;
  target_word_id: string | null;
  action: ModerationAction;
  reason: string;
  created_at: string;
}

// Extended types for UI components
export interface WordWithContributions extends Word {
  contributions?: ContributionWithProfile[];
}

export interface ContributionWithProfile extends Contribution {
  profile?: Pick<Profile, 'display_name' | 'connection_type' | 'trust_score'>;
}

export interface CommentWithProfile extends Comment {
  profile?: Pick<Profile, 'display_name' | 'connection_type' | 'trust_score'>;
  user_vote?: 1 | -1 | null; // Current user's vote on this comment
}

export interface ProfileStats {
  total_contributions: number;
  consensus_rate: number;
  streak_days: number;
  progress_percentage: number;
  recent_contributions: ContributionWithWord[];
}

export interface ContributionWithWord extends Contribution {
  word?: Pick<Word, 'motu_word' | 'consensus_gloss'>;
}

// Form types
export interface SignupFormData {
  email: string;
  password: string;
  name: string;
  display_name?: string;
  age_range: AgeRange;
  locations: string[];
  connection_type: ConnectionType;
  who_taught: string;
  consent_tos: boolean;
  consent_dictionary: boolean;
  consent_ai_training: boolean;
  is_18_or_older: boolean;
  guardian_name?: string;
  guardian_email?: string;
}

export interface ContributionFormData {
  word_id: string;
  english_gloss: string;
  audio_url?: string;
  confidence: ConfidenceLevel; // Keep for now during migration
  notes?: string; // Keep for now during migration
}

export interface CommentFormData {
  word_id: string;
  comment_text: string;
}

export interface VoteAction {
  target_id: string; // contribution_id or comment_id
  vote_type?: 1 | -1; // For comments: 1 = upvote, -1 = downvote
}

// Consensus calculation types
export interface ContributionGroup {
  gloss: string;
  count: number; // Total contributors
  full_count: number; // Full contributions
  agree_count: number; // Agreement clicks
  weighted_count: number;
  contributors: {
    connection_type: ConnectionType;
    trust_score: number;
    agreement_type: 'full' | 'agree';
  }[];
  audio_urls: { url: string; user_id: string }[]; // Track which user uploaded each audio
  user_agreed?: boolean; // Whether current user agreed with this
}

export interface ConsensusResult {
  status: WordStatus;
  consensus_gloss: string | null;
  consensus_audio_url: string | null;
  consensus_confidence: number;
  groups: ContributionGroup[];
}

// Component prop types
export interface WordCardProps {
  word: Word;
  userContribution?: Contribution;
  allContributions: ContributionWithProfile[];
  onSubmit: (data: ContributionFormData) => Promise<void>;
}

export interface ConsensusBarProps {
  contributions: ContributionGroup[];
  status: WordStatus;
  currentConsensus: string | null;
}

export interface AudioRecorderProps {
  onRecordingComplete: (blob: Blob) => void;
  onAudioUrlChange: (url: string | null) => void;
}

// API response types
export interface ApiResponse<T = any> {
  data?: T;
  error?: string;
}
