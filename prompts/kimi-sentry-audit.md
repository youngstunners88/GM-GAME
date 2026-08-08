# Kimi K3 — NARROW audit: Sentry error reporting (PII / re-identification)

**Output rules: emit ONLY the findings blocks and the verdict. No preamble, no
restated code, no extended reasoning. `NONE` for an empty section. Under 350
words total.**

## Engine facts (assume, do not correct)

- Godot 4.3, GDScript. `JavaScriptBridge` exists ONLY on the web export.
- `Web3Bridge.player_id()` = a locally generated random UUID in `user://`.
- The game also knows the player's **wallet address** and optionally an email.
  The backend receives BOTH the wallet and `player_id()` (via `submit_lore`),
  so anything sent to a third party keyed on the raw `player_id()` is one
  backend JOIN away from a wallet-linked identity.
- A Sentry DSN is a public, write-only ingest key (ships in browser bundles by
  design). It is committed deliberately.
- Project rule INJ-003: values interpolated into `JavaScriptBridge.eval` must
  pass a named sanitizer.

## What is new (audit ONLY this file)

`src/autoload/error_reporter.gd`, a new autoload. It loads the Sentry browser
SDK on the web export, tags `release` and a runtime-derived `environment`
(itch / vercel / netlify / cloudflare / local), and exposes
`report(where, context, level)`.

Five existing `push_error()` sites now also call it: three scene-load failure
paths, one save failure, one transition failure. Context dictionaries passed
in are things like `{"path": "res://src/level/level_02.tscn", "err": 1,
"route": "web"}`.

Sentry's own `captureMessage` is used; uncaught JS/WASM exceptions are picked
up by the SDK's global handlers.

## Questions — one or two lines each

1. **Re-identification.** The Sentry user id is
   `sha256("lil-blunt-errors-v1|" + player_id())[:32]`, a DIFFERENT salt from
   the analytics bridge. Does that actually prevent correlating a Sentry
   profile with a PostHog profile or with the backend's wallet-linked id?
   Is a fixed, source-visible salt sufficient here, given the DSN and the salt
   both ship in the client?
2. **Leakage via context.** `_strip_identifiers` removes a denylist of keys.
   Can a *value* still carry PII — e.g. a `res://` path, an error string, or a
   URL containing a token? Should anything be truncated or scrubbed by value
   rather than by key?
3. **Leakage via the SDK.** With `sendDefaultPii: false`, what does the
   browser SDK still attach by default that could identify a player (URL,
   query string, referrer, breadcrumbs, IP)? Anything that should be disabled
   explicitly for this game?
4. **Injection / failure.** Every eval hole goes through `_js_ident`
   (`^[a-z0-9_.:-]+$`), `_js_dsn` (strict DSN regex) or `_js_json`
   (JSON.stringify with U+2028/9 stripped). Any break-out? Can `report()`
   throw, block the main loop, or grow unboundedly if the CDN is blocked?
5. Anything else genuinely wrong.

## Findings format

```
SEVERITY: CRITICAL|HIGH|MEDIUM|LOW
FILE: <path>
CLAIM: <one sentence>
WHY: <runtime mechanism>
FIX: <minimal change>
```

Then `VERDICT: SHIP` / `DO NOT SHIP` + the single most important item.

---

@include src/autoload/error_reporter.gd
