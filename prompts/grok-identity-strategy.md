ROLE: You are a crypto UX strategist writing an options paper for the owner of a
Godot 4.3 HTML5 platformer that has just added an Internet Computer backend.

This is a STRATEGY DOCUMENT. Do not write production code.

CONSTRAINT (non-negotiable): Do not invent APIs, SDKs, file paths, or platform
capabilities that do not exist. If a claim depends on something you are unsure
exists in the ICP or Rabby ecosystem, mark it explicitly as "VERIFY" rather
than asserting it. The owner will act on this document, so a confident wrong
answer is worse than a flagged uncertainty.

## The actual situation (not hypothetical — this is shipped code)

- Godot 4.3, exported to **HTML5, non-threaded** (no SharedArrayBuffer). It runs
  in an itch.io iframe. This constrains what a wallet SDK can do in-page.
- The game already onboards through **Rabby** (EVM). There is a "CONNECT RABBY"
  menu entry and a crypto-onboarding explainer panel.
- Tokens: $SMOKE (Base), $DIAMONDS + $GOLD (Ethereum). Balances are read
  server-side because a wallet provider's `eth_call` only sees its current chain.
- The ICP **read** path works: a `price_feed` canister serves JSON over the
  HTTP gateway; the Godot client parses it.
- The ICP **write** path is blocked on exactly this decision. An HTTP POST to a
  canister arrives as the ANONYMOUS principal, so scores cannot be attributed.
  A real write needs a Candid update call signed by a player identity, which
  means agent-js in the browser.
- Standing product rule: **gameplay is never wallet-gated.** Levels unlock by
  playing. Token holdings may add cosmetics and spectacle only. Any option that
  requires a wallet to play is automatically rejected.
- Theme: "The Smoke Realm". Lil Blunt is a chill, friendly weed-nugget mascot.
  Enemies are bureaucratic tax machines. Tone is relaxed, never aggressive,
  never a hard sell.

## Deliverable (max 900 words)

1. **Rabby-only path.** How would score attribution work if we stay EVM-only —
   sign a message client-side and have the canister verify it? Say plainly
   whether a Motoko canister can verify an EVM signature, and at what cost.
   Mark VERIFY if unsure.
2. **Internet Identity path.** Friction for a player who has never heard of ICP.
   Be specific about what the popup flow costs us in an itch.io iframe.
3. **Hybrid.** Architecture sketch. Where does identity get reconciled — is one
   canonical, or do we key on both?
4. **Recommendation**, with the single strongest argument for and against.
5. **Onboarding narrative** that makes the chosen path feel native to the Smoke
   Realm. Two or three sentences of actual in-game copy, in Lil Blunt's voice.

## Output format

Markdown, numbered to match the above. No preamble. Lead each section with a
one-line verdict, then the reasoning.
