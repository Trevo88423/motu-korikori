import type { MetadataRoute } from 'next'
import { SITE_URL } from '@/lib/seo'

// Public pages are open to search engines and AI crawlers alike (#65, Trevor's
// decision 2026-10-24); account, contribution and admin pages are not.
const disallow = [
  '/admin',
  '/dashboard',
  '/contribute',
  '/my-contributions',
  '/api/auth',
  '/auth',
  '/login',
  '/signup',
  '/verify-email',
  '/forgot-password',
  '/reset-password',
]

// Named so the policy for AI crawlers is explicit, not just implied by "*"
const aiCrawlers = ['GPTBot', 'ClaudeBot', 'Google-Extended', 'PerplexityBot']

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      { userAgent: '*', allow: '/', disallow },
      { userAgent: aiCrawlers, allow: '/', disallow },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
  }
}
