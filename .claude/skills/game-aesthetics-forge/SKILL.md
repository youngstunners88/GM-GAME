---
name: game-aesthetics-forge
description: Master game-art generation for Lil Blunt Adventure via the Muapi Flux API (key in env as MUAPI_API_KEY). Use to create or upgrade any visual asset — sprites, collectibles, platform tiles, backgrounds, UI art — data-driven from assets/art-manifest.json. Activates whenever art looks cheap/placeholder, a new entity needs a sprite, or a visual theme pass is requested.
---

# Game Aesthetics Forge

The art-direction + generation pipeline for Lil Blunt Adventure. Turns text
prompts into game-ready assets via Muapi's Flux models, with a repeatable
process for the two hard parts: **transparent sprites** (Flux can't output
alpha) and **a coherent visual identity** (the game's blockchain/crypto theme
carried subtly through art, not slapped on).

## When to activate

- Art reads as cheap, flat, placeholder, or incoherent (the exact feedback
  that created this skill: "background is bad and incoherent... cheap", "blocks
  are terribly designed").
- A new entity/collectible/power-up ships without real art.
- A themed visual pass is requested (e.g. "make coins crypto logos",
  "make platforms blockchain blocks").
- The user references Muapi or supplies art direction.

## The pipeline (one command)

```bash
python3 scripts/generate_art.py                 # generate everything missing
python3 scripts/generate_art.py --force id…      # regenerate specific ids
python3 scripts/generate_art.py --dry-run        # list planned generations
```

Reads `assets/art-manifest.json`, calls Muapi, writes assets to their final
paths. Raw 512px downloads are cached in `.art-cache/` (gitignored) so
re-keying / re-cropping a sprite is **free** — no re-billing. Delete an output
and re-run (without `--force`) to re-process from cache.

## Muapi API (verified)

- Base `https://api.muapi.ai/api/v1` (override via `MUAPI_BASE_URL`).
- Submit: `POST /flux-dev-image`, header `x-api-key: $MUAPI_API_KEY`,
  body `{"prompt","width","height","num_images"}`. Flux dev wants
  width/height as multiples of 32. Returns `{"request_id", "status"}`.
- Poll: `GET /predictions/{request_id}/result` until `status=="completed"`;
  final image URL is `outputs[0]`. ~3s inference; poll every 3s.
- $0.015 / image. Key is generation-scoped — a 401 on `/user` is expected.

## Transparent sprites — the process that works

Flux outputs opaque PNGs, so:
1. Prompt for the subject **"centered, on a solid flat pure magenta #FF00FF
   background, no shadow, no text"**. Magenta because almost no game subject
   is magenta, so it keys cleanly (never use it for a magenta/pink subject).
2. `generate_art.py`'s `chroma_key()` removes it in three passes:
   - **Corner flood-fill** — erase the contiguous region matching the actual
     corner colour (Flux renders "magenta" as a soft pink field, not pure
     #FF00FF, so a fixed-hue key fails; flood-fill removes what's really there).
   - **Relative pink-scrub** — kill leftover pink shadow ellipses Flux adds
     despite "no shadow": pixels where R and B both sit well above G. Cyan,
     gold, teal, green subjects never qualify (tested).
   - **Trim + square-pad + nearest-downscale** to the target px so pixel edges
     stay crisp.
3. Tune per-asset via `key_tol` in the manifest: **lower** for light/pale
   subjects (a silver coin blends into pink — tol ~38), **higher** for
   saturated subjects far from pink (a cyan block — tol ~95).
4. **Always eyeball the result** (Read the PNG). Generation is nondeterministic
   and keying is heuristic; check transparency % (a centered item should be
   40–75% transparent) and that the subject isn't eaten. Re-key from cache
   until right — it's free.

## Art-direction rules (the "master" part)

- **Pixel-art era anchor**: start prompts with "16-bit pixel art". Without it
  Flux drifts cinematic/realistic, which clashes with the sprite scale.
- **Subtle theme, not literal**: the blockchain/crypto identity reads best as
  *environment* — a glowing Ethereum-diamond "moon", translucent neon
  blockchain cubes drifting in the parallax, faint hex-hash etchings on
  platform blocks, Bitcoin glyphs shimmering in gold-mine haze. NOT logos
  pasted on every surface. Coins are the one place the logo is the point.
- **Cohesion across a set**: backgrounds for the 3 realms share a palette
  logic (each realm its hue: L1 purple-green smoke, L2 blue-purple crystal,
  L3 gold canyon) and the SAME recurring motif (floating neon blockchain
  cubes) so the game feels like one world. Generate a set together, compare.
- **Backgrounds are opaque**: 1216×704 (16:9, mult of 32) → LANCZOS to
  1280×720; no keying. One crisp full-screen painting on a slow-scroll
  parallax layer reads far more premium than chopping one image into
  darkened/cropped duplicate layers (that's what made the old bg look muddy).
- **Platform tiles**: generate as a sprite (magenta-keyed), then tile with
  `texture_repeat` across each platform in `level_base._create_platform` —
  the geometry itself carries the theme.
- **Respect the Global Rules**: chill/positive/never-aggressive; no real
  wallet addresses; enemies never weed-themed.

## Adding an asset

1. Add an entry to `assets/art-manifest.json`:
   - sprite: `{"id","sprite":true,"out_size":N,"width":512,"height":512,
     "key_tol":T,"path":"…","prompt":"… magenta bg …"}`
   - background: `{"id","width":1216,"height":704,"out_w":1280,"out_h":720,
     "path":"…","prompt":"…"}`
2. `python3 scripts/generate_art.py --force <id>`
3. Read the PNG, verify, re-key from cache if needed.
4. Wire it (scene texture, `entity_spawner` entry, tile logic).
5. Browser-verify the level — art must be seen in-engine, not just as a file.

## Files

- `assets/art-manifest.json` — every art asset definition (data-driven)
- `scripts/generate_art.py` — Muapi submit/poll/download + chroma-key (stdlib+PIL)
- `.art-cache/` — raw 512px downloads (gitignored; free re-keys)
- Sibling: `game-audio-forge` (same pattern for sound via ElevenLabs)
