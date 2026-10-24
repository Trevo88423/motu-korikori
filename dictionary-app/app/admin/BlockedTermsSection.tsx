import { addBlockedTerm, approveBlockedTerm, removeBlockedTerm } from './blocked-terms-actions'

interface BlockedTerm {
  id: string
  term: string
  language: string
  category: string
  approved: boolean
  created_at: string
}

const LANGUAGE_LABELS: Record<string, string> = { en: 'English', tpi: 'Tok Pisin', meu: 'Motu' }

function TermRow({ term }: { term: BlockedTerm }) {
  return (
    <li className="flex items-center justify-between gap-2 py-2">
      <span className="text-sm">
        <span className="font-medium text-gray-900">{term.term}</span>
        <span className="text-gray-500"> · {LANGUAGE_LABELS[term.language] ?? term.language} · {term.category}</span>
      </span>
      <span className="flex gap-2">
        {!term.approved && (
          <form action={approveBlockedTerm}>
            <input type="hidden" name="termId" value={term.id} />
            <button type="submit" className="btn btn-primary text-sm">Approve</button>
          </form>
        )}
        <form action={removeBlockedTerm}>
          <input type="hidden" name="termId" value={term.id} />
          <button type="submit" className="btn btn-ghost text-sm text-red-600">Remove</button>
        </form>
      </span>
    </li>
  )
}

// Bad-language filter (#54). Only approved terms are enforced; native and
// heritage speakers can suggest more, which wait here for approval.
export default function BlockedTermsSection({
  terms,
  attemptsThisWeek,
}: {
  terms: BlockedTerm[]
  attemptsThisWeek: number
}) {
  const suggested = terms.filter((t) => !t.approved)
  const approved = terms.filter((t) => t.approved)

  return (
    <div id="blocked-terms" className="mb-12">
      <div className="card">
        <h2 className="text-xl font-bold text-gray-900 mb-2">Blocked Language</h2>
        <p className="text-sm text-gray-600 mb-6">
          Text containing these words is refused with a polite message. Blocked attempts in the
          last 7 days: {attemptsThisWeek}
        </p>

        <form action={addBlockedTerm} className="flex flex-col sm:flex-row gap-2 mb-6">
          <label htmlFor="blocked-term" className="sr-only">Word or phrase</label>
          <input
            id="blocked-term"
            name="term"
            type="text"
            required
            minLength={2}
            maxLength={60}
            placeholder="Word or phrase"
            className="input sm:flex-1"
          />
          <label htmlFor="blocked-term-language" className="sr-only">Language</label>
          <select id="blocked-term-language" name="language" className="input sm:w-36" defaultValue="en">
            <option value="en">English</option>
            <option value="tpi">Tok Pisin</option>
            <option value="meu">Motu</option>
          </select>
          <label htmlFor="blocked-term-category" className="sr-only">Category</label>
          <select id="blocked-term-category" name="category" className="input sm:w-36" defaultValue="profanity">
            <option value="profanity">Profanity</option>
            <option value="slur">Slur</option>
            <option value="sexual">Sexual</option>
            <option value="abuse">Abuse</option>
          </select>
          <button type="submit" className="btn btn-primary">Add</button>
        </form>

        <h3 className="font-semibold text-gray-900 mb-2">Suggested ({suggested.length})</h3>
        {suggested.length > 0 ? (
          <ul className="divide-y divide-gray-200 mb-6">
            {suggested.map((t) => <TermRow key={t.id} term={t} />)}
          </ul>
        ) : (
          <p className="text-sm text-gray-500 mb-6">No suggestions waiting</p>
        )}

        <details>
          <summary className="cursor-pointer font-semibold text-gray-900">
            Blocked words ({approved.length})
          </summary>
          <ul className="divide-y divide-gray-200 mt-2">
            {approved.map((t) => <TermRow key={t.id} term={t} />)}
          </ul>
        </details>
      </div>
    </div>
  )
}
