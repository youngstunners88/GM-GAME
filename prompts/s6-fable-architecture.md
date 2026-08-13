@include prompts/_s6_facts.md

# YOUR ROLE: Fable-5 — lead implementer / architecture

Give concrete Godot 4.3 GDScript guidance (short, code-shaped) for these four,
each with the ONE failure mode most likely to bite and the minimal fix:

## T1 — Diamond Vault clerk + stake/crush economy
Design the cleanest economy model for TWO diamond resources:
- $DIAMONDS tokens (`diamonds_balance`) — STAKED via existing stake_diamonds().
- Blaze Diamonds (NEW counter) — CRUSHED, clamped by a stack limit.
Propose: (a) where the new `blaze_diamonds` counter + `BLAZE_DIAMOND_STACK_LIMIT`
live and how they persist (save/load); (b) a simple, readable CRUSH rule
(crush N Blaze Diamonds -> what? score? mint $DIAMONDS? shares?) — pick ONE and
justify in one line; (c) a minimal dialogue-panel approach in Godot (CanvasLayer
+ Labels + a numeric selector driven by existing input actions ui_left/ui_right/
interact) that avoids needing new input maps. Keep it testable headlessly
(the vault logic must be callable without the UI).

## T2 — S2 boss: diamonds/shards only, no circles
The redirectable ETH-orb volley (`_throw_shards`) is the "circles." Should we
(A) re-skin those orbs as diamond-geometry (hide dot + diamond Polygon2D child,
shift tint), keeping the Forced-Distribution redirect mechanic; or (B) delete
the orb volley entirely? Recommend one. If A, give the exact Polygon2D diamond
points + how to keep `redirected`/homing working with a child poly.

## T3 — S3 boss horizontal chase
Given the suspected jump-in-place cause in the facts, give the minimal change so
he travels meaningful horizontal distance while a player kites, WITHOUT
reintroducing ledge suicide. Constrain the "player above" hop so it can't fire
as a stationary vertical hop when the player is roughly overhead.

## T4 — Fort Knox depth
One concrete second-chamber/platforming beat + one interactable beyond coins
that fits GOLD MINE identity and is headlessly testable.

End each section with: "GATE:" and the single assertion that would fail on the
current code.
