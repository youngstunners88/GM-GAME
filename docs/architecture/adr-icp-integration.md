# ADR: Internet Computer (ICP) as the Layer 4 trust backend

**Status:** Accepted (Phase 1 — one canister, read path only)
**Date:** 2026-07-27
**Supersedes:** nothing · **Superseded by:** nothing
**Related:** `docs/security/GAME_SECURITY_CHECKLIST.md`, `docs/GDD_v1.2_BLUNT_FORCE.md`

---

## Context

The founder's ecosystem ($SMOKE, $DIAMONDS, $GOLD, 420 NFTs) is a tokenised
economy, and an external analysis (ICP_ANALYSIS.md + ICP_integration.pdf,
2026-07) argued that a centralised game backend contradicts that posture and
proposed ICP + Caffeine Skills as a "Layer 4" infrastructure tier.

The strategic argument is sound and we are adopting it. Three things about our
actual situation change the *sequencing*, and this ADR records them because
following the brief literally would have produced a worse result.

### 1. We are not starting from zero

The brief assumes a greenfield backend. We already run a **live Cloudflare
Worker + KV** backend (`config.json → backend_base_url`) serving the
leaderboard, the AI Oracle, analytics, adaptive difficulty, cross-chain balance
reads, and the whole AgentMail engine. So this is a **migration with a
fallback**, not a build-out. Every ICP path added here degrades to the Worker,
which in turn degrades to offline mode.

### 2. Three commands in the brief do not exist

Verified directly, not assumed:

| Brief says | Reality |
|---|---|
| `npm install -g @icp-cli/cli` | **404 — package does not exist.** The DFINITY package is `@icp-sdk/icp-cli` (v1.2.0, Apache-2.0, published 2026-07-23). There *is* an unrelated `icp-cli` on npm from an unaffiliated author — installing that, as the brief's wording invites, would have been wrong and is a supply-chain footgun. |
| `icp init … --template fullstack` | **No `init` subcommand** (it is `icp new`) and **no `fullstack` template.** Real templates: `motoko`, `rust`, `hello-world`, `static-website`, `bitcoin-starter`, `proxy`. |
| `icp deploy --network local` | Command exists, but the local replica cannot start here — see Consequences. |

The build also needs two toolchain pieces the brief never mentions: **`mops`**
(`npm i -g ic-mops`) and **`ic-wasm`** (`cargo install ic-wasm`). Without both,
`icp build` fails.

### 3. "Caffeine Skills" is not a prerequisite

Caffeine Skills are instructional SKILL.md files that help an agent write
correct Motoko/ICP code. They are useful, not load-bearing — the canister in
this ADR was written and compiled without them. We are not blocking on
`npx skills add caffeinelabs/skills`.

---

## Decision

**Adopt ICP as Layer 4, starting with exactly one canister: the leaderboard.**

This follows the brief's own best instruction ("Start with ONE canister
(leaderboard). Prove it works end-to-end before adding more") over its more
expansive Phase 1–4 plan.

### Why the leaderboard first

It is the only part of our backend where centralisation is a **trust** problem
rather than a cost problem. Cloudflare KV is cheap, fast, and globally
distributed — ICP will not beat it on either. What the Worker *cannot* do is
prove it isn't lying: anyone with the API token, including us, can rewrite a
score. On ICP the board is replicated state produced by public code, so "the
scoreboard is honest" becomes checkable rather than promised.

By the same logic we are **not** migrating the price feed first, despite the
brief putting it in Phase 1. A price cache is a latency/cost optimisation;
moving it to ICP adds HTTP-outcall cycle costs and consensus latency to solve a
problem we don't have. It can come later, on merit.

### Architecture as built

```
Godot client ──GET /top────────► leaderboard canister (ICP)   ← reads, public
     │                              ▲
     │                              └── submit(level,score,handle)  ← Candid
     │                                   authenticated update call
     └──fallback──► Cloudflare Worker ──► offline cache
```

- **Reads** go over the canister's HTTP gateway (`http_request` query method,
  returns JSON) so plain `HTTPRequest` works with no client libraries.
