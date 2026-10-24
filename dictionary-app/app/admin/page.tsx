import { requireActiveUser } from '@/lib/auth'
import { createAdminClient } from '@/lib/supabase'
import Link from 'next/link'
import { verifyWord, flagWord, unflagWord, warnUser, suspendUser, banUser, reinstateUser, excludeFromAI, excludeAllContributions, restoreHidden, confirmHidden, updateModerationSetting } from './actions'
import { flagReasonLabel } from '@/lib/flags'
import RecalculateConsensusButton from './RecalculateConsensusButton'
import AdminRoleButton from './AdminRoleButton'

export const dynamic = 'force-dynamic'
// The consensus backfill action runs from this page and can take a while
export const maxDuration = 300

// "Spam or junk ×2, Offensive or rude ×1" from the flags no admin has decided yet
function summariseReasons(flags: { reason: string | null; outcome: string }[] | null) {
  const counts = new Map<string, number>()
  for (const f of flags || []) {
    if (f.outcome !== 'pending') continue
    const label = flagReasonLabel(f.reason)
    counts.set(label, (counts.get(label) || 0) + 1)
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([label, n]) => `${label} ×${n}`)
    .join(', ')
}

function formatDate(value: string) {
  return new Date(value).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
}

// ilike treats % and _ as wildcards; a search for "a_b" means those letters
function escapeLike(value: string) {
  return value.replace(/[\\%_]/g, (c) => `\\${c}`)
}

