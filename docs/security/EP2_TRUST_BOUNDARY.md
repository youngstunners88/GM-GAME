# Episode 2 — Trust Boundary Map

**Audited:** 2026-09-10 · **Skill:** `ep2-security-and-trust-audit`
**Scope:** every value-bearing outcome in the Episode 2 loop and the Gold Mine
economy simulation.

## Standing context — read this first

The game is **free-to-play today**. No real funds are emitted to players or to
any pool; the Gold Mine economy is a simulation in
`src/autoload/goldmine_system.gd`. Nothing below is currently exploitable for
money.

That is exactly why it is written down now. Every row marked **client-authoritative**
becomes a live mint the day this economy is wired to chain actions or
Proof-of-Play. The purpose of this document is to make sure that wiring step
inherits a known list, not a surprise.

## The boundary

The shipped artifact is a **Godot 4.3 web/mobile export**. Everything inside
`index.pck` executes on hardware the player controls:

- GDScript in the pack is not meaningfully obfuscated.
- The save is browser-side (`localStorage`/IndexedDB) and directly editable.
- The wasm can be patched; the JS bridge can be called from the console.

**There is no server.** There is no authority anywhere in the current
architecture that can independently verify anything the client asserts. So the
honest answer to "is this authoritative?" is **No** for every row — the useful
distinction is *how hard the forgery is* and *what it would be worth once real
value is attached*.

## Map

| # | Value-bearing outcome | Computed where | Authoritative? | What a tampered client could forge | Severity once on-chain |
|---|---|---|---|---|---|
| T1 | Entire economy state (all balances, shares, certs, lifetime counters) | `goldmine_system.gd :: load_save_data()` | **No** | Any non-negative balance, directly. Bypasses every function-level guard the economy has, because it assigns fields rather than calling the value-moving functions. | **Critical** — this is the widest hole; it makes every other row redundant for an attacker who just edits the save |
| T2 | GOLD awarded / forfeited by a chamber | `miner_shaft.gd :: _resolve()` | **No** | Any `gold_awarded`, by patching the vest fraction or emitting `chamber_cleared` directly with a chosen dict | **Critical** |
| T3 | Fort Knox shares from a melt | `goldmine_system.gd :: melt_gold(amount, staked_amount)` | **No** | `staked_amount` is a caller argument **never validated against anything the player actually staked**. Unlimited shares without holding the stake. | **Critical** |
| T4 | XAUT from an auction settlement | `settle_auction(user_contribution, total_pool)` | **No** | Both arguments are caller-supplied. Now clamped to a `[0,1]` share, so the ceiling is "the whole pool" rather than unbounded — but the *contribution* itself is still unverified. | **High** (was Critical: unbounded pre-fix) |
| T5 | Treasury distribution | `distribute_treasury_revenue(total_revenue)` | **No** | `total_revenue` is caller-supplied and **nothing is debited** — it is a pure mint into `xaut_balance` and `auction_gold_pool` | **Critical** |
| T6 | "Play happened" (Proof-of-Play) | the whole client loop | **No** | See below — the loop is entirely client-side | **Critical** |
| T7 | wBTC / Diamond / Blaze rewards | `award_wbtc`, `collect_diamonds`, `crush_blaze_diamonds` | **No** | Direct autoload calls; amounts are caller-supplied | **High** |
| T8 | Score / progression | `GameManager` | **No** | Same class; not value-bearing today but feeds reward gating | **Medium** |

### What the hardening pass *did* change

The Phase-1 fixes did **not** move authority — that is impossible without a
server. What they did is make the client-side ledger **internally consistent**,
so an *honest* client can no longer produce an impossible state and a
*dishonest* one has to lie deliberately rather than stumble into a mint:

- No value-moving function creates value from a negative amount (12 paths fixed).
- `settle_auction` can no longer mint unbounded XAUT (was 10⁶× on a crafted call).
- `award_wbtc` no longer overpays 100% on an unrecognised pool.
- `load_save_data` rejects negative balances and out-of-range Blaze stacks.

That is the difference between "the ledger has holes" and "the ledger is sound
but the client is not trusted to report to it". Only the second is a safe
starting point for on-chain wiring.

## Proof-of-Play spoofability

**Can "play happened" be asserted without playing? Yes, trivially, today.**

Concrete forgeries available right now:
1. **Skip the play.** Call the commit path directly (`Ep2SessionRoot._on_chamber_cleared`)
   with a chosen result dict. The guards prevent a *second* payout for the same
   chamber; they do not verify a first one was earned.
2. **Replay.** Re-enter a chamber repeatedly and legitimately claim each time —
   there is no per-account or per-epoch ceiling on how much a session may earn.
3. **Edit the save.** Set the post-reward state directly (T1) and never play at all.

**Design requirement for the on-chain step** (noted, deliberately *not*
half-implemented here): play evidence must be verifiable off-client. The
realistic shape for this game is a **seeded, deterministic replay** — the run's
seed and input sequence are submitted, an authority re-simulates them, and the
claimed outcome must match. The Episode 2 loop is already built for this: both
`RunnerGraybox` and `MinerShaftChamber` expose `step(delta)` and are driven
deterministically with no RNG in their outcome paths, which is precisely what
makes server-side replay feasible. Do not weaken that determinism.

