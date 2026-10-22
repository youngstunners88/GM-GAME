---
name: golden-revolver-hand
description: Build out the founder's first-person golden-revolver grip art (gold Bitcoin-cylinder revolver, brown glove, vine-wrapped arm) as the player's revolver across Stage 3 and Episode 2. TRIGGER on "revolver", "his gun", "player's gun", any edit to sprite_item_golden_revolver.png, the lil_blunt_visual.gd sidearm block, combat_handler.gd revolver fire, runner_view.gd REVOLVER_MODEL, or after another session restyles the revolver, the cowboy tool sprites, or the Stage 2 boss-defeat handoff.
---
# Why (founder 2026-10-15)

The founder supplied first-person grip reference art: a gold revolver with the Bitcoin ₿
struck on the cylinder, held in a brown leather glove with a brass-studded bracer on a
green vine-wrapped arm — Lil Blunt's own arm. Raw intake:
`src/assets/models/_sources/refs/grip_reference.jpg` (1024x1024, white background).

What the game has today is three disconnected pieces and NO hand art:
- 2D sidearm icon `src/assets/sprites/sprite_item_golden_revolver.png` (56x31 landscape,
  cropped from the OLD reference) held at the hip (`player/player.gd:530`,
  `lil_blunt_visual.gd:199-228`) and fired in Stage 3 (`combat_handler.gd:189-202`,
  slug in `combat/revolver_bullet.tscn`).
- 3D `src/episode2/assets/golden_revolver.glb` (`REVOLVER_MODEL` in
  `episode2/runner/runner_view.gd:39`), baked into the runner victory pose.
- Stage 2 boss-defeat cutscene hands the revolver over
  (`level/stage2_boss_defeat_cutscene.gd`) — the gun Lil Blunt carries from there on.

This skill makes the new grip art the canonical look everywhere the player sees the gun.

# Rules

1. **Portrait hand art NEVER replaces the 56x31 landscape sidearm.** The sidearm block
   (`lil_blunt_visual.gd:199-228`) anchors a WIDE sprite at hip height with the grip
   forward; putting tall/portrait art through it re-creates the literal "his entire head
   is the gun" defect (founder, 2026-09-16). Grip art goes to: pickup splash card,
   HUD weapon portrait, Stage 2 handoff close-up, Ep2 FPS grip card / viewmodel
   billboard. Gun-only landscape crops may feed the sidearm slot (rule 3).
2. **Cutout quality is a blotch-rule matter.** The intake JPG is white-background. Ship
   only a transparent cutout with a 1px clean edge: flood-fill from all four corners at
   low fuzz (starter: `magick grip_reference.jpg -fuzz 4% -fill none -draw "alpha 0,0
   floodfill" -draw "alpha 1023,0 floodfill" -draw "alpha 0,1023 floodfill" -trim`),
   then inspect at 200% on BOTH `bg_l3_goldrush.jpg` and near-black — white fringe on
   a dark scene is exactly the class of artifact the founder reports as smudges. Never
   blur to "fix" an edge; re-cut it. Starter cutout lives at
   `src/assets/models/_sources/refs/grip_reference_cut.png` — re-verify, don't trust.
3. **Sidearm-slot crops keep the gun's grammar.** Any crop destined for
   `sprite_item_golden_revolver.png`: landscape, barrel pointing +X (flip_h handles
   facing), grip in the rear third (the sidearm anchor offsets forward by design),
   hold angle stays 0.12, hip anchor stays 78%. If the Bitcoin ₿ is in frame it must
   stay legible. Founder exception approved 2026-10-15: the 56x31 miniature is
   exempt from the 14px minimum; larger cards and close-ups still require a
   measured glyph height of at least 14px. Preserve the sidearm dimensions.
4. **Canon lock.** Brown glove + brass-studded bracer + green vine arm IS Lil Blunt's
   gun hand now. Any future revolver/handoff art must show the same three elements or
   it is a different character's gun. Gold stays warm (no steel recolor: runner_view
   already learned that dropping the metallic map turns gold dark — `runner_view.gd:983`).
5. **One source of truth.** `src/assets/models/_sources/refs/` holds the founder JPG,
   the verified cutout, and any crops. Scenes reference the derived sprites, never the
   raw JPG. New derivations get a row in this skill's asset table (below) in the same
   commit, or the next session will re-derive them differently.

# Asset table (update in place; all paths under `src/assets/models/_sources/refs/`)

| File | Spec | Feeds |
|---|---|---|
| `grip_reference.jpg` | 1024x1024 founder intake, white bg — never shipped | everything below |
| `grip_reference_cut.png` | transparent, trimmed (~748x713), 1px edge | splash, HUD portrait, handoff close-up, FPS card |
| `pickup_splash.png` | 640x640 transparent hand art; glyph 48px | pickup splash candidate |
| `hud_portrait.png` | 320x384 transparent hand art; glyph 24px | HUD portrait candidate |
| `stage2_handoff_closeup.png` | 960x540 transparent hand art; glyph 43px | Stage 2 close-up candidate; film unchanged |
| `fps_grip_card.png` | 768x512 transparent hand art; glyph 41px | Episode 2 grip card candidate; 3D hand unchanged |
| `sidearm_gun_only.png` | 896x496 fresh Blender gun-only render, +X without mirroring | miniature crop source; original hand intake occludes the grip |
| `sidearm_slot.png` / `src/assets/sprites/sprite_item_golden_revolver.png` | 56x31 landscape crop from the existing Blender Remington; no hand | hip tool, Stage 3 fire; runtime regression pending |
| `design/ep2/revolver/golden_revolver_hero.glb` / `golden_revolver_game.glb` | 2026-10-18 Blender pass on the founder's Tripo hand+gun GLB (Drive `golden+revolver+3d`); hero 3.1 MB metal, game 0.73 MB 9k tris metallic 0; reproduce with `tools/ep2_blender/revolver_improve.py -- <in.glb> <out.glb> hero\|game` | not wired; needs pack headroom + in-engine look |

Reproduction: `tools/ep2_blender/render_sidearm_crop.py` (Blender source
`design/ep2/armory/blender/remington_1875_gold.blend`), then
`python tools/ep2_blender/derive_revolver_cards.py`. The four large derivations
preserve the founder's hand image and readable, unmirrored cylinder emblem.
Only the miniature uses the already-authored standalone 3D gun, which has its
emblem on the grip. Do not call the two source designs identical.
Fringe evidence: `design/train-revolver-pass/fringe_goldrush.png` and
`design/train-revolver-pass/fringe_near_black.png`; derivation measurements in
the adjacent JSON receipt. Derivations are assets, not wired pickup/HUD/cutscene
features. Runtime and release verification is pending the documented CI blocker.

# Gate (every time)

- **Fringe check:** cutout composited over `bg_l3_goldrush.jpg` AND over near-black
  (`Color(0.03,0.02,0.05)`); 200% zoom on the barrel top edge, cylinder rim, and
  glove cuff — zero white pixels. Paste the two check screenshots' paths in the commit.
- **Sidearm regression:** if the sidearm sprite changed, live Stage 3 capture firing
  the revolver: gun at hip, grip forward, head fully clear of the sprite bounds.
- **Canon check:** ₿ legible wherever the cylinder is shown; glove + bracer + vine
  arm present in every hand shot.
- **Live proof** before "done": real game capture (skill `browser-verify-game`), not a
  viewer thumbnail. Numbers + picture, same as `ep2-bull-props-visible`.
