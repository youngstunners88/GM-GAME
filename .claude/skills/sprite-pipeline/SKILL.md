---
name: sprite-pipeline
description: Turn client art (Drive folders, key art, transparent PNGs) into working in-game characters, bosses, and environments. Use whenever new art arrives or any entity needs to go from placeholder shapes to real sprites.
---

# Sprite Pipeline — Client Art → Living Game

The proven end-to-end recipe. Every step below has already worked once; do not
improvise a new path when new art arrives.

## 1. Ingest from Google Drive

- Folder listing: `mcp Google Drive search_files` with `parentId = '<folder-id>'`.
- Download RAW bytes (never through context):
  `curl -sL "https://drive.google.com/uc?export=download&id=<ID>" -o file.png`
- Inspect cheaply: PIL thumbnail → Read the small JPEG. Check `im.mode` —
  RGBA = real sprite; RGB = scene/backdrop (or checkerboard-flattened sprite).

## 2. Process (PIL, scripted — see git history of this commit for the exact code)

- **Sprites**: `im.crop(im.getbbox())` (alpha trim) → LANCZOS resize to target
  height → save into `src/assets/sprites/` using the naming convention
  `sprite_<entity>_<variant>.png`.
- **Target heights**: player 72px (vs 32px hitbox — sprite bigger than hitbox
  is correct and forgiving), bosses 150px, collectibles 24–32px.
- **Checkerboard-flattened art**: knock out via edge flood-fill on light-gray
  pixels (`r≈g≈b, r>170`) — never global color-key (kills art interior).
- **Backdrops**: RGB, resize width 1280, JPEG q88 → `src/assets/backgrounds/`.
  Character-free art only — a baked-in character duplicates the live sprite.

## 3. Wire into Godot (patterns that exist — reuse, don't reinvent)

- **Player**: `LilBluntVisual` (src/player/lil_blunt_visual.gd) — Sprite2D
  wrapper keeping the legacy API (`color` tint, `facing_right`, `visible`)
  plus `set_outfit()` texture swap keyed by `Player.Outfit`. Feet-align:
  `spr.position.y = FEET_LOCAL_Y - texture.height/2`.
- **Bosses**: `BossSprite` (src/boss/boss_sprite.gd) — Node2D shim honoring
  the old ColorRect API (`color` red-flash detection, `size` fit, `modulate`,
  `scale.x` flip). In the .tscn keep node NAME "ColorRect" (scripts use
  `$ColorRect`), change type to Node2D + script + `texture_path`.
- **Backdrops**: `LevelData.background_path` / `boss_background_path` +
  `LevelBase._setup_background()` (CanvasLayer −20 TextureRect, KEEP_ASPECT_
  COVERED, modulate 0.82 darken) and `set_boss_background()` on boss trigger.
- Tint semantics after real art: **WHITE = normal**; power-up tints are
  pale (0.55–1.0 range), never fully saturated (art must stay readable).

## 4. Non-negotiable verification (every art change)

1. Push → CI exports (`/export-deploy`) → pull.
2. `strings web/game/index.pck | grep -c <new-asset-name>` ≥ 1.
3. Browser gate: `scripts/serve-web.mjs` + `scripts/verify-web.mjs` → exit 0.
4. **Read the level screenshot with your own eyes** — feet on platforms, no
   double-character (sprite + baked-in art), backdrop correct per level.
5. Deploy, then update STATUS.md + merge to master (ALWAYS-SHIP rule).

## Traps already paid for

- Boss backdrop containing the boss + live boss sprite = two bosses. Use the
  character-free environment for arenas once the boss has a real sprite.
- Sprites ship inside the .pck (Godot imports them) — the .jpg/.png must be
  committed; CI does the import. `.import` sidecar files are generated in CI.
- Drive preview JPEGs lie about alpha (RGBA composited dark). Trust `im.mode`.
