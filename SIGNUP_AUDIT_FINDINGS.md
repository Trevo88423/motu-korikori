<!-- Generated 2026-08-03 by a 13-agent audit: 6 independent lenses, each adversarially verified by a skeptic agent instructed to refute. 36 findings survived, merged into the 23 below. -->

# Truemotu Signup & Authentication Audit

Truemotu's signup and login system has two problems severe enough to stop new contributors from joining at all, and one that could hand control of the whole dictionary to any user who wants it. Six of the eight accounts ever created in production are broken shells with no profile — every signup since 22 January 2026 has failed silently, leaving people with an error message and an unusable account they cannot re-register. Separately, a flaw in the database permission rules means any signed-in contributor can make themselves an administrator with a single web request, giving them power to delete or rewrite all 15,610 dictionary entries. The email confirmation and password-reset links are also broken by design in the code, and logged-in sessions quietly expire after about an hour, throwing people out mid-contribution. Finally, and importantly for a project that invites minors: the field meant to record a parent's or guardian's consent can never be set to true, no guardian is ever contacted, and the Terms of Service the site asks everyone to agree to does not exist. The fixes below are ordered so the things blocking real people come first, then the security holes, then the consent and data-hygiene work.

---

## 1. Any authenticated user can promote themselves to administrator

**`dictionary-app/supabase/schema.sql:192`** (policy `"Users can update own profile"`)

The `FOR UPDATE` policy is `USING (auth.uid() = id)` with **no `WITH CHECK` clause**. Postgres reuses `USING` as the check when `WITH CHECK` is omitted, so the only invariant enforced is that the row's `id` still equals the caller's uid — every other column is freely writable by the row's owner. Verified live against production (`mwygcqumpjswovyukcct`): `pg_policies` shows `with_check = NULL`, and `information_schema.column_privileges` shows the `authenticated` role holds `UPDATE` on all 25 columns of `profiles`, explicitly including `is_admin`, `trust_score`, `status` and `excluded_from_ai`. There are no column-level `REVOKE`s anywhere in the repo, and the only non-internal trigger on `profiles` is `update_profiles_updated_at`.

The escalation chains because the admin policies on the *other* tables correctly gate on the caller's flag — `((SELECT is_admin FROM profiles WHERE id = auth.uid()) = true)` for `words`, `contributions` and `moderation_log`, all `cmd=ALL`.

**Failure scenario.** A contributor signs up normally and gets a session. From the browser console, with only the public anon key and their own access token:

```
PATCH /rest/v1/profiles?id=eq.<their-own-uid>
{"is_admin": true, "trust_score": 9.99}
```

`USING` passes (id unchanged), no `WITH CHECK` rejects it, the column grant permits it, no trigger reverts it. **200 OK — they are now an admin.** They can `DELETE` every row in `words`, rewrite `consensus_gloss` on any entry, exclude rival contributors' work, and read `moderation_log`. `lib/supabase.ts:78` `isUserAdmin()` reads the same column, so the app's own admin dashboard opens for them too. Production currently has **zero** rows with `is_admin=true`, so no legitimate admin would notice a new one appearing.

**Fix.** Revoke the grants and pin the columns:

```sql
REVOKE UPDATE ON public.profiles FROM anon, authenticated;
GRANT UPDATE (name, locations, who_taught, connection_type, age_range)
  ON public.profiles TO authenticated;

DROP POLICY "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
```

Belt and braces: a `BEFORE UPDATE` trigger that raises unless `is_admin`/`trust_score`/`status`/`contribution_count` are unchanged for non-service-role callers. Keep `is_admin` mutable only through the service-role key.

---

## 2. Signup is non-atomic with no rollback — 6 of 8 production accounts are broken shells

**`dictionary-app/app/signup/page.tsx:126`** (and the second write at `:146`)

`handleSubmit` performs two independent writes. Line 126 calls `supabase.auth.signUp`, which immediately and irreversibly creates the `auth.users` row. Only afterwards (line 146, after a 100 ms sleep at line 142) does it call `createUserProfile`. On failure line 192 throws and the user sees a red box. Nothing deletes the just-created auth user, nothing retries, and **there is no other code path in the repo that inserts into `profiles`** — `from('profiles').insert` appears only at `app/signup/actions.ts:38` and `app/api/create-profile/route.ts:30`. There is no `on auth.users` trigger in production to backfill.

The client fallback at `page.tsx:166` is dead code for database failures: `createUserProfile` has its own `try/catch` (`actions.ts:66`) and returns `{success:false}` rather than throwing, so the `catch` at line 162 that would retry against `/api/create-profile` never fires. And the fallback is only entered when the error message contains `'Headers'`/`'header'` (`page.tsx:164`) — a substring match on human-readable text.

Compounding it, `supabaseAdmin` is built once at module scope (`actions.ts:6-15`, `route.ts:5-14`) from `process.env.SUPABASE_SERVICE_ROLE_KEY!`. If that variable is missing or stale in the deployment, `createClient` receives `undefined`, every insert 401s, and the singleton can never recover without a redeploy — which matches the production timeline exactly.

**Failure scenario — verified in production, not hypothetical.** `auth.users` = 8, `public.profiles` = 2, orphans = 6. The last two users with profiles were created 2026-01-20 and 2026-01-22; every signup after that (2026-01-25, 01-29, 02-16, 04-13, 05-19, 06-11) has `has_profile=false`, `email_confirmed_at=null`, `last_sign_in_at=null`. **Six real would-be contributors over five months got an error box and an unusable zombie account, with no way to re-register that email.**

Downstream, if such a user does confirm their email they get wedged rather than blocked: `app/api/auth/login/route.ts:41-49` tests `profile?.status === 'banned'`, which is false for a missing profile, so login succeeds. `app/layout.tsx:48-61` renders `Navigation` with a valid user and `name` undefined, showing Contribute / My Contributions / Dashboard. Clicking any of them: `contribute/layout.tsx` passes (user exists, email confirmed, `profile?.status` undefined), then `contribute/page.tsx:22` calls `getCurrentUserProfile`, whose `.single()` at `lib/supabase.ts:100-106` returns `PGRST116` → `null` → `redirect('/login')`. `/login` does not redirect authenticated users, so the form re-renders, they log in again, and bounce again. `dashboard/page.tsx:11-13` and `my-contributions/page.tsx:12-14` behave identically. And every contribution insert would fail anyway — `contributions_user_id_fkey` references `profiles(id)`.

**Fix.** Make profile creation a consequence of auth-user creation, not a second client call:

- Add an `AFTER INSERT ON auth.users` `SECURITY DEFINER` trigger that inserts the minimal `profiles` row, with signup metadata passed through `supabase.auth.signUp({ options: { data: {...} } })`. This makes the invariant hold at the DB level regardless of client behaviour.
- Or move the whole flow into one server action using `supabaseAdmin.auth.admin.createUser`, and call `admin.deleteUser(id)` if the profile insert fails.
- Fail fast at boot if `SUPABASE_SERVICE_ROLE_KEY` is unset instead of constructing a broken singleton.
- Add a self-heal path: when `getCurrentUserProfile` returns null for an authenticated user, redirect to a "complete your profile" page, never to `/login`. Have `/login` and `/signup` redirect authenticated users so the bounce loop cannot form.
- **Backfill or delete the 6 existing orphans and email those people.**

---

