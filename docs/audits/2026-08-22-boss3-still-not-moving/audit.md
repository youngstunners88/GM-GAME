# Audit — Boss 3 "still not moving" (2026-08-22, ~50th ask)

**Founder**: "Why the fuck don't you make the fucking boss3 move?!"
**Evidence**: `artifacts/founder_shots_2026-08-22_boss3/shot_1.png`
**Status of the previous claim (PR #49, height-sanity ceiling)**: rejected by the
founder, and he was right.

---

## 1. My previous gate measured the wrong axis

`claim_jumper_no_runaway_climb_test` asserts bounded **altitude** and that the
double jump fires. It never asserted that his world **X** changes. The founder
named this exactly:

> "Reject any claim that only shows bounded Y while X is frozen."

X *was* frozen. The gate passed anyway. That is how a fix shipped that did not
address the report.

## 2. Root cause — the arena seal wall was solid to the boss

Method: instantiate the real `level_03_gold_rush.tscn`, trigger the real fight
via `_on_boss_trigger()`, disable Hitbox monitoring, drive a continuous
triangle-wave kiting bot, and log every `get_slide_collision()` contact.

The boss's x pinned at **exactly 3710**, `velocity.x` forced to 0, against
`StaticBody2D@(3700,400)`. Level 3's `boss_arena.start_x` is **3700**, and
`level_base.gd` builds the seal as `_create_wall(_seal_x, 400, 20, 600, true)`
— a 20px-wide wall spanning 3690–3710. Exact match.

The `player_only` flag was **false in practice**:

| | value | layers |
|---|---:|---|
| seal wall `collision_layer` | 8 | layer 4 = **"Collectibles"** |
| player `collision_mask` | 11 | World, Player, Collectibles ✓ |
| boss `collision_mask` | 13 | World, Enemies, **Collectibles** ✗ |

Both bosses mask Collectibles, so the wall built to seal the *player* in was
solid to the *boss*. He ran west into it, latched `is_on_wall()`, and pogoed up
its face for the rest of the fight — which is what the founder has been
screenshotting.

## 3. Fix

`player_only` walls now use a **dedicated layer 9 ("ArenaSeal", value 256)**,
newly named in `project.godot`, and only the player's body opts into it
(`player.tscn` mask 11 → 267). The boss is bounded by his own
`_clamp_to_arena()`, which was always supposed to bound him.

**Layer 2 ("Player") was considered and rejected.** It is the one existing
layer the player masks that bosses do not, so it "works" — but Grok 4.6's audit
correctly refused it: `_create_wall` is shared by every level's seal, and enemy
hurtboxes mask bit 2 (mask 70 = 2|4|64). A wall wearing the Player layer would
proc every "I hit the player" listener against an invisible slab at the arena
mouth — hit sparks on empty air, contact-damage enemies biting the doorway,
aim/aggro queries locking onto the wall's AABB. `is_in_group("player")` guards
most of that, but "most" is not a collision-identity guarantee. A private layer
nothing else masks avoids the whole class.

## 4. Measured — real level_03 arena, 18s continuous kiting bot

| Metric | Before | After |
|---|---:|---:|
| boss x range | [3710, 4050] | [3584, 4110] |
| span covered | 340px | **526px** |
| longest frozen-in-place | 1.35s | **0.88s** |
| % time glued to player (<110px) | **45.9%** | **12.0%** |
| ever east of spawn (4050)? | no | yes (4110) |

The glue figure is the surprise: pinned against the seal he was inside the
player's contact radius **45.9%** of the run. Freeing him both un-parked him
and removed the ride-on-top behaviour.

New gate `claim_jumper_moves_test.gd` asserts **X movement**, crossing the old
3710 boundary, freeze duration, and no re-glue. Verified to FAIL on the old
code (3 of 4 assertions) and pass on the new — it would have caught this.

New gate `arena_seal_contract_test.gd` locks both halves of the seal contract:
the player still cannot leave, the boss is not walled, and the seal stays
invisible to enemy hurtboxes.

## 5. Honest gaps — what is NOT proven

- **The founder's criterion 2 (visible double jump when a single jump cannot
  clear a ledge) is NOT met.** The run recorded 1 air-hop, because on the flat
  arena floor there is no ledge to clear. Counting air-hops is not the same as
  showing one on camera. Do not report this criterion as satisfied.
- Roughly half of the 526px span is him moving **west, out through the arena
  mouth**, not across the room toward the minecart/TNT. His `_clamp_to_arena()`
  bounds his body *centre*, so his left half (x 3584–3700) now sits past the
  entrance line. That is pre-existing, deliberate clamp behaviour, not new —
  but it means "526px covered" overstates how much of the *room* he crosses.
- Headless numbers are not the live experience. Frames captured in
  `docs/captures/2026-08-22-boss3/`.

## 6. Model log

| Model | Contribution |
|---|---|
| Grok 4.6 | **Changed the fix.** Rejected layer 2 as a shared-semantics landmine and rejected claiming the double-jump criterion. Both accepted. Also flagged that most of the new span is westward out the entrance — recorded in §5 rather than argued away. |
