import { requireActiveUser } from '@/lib/auth'

export default async function ContributeLayout({
  children,
}: {
  children: React.ReactNode
}) {
  await requireActiveUser()

  return <>{children}</>
}
