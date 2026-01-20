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

export type ConfidenceLevel = 'certain' | 'somewhat_certain' | 'unsure';

export type ModerationAction =
  | 'warn'
  | 'suspend'
  | 'ban'
  | 'exclude_from_ai'
  | 'exclude_contributions'
  | 'verify_word'
  | 'flag_word'
  | 'unflag_word';

// Database table types
export interface Profile {
  id: string;
  name: string;
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
  consensus_gloss: string | null;
  consensus_audio_url: string | null;
  consensus_confidence: number;
  total_contributions: number;
  unique_contributors: number;
  created_at: string;
  updated_at: string;
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
  matches_consensus: boolean | null;
  created_at: string;
  updated_at: string;
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
  profile?: Pick<Profile, 'name' | 'connection_type' | 'trust_score'>;
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
  confidence: ConfidenceLevel;
  notes?: string;
}

// Consensus calculation types
export interface ContributionGroup {
  gloss: string;
  count: number;
  weighted_count: number;
  contributors: {
    connection_type: ConnectionType;
    trust_score: number;
  }[];
  audio_urls: string[];
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
