"""Generate the Supabase Auth email templates from one shared layout.

Run from anywhere:  python dictionary-app/supabase/templates/build.py

Writes one .html file per template next to this script. The same files are
used by the local stack (config.toml [auth.email.template.*]) and pasted into
the production dashboard (Authentication > Emails > Templates), so local
testing in Mailpit shows exactly what members receive.

Deliverability notes (why these look the way they do):
- Says who sent it and why in the first lines; generic "click this link"
  emails are what phishing filters are trained on.
- One button, plus the same link written out in full, so the visible address
  matches the sending domain (truemotu.org).
- No images, no tracking, no urgent wording, and a calm "if this wasn't you,
  ignore it" line.
- Signup, recovery and magic-link use the token_hash link to /auth/callback,
  which the callback route verifies with verifyOtp. Unlike the PKCE code flow,
  it works when the email is opened on a different device or browser.
  Signup uses type=email (not type=signup): that is what production used when
  the confirmation flow was verified end to end in August 2026.
"""

from pathlib import Path

HERE = Path(__file__).parent

BLUE_DARK = "#1d4ed8"
BLUE = "#2563eb"
TEXT = "#1f2937"
MUTED = "#6b7280"
BG = "#f3f4f6"

LAYOUT = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>{title}</title>
</head>
<body style="margin:0;padding:0;background:{bg};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">{preheader}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{bg};">
  <tr>
    <td align="center" style="padding:32px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;font-family:Inter,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
        <tr>
          <td style="background:{blue_dark};padding:20px 32px;">
            <div style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:-0.2px;">True Motu Dictionary</div>
            <div style="color:#bfdbfe;font-size:13px;margin-top:2px;">Preserving Motu korikori for future generations</div>
          </td>
        </tr>
        <tr>
          <td style="padding:32px 32px 8px 32px;color:{text};font-size:16px;line-height:1.6;">
            <h1 style="margin:0 0 16px 0;font-size:22px;line-height:1.3;color:{text};">{heading}</h1>
{body}
          </td>
        </tr>
        <tr>
          <td style="padding:16px 32px 32px 32px;color:{muted};font-size:14px;line-height:1.6;">
{after}
          </td>
        </tr>
        <tr>
          <td style="border-top:1px solid #e5e7eb;padding:20px 32px;color:{muted};font-size:12px;line-height:1.6;">
            True Motu Dictionary is a community project documenting the Motu language of Papua New Guinea.<br>
            <a href="{{{{ .SiteURL }}}}" style="color:{muted};">truemotu.org</a> &middot; We will never ask for your password by email.
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
"""

BUTTON = """            <table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px 0;">
              <tr>
                <td style="border-radius:8px;background:{blue};">
                  <a href="{url}" style="display:inline-block;padding:12px 24px;color:#ffffff;font-size:16px;font-weight:600;text-decoration:none;border-radius:8px;">{label}</a>
                </td>
              </tr>
            </table>
            <p style="margin:0 0 8px 0;font-size:14px;color:{muted};">If the button doesn't work, copy this address into your browser:</p>
            <p style="margin:0;font-size:13px;word-break:break-all;"><a href="{url}" style="color:{blue};">{url}</a></p>"""


def para(text: str) -> str:
    return f'            <p style="margin:0 0 12px 0;">{text}</p>'


def link(kind: str) -> str:
    return "{{ .SiteURL }}/auth/callback?token_hash={{ .TokenHash }}&type=" + kind


TEMPLATES = {
    # file name: (subject, preheader, heading, body paragraphs, button url, button label, after-text)
    "confirmation": (
        "Confirm your email for True Motu Dictionary",
        "One click to finish creating your True Motu Dictionary account.",
        "Welcome! Please confirm your email",
        [
            "Thanks for joining the True Motu Dictionary. You signed up with <strong>{{ .Email }}</strong>.",
            "Confirm your email address to finish creating your account and start contributing translations.",
        ],
        link("email"),
        "Confirm my email",
        "This link works once and expires in 1 hour. If you didn't sign up for True Motu Dictionary, "
        "you can safely ignore this email; no account will be created.",
    ),
    "recovery": (
        "Reset your True Motu Dictionary password",
        "You asked to reset your True Motu Dictionary password.",
        "Reset your password",
        [
            "We received a request to reset the password for the True Motu Dictionary account "
            "<strong>{{ .Email }}</strong>.",
            "Use the button below to choose a new password.",
        ],
        link("recovery"),
        "Choose a new password",
        "This link works once and expires in 1 hour. If you didn't ask to reset your password, "
        "you can ignore this email; your password will stay the same.",
    ),
    "magic_link": (
        "Your True Motu Dictionary sign-in link",
        "Sign in to True Motu Dictionary with one click.",
        "Sign in to True Motu Dictionary",
        [
            "Use the button below to sign in as <strong>{{ .Email }}</strong>. No password needed.",
        ],
        link("email"),
        "Sign in",
        "This link works once and expires in 1 hour. If you didn't ask to sign in, "
        "you can ignore this email; nobody can sign in without it.",
    ),
    "email_change": (
        "Confirm your new email for True Motu Dictionary",
        "Confirm the change of email address on your True Motu Dictionary account.",
        "Confirm your new email address",
        [
            "You asked to change the email on your True Motu Dictionary account from "
            "<strong>{{ .Email }}</strong> to <strong>{{ .NewEmail }}</strong>.",
            "Confirm the change with the button below.",
        ],
        "{{ .ConfirmationURL }}",
        "Confirm new email",
        "This link expires in 1 hour. If you didn't ask for this change, ignore this email "
        "and your email address will stay the same.",
    ),
    "invite": (
        "You're invited to True Motu Dictionary",
        "You've been invited to help build the True Motu Dictionary.",
        "You're invited to join",
        [
            "You've been invited to join the True Motu Dictionary, a community project "
            "recording and preserving the Motu language.",
            "Accept the invitation to set up your account.",
        ],
        "{{ .ConfirmationURL }}",
        "Accept invitation",
        "This link expires in 24 hours. If you weren't expecting this invitation, you can ignore this email.",
    ),
}


def render(name, subject, preheader, heading, paragraphs, url, label, after):
    body = "\n".join(para(p) for p in paragraphs) + "\n" + BUTTON.format(
        url=url, label=label, blue=BLUE, muted=MUTED
    )
    return LAYOUT.format(
        title=subject,
        preheader=preheader,
        heading=heading,
        body=body,
        after=f'            <p style="margin:0;">{after}</p>',
        bg=BG,
        blue_dark=BLUE_DARK,
        text=TEXT,
        muted=MUTED,
    )


def render_reauth():
    subject = "Your True Motu Dictionary verification code"
    body = "\n".join(
        [
            para("Enter this code on True Motu Dictionary to confirm it's you:"),
            '            <p style="margin:24px 0;font-size:32px;font-weight:700;letter-spacing:6px;color:%s;">{{ .Token }}</p>'
            % BLUE_DARK,
        ]
    )
    return LAYOUT.format(
        title=subject,
        preheader="Your one-time verification code for True Motu Dictionary.",
        heading="Your verification code",
        body=body,
        after='            <p style="margin:0;">The code expires in 1 hour. If you didn\'t request it, '
        "you can ignore this email. Never share this code with anyone.</p>",
        bg=BG,
        blue_dark=BLUE_DARK,
        text=TEXT,
        muted=MUTED,
    )


SUBJECTS = {name: spec[0] for name, spec in TEMPLATES.items()}
SUBJECTS["reauthentication"] = "Your True Motu Dictionary verification code"

if __name__ == "__main__":
    for name, spec in TEMPLATES.items():
        (HERE / f"{name}.html").write_text(render(name, *spec), encoding="utf-8", newline="\n")
    (HERE / "reauthentication.html").write_text(render_reauth(), encoding="utf-8", newline="\n")
    for name, subject in SUBJECTS.items():
        print(f"{name:18} {subject}")
