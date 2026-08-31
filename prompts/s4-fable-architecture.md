You are the LEAD IMPLEMENTER on a Godot 4.3 2D platformer (GM-GAME). This is a
big session with a mandated architecture change plus four combat/flow bug
fixes. Give a concrete, buildable implementation plan for each — exact node
types, files, function signatures, and numbers. Read the shared facts first.

## A. VAULTS → full Blaze-class separate-scene environments (the headline)
The founder has REJECTED the in-level pit vault (last session's
`protocol_vault.gd`) and wants each vault to load a full separate environment
exactly like entering Blaze Rush / the Smoke Lounge secret realm. The Smoke
Lounge pattern (`secret_door.gd` entrance + `secret_realm.gd` scene +
`return_portal.gd` + `level_base._spawn_player()` resume) already does exactly
this and is proven. Plan concretely:
1. The ENTRANCE: replace the `protocol_vault` placement in
   `level_02_crystal_caverns.gd` / `level_03_gold_rush.gd::_setup_depth_routes()`
   with a `secret_door`-style Area2D at the same spot. Does it reuse
   `secret_return` (simplest — one bonus scene at a time) or need its own
   return dict? State the exact wiring, including one-visit-per-stage handling
   and the return-position resume (which `_spawn_player` already implements for
   `secret_return`). Confirm the kill_zone_gaps mechanism from last session
   should be REMOVED from those levels now that the pit is gone.
2. The SCENE: a new code-authored `diamond_vault_realm.gd/.tscn` and
   `fort_knox_realm.gd/.tscn` modeled on `secret_realm.gd` (parallax backdrops
   from the real founder art, own camera limits, floor, a `return_portal`).
   Give the skeleton and the constants (bounds, floor Y, camera limits).
3. The DIAMOND STAKE LOOP (Diamond Vault): a readable in-scene action where the
   player commits collected diamonds and gets a payoff/risk, using the real
   GoldMineSystem primitives (see facts). Propose the exact interactable + the
   exact GoldMineSystem calls + the on-screen readout. Fort Knox gets the
   equivalent GOLD staking loop via `stake_in_fort_knox`.
4. EXIT: `return_portal` back to the origin stage at entry position — confirm
   the existing `secret_return`/`_spawn_player` path delivers this and note the
   Blaze-style exit watchdog if you think it's warranted.

## B. T4 — Stage 3 boss (Claim Jumper)
From claim_jumper.gd + dynamite.gd + boss_sprite.gd + claim_jumper.tscn facts:
give the exact fixes for (1) back-facing (art_faces_right default vs the real
sprite direction, and the `absf(velocity.x) > 12` facing-update gate), (2)
"stops advancing / only jumps straight up" (which of ledge-sense / arena clamp
/ the THROW-VULNERABLE state machine freezes his horizontal advance, and the
minimal fix that restores pursuit without reintroducing the ledge-fall death
bug), (3) explosion "no damage" (i-frames? the await? mask? blast missing?).

## C. T5 — the "hammer"
No "hammer" exists in code. Given the tools that do (thrown axe, big axe,
pickaxe/breakables), and pending the vision model's ID of what the founder
circled, propose the most likely fix path for each candidate so we can apply
the right one fast once identified.

## D. T6 — Stage 3 death respawn
Confirm/refine the fix for the `get_checkpoint(1)` cross-level fallback in
`_respawn_or_game_over()` so the player respawns at/near the death position or
last safe ground in the CURRENT level. Give the exact replacement code.

Be concrete and concise. If a needed fact isn't provided, say what's missing.

@include prompts/_s4_facts.md

--- Entrance/exit/resume pattern to reuse ---
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/secret_door.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/return_portal.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/level_base_spawn_player.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/blaze_exit.gd

--- Current in-level vault to replace ---
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/protocol_vault.gd

--- Stage 3 boss + dynamite + boss sprite ---
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/claim_jumper.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/dynamite.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/boss_sprite.gd

--- Respawn ---
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/player_respawn.gd

--- Tools (for the "hammer") ---
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/axe.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/pickaxe_tool.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/big_axe.gd
