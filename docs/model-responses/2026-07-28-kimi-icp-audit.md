<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-icp-audit.md
     files inlined: 5
     tokens: 12491 in / 15923 out
     cost: $0.2763
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Trap and correctness audit

### price_feed.mo

- **med — price_feed.mo:~252 (`floatToText`, reached via `parseFloat` ~L185) — an unbounded digit string produces `+inf`, which is stored and later traps the `/prices` query.** `parseFloat` accumulates `whole := whole * 10.0 + v` with no magnitude bound; IEEE doubles don't trap on overflow, they go to `+inf`. `inf > 0.0` passes the `ingest` guard (~L171), so the quote is stored. Then `floatToText` calls `Float.toInt(Float.floor(inf))` — `Float.toInt` traps on non-finite input per mo:base. Consequence: `quotesJson()` traps, so `http_request` (`/prices`) and `getQuotes` fail until a clean `refresh` overwrites `quotes`; if the source keeps serving the huge value, reads stay bricked. Requires a hostile or glitched source, and the source is admin-picked — hence med, not high. Fix needs no new imports: reject `price > 1.0e18` in `ingest`.

- **med — price_feed.mo:~164-170 (`ingest`) — a trailing newline silently drops the LAST symbol, every refresh.** `Text.trim(body, #char '}')` only strips trailing `}` if `}` is the final character. For a body ending `...,"SMOKE":0.00042}\n`, the last pair's raw value is `0.00042}\n`, `parseFloat` hits `}` and returns null, and the "tolerant skip" design swallows it. Trailing newlines are common in real API responses, and with the documented two-symbol example it is always SMOKE (the sub-cent token the 8-decimal renderer exists for) that vanishes. Not a trap, but silent data loss on a mainstream input shape.

- **low — price_feed.mo:~169 (`ingest`) — scientific-notation values are silently skipped.** `parseFloat` accepts only plain decimals; `4.2e-4` returns null at the `e`. Sub-cent tokens are exactly where providers emit exponent form. Same skip-by-design path, same silent outcome.

- **low — price_feed.mo:~147 — `last_refresh := now` is set on any HTTP 200, even a garbage body.** If the body parses to zero quotes, `quotes` keeps stale data (intended) but `lastRefresh()` reports fresh and the 60s rate-limit window is consumed. Minor semantics issue: the name implies data freshness, not "last outcall attempt."

- **low — price_feed.mo:~196 (`parseFloat`) — `scale *= 0.1` accumulates rounding error.** Irrelevant at the 8 decimals the renderer keeps; noted only so nobody extends this parser to higher precision.

### leaderboard.mo

- **med — leaderboard.mo:~134 (`submit`) — `withoutPriorRun` keeps the LATEST run, not the "single best run" the comment claims.** Any new submission deletes the player's prior entry for that level unconditionally, then inserts the new one. A player (or a buggy/buggy-retried client) submitting a worse score erases their better one from the board. Self-inflicted only — `caller` is authenticated, so no griefing of others — but it contradicts the documented intent and a `score = 0` double-submit wipes a real record. Fix is in-file: only replace when the new score exceeds the stored one.

- **med — leaderboard.mo:~62, ~84-90 (`cooldowns`, `touchCooldown`, `lastSubmitOf`) — unbounded permanent state, O(n) work per submit.** Every unique principal that ever submits adds a `(Principal, Int)` pair that is never evicted. II principals are free to mint, so an attacker can grow `cooldowns` without limit at the canister's cycle expense; each `submit` then pays an O(n) `Array.find` plus an O(n) filter + Buffer rebuild. The board is proudly capped at `TOP_N = 100`; the cooldown table is the uncapped thing. Fix is in-file: in `touchCooldown`, keep only entries with `now - t < SUBMIT_COOLDOWN_NS` — expired entries are semantically dead anyway.

