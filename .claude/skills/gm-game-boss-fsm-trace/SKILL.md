---
name: gm-game-boss-fsm-trace
description: Freeze/soft-lock taxonomy and boss-chase root-causing for Lil Blunt Adventure. Read this the moment the founder reports "the game froze" (especially "but the music is still playing"), or "the boss doesn't chase / is too easy / is parked". It lists the known freeze classes (which are already hardened, so you don't re-chase them) and the measure-first method for chase complaints.
---

# gm-game boss FSM + freeze trace

Origin: DeepSeek's FSM/freeze packet + real-physics measurement, 2026-08-25
HEAVY GAUNTLET. Persisted so no future session re-derives this from scratch.

## "Frozen but music still playing" — the freeze taxonomy

Audio runs on its own thread, so "music plays while everything else is stuck"
means gameplay stopped advancing. Check these IN ORDER; the first three are
already hardened — confirm they're intact rather than re-investigating them:

1. **Stranded `Engine.time_scale` (hitstop)** — HARDENED. `player.gd::_hitstop`
   and `axe.gd::_boss_hitstop` restore via a tree-owned
   `create_timer(dur, true, false, true)` (ignore_time_scale) + token guard;
   `SceneRouter.load_scene` and `LevelBase._ready` also reset it. Don't re-chase
   unless one of those regressed.
2. **Stranded `get_tree().paused`** — only `StateMachine` sets it (PAUSED state).
   A few UI panels (`oracle/lore/crypto_onboarding/companion`) set it directly,
   but each would show a VISIBLE panel and only the Oracle NPC opens mid-level.
   If the freeze screenshot shows no panel, this is NOT it.
3. **Infinite loop** — there are none unbounded in gameplay (`player.gd`'s
   ladder top-out and `resolve_grow_overlap` are both bounded).
4. **GROW-WEDGE (the 2026-08-25 one, founder shot_2)** — the Magic Mushroom
   scales the player node 1.5x, enlarging his CollisionShape2D 32->48px. The
   shape is TOP-LEFT anchored (offset (16,16)), so growing extends the body
   DOWN and RIGHT. Growing under an overhang / canyon pinch / against a wall
   leaves the body embedded in solids with no free axis; a grounded
   `CharacterBody2D` can't depenetrate, so the player is wedged and unmovable
   while music + enemies run. Fix already in: `player.resolve_grow_overlap()`
   (called from `power_up_handler._update_scale` on grow) slides out along each
   contact normal. Gate: `big_mode_no_grow_wedge_test`. If a new "freeze with a
   mushroom present" appears, verify that path first.

**Overlap detection gotcha:** `move_and_collide(Vector2.ZERO, true)` does NOT
report a resting overlap — you MUST pass `recovery_as_collision=true` (4th arg)
or your depenetration is a silent no-op that still passes a naive gate.

## "Boss doesn't chase / too easy / parked" — MEASURE, don't tune

A dozen sessions tuned speed constants; the founder kept saying "still not
chasing." The trap is headless-green / live-broken. Before changing any
constant:

1. **Measure the real chase** in the real level: park the player, then have it
   flee; log the boss CENTRE x over time. Claim Jumper (Stage 3) was proven to
   WORK this way — parked far west he closed 4184->3806 and GAINED 277px on a
   sprinting player. So "not chasing" there is NOT the chase code; it's the
   contact-restart loop / opening-moment perception. Do not "fix" a working
   chase with numbers.
2. **The real "parked beside me" cause (Stage 2, Distributor):** it steered at a
   point held to one SIDE of the player (`STANDOFF_X`, was 168) and parked there
   ~70% of every cycle — under a following camera that reads as floating beside
   you, never at you. Fix was to steer at the player's own column (STANDOFF_X
   ->60) and make SURGE lunge onto the player's x. Speed floors were never the
   missing piece.
3. **Contact core vs separation (the catch-22):** boss contact =
   `GameManager.boss_contact_restart()` = instant run reset (a LOCKED founder
   rule — never make it a graze). So bosses hold a standoff to avoid touching,
   and the standoff reads as "not chasing." The real contact core is small:
   Claim Jumper's is ~103px (hitbox 0.62x0.78 of a 280 body). `CHASE_SEPARATION`
   must stay OUTSIDE it — 200 settles him ~120px out (safe); dropping it to 160
   made him settle ~97px INSIDE the 103 core, camping/freezing at the wall and
   breaking `claim_jumper_chase_separation_test` + `claim_jumper_passes_circle_test`.
   The outward-hold bias only engages below 0.6*separation, so the settle point
   tracks ~0.6*that value — account for that before lowering it.
4. **Arena clamps** clamp the boss CENTRE into `[min+ARENA_EDGE_MARGIN,
   max-ARENA_EDGE_MARGIN]`; moving AWAY from a wall is never clamped. A boss
   "parked at a fixed x" is usually a clamp or a ledge/gap sense, not slow AI.

## Do-not-regress
- Every cyan block in Level 1 stays SOLID to the Auditor (no collision phasing).
- Web export stays non-threaded.
- Boss contact stays an instant run restart.
- Hitstop timers stay `ignore_time_scale` + tree-owned + token-guarded.
