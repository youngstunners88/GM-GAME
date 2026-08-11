# Secure Build Checklist

> Source: `Documents/VibeCoded-App-Security-DeepDive.md` (9 Instagram reels, July 2026).
> Use this checklist **before** shipping any app, API, service, or agent-built software.

The 15 issues → 10 preventative measures, organised into 9 build-time categories.

---

## When to run this

- Before the first deploy of any new project
- Before every release of an existing project
- Every Monday as a recurring security check
- The moment any new dependency, endpoint, or auth flow is added

---

## 1. Secrets & Environment

- [ ] No secrets hardcoded in source (API keys, tokens, passwords, private keys)
- [ ] `.env` files are gitignored
- [ ] No `.env` file has ever been committed (check `git log --all`)
- [ ] All secrets read from `process.env` / `os.environ` / equivalent at runtime
- [ ] `.env.example` exists with blank values for onboarding

**Why:** Matt Murphy — "847 dependencies. You installed 7. Run npm audit." A single leaked `.env` exposes every service credential. Assume any committed secret is public within minutes.

---

## 2. Dependencies & Supply Chain

- [ ] `npm audit` / `pnpm audit` / `bun audit` reports no high/critical vulnerabilities
- [ ] Lockfile (`package-lock.json`, `pnpm-lock.yaml`, `bun.lockb`) is committed
- [ ] No known-malicious or recently-compromised packages installed
- [ ] All git remotes use HTTPS, not HTTP
- [ ] Deps updated within last 6 months (or pinned with reason)

**Why:** Hayden Smith — vibecoded apps often import 100s of packages with `npm install whatever` and never audit. Transitive dependencies hide one vulnerable package you never chose.

---

## 3. Auth, AuthZ & Sessions

- [ ] Every non-public route calls an auth helper (`requireAuth`, `getServerSession`, `withAuth`, etc.)
- [ ] Public route list is **explicit and small**: login, signup, webhooks, health, public assets
- [ ] No client-side auth check (localStorage, cookies read in browser) is the only check
- [ ] Every protected action re-verifies on the server
- [ ] Webhook handlers verify the provider's signature (Stripe, GitHub, etc.)
- [ ] New routes default to **private** — flip to public only with justification

**Why:** Casco — "This is the #1 security vulnerability we find from [vibe coders]: default-public routes." Every new endpoint ships with auth off, then someone forgets to turn it on.

---

## 4. Injection & Input Validation

- [ ] No raw SQL string concatenation (use parameterised queries / Prisma `$queryRaw` tagged templates)
- [ ] MongoDB queries never receive unsanitised user-controlled objects (block `$gt`, `$ne`, `$where`)
- [ ] HTML rendering uses sanitisation (DOMPurify) or framework default escaping
- [ ] Shell commands use `execFile` / `spawn` with args arrays, never interpolated user input
- [ ] File paths from user input are resolved and verified to start with the intended base directory
- [ ] File uploads validated for type, size, and stored outside the web root

**Why:** Patrick Minardi / Jordan — SQL/NoSQL/command injection are still the #1 class of breach. AI models frequently emit unsafe patterns by default.

---

## 5. AI-Generated Code Specific Risks

