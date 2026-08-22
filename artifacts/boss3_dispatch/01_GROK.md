# Grok 4.6 — Truth audit: Boss 3 "still not moving" (~50th ask)

## Founder (2026-08-22, binding)
"Why the fuck don't you make the fucking boss3 move?!" Claim Jumper is not
chasing / not leaving his position on hard-refresh. Screenshot shows him near
the minecart/TNT area. He explicitly REJECTS the previous fix (PR #49's
height-sanity ceiling on hop/air-hop) as acceptance, and says headless gates
and "closes to zero distance" text are not acceptance.

His acceptance list:
1. Moves past the shot_1 position while Lil Blunt kites.
2. Double jump fires and is VISIBLE when a single jump can't clear a ledge.
3. Visible chase under the follow camera (not hop-in-place, not wall park).
4. Playwright frames a human can match to shot_1.
5. Instrumented boss X/Y over >=12s fleeing bot; max X past prior stuck point,
   # double jumps, % time glued to player.
6. Gates + security 18/18 + butler fresh bytes.

He also told me explicitly: "Reject any claim that only shows bounded Y while
X is frozen."

## What I found this round (measured, real level_03 arena)
My PREVIOUS gate for this boss measured altitude and double-jump count and
never asserted X movement at all — exactly the blind spot he named.

Root cause, found by logging real get_slide_collision() contacts every frame:
`level_base.gd::_create_wall(x, y, w, h, player_only)` builds the boss-arena
SEAL WALL with `collision_layer = 8` when `player_only` is true. In
project.godot, layer 4 = value 8 = "Collectibles". Both bosses carry
`collision_mask = 13` (World|Enemies|Collectibles). So the wall built to seal
the PLAYER into the arena was solid to the BOSS too — `player_only` was simply
false.

Level 3's arena starts at x=3700, so the wall spans 3690-3710. Measured: the
Claim Jumper's x pinned at exactly 3710 with velocity.x forced to 0, then
pogo-hopped up the wall face repeatedly.

## Fix applied
`player_only` walls now use `collision_layer = 2` ("Player"). Layer 2 is the
one layer the player masks (mask 11 = 1|2|8) that the bosses do not
(mask 13 = 1|4|8). The seal still stops the player leaving; the boss is now
bounded by his own `_clamp_to_arena()`, which was always supposed to bound him.

## Measured, real level_03 arena, 18s continuous triangle-wave kiting bot
| Metric | Before | After |
|---|---:|---:|
| boss x range | [3710, 4050] | [3584, 4110] |
| span covered | 340px | 526px |
| longest frozen-in-place | 1.35s | 0.85s |
| % time glued to player (<110px) | 13.9% | 12.1% |

After the fix he tracks the player in BOTH directions (velocity.x swinging
+191 to -286) and never reports is_on_wall(). Before, he never got east of his
own spawn x=4050.

All 11 boss/arena gates pass: boss_arena_reachable, boss_chase_live,
boss_spawn_survives_walk_in, claim_jumper x5, distributor x2.

## Not yet done
No Playwright frames yet. No butler deploy yet.

## Your job — be adversarial
1. Is the layer-2 choice safe, or does putting a wall on the "Player" layer
   create a worse bug? Enemy hurtboxes use mask 70 (2|4|64) — they will now
   overlap this wall. Most code checks `is_in_group("player")`. What concretely
   could break, and how would it show on stream?
2. Does 526px of a 700px arena, with 0.85s max freeze, actually LOOK like
   chasing to a non-technical founder watching 20 seconds? Or will he say
   "still stuck" again? What's the weakest part of this evidence?
3. He requires a VISIBLE double jump. My run recorded only 1 air-hop, because
   on flat arena floor he has no ledge to clear. Is it dishonest to ship this
   claiming criterion 2 is met, and what would actually satisfy it?
4. Anything in this fix that is scope creep, or that risks the Stage 2
   Distributor / minecart / TNT identity he told me not to touch?

Do not accept headless numbers as proof of live experience.