## 3. The PKCE `?code=` callback can never establish a session — confirmation and password-reset links dead-end

**`dictionary-app/app/auth/callback/route.ts:29`**

The callback's cookie adapter hard-codes `getAll() { return [] }` (lines 28-30). Two independent defects make the `?code=` branch unusable:

1. **The verifier is unreadable.** `@supabase/ssr`'s server storage builds `getItem` on top of `getAll` (`ssr/dist/main/cookies.js:233-247`), which returns null for an empty array. `exchangeCodeForSession` reads `${storageKey}-code-verifier` through exactly that storage, and auth-js throws before any network call: `if (!codeVerifier && this.flowType === 'pkce') throw new AuthPKCECodeVerifierMissingError()` (`GoTrueClient.js:766-771`). The verifier cookie **is** present on the request (SameSite=lax, top-level GET) — the adapter simply refuses to read it. `createServerClient.js` pins `flowType: "pkce"` *after* spreading `...options?.auth`, so it cannot even be overridden.
2. **The write would land too late anyway.** `_exchangeCodeForSession` defers the SIGNED_IN notification via `setTimeout(..., 0)` (`GoTrueClient.js:792-796`), and `@supabase/ssr` writes cookies only from that handler — but `route.ts:72` has already returned `response` synchronously. No `Set-Cookie` is emitted. (Contrast the `token_hash` branch: `verifyOtp` *awaits* `_notifyAllSubscribers` at `GoTrueClient.js:947-948`, so that branch does write cookies correctly.)

Every flow in this app is initiated from the browser client, which also defaults to PKCE: `signUp` (`app/signup/page.tsx:126-132`), `resetPasswordForEmail` (`app/forgot-password/page.tsx:20-22`), `resend` (`app/verify-email/page.tsx:34-40`). So a `code_challenge` is always registered and Supabase's default `{{ .ConfirmationURL }}` template redirects here with `?code=`. The `if (code)` branch at `route.ts:62-73` is **dead by construction** — it can only ever take the error path.

**Failure scenario.** A contributor signs up, receives the confirmation mail, clicks the link. Supabase's `/auth/v1/verify` consumes the one-time token and redirects to `/auth/callback?type=signup&code=<uuid>`. The exchange throws, `route.ts:67-69` redirects to `/login?error=PKCE%20code%20verifier%20not%20found%20in%20storage...`, and the raw GoTrue string is rendered verbatim in the login banner. The one-time token is now spent, so re-clicking gives "Email link is invalid or has expired". `email_confirmed_at` stays null, login is refused at `app/api/auth/login/route.ts:31-36`, and every resend produces another link that fails identically. Same for password reset: the recovery link never reaches `/reset-password` with a `PASSWORD_RECOVERY` session, so `app/reset-password/page.tsx:36` `updateUser({password})` fails with "Auth session missing!".

**Caveat on blast radius.** The `token_hash` branch (`route.ts:41-59`) works. If the project's Supabase email templates were manually switched to `{{ .TokenHash }}`, this is latent rather than live today. Nothing in the repo pins that config, so **verify the template setting before or after fixing** — but fix it regardless, because the code's own `emailRedirectTo` wiring drives the broken branch.

**Fix.** Read the real cookie jar, as `app/contribute/layout.tsx:17-19` already does correctly:

```ts
const cookieStore = await cookies()
const supabase = createServerClient(url, key, {
  cookies: {
    getAll() { return cookieStore.getAll() },   // was: return []
    setAll(all) { all.forEach(({name, value, options}) =>
      response.cookies.set(name, value, options)) },
  },
})
```

Because of defect 2, also build the response *after* the exchange and let the cookie writes land on it, or switch both email templates to `{{ .TokenHash }}` and use the branch that already works. Add an end-to-end test that walks a real confirmation URL through the callback and asserts a session cookie is set.

---

## 4. Token refresh is silently discarded everywhere — sessions self-destruct about an hour after login

**`dictionary-app/middleware.ts:7`**

`createServerClient` from `@supabase/ssr` forces `autoRefreshToken: false` and persists rotated tokens **only** from its `onAuthStateChange` handler, which calls the app's `setAll`. This app has nowhere that write can land:

- `middleware.ts:3-8` is a no-op — literally `return NextResponse.next()` — so the documented `@supabase/ssr` session-refresh hop does not exist. The matcher on line 12 still matches every request, so the file *looks* like protection while providing none.
- Every page render goes through `app/layout.tsx:46` `await supabase.auth.getUser()`. In auth-js, `getUser()` → `_useSession` → `__loadSession` (`GoTrueClient.js:1202-1231`) calls `_callRefreshToken` when the access token is within the 90 s expiry margin, which fires `TOKEN_REFRESHED`, which makes `@supabase/ssr` call `setAll` → `cookieStore.set(...)`.
- In a Server Component that `set` **throws**, and the throw is swallowed by empty `catch {}` blocks at `app/layout.tsx:35`, `lib/supabase.ts:33`, `app/contribute/layout.tsx:25` and `app/dashboard/layout.tsx:25`.

So the refresh token is consumed on the Supabase side and the newly issued pair is thrown away. No compensating path exists: no browser client is mounted on ordinary pages (`createClientComponentClient` appears only in `app/signup`, `app/verify-email`, `app/forgot-password`, `app/reset-password` and `components/WordCard.tsx:150`), so client-side auto-refresh never runs during normal browsing.

**Failure scenario.** A contributor logs in at 09:00 (access token TTL 1 h). At 10:20 they open the site → root layout `getUser()` refreshes, GoTrue issues R2 and marks R1 used; the `catch {}` at `app/layout.tsx:35` drops the `Set-Cookie`, so the browser still holds R1. They click "Contribute" 30 seconds later — past GoTrue's 10 s refresh-token reuse interval — and the refresh returns "Invalid Refresh Token: Already Used". `getUser()` returns null, `app/contribute/layout.tsx:37` redirects to `/login`. **The user is logged out mid-session with no explanation and any in-progress contribution state is lost.** After the first failed retry `_callRefreshToken` calls `_removeSession()`, whose SIGNED_OUT write is *also* swallowed, so the stale cookie persists and every later request fails immediately.

**Fix.** Restore a real middleware implementing the standard `@supabase/ssr` Next.js pattern — construct a `createServerClient` whose `getAll` reads `request.cookies` and whose `setAll` writes to **both** `request.cookies` and the `NextResponse` you return, call `supabase.auth.getUser()`, and return that response. Keep the `catch {}` in Server-Component clients only as a fallback once middleware is doing the refresh.

---

## 5. Every consent, age and guardian gate is client-only — both profile writers are unauthenticated service-role endpoints

**`dictionary-app/app/api/create-profile/route.ts:21`** and **`dictionary-app/app/signup/actions.ts:34`**

`POST /api/create-profile` builds a SERVICE ROLE client at module scope (`route.ts:5-14`, bypassing all RLS) and its entire validation is `if (!data.userId || !data.email || !data.name)` at line 21. It never calls `supabase.auth.getUser()`, never reads a cookie or `Authorization` header, never checks `Origin`, and never verifies that `data.userId` belongs to the caller. `middleware.ts:7` is a pass-through, so the route is publicly reachable. `createUserProfile` in `actions.ts:34-58` has the identical gap — a Next.js Server Action is a publicly-callable POST endpoint with fully attacker-controlled arguments — and validates nothing either.

