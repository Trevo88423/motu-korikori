import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="max-w-md mx-auto px-4 sm:px-6 lg:px-8 py-16">
      <div className="card text-center">
        <p className="text-sm font-medium text-primary-600 mb-2">404</p>
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-2">Page not found</h1>
        <p className="text-gray-600 mb-8">
          We couldn&apos;t find that page. The link may be broken, or the word may have moved.
        </p>
        <div className="flex flex-col sm:flex-row justify-center gap-3">
          <Link href="/dictionary" className="btn btn-primary">
            Browse Dictionary
          </Link>
          <Link href="/" className="btn btn-ghost">
            Go Home
          </Link>
        </div>
      </div>
    </div>
  )
}
