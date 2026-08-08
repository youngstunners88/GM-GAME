---
name: pixellab-pipeline
description: Generate pixel art and animation frames for Lil Blunt through the PixelLab MCP. Use when adding a new character/enemy/object sprite, generating walk/attack/idle animation frames, or making tilesets — and specifically when an existing character needs new poses without drifting off-model.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# PixelLab Pipeline

Pixel art + animation generation via the PixelLab MCP. Complements the
existing Muapi path (`game-aesthetics-forge`), which does painterly backdrops
and key art; PixelLab does *sprites and animation frames*, which Muapi cannot.

## Connection

```bash
claude mcp add --transport http pixellab https://api.pixellab.ai/mcp
```

**`--transport http` is required.** Without it the CLI registers the URL as a
**stdio** command and the server silently never works. Verify with
`claude mcp list` — it must say `HTTP` and `✓ Connected`.

**MCP tools load at session start.** If you add the server mid-session its
tools will NOT be callable until the next session. Until then, call it
directly (this is also the fastest way to script a batch):

```bash
curl -s -X POST https://api.pixellab.ai/mcp \
  -H "Authorization: Bearer $PIXELLAB_SECRET" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Responses are **SSE** (`event: message\ndata: {...}`), not plain JSON — parse
with a regex for the `data:` line, not `json.load` on the whole body.

## Secret

`PIXELLAB_SECRET` (environment). Never commit it.

**Check the budget before generating** — this is a metered trial:

```bash
# get_balance -> credits, generations_remaining, generations_total
```
As of 2026-07-30: **trial, 40 generations total.** Cost per call:
`standard` = 1 · `v3` = 2–9 · `pro` = 20–40. A single careless `pro` call can
burn half the budget.

## ⚠️ The lesson from the first spike — read before generating a character

**`mode: "standard"` will NOT reproduce an existing character.** It is
template-based skeleton generation: you give it text, it gives you a generic
humanoid in that palette. Asked for "cute chill green weed-nugget mascot", it
returned a plain thin green humanoid with none of Lil Blunt's identity — no
hat, no bulk, no face. Technically a success, artistically unusable.

For a character that already exists, use **`mode: "v3"` with
`reference_image_base64`** — the only mode that accepts a reference image. It
rotates *your actual sprite* into 8 directions instead of inventing a new
character.

```bash
B64=$(base64 -w0 src/assets/sprites/sprite_lil-blunt_cowboy.png)
# create_character { mode:"v3", view:"side", reference_image_base64:$B64, ... }
```

Reference image rules: south-facing, PNG, **max 256×256**. Output size
defaults to the reference's own dimensions.

## Parameters that matter for THIS game

| Param | Use | Why |
|---|---|---|
| `view` | **`"side"`** | This is a 2D side-scrolling platformer. The default is a top-down RPG angle and produces sprites that cannot be used. |
| `mode` | `v3` for existing characters, `standard` only for throwaway concepting | See above. |
| `size` | match the existing sprite (~48–72px) | Existing Lil Blunt sprites are 49×72 / 51×72. Canvas comes back ~40% larger to leave animation room. |
| `n_directions` | 4 | A side-scroller needs east/west; 8 wastes budget. Ignored in v3/pro (always 8). |
| `outline` | `"single color black outline"` | Matches the shipped sprite style. |

## Async contract

`create_*` returns an id immediately and processes for ~30s–5min. Poll
`get_character` / `get_object` — do not block a session waiting. Status goes
`creating (N% ~Ns)` → `completed`, then the response carries per-direction
PNG URLs plus a `download` link.

## Output paths and naming

Generated art lands in **`assets/pixellab/<entity>/`** first — this is a
staging area, not the shipped location.

Naming follows the project convention in `CLAUDE.md`:
`[type]_[entity]_[action]_[frame].[ext]` →
`sprite_lil-blunt_idle_east.png`, `sprite_lil-blunt_walk_01.png`

**Nothing is shipped straight from the generator.** Promote into
`src/assets/sprites/` only after a human looks at it — the first spike proves
the generator will happily return a confident, on-spec, off-brand character.
Anything under `src/assets/` is force-imported by Godot and reaches players.

## Checklist for a generation run

1. `get_balance` — confirm generations remain.
2. Existing character? → `v3` + `reference_image_base64`. New concept? →
   `standard` (cheap) to explore, then `v3` to lock it in.
3. `view: "side"`, size matched to the existing sprites.
4. Poll until `completed`.
5. Download to `assets/pixellab/<entity>/` with the naming convention.
6. **Look at the image.** Compare against `src/assets/sprites/` for on-model.
7. Only then promote, and re-run the `script_compile_test` gate if you touched
   anything under `src/`.
