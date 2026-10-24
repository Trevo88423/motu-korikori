import { requireActiveUser } from '@/lib/auth'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  await requireActiveUser()

  return <>{children}</>
}