## Config & secrets hygiene (verified this audit)

| Check | Result |
|---|---|
| Setup/provisioning script contains only bash | **PASS** — `scripts/bootstrap-godot.sh` (86 lines). No secrets, no MCP registrations, no onboarding prose. Its two URLs are `BASE_URL=` assignments for the pinned Godot release download — provisioning targets, not stray links |
| Exit-127 setup-script corruption residue | **PASS** — no residue; no API keys, MCP adds, or natural-language instructions anywhere in the script |
| `.mcp.json` | **PASS** — one server (`repowise`), no secrets, no bare URLs |
| `.claude/settings.json` | **PASS** — `enabledMcpjsonServers` is exactly `["repowise"]`; the orphaned `xdevplatform-xmcp` entry (enabled but defined nowhere) was removed in PR #69 |
| gitleaks allowlist narrowness | **PASS** — `.gitleaks.toml` allowlists exactly two compiled build artifacts (`web/game/index.wasm`, `index.pck`) by explicit path. No widened rules, no disabled detectors. `.gitleaksignore` holds 3 specific fingerprints, no wildcards |
| Historical private-key leak (commit `a0a4fb2`) | **RESOLVED** — history rewritten 2026-07-12 (two `git filter-repo` passes, owner-approved), full-history scan verified 0 occurrences. **Fixed this audit:** `.gitleaks.toml`'s comment still claimed the rewrite had *not* happened and that a full-history scan "will keep failing — correctly". That note was stale and actively dangerous: it instructs a future reader to expect a red full-history scan, which is how a genuinely new leak gets waved through. Comment corrected to state that a clean scan is now the expectation and a red one is a new finding |
| Security sentinel | **PASS** — 18/18, 0 blockers at `fail-on=high` |

## Web-export budget

| Metric | Value |
|---|---|
| `index.pck` | **191,857,168 bytes = 182.97 MiB** (valid `GDPC` magic) |
| CI gate | 199,229,440 bytes = 190.00 MiB |
| Headroom | **7,372,272 bytes = 7.03 MiB** |
| Delta from this audit | +2,240 bytes (economy guard code only) |

Test and audit assets are excluded by
`exclude_filter="*.yml,*.yaml,*.md,docs/*,tests/*,prompts/*,scripts/*"`, and no
fixture was added under `src/`. The new gates live entirely in `tests/`.

## Open findings — resolve before on-chain wiring

These are **not** fixed, deliberately. Each needs a product decision or a
protocol number that does not exist yet; inventing one would violate the
never-invent-protocol-numbers rule.

| # | Finding | Why it is not fixed here |
|---|---|---|
| O1 | **Claim certificates are granted free.** `_check_certificates()` gates on 22,000 shares only. `CERT_PRICE_XAUT = 0.5` is declared and **never used** — the white paper's 0.5 XAUT price is not charged | Charging it changes player-facing behavior, and see O2 — it cannot be charged correctly today |
| O2 | **Fractional prices cannot be represented.** `CERT_PRICE_XAUT` is `0.5` but `xaut_balance` is an `int`. A 0.5-XAUT charge is unrepresentable in the current ledger | Needs a fixed-point / decimals decision (the same one on-chain wiring needs). Rounding it silently would be inventing a protocol rule |
| O3 | **`RESERVE_FORFEIT_SPLIT = 0.50` is unused.** `forfeit_to_auction`'s docstring claimed a 50/50 melt-vs-Strategic-Reserve split; the code sends 100% to the auction pool | No Strategic Reserve ledger exists. Docstring corrected to state the real behavior and flag the gap |
| O4 | **`STOCKPILE_LP_MATCH_PCT = 0.10` is unused.** The 10% wBTC LP match has no implementation | Chamber 4 (Stockpile Depot) is unbuilt; the sink has no destination yet |
| O5 | **30% of the treasury split is discarded.** `distribute_treasury_revenue` computes `swf` and `founder` shares and returns them, but moves neither | No SWF or founder ledger exists |
| O6 | **`melt_gold`'s `staked_amount` is unvalidated** (T3). Shares are minted proportional to a number the caller asserts | Fixing it requires a real per-player stake ledger — an architecture change, not a guard |
| O7 | **Fort Knox lock length is not rejected above 2,888 days.** The *bonus* correctly clamps at 2,888d, but the lock length itself is accepted unbounded | Harmless today (bonus is capped); becomes meaningful if lock duration ever drives payouts |
| O8 | **Vercel mirror is missing CSP / nosniff / referrer-policy** on the live response, though `vercel.json` defines them (carried from the 2026-07-12 audit, item A8) | Needs a Vercel redeploy; no Vercel token is wired into this environment. itch.io is primary and serves its own headers |

## Re-audit triggers

The N/A rows in `docs/security/GAME_SECURITY_CHECKLIST.md` are N/A **because the
architecture has no such surface yet**, not permanently. Re-audit immediately and
unprompted the moment any of these appear: a real backend, user accounts, a
leaderboard, real payments, multiplayer, **or any on-chain call**. This document
becomes the checklist that on-chain wiring must clear.
