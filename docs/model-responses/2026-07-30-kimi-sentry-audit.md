<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-sentry-audit.md
     files inlined: 1
     tokens: 3219 in / 4390 out
     cost: $0.0755
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
```
SEVERITY: HIGH
FILE: src/autoload/error_reporter.gd
CLAIM: The Sentry SDK is loaded from a third-party CDN with `crossOrigin` set but no `integrity` hash, inside a page that performs wallet signing.
WHY: `s.src = 'https://browser.sentry-cdn.com/8.42.0/bundle.tracing.min.js'` + `document.head.appendChild(s)` executes remote JS with full page privileges; a compromised or mis-served bundle can intercept wallet-signature flows. The version is pinned but nothing verifies the bytes.
FIX: Add `s.integrity = 'sha384-…'` for the pinned bundle (or ship the SDK inside the export).
```

```
SEVERITY: MEDIUM
FILE: src/autoload/error_reporter.gd
CLAIM: The fixed, source-visible salt does not prevent re-identification by anyone holding the backend's player_id list, contradicting the header's "not joinable" claim.
WHY: The backend stores raw `player_id()` beside the wallet (submit_lore); computing `sha256("lil-blunt-errors-v1|" + player_id)` per row re-links every Sentry profile to a wallet. The distinct salt does correctly block Sentry↔PostHog correlation — that half works.
FIX: Use an independent random UUID in `user://` as the error id; fix the stale "same salted hash as analytics" comment.
```

```
SEVERITY: MEDIUM
FILE: src/autoload/error_reporter.gd
CLAIM: `_strip_identifiers` recurses only dictionaries, matches deny keys exactly, and never inspects values.
WHY: `{"items":[{"wallet":"0x…"}]}` (array) or a camelCase `walletAddress` key passes through intact; error strings/URLs can embed tokens, `0x…` addresses, or RPC keys with no truncation.
FIX: Recurse into TYPE_ARRAY; normalize keys (case/underscore) before denylist check; cap string length (~256) and regex-scrub wallet/URL-query patterns by value.
```

```
SEVERITY: MEDIUM
FILE: src/autoload/error_reporter.gd
CLAIM: With `sendDefaultPii:false`, default integrations still attach the page URL including query string and fetch/XHR breadcrumbs, and Sentry sees the connection IP at ingest.
WHY: HttpContext sets `request.url` from `location.href`; Breadcrumbs records XHR/fetch URLs — Web3 RPC endpoints commonly embed API keys or wallet parameters.
FIX: Add `beforeSend` to strip query strings, `beforeBreadcrumb` to drop/scrub fetch/xhr crumbs; enable "Prevent Storing of IP Addresses" project-side.
```

No injection breakout found: `_js_ident`/`_js_dsn` exclude quotes, `_js_json` interpolates as a bare literal (apostrophes safe inside JSON double quotes, U+2028/9 stripped), the pre-init queue is capped at 50, and all JS paths are try/caught — `report()` cannot throw or block.

VERDICT: DO NOT SHIP — add SRI (or bundle the SDK) before release; an unverified third-party script in a wallet-signing page is the one unacceptable risk here.