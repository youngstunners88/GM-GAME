<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-t1-t3-implementation.md
     files inlined: 6
     tokens: 15106 in / 6208 out
     cost: $0.4615
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Prioritized Plan

## T1 — TAP OUT face (do first, smallest + founder-flagged)

**Pick: resize the source PNG. Don't rely on the import pipeline.**

Justification:
- The source PNG **is committed**; `.import` files are not. A resized source survives CI by definition.
- The project.godot alternative does exist (`[importer_defaults]` section, `texture={"mipmaps/generate": true}`), and since CI regenerates from project-wide defaults it *would* persist — but it flips mipmap generation for **every texture in the project**, changing VRAM footprint and potentially the look of all world sprites, to fix one 58px icon. Wrong blast radius.
- Even with mipmaps working, a 585→58 downscale samples ~mip level 3-4 of Godot's automatic box-filtered chain — mediocre. An offline Lanczos resize is strictly better quality.

**Concrete change:**
1. Resize `src/assets/sprites/sprite_lil-blunt_tapout.png` from 585x586 to **116x116** (Lanczos/bicubic, square it up — source is currently non-square). That's exactly 2x oversample of the 58x58 display size, and covers 2x-DPI display up to the stated 116px ceiling. At ≤2x minification, plain bilinear is clean **with no mipmaps at all**, so the `mipmaps/generate=false` CI default becomes irrelevant.
2. Keep the existing `texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` line in blaze_rush.gd (harmless with no mips, correct if mips ever appear).
3. No change to `expand_mode`/`stretch_mode` — that wiring is correct.

**Screenshot 2 (DIAMOND LOUNGE card): cannot fix from what's provided.** I don't have the band-art wiring code, the card's source PNG dimensions, or its draw size. Send me the scene/script that places the three badges and the card PNG's resolution — likely the same pattern (extreme downscale, no mips) or a non-integer stretch, but I won't guess.

## T3 — Boss "dies without touching him"

**Root cause: the geometry gap is the primary mechanism, amplified by charge speed — no second bug in the state machine.**

- Hurtbox spans local x 0..168. Scaled opaque art: 120px × 1.12 = **134px wide**, source bbox (7..127) → on-screen art spans roughly x 18..153. That's **~17px of dead hurtbox each side**.
- No tunneling: CHARGE at 430px/s = ~7.2px/physics frame; LEAP at 620px/s = ~10.3px/frame — both far under the 168px shape. `move_and_slide` won't skip contact.
- No monitoring race: `monitoring` is set true once in `_ready()` and never toggled until `die()`. `monitorable` toggling only affects the player's *attacks* detecting the boss, not `body_entered`.
- The charge speed is why 17px reads as "never touched": at 430px/s the boss crosses the dead zone in ~2.4 frames (~40ms) — contact fires visibly before the art arrives, then `boss_contact_restart()` wipes the run and fades the scene, so the player's last perceived frame is a non-touch.

**One landmine in the current code:** `_ready()` does `hitbox_shape.shape = collision.shape` — the hurtbox and the body collider **share one RectangleShape2D resource**. Shrinking that shared shape would also shrink the physics body, breaking `is_on_wall()` leap triggers and floor footprint. The fix must allocate a distinct shape.

**Exact changes:**

`src/boss/auditor.gd`:
```gdscript
# New constants (near BODY):
## Hurtbox matches the scaled opaque silhouette of sprite_boss_tax-collector.png:
## opaque bbox (7,0)-(127,143) × fit scale 1.12 ≈ 134x160, centered on the art
## (opaque center offset from texture center: (+1.7, -3.9) from (84,84)).
const HURTBOX_SIZE := Vector2(134.0, 160.0)
const HURTBOX_CENTER := Vector2(86.0, 80.0)
```
In `_ready()`, replace:
```gdscript
hitbox.position = Vector2(BODY / 2.0, BODY / 2.0)
hitbox_shape.shape = collision.shape
```
with:
```gdscript
hitbox.position = HURTBOX_CENTER
var hurt_shape := RectangleShape2D.new()   # deliberately NOT collision.shape —
hurt_shape.size = HURTBOX_SIZE             # sharing would shrink the body too
hitbox_shape.shape = hurt_shape
```

`src/boss/auditor.tscn`: update `RectangleShape2D_hitbox` to `size = Vector2(134, 160)` and `Hitbox/CollisionShape2D` position to `(86, 80)` so scene matches code (the script overwrites both at runtime, but keep them in sync per the file's own comment convention).

**No grace/debounce.** Contact-kill is the founder's deliberate rule and `boss_contact_restart()` already has the double-fire guard (`_boss_restart_pending`). A grace timer would reintroduce "walked through the boss" reports.

**Missing info / verify after:** the **player's** collision shape vs the Lil Blunt sprite silhouette — `body_entered` fires on the player's *collider*, and if that collider is also padded, gaps compound. Player scene wasn't provided; send `src/player/*.tscn` (or equivalent) collision shape size and I'll confirm whether it also needs a trim.

**Order:** T1 (10 min, art asset swap) → T3 code change → playtest CHARGE grazes + LEAP-over-platform cases specifically.