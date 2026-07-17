---
name: game-secret-realm-forge
description: Author decorative "3D-feel" secret bonus realms for Lil Blunt Adventure — hidden-door destinations with parallax depth, atmospheric Muapi art, commentary, and a clean return-to-origin loop. Use when adding or upgrading a secret stage, or when a bonus space needs more visual depth/wow.
---

# Game Secret Realm Forge

Builds the game's secret bonus stages — the reward for finding a hidden door.
These are meant to feel *deeper and more decorative* than the main side-scroll
stages: a sense of 3D space, lush atmosphere, and a distinct vibe, while still
running in Godot's 2D engine and looping cleanly back to where the player
entered.

Reference implementation: `src/level/secret_realm.gd` (the Chill Lounge),
`secret_door.gd`, `return_portal.gd`.

## The "3D feel" in a 2D engine — the core technique

Godot 2D can't do true 3D, but layered parallax at **very different motion
scales** reads as real depth. The rule that sells it:

1. **At least two painted layers** from Muapi: a FAR layer (a deep cosmic /
   vista backdrop) and a NEAR layer (the actual room/lounge). Generate them as
   a *matched set* (same palette, same light direction) so they read as one
   space, not two collaged images.
2. **Exaggerate the motion-scale gap**: far ≈ 0.1, near ≈ 0.45. The wide gap is
   what the eye reads as distance. A subtle gap looks flat (that mistake is
   what made the main-stage parallax look cheap before it was simplified).
3. **Slight zoom on the far layer** (scale ~1.15) pushes it "back" and hides
   its edges as the camera moves.
4. **Vertical parallax too** (`motion_scale.y` ~0.6× the x) so vertical
   movement also reveals depth, not just horizontal.
5. Optional near-camera FX (drifting smoke `CPUParticles2D` with `fx_dot`,
   floating rings) between the player and the near layer add a third depth cut.

## Art direction (Muapi — game-aesthetics-forge pipeline)

- Generate backgrounds via `assets/art-manifest.json` + `scripts/generate_art.py`
  (opaque, 1216×704 → 1280×720). Same prompt discipline as the main-stage bgs:
  "16-bit pixel art side-scroller background, … cohesive painterly pixel style,
  no text".
- **Keep it tasteful.** The lounge aesthetic is atmospheric and classy —
  velvet couches, ornate glowing bongs with curling smoke, warm neon, cosmic
  nebula depth, silhouetted relaxed figures in the *far* background. Per
  CLAUDE.md's Global Rules (weed content positive/chill, no stereotypical or
  degrading imagery), do NOT generate sexualized or objectifying content —
  build mood and place, not pin-ups. A gorgeous, distinct *space* is the goal.
- Muapi + audio (ElevenLabs) are the two content engines; if a Monid/Modin
  tool is wired later, slot it in here as an additional generator once its API
  is documented.

## The return-to-origin loop (required)

A secret realm MUST come back to exactly where the player left:

1. The **secret door** (`secret_door.gd`) records
   `GameManager.secret_return = {scene_path, position}` before loading the realm.
2. The realm's **return portal** (`return_portal.gd`) loads
   `secret_return.scene_path` back.
3. `level_base._spawn_player()` checks `secret_return`: if its `scene_path`
   matches the level being (re)loaded, it spawns the player at the saved door
   position and clears the record — so the detour is seamless.

Mirror the existing Blaze-Rush `dash_return` pattern; use `secret_return` so the
two don't clash.

## Commentary (required — the transition must read)

Announcer VO (same voice as stage intros, `AudioManager.play_voice`) at three
beats so the player always understands the transition:
- **enter** (`secret_enter`) — on the door, before the wipe.
- **ambient** (`secret_ambient`) — ~0.8s after the realm loads (once visible).
- **exit** (`secret_exit`) — on the return portal.
Generate with the ElevenLabs TTS flow (`gen_boss_voices.py` is the reference
for the POST; announcer voice id `N2lVS1w4EtoT3dr4eOWO`).

## Discoverability

The door must be *found*, not invisible: a soft glowing pulse
(`modulate`/`scale` loop) is the cue. Place it somewhere that rewards
exploration (a high ledge, past a gap), not on the main path.

## Authoring a new realm

1. Generate a matched FAR+NEAR background pair (art-manifest + generate_art).
2. Copy `secret_realm.gd`, swap `FAR_BG`/`MID_BG` + the reward list + music.
3. Point a `secret_door` at your realm scene; place it off the main path.
4. Generate any new commentary lines; wire enter/ambient/exit.
5. Browser-verify: enter the door, confirm the parallax reads as depth, grab
   the reward, take the portal, confirm you land back at the door.

## Files

- `src/level/secret_realm.gd` + `.tscn` — the realm (code-built for easy variants)
- `src/level/secret_door.gd` + `.tscn` — entry (records return, VO, wipe)
- `src/level/return_portal.gd` + `.tscn` — exit (loads saved scene back)
- `src/assets/backgrounds/bg_secret_far.jpg` / `bg_secret_mid.jpg` — the pair
- `src/assets/sounds/voice/secret_{enter,ambient,exit}.mp3` — commentary
- Siblings: `game-aesthetics-forge` (art), `game-audio-forge` (VO/SFX)