export default async function AdminPage({
  searchParams,
}: {
  searchParams: Promise<{ member?: string | string[] }>
}) {
  const { supabase, profile } = await requireActiveUser({ requireAdmin: true })

  // Admins and appointments (#64). is_admin and admin_appointments aren't
  // readable with a member's key, so these go through the service role, after
  // the admin check above.
  const adminDb = createAdminClient()
  const { member } = await searchParams
  const memberQuery = (Array.isArray(member) ? member[0] : member)?.trim().slice(0, 100) ?? ''

  const [{ data: admins }, { data: appointments }, { data: memberResults }] = await Promise.all([
    adminDb
      .from('profiles')
      .select('id, display_name')
      .eq('is_admin', true)
      .order('display_name', { ascending: true }),
    adminDb
      .from('admin_appointments')
      .select('user_id, appointed_at, welcomed_at, appointer:profiles!admin_appointments_appointed_by_fkey(display_name)'),
    memberQuery
      ? adminDb
          .from('profiles')
          .select('id, display_name, status, is_admin')
          .ilike('display_name', `%${escapeLike(memberQuery)}%`)
          .order('display_name', { ascending: true })
          .limit(10)
      : Promise.resolve({ data: null }),
  ])

  const appointmentFor = new Map<string, any>((appointments || []).map((a: any) => [a.user_id, a]))
  const myAppointment = appointmentFor.get(profile.id)

  // The first visit after being appointed shows a welcome, once
  const showWelcome = !!myAppointment && !myAppointment.welcomed_at
  if (showWelcome) {
    await adminDb
      .from('admin_appointments')
      .update({ welcomed_at: new Date().toISOString() })
      .eq('user_id', profile.id)
  }

  // Items hidden by flags that no admin has decided on yet (#56). Admins can
  // read hidden rows and their flags through RLS.
  const [{ data: hiddenContributions }, { data: hiddenComments }, { data: moderationSettings }] =
    await Promise.all([
      supabase
        .from('contributions')
        .select(`
          id, word_id, english_gloss, flag_count, flag_weight, hidden_at,
          word:words(motu_word),
          profile:profiles(display_name),
          flags:contribution_flags(reason, outcome)
        `)
        .eq('is_hidden', true)
        .is('hide_confirmed_at', null)
        .order('hidden_at', { ascending: false })
        .limit(50),
      supabase
        .from('comments')
        .select(`
          id, word_id, comment_text, flag_count, flag_weight, hidden_at,
          word:words(motu_word),
          profile:profiles(display_name),
          flags:comment_flags(reason, outcome)
        `)
        .eq('is_flagged', true)
        .is('hide_confirmed_at', null)
        .order('hidden_at', { ascending: false })
        .limit(50),
      supabase
        .from('moderation_settings')
        .select('key, value, description')
        .order('key'),
    ])

  const hiddenItems = [
    ...(hiddenContributions || []).map((c: any) => ({ ...c, kind: 'contribution' as const, text: c.english_gloss })),
    ...(hiddenComments || []).map((c: any) => ({ ...c, kind: 'comment' as const, text: c.comment_text })),
  ].sort((a, b) => (b.hidden_at || '').localeCompare(a.hidden_at || ''))

  // Fetch flagged words
  const { data: flaggedWords } = await supabase
    .from('words')
    .select('*')
    .eq('status', 'flagged')
    .order('updated_at', { ascending: false })
    .limit(20)

  // Fetch low trust users
  const { data: lowTrustUsers } = await supabase
    .from('profiles')
    .select('id, display_name, connection_type, trust_score, contribution_count, status')
    .lt('trust_score', 0.7)
    .order('trust_score', { ascending: true })
    .limit(20)

  // Suspended and banned members, so they can be reinstated
  const { data: inactiveUsers } = await supabase
    .from('profiles')
    .select('id, display_name, connection_type, status')
    .in('status', ['suspended', 'banned'])
    .order('display_name', { ascending: true })
    .limit(50)

  // Fetch recent moderation log
  const { data: moderationLog } = await supabase
    .from('moderation_log')
    .select(`
      *,
      admin:profiles!moderation_log_admin_id_fkey(display_name),
      target_user:profiles!moderation_log_target_user_id_fkey(display_name),
      target_word:words(motu_word)
    `)
    .order('created_at', { ascending: false })
    .limit(50)

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Admin Panel</h1>
        <p className="text-gray-600 mt-2">Moderate content and manage users</p>
      </div>

      {showWelcome && (
        <div role="status" className="mb-8 p-4 bg-primary-50 border border-primary-200 rounded-lg">
          <h2 className="font-bold text-gray-900">Welcome, you're now an admin</h2>
          <p className="text-sm text-gray-700 mt-1">
            {myAppointment.appointer?.display_name ?? 'Another admin'} made you an admin on{' '}
            {formatDate(myAppointment.appointed_at)}. From this page you can verify and unflag words,
            warn, suspend and ban members, and appoint other admins. Most problems are handled by the
            community's own signals; this page is for the exceptions.
          </p>
        </div>
      )}

      {/* Tabs */}
      <div className="mb-8">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            <a href="#hidden-by-flags" className="border-b-2 border-primary-500 py-4 px-1 text-sm font-medium text-primary-600">
              Hidden by Flags
            </a>
            <a href="#flagged-words" className="border-transparent py-4 px-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300">
              Flagged Words
            </a>
            <a href="#low-trust" className="border-transparent py-4 px-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300">
              Low Trust Users
            </a>
            <a href="#inactive-users" className="border-transparent py-4 px-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300">
              Suspended and Banned
            </a>
            <a href="#admins" className="border-transparent py-4 px-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300">
              Admins
            </a>
            <a href="#moderation-log" className="border-transparent py-4 px-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300">
              Moderation Log
            </a>
          </nav>
        </div>
      </div>

      {/* Hidden by Flags Section */}
      <div id="hidden-by-flags" className="mb-12">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-2">
            Hidden by Flags ({hiddenItems.length})
          </h2>
          <p className="text-sm text-gray-600 mb-6">
            The community hid these automatically. Nothing needs doing unless one looks wrong.
            Restoring brings it back and lowers the flaggers&apos; future flag weight; confirming
            keeps it hidden and takes it off this list.
          </p>

          {hiddenItems.length > 0 ? (
            <div className="space-y-4">
              {hiddenItems.map((item: any) => (
                <div key={`${item.kind}-${item.id}`} className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
                  <div className="mb-3 min-w-0">
                    <p className="text-xs font-medium uppercase text-amber-800">
                      {item.kind === 'contribution' ? 'Translation' : 'Comment'} on{' '}
                      <Link href={`/dictionary/${item.word_id}`} className="text-primary-600 hover:underline normal-case">
                        {item.word?.motu_word}
                      </Link>
                    </p>
                    <p className="text-gray-900 mt-1 break-words">{item.text}</p>
                    <p className="text-sm text-gray-600 mt-1">
                      By {item.profile?.display_name || 'unknown'} •{' '}
                      {item.flag_count} {item.flag_count === 1 ? 'flag' : 'flags'} (weight {Number(item.flag_weight).toFixed(2)})
                      {item.hidden_at && <> • hidden {new Date(item.hidden_at).toLocaleDateString()}</>}
                    </p>
                    <p className="text-sm text-gray-700 mt-1">
                      Reasons: {summariseReasons(item.flags) || 'none recorded'}
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <form action={restoreHidden}>
                      <input type="hidden" name="kind" value={item.kind} />
                      <input type="hidden" name="targetId" value={item.id} />
                      <button type="submit" className="btn btn-primary text-sm">
                        Restore
                      </button>
                    </form>
                    <form action={confirmHidden}>
                      <input type="hidden" name="kind" value={item.kind} />
                      <input type="hidden" name="targetId" value={item.id} />
                      <button type="submit" className="btn btn-ghost text-sm text-red-600">
                        Confirm hide
                      </button>
                    </form>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-8">Nothing hidden by flags</p>
          )}

          {moderationSettings && moderationSettings.length > 0 && (
            <details className="mt-6 border-t pt-4">
              <summary className="text-sm font-medium text-gray-700 cursor-pointer">Flag settings</summary>
              <div className="mt-3 space-y-3">
                {moderationSettings.map((setting: any) => (
                  <form key={setting.key} action={updateModerationSetting} className="flex flex-wrap items-end gap-2">
                    <input type="hidden" name="key" value={setting.key} />
                    <label className="flex-1 min-w-[12rem] text-sm text-gray-700">
                      {setting.description}
                      <input
                        type="number"
                        name="value"
                        step="0.05"
                        min="0"
                        defaultValue={setting.value}
                        className="input mt-1"
                      />
                    </label>
                    <button type="submit" className="btn btn-ghost text-sm">Save</button>
                  </form>
                ))}
              </div>
            </details>
          )}
        </div>
      </div>

      {/* Consensus Section */}
      <div id="consensus" className="mb-12">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-2">Consensus</h2>
          <p className="text-sm text-gray-600 mb-4">
            Consensus is recalculated whenever a contribution changes. This recalculates every word
            with contributions at once, e.g. after a deploy or when trust scores have moved.
          </p>
          <RecalculateConsensusButton />
        </div>
      </div>

      {/* Flagged Words Section */}
      <div id="flagged-words" className="mb-12">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-6">
            Flagged Words ({flaggedWords?.length || 0})
          </h2>

          {flaggedWords && flaggedWords.length > 0 ? (
            <div className="space-y-4">
              {flaggedWords.map((word: any) => (
                <div key={word.id} className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h3 className="text-xl font-bold text-gray-900">{word.motu_word}</h3>
                      <p className="text-sm text-gray-600 mt-1">
                        {word.total_contributions} {word.total_contributions === 1 ? 'contribution' : 'contributions'} from{' '}
                        {word.unique_contributors} {word.unique_contributors === 1 ? 'contributor' : 'contributors'}
                      </p>
                    </div>
                    <Link
                      href={`/dictionary/${word.id}`}
                      className="text-primary-600 hover:underline text-sm"
                      target="_blank"
                    >
                      View Details →
                    </Link>
                  </div>

                  <div className="flex space-x-2">
                    <form action={verifyWord}>
                      <input type="hidden" name="wordId" value={word.id} />
                      <button type="submit" className="btn btn-primary text-sm">
                        Mark as Verified
                      </button>
                    </form>
                    <form action={unflagWord}>
                      <input type="hidden" name="wordId" value={word.id} />
                      <button type="submit" className="btn btn-ghost text-sm">
                        Unflag
                      </button>
                    </form>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-8">No flagged words</p>
          )}
        </div>
      </div>

      {/* Low Trust Users Section */}
      <div id="low-trust" className="mb-12">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-6">
            Low Trust Users ({lowTrustUsers?.length || 0})
          </h2>

          {lowTrustUsers && lowTrustUsers.length > 0 ? (
            <div className="space-y-4">
              {lowTrustUsers.map((user: any) => (
                <div key={user.id} className="p-4 bg-gray-50 border border-gray-200 rounded-lg">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h3 className="font-bold text-gray-900">{user.display_name}</h3>
                      <p className="text-sm text-gray-600 mt-1">
                        Trust Score: {user.trust_score.toFixed(2)} •
                        Status: {user.status} •
                        Contributions: {user.contribution_count}
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {user.connection_type.replace('_', ' ')}
                      </p>
                    </div>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <form action={warnUser}>
                      <input type="hidden" name="userId" value={user.id} />
                      <button type="submit" className="btn btn-ghost text-sm">
                        Warn User
                      </button>
                    </form>
                    <form action={suspendUser}>
                      <input type="hidden" name="userId" value={user.id} />
                      <button type="submit" className="btn btn-ghost text-sm text-orange-600">
                        Suspend
                      </button>
                    </form>
                    <form action={banUser}>
                      <input type="hidden" name="userId" value={user.id} />
                      <button type="submit" className="btn btn-ghost text-sm text-red-600">
                        Ban
                      </button>
                    </form>
                    <form action={excludeFromAI}>
                      <input type="hidden" name="userId" value={user.id} />
                      <button type="submit" className="btn btn-ghost text-sm">
                        Exclude from AI
                      </button>
                    </form>
                    <form action={excludeAllContributions}>
                      <input type="hidden" name="userId" value={user.id} />
                      <button type="submit" className="btn btn-ghost text-sm text-red-600">
                        Exclude All Contributions
                      </button>
                    </form>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-8">No low trust users</p>
          )}
        </div>
      </div>

      {/* Suspended and Banned Section */}
      <div id="inactive-users" className="mb-12">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-6">
            Suspended and Banned ({inactiveUsers?.length || 0})
          </h2>

          {inactiveUsers && inactiveUsers.length > 0 ? (
            <div className="space-y-4">
              {inactiveUsers.map((user: any) => (
                <div key={user.id} className="p-4 bg-red-50 border border-red-200 rounded-lg flex items-center justify-between">
                  <div>
                    <h3 className="font-bold text-gray-900">{user.display_name}</h3>
                    <p className="text-sm text-gray-600 mt-1">Status: {user.status}</p>
                  </div>
                  <form action={reinstateUser}>
                    <input type="hidden" name="userId" value={user.id} />
                    <button type="submit" className="btn btn-ghost text-sm">
                      Reinstate
                    </button>
                  </form>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-8">No suspended or banned members</p>
          )}
        </div>
      </div>

      {/* Admins Section */}
      <div id="admins" className="mb-12">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-2">
            Admins ({admins?.length || 0})
          </h2>
          <p className="text-sm text-gray-600 mb-6">
            Admins can ban members and appoint other admins. There must always be at least one.
          </p>

          <div className="space-y-3 mb-8">
            {(admins || []).map((admin: any) => {
              const appointment = appointmentFor.get(admin.id)
              return (
                <div key={admin.id} className="p-4 bg-gray-50 border border-gray-200 rounded-lg flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 className="font-bold text-gray-900">
                      {admin.display_name}
                      {admin.id === profile.id && <span className="font-normal text-gray-500"> (you)</span>}
                    </h3>
                    <p className="text-sm text-gray-600 mt-1">
                      {appointment
                        ? `Admin since ${formatDate(appointment.appointed_at)}, appointed by ${appointment.appointer?.display_name ?? 'a former member'}`
                        : 'Admin from before appointments were recorded'}
                    </p>
                  </div>
                  <AdminRoleButton
                    mode="revoke"
                    userId={admin.id}
                    displayName={admin.display_name}
                    isSelf={admin.id === profile.id}
                  />
                </div>
              )
            })}
          </div>

          <h3 className="font-bold text-gray-900 mb-2">Make someone an admin</h3>
          <form method="get" action="/admin#admins" className="flex flex-wrap gap-2 mb-4">
            <label htmlFor="member-search" className="sr-only">Member's display name</label>
            <input
              id="member-search"
              type="search"
              name="member"
              defaultValue={memberQuery}
              placeholder="Search by display name"
              className="input flex-1 min-w-[12rem]"
            />
            <button type="submit" className="btn btn-ghost text-sm">Search</button>
          </form>

          {memberQuery && (
            memberResults && memberResults.length > 0 ? (
              <div className="space-y-3">
                {memberResults.map((member: any) => (
                  <div key={member.id} className="p-4 bg-gray-50 border border-gray-200 rounded-lg flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h3 className="font-bold text-gray-900">{member.display_name}</h3>
                      <p className="text-sm text-gray-600 mt-1">Status: {member.status}</p>
                    </div>
                    <AdminRoleButton
                      mode="grant"
                      userId={member.id}
                      displayName={member.display_name}
                      isAdmin={member.is_admin}
                    />
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-gray-500 text-sm">No members match &ldquo;{memberQuery}&rdquo;.</p>
            )
          )}
        </div>
      </div>

      {/* Moderation Log Section */}
      <div id="moderation-log">
        <div className="card">
          <h2 className="text-xl font-bold text-gray-900 mb-6">
            Recent Moderation Actions
          </h2>

          {moderationLog && moderationLog.length > 0 ? (
            <div className="space-y-3">
              {moderationLog.map((log: any) => (
                <div key={log.id} className="p-3 bg-gray-50 rounded-lg text-sm">
                  <div className="flex items-start justify-between">
                    <div>
                      <span className="font-medium">{log.admin.display_name}</span>
                      <span className="text-gray-600"> performed </span>
                      <span className="font-medium text-primary-600">{log.action.replace('_', ' ')}</span>
                      {log.target_user && (
                        <>
                          <span className="text-gray-600"> on user </span>
                          <span className="font-medium">{log.target_user.display_name}</span>
                        </>
                      )}
                      {log.target_word && (
                        <>
                          <span className="text-gray-600"> on word </span>
                          <span className="font-medium">{log.target_word.motu_word}</span>
                        </>
                      )}
                    </div>
                    <span className="text-xs text-gray-500">
                      {new Date(log.created_at).toLocaleString()}
                    </span>
                  </div>
                  {log.reason && (
                    <p className="text-gray-600 mt-1 italic">Reason: {log.reason}</p>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-8">No moderation actions yet</p>
          )}
        </div>
      </div>
    </div>
  )
}