- [ ] No `eval()`, `new Function()`, or string-based `setTimeout` / `setInterval` in source
- [ ] **Supabase / Postgres tables have RLS enabled AND a policy created** (not just `ENABLE ROW LEVEL SECURITY` with no policy — that's still allow-all)
- [ ] CORS is not wildcard (`*`) on authenticated routes
- [ ] **API keys never bundled into client**: no `VITE_`, `NEXT_PUBLIC_`, `REACT_APP_`, `EXPO_PUBLIC_` prefixes for secrets
- [ ] AI-generated code reviewed by a human or second pass before merge
- [ ] Prompt-injection guards on any user-input-fed LLM feature

**Why:** Perly — "Stop using Supabase if you code with AI." RLS defaults off; vibe coders ship the entire user table as public read. Mritunjay — most breaches are "unseen" because nobody looks.

---

## 6. API Hardening

- [ ] Rate limiting on every public endpoint (default 60/min/IP reads, 10/min/IP writes, 5/min auth)
- [ ] Bearer auth on write API routes (since most platforms expose them publicly by default)
- [ ] Generic error messages in production (no stack traces leaked to client)
- [ ] Request size limits (body, file upload) configured
- [ ] CORS origin is an explicit allowlist, not `*`

**Why:** Mritunjay — exposed APIs get discovered by automated scanners within hours. Rate limits + auth on writes are the baseline.

---

## 7. Logging, Monitoring & Error Tracking

- [ ] Error tracking live in production (Sentry, PostHog, LogRocket, Bugsnag)
- [ ] No PII in logs (emails, passwords, tokens, payment data)
- [ ] Audit log for: login, logout, signup, password reset, role change, API key creation
- [ ] Alerts configured for: auth failures spike, error rate spike, unusual outbound traffic

**Why:** Emmanuel — "If you don't want to get hacked, use these." Visibility is the difference between learning about a breach from your users vs. your bank.

---

## 8. Data Handling & Legal Posture

- [ ] Terms of Service published before collecting any data or charging money
- [ ] Privacy Policy published and reflects actual data collected
- [ ] User data export and account deletion flows exist (GDPR / POPIA right-to-be-forgotten)
- [ ] All third-party assets (fonts, images, models, snippets) have compatible licenses
- [ ] Cookie banner / consent if you serve EU users

**Why:** @thedslabs — "Vibe coders are getting sued. Most haven't realised." ToS/PP missing = you can't legally collect emails, let alone charge.

---

## 9. Infrastructure & Deployment

- [ ] HTTPS enforced everywhere; HSTS header set
- [ ] `NODE_ENV=production` set in deploy environment (not just `.env`)
- [ ] Database backups automated, daily, with offsite copy; restore tested quarterly
- [ ] Secrets stored in platform secret manager, not `.env` files in production
- [ ] Dependencies and base images regularly updated (Dependabot / Renovate / equivalent)

**Why:** Vibecoded apps frequently ship with debug mode on, no backups, and secrets in `.env` on the server. Each of those is a single point of failure.

---

## 10. Platform Privilege & Control-Plane Abuse

- [ ] Every privileged capability has a written purpose, least-privilege boundary, consent flow, visible indicator, revocation path, and abuse-case test.
- [ ] Release builds cannot enable or self-pair Wireless ADB, drive Developer Options, or connect to a device debug daemon.
- [ ] No silent permission grants, package install/uninstall, arbitrary shell commands, or hidden privileged helpers.
- [ ] Accessibility services, overlays, screen capture, device-admin, background services, boot receivers, and update mechanisms are explicitly justified and stoppable.
- [ ] Remote command and streaming channels use TLS plus strong peer authentication, scoped capabilities, replay protection, rate limiting, and revocation.
- [ ] The actual release artifact has been inspected for debug bridges, test endpoints, developer menus, source maps, test certificates, and verbose logs.
- [ ] Kill, revoke, reboot, uninstall, offline, and compromised-server tests have been run.

Why: Group-IB documented RedHook abusing a legitimate Android control plane: Accessibility automation enabled Wireless Debugging, an on-device ADB client reached the local daemon, and a Shizuku-derived helper obtained shell-level capability. The lesson generalises beyond Android: legitimate privileged interfaces become attack paths when consent, scope, visibility, and release isolation are weak.

## Pre-Launch AI Audit Prompts

Run these four prompts against your codebase before each release:

### 1. Supply-Chain Scan
> Audit the dependency tree. List every direct dep, the version, when it was last updated, and any open CVEs (≥7.0 CVSS). Flag any package that hasn't been updated in >12 months. Flag any package with <1000 weekly downloads unless it's a well-known foundation lib.

### 2. Permission Audit
> List every file/database/endpoint in this app. For each, answer: who can access it, how is that verified, what's the blast radius if compromised? Flag any resource where "anyone on the internet" is currently the answer.

### 3. Input-Trust Audit
> Find every place user input enters the system (request body, query params, headers, file uploads, webhooks). For each, trace where it flows: rendered as HTML? Concatenated into SQL? Interpolated into a shell command? Used as a file path? Used as a Mongo query key? Flag anything not parameterised / sanitised / allowlisted.

### 4. Secret-Leak Scan
> Grep the entire codebase (including git history) for: api_key, secret, password, token, bearer, AWS_, sk_live_, sk_test_, whsec_, xoxb-, ghp_, AKIA, BEGIN PRIVATE KEY. Report any matches with file path, line, and whether the value looks like a real credential (≥16 chars, not 'example', not 'xxx').

---

## Quick Decision Tree

```
Shippable now?
├─ Any SEC or AUTH critical open?  →  NO. Block release.
├─ Any INJ or AI critical open?    →  NO. Block release.
├─ Any DEP critical open?          →  NO. Block release.
├─ Anything else open?             →  Document, prioritise, ship with timeline.
└─ All clear?                      →  Ship. Re-run weekly.
```

## References

- `Documents/VibeCoded-App-Security-DeepDive.md` — full source essay
- `assets/checklist.json` — machine-readable rules (used by `scripts/audit.ts`)
- `scripts/audit.ts` — automated scanner that runs every check against a project
