import Link from 'next/link'
import { BIBLE_CREDIT } from '@/lib/bible-credit'

// The licence credit shown under every set of Bible examples (#67)
export default function BibleCredit() {
  return (
    <p className="text-xs text-gray-500 mt-2">
      {BIBLE_CREDIT.motu},{' '}
      <a href={BIBLE_CREDIT.licenceUrl} target="_blank" rel="noopener noreferrer license" className="underline hover:text-gray-700">
        {BIBLE_CREDIT.licence}
      </a>
      , via{' '}
      <a href={BIBLE_CREDIT.sourceUrl} target="_blank" rel="noopener noreferrer" className="underline hover:text-gray-700">
        {BIBLE_CREDIT.source}
      </a>
      . {BIBLE_CREDIT.english}.{' '}
      <Link href="/sources" className="underline hover:text-gray-700">
        Sources
      </Link>
    </p>
  )
}
