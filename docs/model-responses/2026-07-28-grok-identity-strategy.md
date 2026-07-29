<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-identity-strategy.md
     files inlined: 0
     tokens: 941 in / 1997 out
     cost: $0.0139
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Score Attribution Options — Smoke Realm / ICP

## 1. Rabby-only path
**Verdict: Viable; attribute scores to an EVM address by verifying a signed message inside the canister (or a helper canister)—no ICP wallet required.**

Flow: client asks Rabby for `personal_sign` (or equivalent) over a structured payload (`score`, `level`, `timestamp`, `nonce`, game id). The signature + payload are submitted as **arguments** to a canister update. The call itself may arrive as the anonymous principal; attribution comes from ecrecover on the payload, not from the IC principal. This preserves “gameplay is never wallet-gated”: signing is only for submitting a run, not for playing.

**Can Motoko verify an EVM signature?** Ethereum signatures are secp256k1 + keccak256, with pubkey recovery. Motoko has **no built-in ecrecover**. Options that exist in the ecosystem (do not treat as drop-in without checking current status):
- A **Rust canister** (or Motoko → inter-canister call) using a secp256k1/keccak library to recover the address and compare to the claimed player.
- Community Motoko crypto libs—**VERIFY** maturity, audit status, and whether they support keccak256 + secp256k1 recovery (not just verification with a known pubkey).
- **VERIFY** cycle cost: recovery + keccak per submit is typically modest vs. game logic, but measure on a mainnet-equivalent subnet; reject if it forces fee UX onto players.

**HTML5 / itch.io constraint:** This path reuses the already-shipped Rabby path. No agent-js identity required for attribution if the canister trusts the recovered address + replay protections (nonce, max clock skew, one-submit-per-run id). **VERIFY** that your HTTP-gateway update path can pass arbitrary candid/JSON args from the non-threaded Godot export without SharedArrayBuffer; if gateway updates from raw `fetch` are too painful, a thin JS bridge page still does not need II.

**Cost summary:** Engineering cost is crypto-verify + replay layer; user cost is one Rabby signature prompt on submit—not on boot.

---

## 2. Internet Identity path
**Verdict: Clean IC-native auth, poor fit for anonymous itch.io traffic who only know Rabby.**

Friction for someone who has never heard of ICP:
1. Explain a second identity system unrelated to their EVM wallet.
2. Internet Identity popup / WebAuthn (passkey or device auth).
3. Return to the game and retry the write.

**itch.io iframe costs (specific):**
- The game already runs in a **cross-origin iframe**. II auth expects a popup or redirect and WebAuthn. **VERIFY** current II behavior under nested iframes and itch.io’s popup/sandbox attributes; this is a known class of breakage (popup blocked, `window.opener` severed, WebAuthn bound to wrong origin).
- Non-threaded Godot HTML5 further pushes you toward a **JS glue layer** (agent-js) outside the engine; II sessions must live there and survive iframe reloads.
- Cold-start players bounce: “Create Internet Identity” is a harder ask than “sign this run” for an audience already primed on Rabby.

Gameplay stays ungated only if II is required solely at **score submit** or **cosmetic claim**—never at level start. Even then, conversion will lag the Rabby-only path.

---

## 3. Hybrid
**Verdict: Use EVM address as the player-facing key; optional II principal as an IC-native capability link later.**

Sketch:
- **Play:** no wallet.
- **Submit run / write path:** Rabby `personal_sign` → canister verifies → store under `evm_address` (canonical leaderboard key for now).
- **Optional link:** once (or never) bind an II principal to that `evm_address` via a signed statement from both sides (“link claim”). **VERIFY** product need before building link UX.
- **Reads** (price feed, public boards): stay on anonymous HTTP gateway as today.
- **Reconciliation:** one canonical id for scores = **checksummed EVM address**. II principal is an alternate capability (e.g., future pure-IC features), not a second leaderboard row. If both present, map `principal → evm_address`; never split one player into two ranks.
- **Do not** require agent-js for the minimum write path; add it only if you later need non-anonymous IC calls (cycles-paying callers, per-principal allowlists, etc.). **VERIFY** before depending on delegated identity from inside the itch iframe.

---

## 4. Recommendation
**Verdict: Ship Rabby-only signed submits to the canister; defer II.**

| | |
|---|---|
| **Strongest for** | Players already have the Rabby onboarding path; one extra signature on submit matches “cosmetics and spectacle,” keeps itch.io iframe risk on a known integration, and unblocks ICP writes without teaching a second chain identity. |
| **Strongest against** | Canister must correctly implement EVM recover + replay resistance (or call a verified helper). Mistakes here are attribution bugs or forged scores—higher cryptographic burden than “trust II principal.” |

Reject pure-II as default: iframe + cold ICP education fights the chill, low-friction tone. Revisit hybrid only if you need IC-native permissions that cannot hang off a verified EVM address.

---

## 5. Onboarding narrative (Lil Blunt)
**Verdict: Frame signing as stamping a chill run receipt—not “connecting finance.”**

Example copy (submit moment, after a run—not at boot):

> “Nice run, friend. If you want it on the Realm board, Rabby can stamp this receipt—just a little smoke signal so the tax machines can’t fake your score. Play either way; the Realm stays open.”

> “Wallet’s only for flair and bragging rights. Levels? You unlock those with your feet.”