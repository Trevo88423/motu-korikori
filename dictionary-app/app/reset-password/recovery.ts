import { cookies } from 'next/headers'
import { createServerComponentClient } from '@/lib/supabase'
import { RECOVERY_COOKIE, isValidRecoveryMarker } from '@/lib/recovery-marker'

// True only when the signed-in session is the one that just verified a
// password-recovery link. Used by both the page and the server action, so the
// form can't be skipped by calling the action directly.
export async function hasRecoverySession() {
  const supabase = await createServerComponentClient()
  const { data } = await supabase.auth.getClaims()
  const userId = data?.claims.sub
  const sessionId = data?.claims.session_id
  if (!userId || !sessionId) return { supabase, ok: false }

  const marker = (await cookies()).get(RECOVERY_COOKIE)?.value
  return { supabase, ok: isValidRecoveryMarker(marker, userId, sessionId) }
}