Consequently **every rule in `validateStep1`/`validateStep2` (`page.tsx:47-103`) exists only in browser JavaScript**: required consents, the guardian requirement, required `age_range`/`connection_type`, email format. Production `profiles` carries no CHECK constraints at all — `pg_constraint` returns exactly two rows, `profiles_pkey` and `profiles_id_fkey`.

The client-supplied `email` (`actions.ts:42`, `route.ts:34`) is written straight to `profiles.email` and never reconciled against `auth.users.email`; there is no UNIQUE constraint on it either. Because of the confirmed anon-readable leaderboard policy, a forged email is what every visitor sees.

The two writers have also **drifted from each other** despite being written as interchangeable: `actions.ts:44` writes `locations: data.locations` raw while `route.ts:36` writes `data.locations || []`. `profiles.locations` is `NOT NULL DEFAULT '{}'` (`schema.sql:53`), so an identical call succeeds against the API route and raises a Postgres NOT NULL violation against the server action — whose raw message is then rendered to the user at `page.tsx:193`/`202`, disclosing constraint and column names.

**Failure scenario.** A user signs up to obtain a real `auth.users` id, abandons or lets step 2 fail (leaving an orphan — see finding 2, six of which exist), reads their uid from the JWT, and sends with no cookies and no `Authorization` header:

```bash
curl -X POST https://truemotu.org/api/create-profile \
  -H 'Content-Type: application/json' \
  -d '{"userId":"<their uid>","email":"admin@truemotu.org","name":"Truemotu Admin",
       "age_range":"under_18","connection_type":"native_speaker",
       "consent_tos":false,"consent_dictionary":false,"consent_ai_training":false,
       "is_18_or_older":true}'
```

HTTP 200. The row is `status:'active'`, `trust_score:1.0`, a display email impersonating the project, `is_18_or_older` self-asserted true with no guardian fields, and **all three consent columns recorded FALSE while the account is fully usable for contributing**. The organisation's own database now asserts this contributor refused the Terms of Service, refused dictionary publication and refused AI-training use — the exact record you would need in a dispute says the opposite of what happened.

**Bounded blast radius, stated honestly.** `profiles_id_fkey` forces `id` to be a real `auth.users` row and the call is `.insert()` not `.upsert()`, so no existing profile can be overwritten and no arbitrary UUID conjured. `is_admin:false`, `status:'active'` and `trust_score:1.0` are hardcoded server-side (`route.ts:46-49`, `actions.ts:54-57`), so this is **not** privilege escalation. It is self-service falsification of one's own consent and age record.

**Fix.** Authenticate both writers identically — build a cookie-bound server client, call `getUser()`, reject unless `user.id === data.userId`, and take `email` from `user.email` rather than the body. Extract one shared zod-validated builder used by both paths so they cannot drift again:

```ts
const ProfileInput = z.object({
  name: z.string().trim().min(1).max(100),
  age_range: z.enum([...]),
  connection_type: z.enum([...]),
  locations: z.array(z.string().trim().min(1).max(100)).max(20),
  who_taught: z.string().trim().max(500).optional(),
  consent_tos: z.literal(true),
  consent_dictionary: z.literal(true),
  consent_ai_training: z.literal(true),
}).refine(d => d.is_18_or_older || (d.guardian_name && d.guardian_email),
          'guardian details required for minors')
```

Add DB CHECK constraints as the last line of defence (`CHECK (consent_tos)`, `CHECK (is_18_or_older OR (guardian_name IS NOT NULL AND guardian_email IS NOT NULL))`). Replace the substring fallback at `page.tsx:164` with a typed check, and stop rendering raw `error.message` at `page.tsx:193`/`202`. Better still, replace both service-role writers with the `auth.users` trigger from finding 2 so no public HTTP surface ever holds the service-role key.

---

## 6. Production admin policies test the target row's `is_admin`, not the caller's — anon can UPDATE any admin profile

**`dictionary-app/supabase/schema.sql:207`**

The repo writes these two policies correctly, with a subquery against the caller. **Production has drifted** to a bare, unqualified column reference. Verified via `pg_policies` on `mwygcqumpjswovyukcct`:

- `"Admins can update any profile"`, `cmd=UPDATE`, `roles={public}`, `qual = ((auth.uid() = id) OR (is_admin = true))`, `with_check = NULL`
- `"Admins can view all profiles"`, `cmd=SELECT`, `roles={public}`, same `qual`

In a policy `USING` clause an unqualified column name resolves to **the row being scanned**, not the caller. The predicate therefore reads "this row is visible/updatable if the row itself is an admin row" — the opposite of the intent. Because `roles={public}` the policy also applies to `anon`: `auth.uid()` is NULL, `(NULL = id)` is NULL, `(is_admin = true)` is TRUE for any admin row, and `NULL OR TRUE = TRUE`. `anon` holds UPDATE on all 25 columns, and `with_check` is NULL so `USING` is reused — as long as the attacker leaves `is_admin=true`, the post-image also satisfies the predicate.

This cannot *create* an admin (for a non-admin target the predicate is `NULL OR FALSE = NULL`, so the row is invisible), which is why finding 1 is the bootstrap and this is the follow-on.

**Failure scenario.** An admin exists — created legitimately, or minted via finding 1. An attacker **with no account at all**, holding only `NEXT_PUBLIC_SUPABASE_ANON_KEY` (which ships in every browser bundle), reads the admin's id via the confirmed leaderboard policy: `GET /rest/v1/profiles?is_admin=eq.true&select=id,email`. Then:

```
PATCH /rest/v1/profiles?id=eq.<admin-uid>
{"status": "banned", "email": "attacker@evil.com", "is_admin": true}
```

`USING` passes on `is_admin=true`, the reused check passes because `is_admin` stays true, and **the write succeeds unauthenticated**. The project's only administrator is locked out (`app/api/auth/login/route.ts` rejects `status='banned'`) and their contact address is attacker-controlled. Production has 0 admin rows today, so there is no live target this instant — **the hole arms itself the moment any admin exists**, which finding 1's fix implies.

**Fix.** Test the caller, and avoid policy recursion with a `SECURITY DEFINER` helper:

```sql
CREATE FUNCTION public.is_current_user_admin() RETURNS boolean
  LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT coalesce((SELECT is_admin FROM profiles WHERE id = auth.uid()), false) $$;
```

Then `USING (public.is_current_user_admin())` **plus a matching `WITH CHECK`**, scoped `TO authenticated` rather than `public`. Then capture the corrected state as a real migration file — production has zero recorded migrations and has silently diverged from `schema.sql`.

---

## 7. Guardian consent can never be granted: no control, no email, no verification, and the Terms of Service do not exist

**`dictionary-app/app/signup/page.tsx:36`** (and `components/ConsentForm.tsx:40`, `:116`, `:128-145`)

This is the single most important finding for a project that solicits recordings from children, and it has four interlocking parts.

**`guardian_consent` is hardcoded false.** It is initialised to `false` at `page.tsx:36` and forwarded verbatim at `page.tsx:160` (server action) and `page.tsx:183` (API route), landing at `actions.ts:53` and `route.ts:45`. A repo-wide grep returns exactly six occurrences — the initialiser, two pass-throughs, and three writes. There is **no setter anywhere**: `ConsentFormProps` (`ConsentForm.tsx:5-15`) does not even declare the field, so the component cannot change it, and `validateStep2` (`page.tsx:82-103`) never inspects it. Production confirms: `count(*) where guardian_consent is true` = **0**. The one column whose entire purpose is to record guardian consent is uniformly false and carries zero information.

