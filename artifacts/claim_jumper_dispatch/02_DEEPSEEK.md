# DeepSeek — Claim Jumper stuck fix: failure modes + regression risk checklist

## Context
Same patch as described for Kimi's review (see below) — a height ceiling
(`already_high_enough`, gating at >400px above the player's y) added to two
trigger points in the Claim Jumper (Stage 3) boss's hop/air-hop logic, to
stop an unbounded vertical-chaining bug that read as "stuck near the
minecart/TNT/Hall of Blaze area."

@include src/boss/claim_jumper.gd

## Founder's explicit hard rules for this fix (must not be violated)
- Never stuck — must always eventually leave a ledge/platform when the
  player is beyond it.
- Double jump must still fire in real chase paths.
- Must NOT regress the Stage 2-style standoff/CHASE_SEPARATION behavior into
  "ride on top of the player" lock-on.
- No speed-only fix (this isn't one — it's a height gate).
- Preserve TNT/dynamite attack windows and identity.
- Do not touch Stage 2 (`src/boss/distributor.gd`) or level_02 files.
- No new art assets.

## Your job
Produce a failure-mode / regression-risk checklist for THIS SPECIFIC PATCH
(not a generic Godot boss AI checklist). For each item: is it a real risk
given the actual code above, or ruled out — and why?
1. Could `already_high_enough` ever get stuck TRUE for the rest of the
   fight (e.g. if the player dies/respawns far below, or the player
   reference becomes stale/null mid-fight), permanently disabling hops?
2. Could the gate cause the boss to get stuck in a NEW way — e.g. refusing
   to hop across a legitimately tall gap because the player is temporarily
   >400px below, even though the correct chase behavior needs the hop?
3. Does gating the outer `if is_on_floor() and _hop_cooldown <= 0.0 and not
   already_high_enough:` risk skipping something else nested inside that
   block that ISN'T actually part of the height-chaining bug (re-read the
   full nested block to check what else lives inside it before answering)?
4. Interaction with `_clamp_to_arena()`'s deliberate floor-only Y clamp —
   does the new ceiling gate conflict with, duplicate, or leave a gap
   relative to that existing design decision?
5. Any test-coverage gap: what real-arena scenario would you add beyond
   "player pinned at the wall for 16s" to be confident this doesn't
   regress in actual play (e.g. player oscillating in/out of arena, player
   dying near the wall, TNT explosion mid-chain)?

Answer as a numbered list, each with verdict (REAL RISK / RULED OUT) and one
sentence of reasoning grounded in the actual code shown above.
