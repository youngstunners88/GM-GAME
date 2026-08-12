Role: RE-ROOT-CAUSE from scratch, no memory of prior sessions, show all
arithmetic — this is the load-bearing role this session. A Godot 4.3 2D
platformer. Read the shared facts. Four questions.

## Q1 — Stage 2 boss "STILL not chasing, STILL not firing crystals" LIVE
A prior session moved the crystal-shard attack to rotation slot 0 and proved,
in a headless real-physics gate, that it fires at ~2.2s and the boss closes on
a kiting player. The founder says it's STILL broken live — no chase, and the
attack "looks the same as the Stage 1 boss". Treat the prior fix as unproven.
Re-derive from `distributor.gd` (full file below) against the REAL Stage 2
arena (boss spawn, arena clamp, single flat floor — in the facts):
1. Is there ANY path where `_physics_process` silently no-ops or the boss never
   leaves its opening state in a FRESH fight (the player's first impression)?
2. The founder says the crystal attack "looks the same as the Stage 1 boss".
   Compare what `_throw_crystal_shards` actually spawns (scene, tint, motion)
   vs `_throw_shards` (the ETH orbs) vs the Stage-1 clipboard — is the crystal
   shard visually distinct ENOUGH, or does it reuse the same projectile scene
   so it reads identical? If it's not visually distinct, that IS the bug the
   founder is reporting, regardless of timing.
3. Is the chase real against a KITING player (running away) in the real arena,
   or only against a stationary one? Re-derive the net closing rate.
4. Given headless gates keep passing while the founder sees it broken, what is
   the most likely LIVE-only explanation, and what gate would actually catch
   it? Give the exact fix.

## Q2 — Stage 3 boss (Claim Jumper): back-facing + freeze + no-damage
From claim_jumper.gd + dynamite.gd + boss_sprite.gd (below) and the facts:
1. Back-facing: reason through `art_faces_right` (defaults true; is the
   bandit-cart art actually right-facing?) AND the `absf(velocity.x) > 12`
   facing-update gate. Which causes the reported back-to-player, and the fix.
2. "Doesn't move beyond this point, only jumps straight up": walk the state
   machine + ledge-sense + arena clamp in the real level_03 arena. What
   specifically zeroes his horizontal advance and leaves only the vertical hop?
   Give the minimal fix that restores horizontal pursuit WITHOUT reintroducing
   the ledge-fall-death bug (`_ledge_ahead`/`_gap_crossable` exist for that).
3. Explosion "no damage": trace `dynamite._explode()` step by step against the
   player's `take_damage()` (i-frame gate: 1.0s post-hit, 1.5s post-respawn;
   PLAYING-only). Is it i-frames, the one-frame await, the mask, or the blast
   landing where the player no longer is? State the single most likely cause
   with the timing arithmetic and the fix.

## Q3 — Stage 3 death respawn "appears somewhere else"
Confirm/refine: `_respawn_or_game_over()` falls back to `get_checkpoint(1)`
(Level 1's checkpoint COORDINATE) when the current level has no checkpoint,
teleporting the player to a Level-1 x/y inside the Level-3 scene. Give the
exact replacement so the player respawns at/near the death position or the
last safe grounded position in the CURRENT level. Watch for: respawning inside
a wall/into the boss, respawning over a pit, and the lives==0 full-wipe branch
(which should still restart the level from its start — don't break that).

## Q4 — Vault soft-lock invariants for the NEW scene-transition architecture
The vaults are being rebuilt as separate scenes (Blaze/Smoke-Lounge pattern:
`secret_return` dict + `return_portal` + `_spawn_player` resume). Give the
soft-lock invariants this MUST satisfy: what happens if the return dict is
empty/stale, if the player dies inside the vault scene, if the return scene
path is wrong, and how the existing exit-watchdog pattern (blaze_exit.gd)
should or shouldn't be reused. What's the failure mode to gate against?

Show arithmetic where it matters. Name any missing fact.

@include prompts/_s4_facts.md
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/distributor.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/claim_jumper.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/dynamite.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/boss_sprite.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/player_respawn.gd
