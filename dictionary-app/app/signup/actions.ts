'use server'

import { createClient } from '@supabase/supabase-js'

// Create a service role client for admin operations during signup
const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
)

export interface SignupData {
  userId: string
  email: string
  name: string
  age_range: string
  locations: string[]
  connection_type: string
  who_taught: string
  consent_tos: boolean
  consent_dictionary: boolean
  consent_ai_training: boolean
  is_18_or_older: boolean
  guardian_name?: string
  guardian_email?: string
  guardian_consent?: boolean
}

export async function createUserProfile(data: SignupData) {
  try {
    // Use service role to bypass RLS during profile creation
    const { error } = await supabaseAdmin
      .from('profiles')
      .insert({
        id: data.userId,
        email: data.email,
        name: data.name,
        age_range: data.age_range,
        locations: data.locations,
        connection_type: data.connection_type,
        who_taught: data.who_taught,
        consent_tos: data.consent_tos,
        consent_dictionary: data.consent_dictionary,
        consent_ai_training: data.consent_ai_training,
        is_18_or_older: data.is_18_or_older,
        guardian_name: data.guardian_name,
        guardian_email: data.guardian_email,
        guardian_consent: data.guardian_consent,
        status: 'active',
        trust_score: 1.0,
        contribution_count: 0,
        is_admin: false
      })

    if (error) {
      console.error('Profile creation error:', error)
      return { success: false, error: error.message }
    }

    return { success: true }
  } catch (error: any) {
    console.error('Unexpected error:', error)
    return { success: false, error: error.message }
  }
}
