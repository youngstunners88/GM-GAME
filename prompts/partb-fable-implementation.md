You are the LEAD IMPLEMENTER on a Godot 4.3 2D platformer (GM-GAME, "Lil
Blunt Adventure"). Design a concrete, minimal implementation plan for two
DOWNWARD set-pieces — Diamond Vault (Stage 2) and Fort Knox (Stage 3) — as
described in the shared facts below. These are in-level physical drop-in
chambers with a ladder exit, NOT separate-scene loads.

Answer these specific decisions, concretely, referencing the real files:

1. **One parametric `protocol_vault.gd`/.tscn (protocol: "diamonds"|"gold") vs
   two separate scenes** — which, and why? I lean parametric for reuse; push
   back if you see a reason not to.

2. **Chamber geometry as procedural StaticBody2D children built in _ready()**
   (matching how `level_base._create_platform` builds platforms) vs authored
   in a .tscn. Give the exact node structure: floor StaticBody (surface y≈800),
   two side-wall StaticBodies, and how to guarantee the player can't slip past
   a wall into the full-width kill band at y≈825. Give concrete sizes/positions
   for the Diamond Vault at L2 gap 2400-2500.

3. **The drop-in mouth**: the existing pit is only 100px wide. Confirm a 32px
   player falls cleanly through, and specify whether I need to widen the mouth
   or add guide walls so they can't catch the shoulder of an adjacent floor
   segment (segments extend y=650..720).

4. **The ladder exit**: exact `global_position`, `height`, and
   `top_exit_offset` so the player climbs from the chamber floor (~800) back
   onto the adjacent solid segment surface (y=650) — landing centred on solid
   ground, NOT over the pit (the top_exit_offset-lands-on-air bug already broke
   Stage 2 once). Do the arithmetic.

5. **Reward hook**: use `EntitySpawner.spawn("coin_diamonds", pos, self)` /
   `"coin_goldmine"` (these credit the correct HUD protocol row). How many /
   where inside the chamber for a satisfying but not degenerate reward.

6. **Wiring into the level**: both level scripts call `_setup_depth_routes()`
   in `_ready()`. Show the exact lines to add there for each level, and confirm
   nothing conflicts with the existing platforms/ladders/secret walls already
   placed at those x-ranges.

7. **Fort Knox name collision**: L3 already has a wallet-gated
   `hall_of_blaze` alcove titled "— THE FORT KNOX VAULT —" at x=3420. The new
   downward Fort Knox is different. Recommend the cleanest resolution (rename
   the alcove? re-title the new one?) that keeps the founder's locked "Fort
   Knox = downward vault" identity.

Keep it concise and concrete — exact numbers, exact node types, exact file
edits. If a needed fact isn't below, say what's missing rather than guessing.

@include prompts/_partB_design_facts.md
@include src/level/level_02_crystal_caverns.gd
@include src/level/level_03_gold_rush.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/partb/level_base_geometry_killzone.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/partb/ladder.gd