- **low — leaderboard.mo:~167 (`claimAdmin`) — first-come claim has a front-run window.** Any authenticated principal that calls before the deployer claims admin, and admin can `removeEntry`. Damage is delete-only by design (no score fabrication possible), which is the right blast-radius limit — but deployment procedure must claim in the same script that deploys.

- No trap paths found in the array handling: all four `Array.subArray` calls (`submit` ~L137, `top` ~L155, `topForLevel` ~L160, `http_request` ~L325) are guarded by explicit size clamps; `queryNat` accumulates into an unbounded `Nat`, so a huge `?limit=` cannot overflow; the rank loop's `e.at == now` match is unique because the 10s cooldown prevents same-nanosecond resubmission.

### player_registry.mo

- No trap paths found. `profiles[i]` is only indexed via `indexOf` results; `replaceAt` receives valid indices; `validWallet` and `sanitizeHandle` do no Nat subtraction and no slicing. The file is trap-clean as written.

- **med-low — player_registry.mo:~51 (`indexOf`), ~117 (`register`), ~154 (`heartbeat`) — unbounded `profiles` array with a linear scan on every call, and a full-array Buffer rebuild on every update.** One entry per principal is inherent to a registry, so this can't be exploited into corruption — but per-call cost grows linearly with player count, there is no cap or indexing, and `heartbeat` exists to be called often. Fine at hundreds of players; a cycles concern at tens of thousands.

- **low — player_registry.mo:~181 (`claimAdmin`) — same first-come front-run window as leaderboard.** Lower stakes (roles are documented cosmetic-only and cannot gate content), but `setRole` still controls the `#premium` flag.

### Bridge (icp_backend.gd) — not a canister, but in scope

- **low — icp_backend.gd:~127-136 (`fetch_prices`) — inconsistent `icp_online` latching across the three failure branches.** Non-200 → latch off; body-not-a-Dictionary → latch off; but `prices`-key-not-a-Dictionary → `_fallback_prices()` with NO latch. A canister returning well-formed JSON of the wrong shape gets retried (and pays the 6s timeout) on every call, unlike the other two failure modes.

- **low — icp_backend.gd:~36 — one `icp_online` latch covers two independent canisters.** A dead price-feed canister latches `icp_online = false` and silently disables leaderboard reads for the rest of the session, and vice versa. Degradation is safe (Worker fallback), but provenance shown in the HUD becomes wrong for a service that was actually up.

- **low — icp_backend.gd:~197 — malformed leaderboard payload emits `([], "icp")`.** If `entries` is missing or not an array, the client reports ICP provenance for an empty list instead of falling back to the Worker, which has real data. Cosmetic-trust issue, not a crash.

## 2. Consensus review of the outcall

Stripping all headers in `transform` (~L113) handles the documented problem (Date, rate-limit counters) and `transform` itself is deterministic (pure query, no state). It is **not sufficient in general**, because two fields survive verbatim and both can differ per replica:

1. **`status`.** The transform copies `arg.response.status` unchanged. If the provider returns 200 to some replicas and 429/503 to others — routine behavior once 13 replicas hit the same endpoint simultaneously, which itself can trigger provider-side rate limiting — consensus fails. The failure is caught (`#err("outcall failed: ...")`), so it manifests as intermittent flakiness, exactly what the comment claims to eliminate.
2. **`body`.** Kept byte-identical. Any per-request nondeterminism — embedded timestamps, request IDs, key reordering, whitespace — fails consensus. The current design is safe **only** against a source that returns byte-identical status and body for identical GETs within the consensus window. That is a property of the provider, not of this code, and `setSource` can change the provider without a canister upgrade, so the invariant is one admin call away from being silently violated.

What is fine: `max_response_bytes` truncation is consensus-applied and deterministic; the request carries a constant User-Agent and no per-replica headers. The robust fix (canonicalize status and body inside `transform`) would require re-serializing the parsed quotes — the parsing machinery (`parseFloat`/`ingest`) exists in-file, but `transform` would need a canonical body renderer, which is a design change, not a one-liner.

