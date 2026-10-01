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

# DONE 2026-10-01: the Bull is rigged (founder: "of course you must spend what we have on Meshy")
- Rig the REMESHED task (`meshy_rig input_task_id=<remesh id>`, 5 credits; the 30k-tri remesh is under the 300k cap),
  then bake clips onto that rig in ONE call: `python3 tools/meshy/meshy_rig.py <task> out.glb --rig-task <rig id>
  --actions 11,342,313,292` (3 credits each) -> `inferno_bull_rigged.glb` (Idle_02, Stand_and_Drink,
  Talk_with_Hands_Open, Gesture_with_Hand_on_Gun). Shrink with `shrink_glb.py` (23.7 MB -> 3.2 MB). The rig drops the
  normal map (known trap). Origin at his feet, 2.4 m tall.
- Action ids: scrape `https://docs.meshy.ai/en/api/animation-library` into `.farm/meshy_actions.txt` (656 rows) and
  grep (drink 342/343, talk 308-314, gesture 292, sit 32/33, sit-to-stand 52/53, walks 30/106/115...).
- Clips import NON-looping: set `loop_mode = LOOP_LINEAR` on idle/talk/drink. Crossfade with `play(clip, 0.4)`.
- Props ride bones: `BoneAttachment3D` children of the Skeleton3D (`RightHand`, `LeftHand`, `headfront`). Find out
  EMPIRICALLY which hand a clip lifts: on Stand_and_Drink he lifts the hand that holds his baked rifle, so the glass
  goes on that hand and the hand-overs use the free hand (`get_bull_hand()`).
- Clip by beat: drink on WAKE/DRINK lines, open-hands talk on the hand-overs and other lines, hand-on-gun for his
  terms, idle otherwise with a sip every 16 s. He also turns (max 60 degrees) to keep Lil Blunt in front of him.
- Lil Blunt's free walk/run: every Meshy rig result carries `basic_animations.walking_armature_glb_url` (armature
  only, ~65 KB). Same track paths as the hero (`Armature/Skeleton3D:<bone>`), so copy the Animation into his
  AnimationPlayer library at runtime (`_add_hero_clip`) and set `RunnerArmRest.legs_free` while it plays so the clip
  drives the legs and the pose modifier keeps the arms/weapons.