**`guardian_email` is write-only.** It is collected at `ConsentForm.tsx:142`, checked for non-emptiness at `page.tsx:97`, and inserted — and never `SELECT`ed by any query in the repo. I checked `package.json`: dependencies are `@anthropic-ai/sdk`, `@supabase/ssr`, `@supabase/supabase-js`, `dotenv`, `next`, `react`, `react-dom`. **There is no email package at all** — no nodemailer, sendgrid, postmark, resend or SES — so there is no mechanism to contact a guardian even in principle. The guardian never learns the account exists.

**The Terms of Service and Privacy Policy do not exist.** `ConsentForm.tsx:40` and `:44` render literal `<a href="#">Terms of Service</a>` and `<a href="#">Privacy Policy</a>`. There is no `/terms`, `/privacy` or `/legal` route in `app/`, and a repo-wide search for such a document returns nothing. Ticking the box (`ConsentForm.tsx:31-37`) sets `consent_tos`, which `page.tsx:85-87` enforces as mandatory and `actions.ts:47` persists as `true`. Clicking either link scrolls to the top of the page. For an under-18 contributor this is the only place data handling, publication of voice recordings, and AI-training use would have been disclosed to a guardian — so **there is no disclosure at all**.

**The consents are never read after signup.** A repo-wide grep for `consent_tos|consent_dictionary|consent_ai_training` returns only the signup write path, `ConsentForm.tsx`, `lib/types.ts` and `schema.sql` — not one `.select()` or filter. `contribute/actions.ts:18-26`/`:112-120` and `contribute/layout.tsx:47-55` select only `status`. `lib/consensus.ts` filters on `is_excluded` (lines 52, 156, 239) and mentions consent nowhere. The only AI-exclusion mechanism is a *different* column, `excluded_from_ai`, set solely by a manual admin action (`admin/actions.ts:171`) and never derived from `consent_ai_training` — and it is itself write-only. So consent is structurally unenforceable.

**Failure scenario.** A 13-year-old opens `/signup`, selects "I am under 18 (requires guardian consent)" (`ConsentForm.tsx:116`), and types "Mary Vagi" / "mary.vagi@gmail.com". Signup succeeds. The row is `is_18_or_older=false`, `guardian_name='Mary Vagi'`, `guardian_email='mary.vagi@gmail.com'`, `guardian_consent=false`, `status='active'`, `consent_ai_training=true`. **No message is ever sent to that address; the guardian never learns the account exists.** The child contributes immediately — `contribute/layout.tsx:47-55` and `contribute/actions.ts:18-26` gate only on `status`, never on age or guardian consent — and their voice recordings are published on public word pages (`dictionary/[id]/page.tsx:307` renders `<audio src={contrib.audio_url}>` unconditionally). If the project is later asked to evidence guardian consent, its own records affirmatively state consent was **not** given, for every minor, while the recordings are already public and in the consensus corpus. And because the child agreed to a Terms of Service that does not exist, there is no answer to "what did my child agree to?"

The blast radius is zero rows *today* — both existing profiles are adults and, per finding 2, no signup has succeeded since January. This is a live defect awaiting the first real minor, which is precisely the moment to fix it.

**Fix.** Either remove the under-18 path until a real out-of-band flow exists, or implement one properly:

1. Publish real `/terms` and `/privacy` pages, including a plain-language section addressed to guardians covering what is collected from minors, that audio is published publicly, and how to withdraw. Point the links at them. Record `consent_tos_version` and `consented_at` alongside the boolean so the project can prove what each user agreed to.
2. On signup with `is_18_or_older=false`, create the profile as `status='pending_guardian_consent'`, email a signed single-use token to `guardian_email`, and set `guardian_consent=true` with a `guardian_consent_at` timestamp only when that token is redeemed from the guardian's own inbox. This requires adding email infrastructure the project does not currently have.
3. Gate contribution on `is_18_or_older = true OR guardian_consent = true` in both `contribute/layout.tsx` and `contribute/actions.ts`.
4. Make consent load-bearing everywhere contributions are read for publication — `lib/consensus.ts` and `dictionary/[id]/page.tsx` — or add a trigger forcing `excluded_from_ai = TRUE` whenever `consent_ai_training` is false or a minor lacks guardian consent.
5. Add `CHECK (guardian_email <> email)` so a minor cannot supply their own address, and a constraint preventing `status='active'` for `is_18_or_older=false` rows without recorded consent.

---

## 8. Public leaderboard publishes every contributor's full legal name, minors included

**`dictionary-app/app/leaderboard/page.tsx:107`**

`SignupForm.tsx:83-94` collects "Full Name" as required with no display-name or pseudonym option. `leaderboard/page.tsx:12` selects `id, name, contribution_count, connection_type, trust_score, status` for the top 100 and line 107 renders `{contributor.name}` in a public table. The page has no auth guard, and `middleware.ts:3-8` intercepts nothing, so `/leaderboard` is fully public to logged-out visitors and crawlers. None of the three consent strings (`ConsentForm.tsx:38-48`, `60-64`, `76-80`) mentions publishing the contributor's identity — `consent_dictionary` covers "my contributions being used in the public True Motu dictionary", **not** publication of the contributor's name.

**Failure scenario.** A 13-year-old in Hanuabada signs up with their real full name (the form offers no alternative) and contributes 50 words. Their full legal name, native-speaker classification, activity volume and trust score become a publicly indexable row at `truemotu.org/leaderboard`. Because the confirmed production anon `SELECT` policy exposes `is_18_or_older` and `guardian_email` on the same table, an unauthenticated scraper can join the publicly rendered name to the flag identifying that person as a child and to their guardian's email — **producing a list of named children in a small, identifiable community.** No consent text ever asked for this and no guardian was in a position to refuse it.

**Fix.** Add a separate `display_name` (defaulting to first name or a user-chosen handle) and render that instead of `name`. Exclude minors from the public leaderboard entirely, or require a separate explicit opt-in. Independently, replace the production `"Anyone can view profiles for leaderboard"` policy with a view or RPC exposing only `display_name`, `contribution_count` and `connection_type` — never `email`, `guardian_email` or `is_18_or_older`.

---

## 9. Users can rewrite the vote counters on their own contributions, and trust score ratchets upward

**`dictionary-app/supabase/schema.sql:237`**

`"Users can update own contributions" FOR UPDATE USING (auth.uid() = user_id)` has no `WITH CHECK`; production `pg_policies` confirms `with_check=NULL`. As with finding 1, `USING` is reused as the check, so the owner may rewrite every non-key column of their own row. `supabase/migration-voting-system.sql:66-68` added `upvote_count` and `net_votes` as denormalised counters maintained by the `update_contribution_vote_counts` trigger (lines 220-245) — they sit in the same table under the same permissive policy, so **the counters an author competes on are writable by that author**. `is_excluded` and `matches_consensus`, both moderation fields, are equally writable.