## 3. Cycles safety

- **Under-attachment:** the management canister rejects the call, the `await` throws, the `catch` returns `#err("outcall failed: ...")`. Attached cycles are refunded on reject, `last_refresh` is untouched so an immediate retry is allowed, and no state mutates. Graceful.
- **Fixed amount risk is liveness, not theft:** 230,949,972,000 is sized for a 13-node subnet. Outcall cost scales with subnet size, so on a larger subnet every `refresh` under-attaches and fails — the feed can never update, permanently. On a local replica it is fine.
- **Drain surface:** none reachable by a player. The only expensive path (`refresh`) is admin-gated AND rate-limited before `Cycles.add` executes. `transform`, `http_request`, `getQuotes`, `lastRefresh`, `top*`, `me`, `getProfile`, `count`, `size`, `getAdmin` are queries (no canister cycles). Reject paths in `submit`/`register`/`claimAdmin` are early returns costing trivial cycles. The one amplifier is the leaderboard `cooldowns` growth (§1): authenticated users make each subsequent `submit` O(n) — bounded per-call, but the bound ratchets upward forever.

## 4. Missing test assertions, ranked

1. **Leaderboard happy path.** Serve the exact bytes `leaderboard.mo`'s `listToJson` emits (`{"source":"icp","count":N,"entries":[{"player":"...","handle":"...","level":N,"score":N,"at":N}]}`) from the stub, call `fetch_leaderboard(2, 10)`, assert parse, `source == "icp"`, and that `level=2`/`limit=10` reached the URL. All 13 current assertions cover prices/URLs; the leaderboard read path — the primary feature — has zero coverage. **No replica needed** (stub HTTP, same pattern as the price test).
2. **Leaderboard fallback + latch.** Stub returns 500 → assert `leaderboard_ready` fires exactly once with Worker/offline provenance and `icp_online == false`. Also covers the empty-`entries` misprovenance finding above. **No replica needed.**
3. **Malformed prices shape.** Stub returns `{"source":"icp","prices":"oops"}` → assert offline fallback AND pin down the latch behavior (currently inconsistent with the other two failure branches — this test will document or catch the bug in §1). **No replica needed.**
4. **Non-positive price guard.** Stub returns `{"ETH":0}` → assert `GameManager.get_crypto("eth_price")` is unchanged. Note: this relies on `set_crypto_price` ignoring non-positive values; `game_manager.gd` is not inlined, so that guard is asserted by `icp_backend.gd`'s comments but unverifiable from the provided files. **No replica needed.**
5. **`check_health` true/false.** Cheap, and it is the only public method with no coverage at all. **No replica needed.**

Cannot be tested without infrastructure we don't have (named, per the sandbox note already in the test file): `submit()` anonymous rejection, the 10s cooldown, `MAX_SCORE`/`MAX_LEVEL` ceilings, latest-vs-best replacement (§1), `transform` determinism, and `refresh` rate-limit/cycle behavior. These need a running canister — a local replica via `dfx` or PocketIC; the test header states the sandbox can start neither, so these stay canister-compile-only for now.

## 5. Verdict

Safe to deploy to a **local replica** as-is, with two procedural conditions: claim admin on all three canisters in the same deployment script (the first-come claim windows are the only remotely exploitable items, and only at deploy time), and test `refresh` against the real source URL before trusting prices, because the parser silently drops the last symbol on trailing-newline bodies and drops exponent-notation values outright. The `floatToText` inf-trap and the consensus brittleness both require a hostile or nondeterministic source, which is admin-configured — acceptable locally, but they plus the unbounded `cooldowns`/`profiles` growth and the latest-overwrites-best score bug are the mandatory fix list before any mainnet deployment. Nothing secret is in the code, writes are correctly kept off the anonymous HTTP path, and the client degrades honestly — the architecture is sound; the findings are robustness and one real leaderboard logic bug, not design flaws.