<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-analytics-audit.md
     files inlined: 1
     tokens: 2493 in / 5768 out
     cost: $0.0940
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**1. INJECTION — NONE**
Name regex excludes quotes/backslashes; the JSON lands as a bare JS literal (not inside a quoted JS string), so JSON-escaped `\"`/`\\` cannot terminate anything; `</script>` is inert under `eval` (no HTML parsing); U+2028/2029 are stripped; other non-ASCII is harmless inside JS strings.

**2. PII LEAKAGE**
```
SEVERITY: MEDIUM
FILE: src/autoload/analytics.gd
CLAIM: Nothing in capture() enforces the no-wallet/no-email rule — props are forwarded verbatim, and the call sites building them were not provided.
WHY: props.duplicate(true) goes straight into JSON.stringify; any caller-supplied key (wallet, email) or a score+timestamp correlatable with the public on-chain leaderboard reaches PostHog unfiltered. The Web3Bridge.report_event/report_metric/track bodies and EVENT_SCHEMA.md are missing, so the trace cannot be completed.
FIX: Strip a denylist (wallet, address, email, name) from payload before stringify — distinct_id is already force-overwritten — and provide Web3Bridge.gd to finish the audit.
```
```
SEVERITY: LOW
FILE: src/autoload/analytics.gd
CLAIM: distinct_id reuses the backend telemetry UUID, so PostHog data is one backend JOIN away from a wallet-linked identity.
WHY: the same player_id() keys both pipelines; if the backend ever maps that UUID to the wallet the game knows, the pseudonymous PostHog profile is re-identified.
FIX: Send an analytics-scoped ID (second random UUID in user://, or a hash of player_id with a "posthog" salt).
```

**3. FAILURE MODES — NONE**
Blocked script sets `__lbPH.blocked`; queue capped at 100; all JS wrapped in try/catch; malformed token/host disables before eval; capture() early-returns and cannot throw, block, or grow memory.

**4. AUTOLOAD — NONE**
Web3Bridge precedes Analytics; player_id() is called only at runtime behind the `_enabled`/`_loaded` gates; on non-web the `OS.has_feature("web")` check exits before any Web3Bridge touch.

**5. OTHER**
```
SEVERITY: LOW
FILE: src/autoload/analytics.gd
CLAIM: CSP correctness is load-bearing but unverifiable from this file.
WHY: the comment says the shipped CSP was `connect-src 'self'` and that vercel.json, netlify.toml and web/_headers were updated; none were provided — if wrong, events vanish silently (fail-quiet by design, but dead analytics).
FIX: Provide the three header files; confirm script-src and connect-src allow the configured host.
```
Also missing: `config.json` itself — token/host values unverified (the regexes cover shape only).

VERDICT: SHIP — first add the props denylist in capture(): it is the only code-level enforcement of "wallet never leaves the client," which today rests entirely on caller discipline.