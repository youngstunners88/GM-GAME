---
name: observability-wiring
description: Wire a third-party browser SDK (Sentry, PostHog, or the next one) into the Godot HTML5 export without it silently doing nothing. Use when adding analytics, error reporting, session replay, or any service that loads JS and POSTs from the game.
user-invocable: true
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Observability Wiring

Distilled from wiring PostHog and Sentry into this Godot 4.3 HTML5 build. Both
integrations hit the *same* traps. This exists so the third one doesn't.

## The failure mode this is really about

Every one of these integrations can be **fully written, compile clean, pass
every gate, and send nothing at all**. Analytics and error reporting are
uniquely bad here because *silence looks exactly like success* — no events is
indistinguishable from no errors. Assume it is broken until an event is
observed server-side.

## Order of work

### 1. Get a real credential and PROVE it before writing code

Do not build against a placeholder. Sentry's DSN and PostHog's `phc_` key are
both **public, write-only** ingest keys designed to ship in browser bundles, so
you can hold them locally.

Prove ingest with one curl **before** touching GDScript:

```bash
# Sentry — expect HTTP 200 + {"id": ...}
curl -s -w "HTTP %{http_code}\n" -X POST "https://$HOST/api/$PROJ/store/" \
  -H "Content-Type: application/json" \
  -H "X-Sentry-Auth: Sentry sentry_version=7, sentry_key=$KEY, sentry_client=probe/1.0" \
  -d '{"message":"probe","level":"info","platform":"javascript"}'
```

Then confirm it is **visible in the project**, not just accepted:
`GET /api/0/projects/<org>/<proj>/issues/`. Accepted-but-invisible is a real
state (wrong project, wrong DSN).

If the org/project doesn't exist yet, create it over the API rather than
asking the owner — the tokens are there for that:
`POST /api/0/teams/<org>/<team>/projects/` then read the DSN from
`/api/0/projects/<org>/<proj>/keys/`.

### 2. ⚠️ CSP — the trap that got BOTH integrations

The shipped policy was `connect-src 'self'`. That silently drops every event
while the code looks perfectly healthy.

**Both directives are needed**, and people forget the first:
- `script-src` → the CDN the SDK loads from
- `connect-src` → the ingest host it POSTs to

Update **all three** header files and verify the previous integration survived:

```bash
for f in vercel.json netlify.toml web/_headers; do
  echo "$f: posthog=$(grep -c posthog $f) sentry=$(grep -c sentry $f)"
done
python3 -c "import json;json.load(open('vercel.json'))"   # keep it valid JSON
```

itch.io serves its own headers and is unaffected — which means **a bug here is
invisible on itch and only appears on the mirrors**, or vice versa.

### 3. Mirror what exists; do not build a parallel system

Both integrations were wired by extending existing plumbing, not adding call
sites across the codebase:

- PostHog → mirrored `Web3Bridge.track/report_event/report_metric`
- Sentry → mirrored the existing `push_error()` sites

One taxonomy, two destinations. Two parallel lists drift within a month.

**Put the mirror call BEFORE any early-return.** PostHog's first draft sat
behind `has_backend()`, which would have switched analytics off entirely
whenever the game's own backend was unconfigured — alive in dev, dead in prod.

### 4. Privacy, enforced in code not in comments

- Never send the wallet address. It is a permanent financial identifier.
- Never send the raw `player_id()` — the backend receives BOTH it and the
  wallet, so a third-party profile keyed on it is one JOIN from being
  re-identified. Send `sha256("<service>-salt|" + player_id())[:32]`, with a
  **different salt per service** so the services can't be cross-joined either.
- Strip a denylist of keys recursively from any caller-supplied context. A
  promise in a docstring is not enforcement — this was a real Kimi finding.
- Turn off what the SDK does by default: autocapture, session recording,
  pageview capture, `sendDefaultPii`.

### 5. Expect the security sentinel to block you — do NOT hide from it

Any new `JavaScriptBridge.eval` with interpolation trips **INJ-003**. That is
the gate working.

The wrong fix is restructuring so the scanner can't see the interpolation.
The right fix: route every hole through a **named** sanitizer
(`_js_ident` whitelist, `_js_json` JSON literal, `_js_config`/`_js_dsn` strict
regex), then extend the sentinel's safe set to name it, with a comment saying
why it is provably safe.

**Then prove you extended rather than weakened it** — drop in a deliberately
unsafe eval, confirm INJ-003 FAILS, delete it, confirm it passes:

```gdscript
JavaScriptBridge.eval("window.foo('%s');" % [evil], true)   # must FAIL the gate
```

Note a known looseness: the check passes if *any* recognised sanitizer appears
anywhere in the eval expression, so a mixed call can pass on one marker while
another hole uses something unlisted. Add every sanitizer you use to the list
explicitly rather than relying on that.

### 6. Fail quiet, always

Missing key, non-web platform, blocked CDN, ad-blocker, service down — every
path must be a no-op. Queue with a hard cap (50–100) and wrap all JS in
try/catch. Observability must never be able to break the game.

## Checklist

- [ ] Credential proven with curl (HTTP 200) **and** visible in the dashboard
- [ ] `script-src` + `connect-src` updated in all 3 header files
- [ ] Previous integration's hosts still present
- [ ] `vercel.json` still parses as JSON
- [ ] Mirrored existing plumbing, no new parallel call sites
- [ ] Mirror call sits before any early-return
- [ ] Per-service salted id; denylist enforced in code
- [ ] Sentinel green; negative control proves the gate still bites
- [ ] `script_compile_test` green (a missing Godot binary makes a grepped run
      look like a silent pass — check for the "checked N scripts" line)