- **Writes stay Candid update calls.** An HTTP POST to a canister arrives as
  the *anonymous principal*, so it could not be attributed to a player — an
  HTTP write path would make the on-chain board exactly as trustworthy as the
  Worker one, i.e. it would be theatre. Until Internet Identity is wired
  through `JavaScriptBridge`, `IcpBackend.submit_score()` delegates to the
  Worker and says so in the code.

### Anti-cheat: the honest claim

The canister enforces authenticated caller, rejects the anonymous principal,
caps score and level, applies a 10s per-principal cooldown, and keeps one best
run per player per level. Admin can **remove** entries but there is
deliberately no "set score" — a compromised admin key can delete, never
fabricate.

What this does **not** do is stop a modified client from reporting a score it
didn't earn. Our game is client-authoritative; no backend choice fixes that.
The honest claim is **attribution and an auditable history**, and the marketing
copy must say that and not "cheat-proof."

### Guard rails carried over from existing project rules

- Canister IDs live in `config.json`, never in code — same rule already applied
  to contract addresses. `IcpBackend` validates the ID's character set before
  interpolating it into a URL.
- **No wallet gate on gameplay.** This does not change with ICP. Per
  `docs/GDD_v1.2_BLUNT_FORCE.md` pillar 4, token holdings may unlock cosmetics
  and spectacle only. The brief's "Fort Knox stake proven → unlock Gold Rush
  early access" is **rejected** on those grounds — it gates content behind
  holdings, which contradicts the no-pay-to-win posture we already committed to.
- The empty `leaderboard_canister_id` makes `IcpBackend` inert, so this ships
  dark and changes nothing at runtime until a canister is actually deployed.

---

## Consequences

### Positive
- Leaderboard becomes independently verifiable; anyone can `GET /top` and read
  the canister's public source.
- No new runtime risk: ICP is strictly additive behind a fallback chain, proven
  by both browser suites passing unchanged with the autoload registered.
- The Motoko canister **compiles to wasm** (264 KB) with a Candid interface —
  this is verified, not planned.

### Negative / accepted costs
- Cycles must be topped up or the canister freezes. Unlike the Worker's free
  tier this is a recurring, if small, obligation.
- Two extra toolchain dependencies (`mops`, `ic-wasm`) for anyone building the
  canister.
- Query calls are not certified by default; a gateway could in principle serve
  a stale board. Certified reads are a later hardening step.

### Blocked in this environment (verified, not assumed)
`icp network start` **cannot run in the CI sandbox.** The launcher is fetched
from `https://api.github.com/repos/dfinity/icp-cli-network-launcher/releases/latest`,
which returns **403 from the egress policy** (bare `api.github.com` returns 200,
so it is that specific path, consistently). The Docker fallback network mode is
also unavailable — Docker is installed but has no running daemon.

Per the sandbox's own proxy guidance, a policy 403 is reported, not routed
around. So local end-to-end deploy is the one brief deliverable that must be
run on a developer machine. Everything up to it — scaffold, dependency
resolution, Motoko compile, wasm + Candid emission — is verified here.

---

## How to deploy (developer machine, ~5 minutes)

```bash
npm install -g @icp-sdk/icp-cli ic-mops   # NOT @icp-cli/cli — that is a different package
cargo install ic-wasm                     # required by the Motoko recipe

cd lil-blunt-icp
mops install
icp build                                 # verified working in CI
icp network start --background            # needs api.github.com reachable
icp deploy --network local
icp canister call leaderboard claimAdmin  # one-time, first-come
```

Then put the printed canister id into `config.json → icp.leaderboard_canister_id`
and the game starts reading from ICP with the Worker still standing behind it.

Mainnet deploy additionally needs cycles; see `icp cycles --help`.

---

## Open questions for the founder

1. **Identity.** Internet Identity is the natural fit for authenticated
   submissions, but the game currently onboards through Rabby (EVM). Do we want
   players holding two identities, or should II be introduced only on the
   leaderboard screen?
2. **Cycles ownership.** Who funds and monitors the cycles balance? A frozen
   canister fails closed to the Worker, so it degrades safely — but silently.
3. **Migration or mirror?** Do we dual-write scores to both backends for a
   period and compare, or cut the leaderboard over once II lands?
