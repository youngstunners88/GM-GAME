ROLE: You are a verification engineer auditing Motoko canisters and the Godot
bridge that talks to them.

The complete, current source of every file under discussion is inlined below.
You are NOT being asked whether these files exist — they do, and you can read
them. Base every statement on the code as given.

CONSTRAINT (non-negotiable): Do not invent methods, file paths, functions, or
Motoko/GDScript standard-library APIs that do not appear in the inlined files.
If you need something that was not provided, name exactly what is missing
instead of guessing.

## Ground truth (correct these if the code contradicts them)

- `leaderboard.mo` owns score submission. `player_registry.mo` owns identity
  and roles ONLY — it has no score path. (An earlier brief claimed otherwise.)
- `price_feed.mo` performs HTTPS outcalls and defines the `transform` query
  function that IC consensus requires.
- 13/13 assertions in `tests/icp_contract_test.gd` currently pass. They test the
  GODOT half over real HTTP against the exact JSON `price_feed.http_request`
  emits. They do NOT execute the canisters — no local replica is available.
- `crypto_state` is a live cache inside `game_manager.gd`. It is a Dictionary,
  not a separate file. Balances and prices must never be written to disk.
- Writes go to the Cloudflare Worker, not to a canister, because an HTTP POST
  to a canister arrives as the anonymous principal.

## Files

@include lil-blunt-icp/src/price_feed.mo
@include lil-blunt-icp/src/player_registry.mo
@include lil-blunt-icp/src/leaderboard.mo
@include src/autoload/icp_backend.gd
@include tests/icp_contract_test.gd

## Tasks

1. **Trap and correctness audit of the Motoko.** For each canister, list any
   place that can trap at runtime or silently corrupt state. Be specific:
   function name, the condition, and the consequence. Pay particular attention
   to `parseFloat` and `ingest` in `price_feed.mo`, and to the array rebuild
   patterns in `leaderboard.mo` and `player_registry.mo`.

2. **Consensus review of the outcall.** `transform` strips all headers. State
   whether that is sufficient for IC consensus given the request as written,
   and name anything else in the response that could differ per replica.

3. **Cycles safety.** `refresh()` attaches a fixed cycle amount. Identify what
   happens on under-attachment, and whether any caller can drain cycles.

4. **Test gaps.** The existing suite tests the Godot client. List the highest
   value assertions that are MISSING, ranked, and say for each whether it can
   be tested without a local replica. Do not write tests that would require
   infrastructure we do not have.

5. **One-paragraph verdict**: is this safe to deploy to a local replica as-is?

## Output format

Markdown. For every finding: `severity (high/med/low) — file:line-ish — claim —
why it matters`. No preamble, no summary of what you were asked to do.
