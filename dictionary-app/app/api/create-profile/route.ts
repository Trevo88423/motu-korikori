import { NextRequest, NextResponse } from 'next/server'
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

export async function POST(request: NextRequest) {
  try {
    const data = await request.json()

    // Validate required fields
    if (!data.userId || !data.email || !data.name) {
      return NextResponse.json(
        { success: false, error: 'Missing required fields' },
        { status: 400 }
      )
    }

    // Use service role to bypass RLS during profile creation
    const { error } = await supabaseAdmin
      .from('profiles')
      .insert({
        id: data.userId,
        email: data.email,
        name: data.name,
        age_range: data.age_range,
        locations: data.locations || [],
        connection_type: data.connection_type,
        who_taught: data.who_taught || '',
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
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 500 }
      )
    }

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Unexpected error:', error)
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 500 }
    )
  }
}
