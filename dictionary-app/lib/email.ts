// App-sent email through Resend's HTTP API. Server-only.
//
// Auth emails (confirmations, password resets) don't come through here: they
// go through Supabase Auth's custom SMTP. This is for the few messages the app
// sends itself, e.g. telling a member they've been made an admin (#64).
//
// Needs RESEND_API_KEY. Without it, nothing is sent and the skip is logged, so
// local dev and previews work without a key. EMAIL_FROM overrides the sender;
// its domain must be verified in Resend.

const RESEND_ENDPOINT = 'https://api.resend.com/emails'
const DEFAULT_FROM = 'True Motu Dictionary <noreply@truemotu.org>'

export interface EmailMessage {
  to: string
  subject: string
  text: string
  html: string
}

export type EmailResult = 'sent' | 'skipped' | 'failed'

export async function sendEmail(message: EmailMessage): Promise<EmailResult> {
  const apiKey = process.env.RESEND_API_KEY
  if (!apiKey) {
    console.info(`Email skipped (RESEND_API_KEY not set): "${message.subject}"`)
    return 'skipped'
  }

  try {
    const response = await fetch(RESEND_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.EMAIL_FROM || DEFAULT_FROM,
        to: [message.to],
        subject: message.subject,
        text: message.text,
        html: message.html,
      }),
    })

    if (!response.ok) {
      console.error(`Email failed (${response.status}): ${await response.text()}`)
      return 'failed'
    }
    return 'sent'
  } catch (error) {
    console.error('Email failed:', error)
    return 'failed'
  }
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}
