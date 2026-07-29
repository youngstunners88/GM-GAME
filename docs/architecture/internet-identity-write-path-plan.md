# Internet Identity write path — implementation plan

Owner decision (previous session): **Option B, Internet Identity**, over Rabby
signature verification. This plan sequences the build and reports a real
feasibility probe run this session — not a paper estimate.

## Probe run this session (facts, not projections)

Before writing a line of production code, I tested the exact risk the ADR
flagged as unverified: loading `@dfinity/auth-client` (agent-js) and calling
`AuthClient.login()` from inside a browser context, both plain and inside a
`sandbox="allow-scripts allow-same-origin allow-popups allow-forms"` iframe
matching itch.io's embed constraints.

**Infrastructure reachability (all confirmed live from this environment):**
- `identity.ic0.app` → 200
- `id.ai` → 200
- `@dfinity/auth-client` on npm → 3.4.3, exists
- esm.sh / jsdelivr CDN URLs for the package → 200 via `curl`

**The actual test result:** `await import('https://esm.sh/@dfinity/auth-client@2.1.3?bundle')`
**hangs indefinitely** in Playwright's Chromium — no resolution, no rejection,
no network request/response event fires for the module at all. I confirmed
this happens **identically outside any iframe**, in a plain top-level page, so
it is not an iframe-sandboxing finding — it's a limitation of this sandboxed
test environment's Chromium network stack for ES-module dynamic imports
specifically (the same URL succeeds instantly via `curl` and via Node's
`fetch`, both of which go through the same egress proxy).

**Conclusion:** I cannot validate the itch.io-iframe-specific popup/WebAuthn
risk from this environment — not because it's hard, but because the browser
automation here cannot complete the one prerequisite step (loading agent-js)
regardless of iframe sandboxing. That risk is **still exactly as untested as
the ADR already said it was**. The plan below front-loads a cheap, real-browser
check of it before any further investment, rather than assuming either outcome.

## Build sequence

### Phase 0 — Real-browser validation spike (do this FIRST, ~30 min, no code committed)
On a real developer machine (not this sandbox):
1. Serve a one-file HTML page that imports agent-js from a CDN and calls
   `AuthClient.create()` → `client.login({ identityProvider: 'https://identity.ic0.app' })`.
2. Open it inside an actual sandboxed iframe (reproduce itch.io's iframe
   attributes — check the real embed's `sandbox` attribute value; itch.io
   games commonly run under `allow-scripts allow-same-origin` plus varying
   popup permissions depending on the page's "fullscreen" setting).
3. Record: does `window.open` get called, does it return a handle or `null`
   (`null` = popup blocked), does `onSuccess`/`onError` ever fire.
4. **Gate**: if the popup is blocked, do not proceed to Phase 1 as designed —
   fall back to `identityProvider` redirect mode (agent-js supports a
   full-page redirect flow as an alternative to the popup) and re-plan Phase 2
   around that instead.

This 30-minute spike is what turns the rest of this plan from a guess into a
plan grounded in the actual constraint.

### Phase 1 — Bridge script (`web/ii-bridge.js`)
Same pattern as the existing `web/web3.js` — a plain script (no build step,
no bundler) exposing `window.LilBluntII` with:
- `login()` — kicks off `AuthClient.login()`, resolves/rejects a promise
- `getPrincipal()` — returns the authenticated principal as text, or `""`
- `isAuthenticated()` — bool
- `logout()`

Loaded via `html/head_include` in `export_presets.cfg`, exactly like
`web3.js` is today (see `.github/workflows/export-game.yml`'s "Create export
preset" step) — additive, does not touch the existing Rabby script tag.

### Phase 2 — Godot bridge (`src/autoload/icp_backend.gd`)
New methods, following the `connect_wallet()` poll-until-done pattern already
in `web3_bridge.gd`:
- `login_with_ii(on_done: Callable)` — calls `window.LilBluntII.login()` via
  `JavaScriptBridge.eval`, polls for completion.
- `get_ii_principal() -> String`
- `submit_score()` rewritten to make an authenticated Candid update call to
  `leaderboard.submit()` using the II-derived identity, instead of routing to
  the Cloudflare Worker. `writes_are_onchain()` flips to `true` once this path
  is live and tested — not before.

No changes needed to `leaderboard.mo` or `player_registry.mo` — both already
authenticate on `Principal` and reject anonymous, which is exactly what II
provides. This is the concrete advantage Option B had over Option A: zero
canister rework.

### Phase 3 — UI entry point
New button in the layer-shift column (`src/ui/main_menu.gd`) or the crypto
onboarding panel — needs your call on exact placement/copy, since it's a new
user-facing concept ("connect with Internet Identity") alongside the existing
"CONNECT RABBY". Recommend: keep Rabby for token-perk reads (unchanged), add
II specifically at the leaderboard-submit moment, so a player never has to
understand both systems unless they want the on-chain score.

### Phase 4 — Verification
- Extend `tests/icp_contract_test.gd` with the authenticated-submit path
  (client-side construction only — signature/principal verification happens
  in Motoko and can't be exercised without a running replica, same limitation
  documented in the ICP ADR).
- Real-browser test via Playwright **outside** this sandbox if the Phase 0
  spike showed it's viable — this sandbox's Chromium cannot complete the
  agent-js import, so this gate cannot run here.
- Full 8-gate battery, as with every change.

## What I will not do

Per "do not commit broken auth code" — no bridge code lands until Phase 0's
real-browser spike confirms the popup/redirect question, because building
Phase 1-2 against the wrong assumption (popup works vs. needs redirect) means
rewriting the bridge's control flow, not just tuning it.

## Estimate

Phase 0 is a same-day check on a real machine. Phases 1-4 are the "2-3
sessions" from the original options paper, contingent on Phase 0's answer —
redirect-mode, if needed, is more code than popup-mode (a full page
navigation away from and back to the game, needing session/state
preservation across that round trip) and would revise this estimate upward.
