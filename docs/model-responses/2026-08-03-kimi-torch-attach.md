<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-torch-attach-audit.md
     files inlined: 2
     tokens: 11251 in / 14187 out
     cost: $0.2466
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Findings

**MEDIUM — lil_blunt_visual.gd:136-137 vs 183-187 — walk-bob decoupling: `_process` bobs/rotates `_spr` every frame (`_spr.position.y = feet_y - lift`, up to 4px; `_spr.rotation` ±~0.09 rad) but `_tool` is a *sibling* of `_spr`, not a child, and receives none of it. During any walk cycle the tool floats/slides relative to the hand even though the static math is correct. Fix: cache the grip base Y at equip and apply the same `lift`/rotation to `_tool` in the moving branch (and reset in idle), or parent `_tool` to a hand Marker2D that gets the bob.

**MEDIUM — lil_blunt_visual.gd:143-144, 152-154 — legs render below the collision floor.** `feet_y` is the body sprite's *center* (`FEET_LOCAL_Y - height/2` = 0 for a 32px body), but the leg formula `feet_y + height - 8` treats it as the sprite's *top*. For a 32px body, legs land at y=24 — 8px *below* the +16 floor line, inside the terrain. This is the only thing this file provably renders "at the feet." Fix: `feet_y + _spr.texture.get_height() / 2.0 - 8` (equivalently `FEET_LOCAL_Y - 8`).

**LOW — lil_blunt_visual.gd:262 (latent z-order) — `_anim` is `add_child`'d in `_setup_frames_for_outfit`, which runs on every `set_outfit()`. Today no `.tres` frame sheets exist so `_anim` is never created, but if one ships and a re-outfit happens while a tool is equipped, `_anim` appends *after* `_tool` and draws over it. Fix: `move_child(_tool, -1)` after creating `_anim`, or set `_tool.z_index = 1` at creation.

**LOW — lil_blunt_visual.gd:170, 41-43 — `_tool.rotation = 0.35` is set once and never mirrored.** On facing flip, `flip_h` mirrors the art but the lean stays +0.35 in world space, so the torch leans asymmetrically (into the body on one side). Cosmetic. Fix: set `_tool.rotation = 0.35 if value else -0.35` in the facing setter.

**INFO — lil_blunt_visual.gd:183-187 — grip math is provably correct *for the assumed asset*.** Computed: grip sits at local y=+2 regardless of texture height; tool bottom edge = `2.0 + tex_height/4`. For the commented ~34-36px torch: bottom at y≈+11, top at y≈-25 (flame above the head, feet at +16). **But the bottom edge crosses the feet line when tex_height ≥ 56px.** If the real `sprite_item_torch.png` is taller than the comment assumes, or its visible pole doesn't fill the canvas (transparent padding below the grip point), the "at the feet" read returns with this exact code. This is checkable in seconds: open the PNG, read its height and opaque bounding box.

**INFO — not verifiable from the provided files:** `player.tscn` was not provided, so `$Visual`'s own position/scale in the scene is unchecked; `PowerUpHandler` was not provided, so a second torch/icon visual drawn by another node cannot be ruled out as the thing the founder is seeing.

## Answers

**1. Attach point:** `_tool` is parented **directly to `LilBluntVisual`** (`add_child(_tool)`, line ~171). No intermediate limb/body node. `_spr` is a sibling, so `_spr`'s per-frame position/rotation changes do *not* propagate to `_tool` — which is why the static math is trustworthy and why the walk-bob drift (Finding 1) exists. Ancestor transforms above `LilBluntVisual`: Player's `scale` tweens (jump stretch / land squash / death), which affect all children uniformly.

**2. Z-order:** Add order in `_ready`: `_spr` first, then each leg `add_child` + `move_child(leg, 0)` → final order `[leg2, leg1, _spr]`. `_tool` is created later, appended **last** → topmost sibling. `_glow` is a child of `_tool` → above the tool. **Z-order is not the bug today**; the tool draws over body and legs. Only the latent `_anim` case (Finding 3) threatens this.

**3. Facing flip:** The two sites (`facing_right` setter, lines 41-43; `set_tool`, lines 173/185-187) use identical expressions keyed off the same `facing_right`. Per-frame order in `player.gd:_physics_process`: `_update_tool_visual()` → `sprite.facing_right = ...`. `set_tool` early-returns on unchanged path, so after equip only the setter writes `_tool`; on the equip frame the setter runs *after* `set_tool` and overwrites with the same values. **No desync possible.** The only asymmetry: the setter never touches `position.y` or `rotation` — correct for Y, cosmetic issue for rotation (Finding 4).

**4. Animation coupling:** Yes, decoupled — see Finding 1. `_tool` gets no per-frame offset while `_spr` bobs 4px and rotates, and the legs swing ±7px. At idle the body resets to `feet_y` and the tool's static anchor is again consistent. If the founder's complaint is observed *while walking*, this is the prime code-level suspect; if observed *at idle*, it is not.

**5. Requires a screenshot / asset inspection, not more code reading:**
- Actual pixel height and **opaque bounding box** of `sprite_item_torch.png` / `sprite_item_pickaxe.png` — the 0.25 grip fraction and the "~34-36px" comment are unverified assumptions; ≥56px canvas height puts the handle below the floor line.
- Where the **hand is actually drawn** in `sprite_lil-blunt_*.png` — the grip anchors at local (±14, +2); whether that visually reads as "in hand" depends on the art.
- `$Visual`'s transform in `player.tscn` (not provided).
- Whether the object seen at the feet is `_tool` at all, versus the below-floor leg ColorRects (Finding 2) or a visual from a file not provided (`PowerUpHandler`, level foreground).
- Whether the complaint reproduces **at idle** (points to asset/scene) or **only while walking** (points to Finding 1). One screenshot with the remote scene tree visible settles all of these.