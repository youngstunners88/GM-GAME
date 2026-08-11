<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-hud-tokens-clarity.md
     files inlined: 1
     tokens: 2642 in / 947 out
     cost: $0.0110
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Review

### 1. Does "TOKENS" communicate tokens ≠ coins?

**Partially. Weakly.**

What works:
- Header is smaller (18 vs 26) and cooler-tinted — hierarchy is visible.
- Sits under COINS/RINGS, so vertical order implies a category break.

What fails:
- Five same-size, same-style rows under one word still read as **one undifferentiated number wall**. A cold player sees `COINS 0 / RINGS 0 / TOKENS / GOLD 0 / DIAMONDS 0 / TITANX 0 / wBTC 0 / XAUT 0` and does not reliably parse “protocol tokens vs stage currency.”
- No indent, no shared tint on the children, no divider, no icons. The header is a label, not a group.
- COINS is still just another row above — nothing says “COINS = ETH/SOL/BTC per stage.”

To read better (minimal):
- Indent token rows ~8–12px, **or** tint all five token values the same cool color as the header.
- Optionally rename `COINS` → `COINS (ETH)` (or stage-aware) so the contrast is explicit.
- Without one of those, it’s clutter with a caption.

### 2. wBTC / XAUT inside TOKENS?

**Agree — keep them in.** Founder named the three protocol tickers; wBTC/XAUT are also not stage coins. Pulling them out creates a third mystery tier (“why are these orphans?”). Worse UX than a slightly broad TOKENS bucket.

If you ever split: only do it with a second sub-header (e.g. `RESERVES`), not by naked adjacency.

### 3. DIAMONDS vs BLAZE DIAMONDS

**Yes, confusable.** Same root noun, same font size, one row apart (only wBTC/XAUT between them after the reorder — and BLAZE is directly under the cluster). Players will merge them.

Minimal wording fix **without data-model changes** (pick one):
- Best: `BLAZE DIAMONDS` → `BLAZE` or `BLAZES` (drop the shared noun).
- Alt: protocol row → `$DIAMONDS` and keep `BLAZE DIAMONDS` (ticker sigil separates “protocol” from “minigame”).
- Alt: `BLAZE DIAMONDS` → `RUSH DIAMONDS` / `SMOKE` if lore allows.

Do **not** leave both as `*DIAMONDS` at the same type scale.

### 4. TAP OUT + Lil Blunt face (label + placement only)

**Mostly lands as forfeit/rage-quit**, not pause or shop.
- “TAP OUT” is wrestle/combat slang = surrender. Good match for “too hard, I’m out.”
- Face **immediately left** of a wide button reads as character endorsing the action (mascot quit button). Risk: can also read as “talk to Lil Blunt” / character action if the face is large or expressive/smiling.
- Mitigate by face scale ≤ button height, neutral/wilted expression, and keeping `(Q)` so it stays clearly a control, not flavor.

### 5. Label rewrites (by impact)

1. **`BLAZE DIAMONDS` → `BLAZES`** — kills DIAMONDS collision; highest priority.
2. **`COINS` → `COINS (ETH)`** (stage-swapped later) — makes TOKENS≠COINS actually legible.
3. **`DIAMONDS` → `$DIAMONDS`** (and `$GOLD` / `$TITANX`) — ticker mark = protocol, not loot.
4. **`TOKENS` → `PROTOCOL TOKENS`** only if space allows; else keep `TOKENS` + indent/tint children.
5. **`RINGS`** — fine; leave it.

**Bottom line:** TITANX row + rename PUFFS→BLAZE DIAMONDS + EXIT→TAP OUT are fine directionally. The TOKENS header alone does **not** carry the founder’s distinction; indent/shared tint + disambiguate the two “diamonds” or players will still treat everything as one loot list.