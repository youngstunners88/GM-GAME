# Assets Workspace

This is where the visual and audio identity of the game is defined. All art direction, sprite specs, color palettes, and audio mood live here. This workspace tells the /godot workspace WHAT the game should look and sound like.

## What Happens Here
- Sprite sheet specifications and animation frame definitions
- Tileset grid and biome specifications
- Audio direction (chiptune + lo-fi hybrid? retro SFX?)
- Color palette definitions per realm
- Reference images and style guides derived from client branding

## Art Direction
- **Style**: 16-bit pixel art, GBA-era platformer (Super Mario Advance / Metroid Fusion aesthetic)
- **Base Resolution**: 480x270 viewport, scaled up with nearest-neighbor or CRT shader optional
- **Sprite Grid**: 32x32 pixels for Lil Blunt, 16x16 for tiles and small enemies, 64x64 for boss
- **Animation Frames**: 4-6 frames per action (idle, run, jump, fall, Blaze Mode puff, damage)

## Color Palettes
- **Smoke Realm**: Deep purples (#2D1B4E), hazy greens (#4ADE80), glowing cyan (#22D3EE), warm orange accents (#FB923C), smoke whites (#F3F4F6)
- **Lil Blunt**: Bright friendly green (#22C55E), brown blunt accents (#92400E), big chill eyes, relaxed smile
- **UI**: Retro arcade chunky pixels, high contrast black background with neon green/cyan borders
- **DIAMONDS nod**: Diamond Shards use icy blue (#60A5FA) and white sparkle
- **GoldMine nod**: Gold coins use rich yellow (#FACC15) with brown outlines

## Asset Naming
- `sprite_[entity]_[action]_[frame].png` — e.g., `sprite_lil-blunt_run_01.png`
- `tileset_[biome]_[type].png` — e.g., `tileset_smoke-realm_ground.png`
- `sfx_[event].wav` — e.g., `sfx_jump.wav`, `sfx_blaze-puff.wav`
- `music_[level]_[mood].ogg` — e.g., `music_smoke-realm_chill.ogg`, `music_boss_tense.ogg`

## Good Assets Look Like
- Consistent pixel grid alignment (no half-pixel offsets)
- Limited color count per sprite (8-16 colors max)
- Clear silhouette readability at 1x scale
- Loop-friendly music tracks (seamless, 60-90s loops)
- SFX that feel retro but punchy (short, <1 second, distinct frequencies)
