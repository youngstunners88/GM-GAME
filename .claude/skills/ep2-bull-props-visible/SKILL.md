---
name: ep2-bull-props-visible
description: Inferno Bull's signature props - his own Winchester and his whiskey glass - must be SEEN from where the player actually stands after the founder's film. Prove it with the post-film capture (on-screen pixel size per prop), not a hand-placed camera. TRIGGER on "can't see his rifle / gun / whiskey / glass", any edit to _sync_bull_hand_props, _build_bull_props, _add_whiskey_inside, BULL_RIFLE_SCALE, GLASS_HEIGHT, REST_FACE_SLACK, the Bull's rest facing, or after another session (ChatGPT/Codex) restyles the hideout or the Bull.
---
# Why (founder 2026-10-04)
"ChatGPT improved Inferno Bull ... but we still can't see his rifle or the whiskey glass." Both props existed in
code and passed every test - and neither read on screen. Measured in the post-film state:
- After the film the Bull stood at `BULL_REST` facing the room (`facing = PI`) while Lil Blunt stood at `HAND_MARK`
  to his side: the player saw him in PROFILE. His rifle hung low on his far side, completely behind his body.
- The founder's Meshy tumbler bakes opaque white glass with orange flecks; with an emission boost it read as a
  white beer mug at 3-4 m.

# Rules
1. **He faces Lil Blunt.** `_on_video_film_finished` sets his facing toward `HAND_MARK`; at rest
   `_face_player_at_rest()` turns him in place (never walks: `ep2-bull-rest-pose`) whenever Lil Blunt is more than
   `REST_FACE_SLACK` (0.45 rad) off his nose. Props on the far side of a body are invisible props.
2. **His own Winchester is shoulder-carried**: muzzle up (dir.y > 0.85) past his right shoulder, tipped out and
   back, gripped at the stock wrist, `BULL_RIFLE_SCALE` 1.3 (the traded rifle stays 1.05). Muzzle tip must reach his
   shoulder line (> 2.0 m). A low diagonal at the hip hides behind his hip from half the room.
   Rifle GLB facts (skill ep2-handoff-props): 1.2 m, muzzle +Z, centred. In `_sync_bull_hand_props`, `forward` is
   his BACK and `across` is his LEFT (actor facing 0 looks down +Z). Build bases right-handed (x cross y = z) or the
   rifle renders mirrored.
3. **The whiskey must read as whiskey**: keep the founder's tumbler SHAPE, replace the baked look with clear glass
   (alpha 0.22, rim light) + `_add_whiskey_inside()`: an amber liquid that glows (emission 1.6, fills 62 %), an ice
   cube and a bright rim. `GLASS_HEIGHT` 0.31 m in his left hand - he is ~2.5 m tall.
4. Props stay separate rigid nodes placed from the final bone pose (never skinned to an arm: "liquid arm").

# Gate (both, every time)
- `tests/ep2_hideout_corrections_test.tscn`: faces Lil Blunt after the film and from the other side, rifle shown,
  muzzle up, scale, muzzle height, glass in hand with Whiskey/Ice/Rim, no walking.
- Real render: `xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --rendering-method
  gl_compatibility --resolution 960x540 res://tools/ep2_shots/bull_props_shot.tscn -- out=.farm/bullprops`
  prints `on_screen` + pixel size per prop for the post-film view, a look at the Bull, and the other side.
  Shipped numbers: rifle 71x211 px / 84x254 px, glass 61x54 / 73x66 at 960x540. LOOK at `bp1` and `bp3` - the
  numbers say it is on screen, only the picture says it reads.
