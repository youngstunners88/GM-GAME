# ICP write-path identity — two options

Facts only, per request. No recommendation. Decide, then say which and I'll
scope a story from the matching section.

Both options assume the same starting point: `leaderboard.mo` currently
rejects the anonymous principal, keys every `Entry` on `player : Principal`,
and its whole trust model rests on `caller` being unforgeable. `submit_score()`
in `icp_backend.gd` currently routes to the Cloudflare Worker, not the
canister, and `writes_are_onchain()` returns `false` — that flag is the single
place that needs to flip to `true` once either path is real.

---

## Option A — Rabby-only (EVM signature, anonymous principal accepted)

Score attribution comes from an EVM signature in the call *arguments*, not
from the IC principal. The canister accepts anonymous calls and recovers the
signer.

### Files that change

| File | Change |
|---|---|
| `lil-blunt-icp/src/leaderboard.mo` | Remove the `Principal.isAnonymous` rejection in `submit`. Add `mo:ecdsa` (or similar, see below) + a keccak256 implementation. Add a `submitSigned(payload, signature)` entrypoint that recovers an address from the signature and checks it against a claimed `wallet` field. `Entry.player : Principal` becomes `Entry.wallet : Text` (checksummed EVM address) or a parallel field is added and the ranking/dedup logic (`byScoreDesc`, `withoutPriorRun`, `bestScoreFor`) is re-keyed on it. |
| `lil-blunt-icp/mops.toml` | Add the ECDSA + hashing package dependencies (`ecdsa` v8.0.1 confirmed on mops; a keccak256-specific implementation still needs sourcing — `sha3` v0.1.1 exists but is unverified for keccak vs. standard SHA3 padding, per the Grok/Kimi audits). |
| `web/web3.js` | Add a `signScore(payload)` function calling `window.ethereum.request({method:'personal_sign', ...})` (or `eth_signTypedData_v4` for structured data), returning the signature to Godot. |
| `src/autoload/web3_bridge.gd` | New method to invoke the JS signing call via `JavaScriptBridge.eval`, matching the existing `connect_wallet()` poll-until-done pattern. |
| `src/autoload/icp_backend.gd` | `submit_score()` rewritten to: build the payload, call the new `web3_bridge` signing method, then POST/Candid-call `leaderboard.submitSigned` with payload+signature. `writes_are_onchain()` → `true`. |
| `tests/icp_contract_test.gd` | New assertions for the signed-submit path (client-side construction and dispatch only — signature *verification* happens in Motoko and can't be exercised without a running replica, same limitation as today). |
| `docs/architecture/adr-icp-integration.md` | Update the "Write path" section — this is the ADR's stated blocker, currently unresolved. |

### Nonce / replay protection required (new surface, not in the code today)
- A monotonic nonce or `(timestamp, max_skew)` window inside the signed payload.
- Canister-side tracking of used nonces per address, or a tight timestamp window — this is new state, analogous to but separate from the existing `cooldowns` table (which is keyed on `Principal`, not on an EVM address, so it cannot be reused as-is).

### Estimated Claude sessions
**3–4.** One for the Motoko crypto integration and re-keying (this is the largest single piece — recovering and checksumming an EVM address in Motoko has no existing precedent in this codebase to build from), one for the JS/GDScript signing bridge, one for wiring + the replay-protection state, one for verification/gates/fixes. Session 1 carries the most schedule risk (see below).

### Main risk
**The keccak256-vs-SHA3-256 padding mismatch**, flagged independently by both Grok's strategy paper and (implicitly, via the stale `sha3` v0.1.1 package) Kimi's audit. Ethereum's `keccak256` and the standardized `SHA3-256` differ in padding bytes; a package simply named "sha3" may implement either, or both under different function names, and there is no way to know without testing against a known Ethereum signature test vector. Get this wrong and every signature silently fails to recover the correct address — the failure mode looks like "the wallet integration is broken," not "we used the wrong hash," and could pass code review while being cryptographically incorrect.

---

## Option B — Internet Identity-only (keep current Principal model)

Keep `leaderboard.mo` exactly as it authenticates today (`caller : Principal`,
anonymous rejected). Add an Internet Identity login flow to the Godot HTML5
export so a real, non-anonymous `Principal` reaches the canister.

### Files that change

| File | Change |
|---|---|
| `lil-blunt-icp/src/leaderboard.mo` | **No changes required.** The identity model as built already assumes this path. |
| `lil-blunt-icp/src/player_registry.mo` | No changes required — `register()`/`me()` already key on `caller : Principal` and already reject anonymous. |
| `web/` (new file, e.g. `web/ii-bridge.js`) | New. Loads `@dfinity/auth-client` (or equivalent agent-js II client) via a `<script>` tag, exposes `window.LilBluntII.login()` / `.getPrincipal()` / `.getIdentity()` to be called via `JavaScriptBridge.eval`, matching the existing `web/web3.js` pattern. |
| `web/game/index.html` (CI-generated, but the export template/head-include changes) | Add the auth-client script tag. Per `.github/workflows/export-game.yml`, `html/head_include` already injects `web3.js` this way — the II script gets added alongside it. |
| `src/autoload/icp_backend.gd` | New `login_with_ii()` method (poll-until-done, same shape as `Web3Bridge.connect_wallet()`). `submit_score()` rewritten to make an authenticated Candid update call to `leaderboard.submit()` using the II-derived identity instead of routing to the Worker. `writes_are_onchain()` → `true`. |
| `src/ui/main_menu.gd` and/or `src/ui/crypto_onboarding.tscn` | New UI entry point — "CONNECT VIA INTERNET IDENTITY" or similar, alongside/instead of "CONNECT RABBY". Needs an owner decision on whether both wallet options are offered or II replaces Rabby for the write path specifically. |
| `docs/architecture/adr-icp-integration.md` | Update "Write path" section; the "Open questions" section already lists this as question 1. |

### The known unknown (per the existing ADR, marked "not verified")
`docs/architecture/adr-icp-integration.md` already flags: *"II auth expects a popup or redirect and WebAuthn... this is a known class of breakage (popup blocked, `window.opener` severed, WebAuthn bound to wrong origin)"* — inside an itch.io iframe specifically. This has not been tested in this environment and would need to be tested in a real browser, on the real itch.io embed, before the approach can be trusted.

### Estimated Claude sessions
**2–3.** No new Motoko, no new cryptography — the canister-side trust model doesn't change at all, which is the majority of the risk removed. The work is almost entirely: get agent-js loading correctly in a non-threaded HTML5 export, get the II popup/redirect flow working inside an itch.io iframe, and wire the Godot↔JS bridge in the existing pattern.

### Main risk
**The itch.io iframe may block the II popup outright**, and this can't be diagnosed by reading code — it requires a real browser test against the actual itch.io embed (sandboxed iframes, cross-origin popup restrictions, and WebAuthn's origin-binding are all runtime behaviors, not static properties). If it breaks, the fallback is a redirect-based flow instead of a popup, which is a different, larger implementation, or accepting that II only works when the game is played outside the itch.io iframe (e.g., a direct URL), which may be an unacceptable UX regression depending on how much itch.io traffic embeds vs. links out.

---

## Side-by-side

| | Option A (Rabby) | Option B (Internet Identity) |
|---|---|---|
| Canister identity model changes | Yes — significant rework | No |
| New cryptography in Motoko | Yes (ECDSA + keccak) | No |
| Reuses existing project pattern | Partially (Rabby UX already shipped for read-side perks) | Partially (agent-js is the "native" ICP pattern, but new to this repo) |
| Primary risk category | Cryptographic correctness (silent failure) | Runtime/iframe compatibility (must test in a real browser) |
| Sessions | 3–4 | 2–3 |
| Testable in this sandboxed environment ahead of time | Partially — Motoko logic testable once written; the client can't test against a live wallet extension here | Minimally — the iframe/popup risk specifically requires a real browser + real itch.io embed, which this environment cannot reproduce |