A related weakness compounds it: `update_author_trust_on_vote` (`migration-voting-system.sql:335-399`) is attached `AFTER INSERT` only (lines 402-412) with no DELETE branch, while `"Users can delete their own contribution votes"` (line 181-183) permits removing a vote. Trust credit granted on insert is never reversed on delete. `trust_score` is not cosmetic — it feeds vote weighting at `migration-voting-system.sql:362-367` and is surfaced through the `contributions_with_votes` and `comments_with_votes` views.

**Failure scenario.** A contributor wants their translation adopted as the consensus gloss and sends `PATCH /rest/v1/contributions?id=eq.<their own contribution>` with `{"upvote_count": 500, "net_votes": 500}`. `USING` passes, no `WITH CHECK` rejects it, and the vote trigger only fires on `contribution_votes` rows so it never recomputes the value. Their entry outranks every genuinely upvoted translation in any ordering reading these columns. Separately, they repeatedly POST then DELETE a vote on an ally's contribution; each insert adds `0.1 * vote_weight`, each delete removes nothing, so the ally's `trust_score` climbs without limit and their future votes carry maximum weight.

**Fix.**

```sql
REVOKE UPDATE ON public.contributions FROM anon, authenticated;
GRANT UPDATE (english_gloss, audio_url, confidence, notes)
  ON public.contributions TO authenticated;
```

Add `WITH CHECK (auth.uid() = user_id)` to the policy. Leave `upvote_count`, `net_votes`, `is_excluded` and `matches_consensus` writable only by triggers and the service role. Extend `update_author_trust_on_vote` to handle `TG_OP = 'DELETE'` and attach it `AFTER INSERT OR DELETE`, or recompute `trust_score` from the vote tables rather than accumulating it.

---

## 10. Banning a user does not revoke their session, and several server actions never check status

**`dictionary-app/app/admin/actions.ts:148`**

`banUser` only writes `profiles.status = 'banned'` (lines 146-149). There is no `auth.admin.signOut(userId)` or `updateUserById(userId, { ban_duration })` anywhere in the repo, so the banned user's access and refresh tokens remain valid for their full lifetime.

Enforcement is then ad-hoc and incomplete. `contribute/layout.tsx:53`, `dashboard/layout.tsx:48`, `contribute/actions.ts:24` and `addComment` (`comment-actions.ts:32`) check status. But `updateComment` (`:57`), `deleteComment` (`:90`), `flagComment` (`:117`), `voteOnComment` (`:146`) and `voteOnContribution` (`:217`) check only `if (!user)`. There is no RLS backstop: in production the vote INSERT policies are just `auth.uid() = user_id AND auth.uid() <> <author>`, comment UPDATE/DELETE are `auth.uid() = user_id`, and only `contributions` INSERT carries a status gate. `increment_comment_flags` is `SECURITY DEFINER` with no status check and no per-user dedup, so a banned session can push any comment past the auto-hide threshold of 3.

