# SESSION 8 SHARED FACTS — Lil Blunt Adventure (Godot 4.3 GDScript platformer)
Co-worker model: be terse, Godot-4.3-correct, concrete. Do not restate code.

## Founder live complaints after S7
1. Mira Voss (Diamond Vault clerk) needs: a VOICE, to stand on the SAME floor
   level as Lil Blunt (not floating), to FACE him when he's near, a FAREWELL
   line when he leaves, and the E-to-talk dialogue must NOT dump the whole
   conversation instantly — the player must be able to read/step through it.
2. Stage 2 boss STILL not chasing (reported every session). Range was fixed in
   S7 (projectile lifetime). Chase: S7 raised HOVER_ACCEL 430->1600.
3. Final boss (Claim Jumper, Stage 3) still "jumps in place", must chase
   horizontally. (S6 gated a fix via _higher_ground_ahead; founder still unhappy.)
4. Art: restore the previous (bigger) Bitcoin sun in the Gold Rush backdrop (the
   S7 shrink was rejected); wire founder redesign emblems; 288/2888 pools must be
   larger + visually distinct with clear labels.
5. Fort Knox: add Gideon "Goldwater" Vale (western banker NPC, cowboy accent VO);
   shift layout so hierarchy is readable; highlighted platforms golden.

## Current code
- Vault UI: src/level/vault_realm.gd. Mira is a Sprite2D (mira_voss.png) at a
  clerk Node2D; clerk_open() shows a big-button panel (STAKE/CRUSH/CONFIRM);
  labels use style_label (>=24px + outline). Fort Knox has an Assay Hall
  mezzanine + assay_scale + gold_scale.png instrument. Altars: _setup_altar
  ("short" 288-day, "long" 2888-day).
- style_label(l,size) / style_button(b,size) helpers exist.
- S2 boss src/boss/distributor.gd: _hover_pursue, HOVER_ACCEL 1600,
  MIN_PURSUE_SPEED 345, arena bounds from level_02 (700px wide, 3700..4400).
- S3 boss src/boss/claim_jumper.gd: _ground_chase + PATROL hop gated on
  _higher_ground_ahead (real ledge) so it shouldn't pogo on flat ground.
- Player is on the floor; vault clerk Mira sprite anchored at clerk Node2D y.

## New founder art (already saved, transparent cut-outs)
- src/assets/art/vaults/gideon_vale.png (1024x1536 western banker)
- src/assets/art/vaults/diamond_sentinel.png (crystal diamond emblem)
- src/assets/art/vaults/fortknox_sentinel.png (fiery gold gear emblem)

## Constraints
- Web export non-threaded. No hardcoded addresses. Godot 4.3 `var x:=<Variant>`
  is a hard parse error — type explicitly. Every fix needs a headless gate that
  fails on pre-fix code.
