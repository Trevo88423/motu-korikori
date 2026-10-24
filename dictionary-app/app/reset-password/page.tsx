import { redirect } from 'next/navigation'
import ResetPasswordForm from './ResetPasswordForm'
import { hasRecoverySession } from './recovery'

export const dynamic = 'force-dynamic'

// Only reachable straight after a password-recovery link (issue #15); a
// normally signed-in session can't use this page to change the password.
export default async function ResetPasswordPage() {
  const { ok } = await hasRecoverySession()
  if (!ok) redirect('/forgot-password?error=recovery_link_required')

  return <ResetPasswordForm />
}
