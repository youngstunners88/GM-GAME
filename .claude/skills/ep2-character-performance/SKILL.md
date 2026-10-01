---
name: ep2-character-performance
description: Make Episode 2 characters ACT in a cutscene or chamber when the model has no clip for it - a statue-pose Meshy model (Inferno Bull), or Lil Blunt whose rig only carries runner poses. Procedural, deterministic acting - breathing, weight shift, lean into a hand-over, props that travel through a hand, walk bob, 3/4 turns, joy hop, cigar puff, sip of whiskey. TRIGGER when the founder says the characters "stand there", movements are stiff/teleporting, an item "appears" in a hand, or asks to improve a scene's movement or emotion.
---

# Why this exists
Founder 2026-10-01: "improve the movements of the characters". The facility had Lil Blunt sliding on rails, the rifle
and helmet TELEPORTING (rifle snapped into his hands, helmet appeared on his head the frame the beat began), and a
Bull who never moved. The Bull model (`inferno_bull.glb`) has no skeleton, so clips cannot help; the fix is acting
done in code, small and readable, driven by the beat sheet.

# The toolkit (all in `smelting_facility.gd`, `_animate*`)
1. **Pivot at the feet.** Wrap a statue in a `Node3D` pivot at its boots (`_bull_pivot`) with the model as a child.
   Rotating the model itself swings him about his belly and lifts his boots off the floor.
2. **Idle is never zero.** Breath = `scale.y` +-0.6 %, weight shift = roll +-0.8 degrees at 0.55 Hz. Tiny, but a
   frozen figure is the "mannequin" look the founder rejects.
3. **Lean into the beat.** While handing something over, ease `rotation.x` to +0.15 rad (positive leans toward the
   world -Z for a node yawed PI, i.e. toward the player) with `lerp(.., 4*dt)`; ease back after.
4. **Items travel, never teleport.** Path = crate -> the giver's hand -> a hold with a tiny bob -> the receiver
   (hand or head). Use `smoothstep`, an arc (`+0.3*sin(t*PI)`), and measured phase lengths (0.9 s lift, 1.2 s offer,
   1.0 s hand-over). Gate state on the animation (`_helmet_on_head`), not on the beat flag: `has_helmet()` / signals keep
   their old meaning for tests and the HUD while the visual follows the performance.
5. **Receiver reacts.** Reach: pitch forward 0.16 rad and rise 5 cm on tiptoe as the item arrives; then a joy hop
   (`_hop_v = 3.4`, gravity 15) when the helmet lands.
6. **Walk reads as walking.** Bob `abs(sin(phase))*0.075` at 9.5 rad/s, sway roll +-0.07; idle sway otherwise.
7. **Turn to the camera, not the wall.** Talking beats yaw him ~66 degrees (1.15 rad) so the hero camera sees his
   3/4 face and he faces the Bull; walking resets yaw to 0.
8. **Business with props.** Whiskey glass: hip -> lip -> pause -> hip on a 9 s cycle; cigar ember brightens and scales
   1.5x on the puff that follows the sip; smoke particles are a soft sprite (see ep2-hideout-set-dressing).
9. **Cameras are acting too.** `CAM_HAND` (low, front-left, 3/4) for hand-overs; cameras carry a yaw (3rd array
   element) and lerp it.

# Rules
- The `step(delta)` entry point drives all of it, so headless tests exercise the performance (no frame clock).
- Never move the LOGIC position (`_player_pos`) for acting: only the visual node. Tests and the beat sheet read logic.
- Keep timings human: lines hold >= their clip length; an offer pause >= 1 s so the player sees the item before it moves.
- Test what you animate: the helmet is NOT on the head the instant it is granted, it passes within 0.35 m of the hand,
  it lands, the rifle ends in the hands, the lean exceeds 0.05 during a hand-over (section 11 of the facility test).

# The real fix, when the founder wants it (ask first - costs credits)
Procedural acting cannot move the Bull's arms or head. A Meshy `meshy_rig` pass (5 credits, includes walk/run) on
`inferno_bull.glb` plus `meshy_animate` (3 credits per clip: pour, offer, sip, laugh) gives true limb animation. Present
the cost and get confirmation before spending (Meshy rule 1); after rigging, replace `_animate_bull`'s whole-body lean
with `AnimationPlayer` clips and keep the pivot/props code.