The login-route ban check (`app/api/auth/login/route.ts:41-49`) cannot be relied on as a control either: the anon key is in the client bundle and `@supabase/ssr` writes the auth cookie with `httpOnly: false` (`ssr/dist/main/utils/constants.js:4-11`), so a banned user can POST directly to `/auth/v1/token?grant_type=password` and set `sb-<ref>-auth-token` from `document.cookie`, obtaining exactly the session the 403 was meant to withhold. (That last point is inherent to Supabase's client-side auth model, not unique to this code.)

**Failure scenario.** An admin bans a spammer. The user's tab still holds a valid session. `/contribute` redirects them, but they can call the server actions directly from any page rendering comments: `voteOnContribution(<uuid>)` and `flagComment(<uuid>)` succeed, letting the banned account keep downvoting and mass-flagging other contributors' entries into auto-hidden status.

**Fix.** In `banUser`/`suspendUser`, also call `auth.admin.signOut(userId, 'global')` (or set `ban_duration`) so tokens are revoked at the identity provider. Factor the status check into a single `requireActiveUser()` helper and use it in **every** mutating server action, including `updateComment`, `deleteComment`, `flagComment`, `voteOnComment` and `voteOnContribution`. Add a per-user uniqueness guard to `increment_comment_flags`.

---

## 11. `/reset-password` changes the password of whatever session happens to exist

**`dictionary-app/app/reset-password/page.tsx:36`**

The page is a plain public client component. It renders the new-password form unconditionally and calls `supabase.auth.updateUser({ password })` with no prior `getUser()`/`getSession()` check, no check that the session came from a recovery token, and no current-password field. `middleware.ts` intercepts nothing and there is no `app/reset-password/layout.tsx`, so the route is reachable by anyone at any time. `updateUser` simply applies to whichever access token is in the browser's Supabase cookies, whoever it belongs to — and those cookies are `httpOnly:false` with `maxAge` 400 days (`ssr/dist/main/utils/constants.js`).

**Failure scenario.** Shared laptop at a language centre. Contributor A logs in and walks away without logging out. Contributor B sits down, navigates to `/reset-password` (browser back, history, or by typing it), enters a new password twice and submits. `updateUser` runs against **A's** still-valid access token: A's password is silently changed to B's chosen value, B sees the green "Password Reset!" screen, and B can now log in as A. The same path means anyone who obtains a session cookie can change the password without knowing the old one, locking the real owner out.

The exploit is not remote — it requires a browser already holding a valid session for the victim, at which point the attacker is already authenticated as them. The incremental gain is **persistence and owner lockout**, not initial access. But the defect stands on the plain reading of line 36.

**Fix.** On mount, call `supabase.auth.getUser()` and render the form only for a session that arrived via recovery — capture that state in the callback (a short-lived single-use marker cookie set alongside the redirect at `route.ts:12-21`, or subscribe to the `PASSWORD_RECOVERY` auth event) and otherwise show a link back to `/forgot-password`. Enable Supabase's "Secure password change" reauthentication so `updateUser` cannot change a password from an ordinary long-lived session, and sign out other sessions after a successful reset.

---

## 12. Login and callback cookie adapters return no existing cookies, so stale auth-cookie chunks are never cleared

**`dictionary-app/app/api/auth/login/route.ts:16`** (identical to `app/auth/callback/route.ts:29`)

`getAll() { return [] }` is not merely an optimisation. `@supabase/ssr`'s `applyServerStorage` uses the value returned by `getAll` to compute which existing cookies to expire: `const cookieNames = allCookies?.map(({name}) => name) || []`, then `removeExistingCookiesForItem = cookieNames.filter(name => isChunkLike(name, itemName))` (`ssr/dist/main/cookies.js:299-320`). With `[]`, `removeCookies` is always empty, so **a login never expires the previous session's cookies** — they survive at the default 400-day `maxAge`.

This matters because the session cookie is chunked at 3180 encoded chars (`utils/chunker.js:8`) and `combineChunks` prefers the unchunked name over the numbered chunks (`chunker.js:66-70`): a leftover `sb-<ref>-auth-token` **wins** over a freshly written `sb-<ref>-auth-token.0/.1`.

**Failure scenario.** A shared community laptop. User A logs in; A's session serialises under 3180 chars, so one cookie `sb-<ref>-auth-token` is written. A closes the tab without using Log Out. User B logs in via `/api/auth/login`; B's session (more identities/metadata) exceeds 3180 chars, so lines 18-22 write `.0` and `.1` — and A's unchunked cookie is left in place. On the next request `app/layout.tsx:46` reads the jar, `combineChunks` returns A's still-unexpired value first, and **B is served the site authenticated as A**: A's name in the nav, A's data on `/my-contributions`, and any contribution B makes attributed to A.

The full impersonation outcome needs that specific chunked/unchunked crossover plus a shared device; the more common mismatch (differing chunk counts) yields a corrupted cookie and an unexplained logout.

**Fix.** Give both routes a real `getAll()` returning `request.cookies.getAll()` — the login handler's `req` and the callback's `request` are both in scope — so `@supabase/ssr` can emit the `maxAge:0` removals for stale chunks alongside the new cookies. This is the same one-line change as finding 3.

---

## 13. Duplicate signup surfaces a raw Postgres constraint error and leaks account-existence state

**`dictionary-app/app/signup/page.tsx:136`**

The code checks `authError` (line 134) and `authData.user` truthiness (line 136) but never inspects `authData.user.identities`. With Supabase's user-enumeration protection and email confirmation enabled, `signUp` on an already-registered address returns **success**, not an error: for a confirmed existing email GoTrue returns a fabricated user object with a random id and `identities: []`. Because the code accepts it and proceeds to insert into `profiles` keyed on that id, the insert hits `profiles_id_fkey` — and the resulting `error.message` is returned raw (`actions.ts:62`/`route.ts:55`) and rendered verbatim at `page.tsx:193` → `202` → `264`.

**Failure scenario.** An attacker submits the signup form with `victim@example.com`. If that address has a confirmed account, the fabricated random uuid is not in `auth.users` and the page displays `insert or update on table "profiles" violates foreign key constraint "profiles_id_fkey"`. If the address is unregistered, signup simply succeeds. Two distinguishable responses give a usable oracle for whether an address has an account — defeating the enumeration protection GoTrue was trying to provide. A legitimate returning user meanwhile gets an incomprehensible Postgres error instead of "that email is already registered".

(The unconfirmed-account branch does *not* produce a third distinct signal as one might expect: per finding 2 those users have no profile row, so the insert succeeds. And the oracle depends on Supabase project settings that nothing in this repo pins.)

**Fix.** After `signUp`:

```ts
if (!authData.user?.identities || authData.user.identities.length === 0) {
  // existing account — show the SAME neutral message as success
  router.push('/verify-email'); return
}
```

Show "If that address is new, check your inbox for a confirmation link" for both cases. Never render a Postgres or GoTrue `error.message` to the client — log it server-side and return a generic string.

---

## 14. Profile insert is not idempotent; a lost response reports failure for an account that was actually created

**`dictionary-app/app/signup/page.tsx:162`**

Both writers use `.insert()`, not `.upsert()`/`ON CONFLICT` (`actions.ts:37-58`, `route.ts:29-50`), so the operation cannot be safely repeated. The `catch` at line 162 diverts to the fallback only when the message contains `'Headers'`/`'header'` (line 164); everything else — including the `Failed to fetch` produced when the server action *ran to completion* but the response was lost — is rethrown at line 188. The user is told signup failed even though the row exists, and `page.tsx:197` (the redirect to `/verify-email`) never runs, so they are never told to check their inbox. Their only visible next move — pressing Create Account again — hits finding 13. Additionally, `page.tsx:186` calls `await response.json()` without checking `response.ok`, so a platform-level 502/504 HTML body throws an unrelated `SyntaxError`.

**Failure scenario.** The server action inserts the profile successfully, then the serverless response is lost (Vercel timeout, mobile network drop, proxy reset). The client shows `Failed to fetch`. The user concludes the account was not created, never checks their email, and retrying gives a foreign-key error. Resulting state: a valid, verified-pending account whose owner believes it does not exist, plus an unconsumed confirmation email. The row itself is correct and the account works on the next login — the harm is a misleading error and a confusing retry.

**Fix.** Make the write idempotent — upsert on `id` with `ignoreDuplicates`, or treat a `23505` duplicate-key result as success — and treat any non-header error the same as the header case: retry once against `/api/create-profile`, then re-check whether the profile now exists before declaring failure. Check `response.ok` before parsing JSON at `page.tsx:186`.

---

## 15. Repo schema lacks the `guardian_consent` column the signup code inserts — any fresh environment orphans 100% of signups

**`dictionary-app/app/signup/actions.ts:53`**

Both profile writers insert a `guardian_consent` column (`actions.ts:53`, `route.ts:45`), but the `profiles` definition in `supabase/schema.sql:43-79` has no such column — the consent block stops at `guardian_email` (`schema.sql:63`). A repo-wide grep confirms the string appears in **no** `.sql` file at all, and `supabase/migrations/` contains only `add-ai-linguistic-fields.sql`. Production has drifted to include the column; the repo SQL is what any new environment gets.

PostgREST rejects an insert naming an unknown column with `PGRST204` ("Could not find the guardian_consent column of profiles in the schema cache"), which `actions.ts:60-63` returns as `{success:false}`, which `page.tsx:192-194` throws. Combined with finding 2 that means the auth user is created and the profile never is — **on every single signup, deterministically**. The fallback at `page.tsx:164` does not help because the message contains neither `'Headers'` nor `'header'`.

**Failure scenario.** A developer or staging deploy applies `supabase/schema.sql` to a fresh Supabase project. Every user who completes the form gets an `auth.users` row, then a PGRST204 error. Nobody can complete signup, and each attempt leaves another orphaned, un-cleanable auth user. The same happens if production is ever rebuilt from the repo.

**Fix.** Add `guardian_consent BOOLEAN NOT NULL DEFAULT FALSE` to `profiles` in `schema.sql`, and capture it — plus the production-only `user_word_completion` table and the leaderboard SELECT policy — as a real numbered migration under `supabase/migrations`, so repo SQL and production converge.

---

## 16. `age_range='under_18'` and `is_18_or_older=true` can both be stored; the two age questions are never cross-checked

**`dictionary-app/app/signup/page.tsx:97`**

Step 1 asks for age range including an explicit `under_18` option (`SignupForm.tsx:117`). Step 2 asks again as a radio pair (`ConsentForm.tsx:88-117`). `validateStep2` at `page.tsx:97` consults only `formData.is_18_or_older` and never compares it against `formData.age_range`. No server-side check exists (`actions.ts:34-58`, `route.ts:16-50`), and `schema.sql:43-80` has no CHECK constraint tying the columns together.

**Failure scenario.** A 14-year-old honestly selects "Under 18" on step 1, then on step 2 clicks "I am 18 years of age or older". That handler (`ConsentForm.tsx:93-97`) sets `is_18_or_older=true` and blanks `guardian_name`/`guardian_email`. The guardian panel (gated on `=== false` at `ConsentForm.tsx:120`) disappears, `validateStep2` passes with zero errors, and the profile is stored as `age_range='under_18'` **and** `is_18_or_older=true` with empty guardian fields. **This requires no devtools and no technical skill — just clicking the wrong radio.** Nothing in the application or schema ever flags the contradiction, so an operator auditing "which accounts are minors" gets a different answer depending on which column they trust.

**Fix.** Treat `age_range='under_18'` as authoritative — derive `is_18_or_older` from it rather than asking twice — or at minimum block submission and reject server-side when `age_range === 'under_18' && is_18_or_older === true`. Add `CHECK (NOT (age_range = 'under_18' AND is_18_or_older = TRUE))`. Run a one-off audit query against production for existing rows in this state. Note this also removes the second age radio entirely, which is where the already-known "guardian fields show before any age is chosen" defect lives.

---

## 17. Route protection is layout-only and inconsistent; `/my-contributions` and `/admin` have no status gate

**`dictionary-app/app/my-contributions/page.tsx:12`**

With `middleware.ts` neutered, the only access control is what each route re-implements:

| Route | auth | email confirmed | status |
|---|---|---|---|
| `/contribute` | ✅ `layout.tsx:37` | ✅ `:42` | ✅ `:53` |
| `/dashboard` | ✅ `layout.tsx:37` | ❌ | ✅ `:48` |
| `/my-contributions` | `page.tsx:12` (`if (!profile)`) | ❌ | ❌ |
| `/admin` | `page.tsx:11` | ❌ | ❌ (`is_admin` only, `:15`) |
| `/login`, `/signup` | no authenticated-user redirect | — | — |

`app/admin/actions.ts:6-13` `requireAdmin` likewise checks only `!profile || !profile.is_admin`. The DB does not compensate — production admin policies key off `is_admin = TRUE` alone.

**Failure scenario.** A banned user opens `/my-contributions`: `page.tsx:12` finds a profile (status not inspected) and renders their full contribution history, trust score and stats. More seriously, an admin account later suspended for abuse keeps working at `/admin` and can continue calling `banUser`/`excludeAllContributions` on other members.

The concrete exploit here is mild — the banned user sees only their own data and a link that bounces them out. The value of this finding is architectural: **there is no single choke point**, so every new protected route must remember to re-implement three checks, and two of the four existing ones already miss some.

**Fix.** Move authentication, email-confirmation and status checks into a shared `requireActiveUser({ requireAdmin?, requireVerified? })` helper used by every protected page and layout, backed by the middleware pass from finding 4. Add an authenticated-user redirect to `/login` and `/signup`.

---

## 18. Callback error and success text are echoed verbatim into styled login banners

**`dictionary-app/app/login/page.tsx:16`**

The callback builds failure redirects as `/login?error=${encodeURIComponent(error.message)}` (`app/auth/callback/route.ts:54, 68, 77`), and the login page copies `searchParams.get('error')` and `searchParams.get('message')` into state (`login/page.tsx:13-18`), rendering them as a red alert box (lines 105-109) and a green success box (lines 99-103). Nothing validates or allow-lists the values. The reset flow already trains users to expect such banners (`app/reset-password/page.tsx:46` pushes `/login?message=Password reset successful...`). React escapes the text, so this is **not** XSS — but the content is attacker-controlled first-party UI.

**Failure scenario.** An attacker sends contributors `https://truemotu.org/login?message=Your%20account%20was%20migrated.%20Your%20temporary%20password%20is%20motu2026%20-%20confirm%20it%20at%20truemotu-support.example.com`. The page loads on the genuine domain, over the genuine certificate, with a green success banner above the real login form. There is no visual difference from a legitimate post-reset message. The mirror-image attack uses `?error=` for a fake "account suspended, contact <attacker address>" alert. Impact is limited to social-engineering copy — no script execution, no credential capture, no state change.

**Fix.** Map callback failures to a small set of internal codes (`/login?error=link_expired`) and translate the code to fixed in-app copy; ignore any value that is not a known code. Same for `?message=`. This also removes the raw GoTrue error text from URLs.

---

## 19. Optional fields are written as empty strings instead of NULL

**`dictionary-app/components/ConsentForm.tsx:95`**

When a user selects "I am 18 or older", `ConsentForm.tsx:95-96` explicitly writes `''` into `guardian_name` and `guardian_email` rather than null; `page.tsx:34-35` initialises them to `''` too, and `who_taught: formData.who_taught || ''` appears at `page.tsx:153`, `actions.ts:47` and `route.ts:38`. All three columns are nullable TEXT in production and `lib/types.ts:44,49,50` declares them `string | null` — **the code contradicts its own type contract.**

**Failure scenario.** Verified in production: of the 2 existing profiles, `count(*) where guardian_name = '' or guardian_email = ''` is **2**, and `count(*) where guardian_name is null and guardian_email is null` is **0**. The natural safeguarding query an admin would write — `SELECT * FROM profiles WHERE guardian_email IS NOT NULL` — returns every adult on the site and is useless for finding accounts needing guardian follow-up. `who_taught` transmission-pattern analytics (`SignupForm.tsx:196-198`) cannot distinguish "skipped" from "answered blank".

**Fix.** Normalise on the server before insert (`const nullIfBlank = (s?: string) => s?.trim() || null`), pass `null` at `ConsentForm.tsx:95-96`, and backfill: `UPDATE profiles SET guardian_name = NULLIF(guardian_name,''), guardian_email = NULLIF(guardian_email,''), who_taught = NULLIF(who_taught,'')`.

---

## 20. No length, trim, or cardinality limits on any user-supplied string

**`dictionary-app/components/SignupForm.tsx:22`**

`handleLocationAdd` guards only with `if (location && !formData.locations.includes(location))` — a truthiness test, so `'   '` passes and is stored. Nothing trims, normalises case, caps entry length, or caps the number of entries. Neither `createUserProfile` (`actions.ts:37-58`) nor the API route (`route.ts:29-50`) applies any length limit to `name`, `email`, `who_taught`, `guardian_name`, `guardian_email`, or the `locations` elements. Production confirms every one of these columns is bare `text`/`text[]` with `character_maximum_length` null and zero CHECK constraints. `/api/create-profile` is a plain route handler with no configured body-size limit (unlike Server Actions, which default to 1 MB).

**Failure scenario.** Through the normal UI, a user pressing Enter on the location box with only spaces adds an invisible chip that can never be matched or deduplicated, and slight variations (`Hanuabada`, `hanuabada `, ` Hanuabada`) fragment the very location data the project exists to collect. Via the unauthenticated endpoint of finding 5, a `name` of 5 MB and a `locations` array of 100,000 strings are accepted and stored unbounded.

**Fix.** A zod schema on the server (`name: z.string().trim().min(1).max(100)`, `who_taught: …max(500)`, `locations: z.array(z.string().trim().min(1).max(100)).max(20)`) — this is the same schema as finding 5. Trim before the truthiness and `includes` checks at `SignupForm.tsx:21-25`. Add matching DB CHECK constraints (`char_length(name) <= 100`, `array_length(locations,1) <= 20`) so the invariant survives future code paths.

---

## 21. `profiles.email` is client-supplied, never reconciled with `auth.users.email`, and has no UNIQUE constraint

**`dictionary-app/app/signup/actions.ts:42`**

The email written to the profile comes from the request payload (`actions.ts:42`, `route.ts:34`), not the authenticated identity. The server already has the trustworthy value — `auth.users.email` for `data.userId` — and never consults it; no `admin.getUserById` call exists anywhere. The only format check is a loose `/\S+@\S+\.\S+/` at `page.tsx:52`, client-side, which the server does not repeat. Production has no unique index on `email` (only `profiles_pkey` and `profiles_id_fkey`).

**Failure scenario.** Divergence is **not** reachable through the browser flow — `page.tsx:127` and `:148` pass the same `formData.email` to both `signUp` and `createUserProfile`. Producing a mismatch requires the unauthenticated service-role write of finding 5, where a caller supplies their own `userId` with `"email":"elder@truemotu.org"`. The row is created and `profiles.email` now disagrees with `auth.users.email`; because the anon leaderboard policy exposes it, that forged address is what every visitor and any admin tooling reading `profiles` sees. This is not account takeover — password reset and login both go through `auth.users` — but it corrupts the contributor provenance record a language-preservation corpus depends on.

**Fix.** Drop `email` from the client payload entirely; in the server writer fetch it via `supabaseAdmin.auth.admin.getUserById(data.userId)` and insert `user.email`. Add `ALTER TABLE profiles ADD CONSTRAINT profiles_email_key UNIQUE (email)`.

---

## 22. The advertised 8-character password minimum is enforced only in browser JavaScript

**`dictionary-app/app/signup/page.tsx:58`**

The rule lives in three client-side places — `formData.password.length < 8` at `page.tsx:58`, `minLength={8}` at `SignupForm.tsx:62` with the visible promise "At least 8 characters" at `SignupForm.tsx:64-66`, and the duplicate at `reset-password/page.tsx:28`. The password never travels through any server code in this repository: `supabase.auth.signUp` is called directly from the browser (`page.tsx:126`) and `supabase.auth.updateUser` directly from the browser (`reset-password/page.tsx:36`). The only authority that evaluates password strength is the Supabase project's dashboard setting, which nothing in this repo pins or documents. Supabase's default is 6 characters with no complexity requirement.

**Failure scenario.** Anyone with devtools calls `supabase.auth.signUp({email, password:'abc123'})` against the public anon key, or edits the DOM to remove `minLength`. GoTrue accepts it if the project is on the default minimum, and the account is created with a 6-character password while the UI told every honest user the minimum was 8. The same bypass applies at `/reset-password`, so an existing account can be *downgraded* to a weaker password.

**Fix.** Set the minimum password length to 8 and enable the leaked-password check in the Supabase Auth dashboard, and record that setting in the repo's config or docs so it survives a project rebuild. The client checks are then a UX nicety rather than the actual control.

---

## 23. Minor's email address is placed in a URL query string, and `/verify-email` resends to any address supplied there

**`dictionary-app/app/verify-email/page.tsx:34`**

On successful signup `page.tsx:197` redirects to `/verify-email?email=<address>`, putting the contributor's email — potentially a child's — into a URL that lands in hosting access logs, browser history and any outbound referrer. `verify-email/page.tsx:10` reads the query param and lines 34-40 pass it straight to `supabase.auth.resend({type:'signup', email})` with the anon key. Nothing verifies the visitor has any relationship to that address. The only throttle in the app is the client-side `cooldown` state at line 45, which resets on page reload. `contribute/layout.tsx:43` builds the same email-bearing URL.

**Failure scenario.** Every contributor's email address is written into request URLs, so the hosting provider's access logs contain a list of addresses — including minors' — in plaintext regardless of how well the database is protected. Anyone can also visit `/verify-email?email=victim@example.com` and click Resend, though GoTrue enforces its own server-side per-address rate limits, so this is not unbounded, and whether the success/error rendering at lines 95-107 constitutes an enumeration oracle depends on GoTrue's enumeration-protection setting, which this codebase does not control.

**Fix.** Carry the email through a short-lived server-set cookie or `sessionStorage` rather than the query string so it never appears in a URL. Move the resend behind a server route that reads the address from the pending session rather than from user-controlled input, and return an identical response whether or not an unconfirmed account exists.

---

## Suggested order of work

The sequence below is dependency-aware: earlier items unblock or de-risk later ones. Items in the same numbered step can be done together.

1. **Close the self-promotion hole (finding 1).** `REVOKE UPDATE` on `profiles` plus a column allow-list and an explicit `WITH CHECK`. This is a pure SQL change with no code dependency and it is the only finding that hands over the entire dictionary. Do it first, today.

2. **Fix the drifted admin policies (finding 6) in the same migration.** Rewrite them to test the caller via `is_current_user_admin()` and scope them `TO authenticated`. This must land *before* you create the project's first admin account, because finding 6 arms itself the moment an admin row exists — and fixing finding 1 implies you will soon want a legitimate admin.

3. **Establish migration discipline.** Capture steps 1-2, plus the missing `guardian_consent` column (finding 15), the production-only `user_word_completion` table, and the leaderboard SELECT policy, as real numbered files under `supabase/migrations`. Everything after this point assumes repo SQL and production agree; without it, later schema fixes will drift again.

4. **Make signup atomic (finding 2).** Add the `AFTER INSERT ON auth.users` `SECURITY DEFINER` trigger and move profile creation server-side. Then backfill or delete the six orphaned production accounts and email those people. This is the fix that lets new contributors join at all, and it also resolves the non-idempotency (14) and largely retires the dual-writer divergence.

5. **Fix the cookie adapters (findings 3 and 12).** Change `getAll() { return [] }` to `request.cookies.getAll()` in both `app/auth/callback/route.ts:29` and `app/api/auth/login/route.ts:16`, restructure the callback so the exchange's cookie write lands before the response returns, and verify the Supabase email template setting end to end. One change, two findings; do it after step 4 so you can test a genuine new signup through the confirmation link.

6. **Restore real middleware (finding 4)** using the standard `@supabase/ssr` refresh pattern. Depends on step 5 in the sense that you want confirmation links working before you go looking for session bugs.

7. **Introduce a single `requireActiveUser()` choke point (findings 17 and 10).** Use it in every protected page, layout and mutating server action, and add `auth.admin.signOut(userId, 'global')` to `banUser`/`suspendUser`. Natural to build directly on the middleware from step 6.

8. **Authenticate and validate both profile writers (findings 5, 20, 21).** One shared zod schema enforcing consents, enums, string lengths and array cardinality; `getUser()` ownership check; email sourced from `auth.users`. Much of this is moot if step 4 replaced the writers with a trigger — do whichever remains.

9. **Add the missing `WITH CHECK` and column grants on `contributions`, and fix the trust-score ratchet (finding 9).** Independent of the auth work; slot in wherever there is SQL capacity after step 3.

10. **Do the safeguarding work (finding 7).** Publish real `/terms` and `/privacy` pages, add email infrastructure, implement the guardian token flow, gate contribution on guardian consent, and make the consent flags load-bearing in `lib/consensus.ts` and the public word pages. This is the largest item and the one with the longest lead time — start the Terms/Privacy drafting in parallel with steps 1-4, since it is writing rather than engineering.

11. **Fix the age contradiction (finding 16)** by deriving `is_18_or_older` from `age_range` and deleting the duplicate radio pair. Do it as part of step 10's ConsentForm rework — it also removes the already-known "guardian fields show before any age is chosen" defect.

12. **Add a `display_name` and de-identify the leaderboard (finding 8),** replacing the anon `USING (true)` policy with a minimal view. Depends on step 3 for the migration and step 10 for knowing which users are minors.

13. **Gate `/reset-password` on a recovery session (finding 11)** and enable Supabase's secure-password-change reauthentication. Easier once step 5 has the recovery callback actually working.

14. **Clean up error handling and messaging (findings 13, 18).** Neutral duplicate-signup message via the `identities` check, allow-listed banner codes, and no raw Postgres or GoTrue text rendered to users anywhere.

15. **Data hygiene and configuration (findings 19, 22, 23).** NULL-normalise the optional fields and backfill; set the password minimum and leaked-password check in the Supabase dashboard and record it in the repo; move the email out of the `/verify-email` query string.