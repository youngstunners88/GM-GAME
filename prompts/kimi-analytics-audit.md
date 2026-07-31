# Kimi K3 — NARROW audit: PostHog analytics bridge (privacy + injection)

**Output rules: emit ONLY the findings blocks and the verdict. No preamble, no
restated code, no extended reasoning. Write `NONE` for an empty section. Keep
the whole reply under 350 words.**

## Engine facts (assume, do not correct)

- Godot 4.3, GDScript, tabs. `JavaScriptBridge` exists ONLY on the web export.
- `JavaScriptBridge.eval(code: String, use_global_execution_context: bool)`.
- `Web3Bridge.player_id()` returns a locally generated random UUID stored in
  `user://`. It is NOT derived from anything personal.
- The game also knows the player's wallet address and (optionally) an email.
- Project rule INJ-003: anything interpolated into `JavaScriptBridge.eval`
  must be sanitized or come from a fixed template.
- `config.json` ships inside the exported pck.

## What is new (audit ONLY this)

`src/autoload/analytics.gd` is a new autoload that forwards the game's
existing telemetry to PostHog on the web build. `Web3Bridge.track()`,
`report_event()` and `report_metric()` each now call `Analytics.capture(...)`
BEFORE their `has_backend()` early-return, so PostHog fires even when the
game's own backend is unconfigured.

The PostHog token is a `phc_` PROJECT WRITE key — public by design, append
only, cannot read data back. It lives in `config.json`, not in code.

## Questions — one or two lines each

1. **Injection.** `capture()` whitelists the event name to `^[a-z0-9_]+$` and
   passes properties as `JSON.stringify(...)` output with U+2028/U+2029
   stripped, interpolated into
   `window.__lbCapture && window.__lbCapture('<name>', <json>);`.
   Can ANY gameplay-controlled value break out of that JS string or execute
   code? Consider nested quotes, backslashes, `</script>`, and non-ASCII.
2. **PII leakage.** Only `distinct_id = player_id()` is attached. Trace the
   `props` dictionaries that flow in from `report_event`/`report_metric` —
   can a wallet address, email, or score-linked identifier reach PostHog
   through them? Flag any property that is effectively an identifier.
3. **Failure modes.** If the posthog script is blocked (CSP/ad-blocker) or
   the token is malformed, can `capture()` throw, block, queue unboundedly,
   or slow the game loop? The JS keeps a queue capped at 100.
4. **Autoload order / lifetime.** `Analytics` is registered AFTER
   `Web3Bridge` in project.godot but `capture()` calls
   `Web3Bridge.player_id()`. Any order or null hazard, including on the very
   first frame or on a non-web platform where `_enabled` is false?
5. Anything else genuinely wrong.

## Findings format

```
SEVERITY: CRITICAL|HIGH|MEDIUM|LOW
FILE: <path>
CLAIM: <one sentence>
WHY: <runtime mechanism>
FIX: <minimal change>
```

Then `VERDICT: SHIP` or `VERDICT: DO NOT SHIP` + the single most important item.

---

@include src/autoload/analytics.gd
