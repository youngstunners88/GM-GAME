<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/s7-fable-implementer.md
     files inlined: 1
     tokens: 2220 in / 3194 out
     cost: $0.1819
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## T1 Readable text

**Failure mode:** per-label `add_theme_*_override` calls scattered across `vault_realm.gd` drift out of sync — someone adds a new label and forgets the outline.

**Fix:** one static helper, applied everywhere labels are made in `vault_realm.gd`:

```gdscript
static func style_vault_label(l: Label, size: int) -> void:
    var s: int = maxi(size, 24)  # 24px minimum for mobile web
    l.add_theme_font_size_override("font_size", s)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", maxi(4, s / 4))
```

**Per-label helper vs Theme:** use the helper. A Theme resource styles ALL Labels in the tree (would hit HUD/level labels outside the vault) unless you introduce theme_type_variations, which is more churn. The helper is grep-able and testable headlessly. Bump the current sizes: readout 20→28, prompt 18→26, amount 26→40, hint 13→24, plates 13→24.

**GATE:** instantiate the vault scene headless; assert every `Label` under the vault UI has `get_theme_constant("outline_size") >= 4` and `get_theme_font_size("font_size") >= 24`. Fails now (outline_size 0, hint 13).

---

## T2 Big-button clerk

**Failure mode:** putting stake/crush math inside button callbacks — then the headless gate can't exercise it and clamping bugs (amount > owned) slip through. Keep all validation in `goldmine_system.gd`; buttons only call it.

**Layout** (built in `vault_realm.gd`, replacing the text-adjuster):

```
CanvasLayer "ClerkUI"
└─ HBoxContainer (anchored center, full-rect margins)
   ├─ TextureRect  "MiraPortrait"   (founder Mira Voss art, stretch_mode KEEP_ASPECT)
   └─ PanelContainer
      └─ VBoxContainer (separation 16)
         ├─ Label  "Holdings"       # "$DIAMONDS: N | Blaze: M" via style_vault_label(…, 28)
         ├─ HBoxContainer  # STAKE row: Button "-", Label amount(40px), Button "+"
         ├─ HBoxContainer  # CRUSH row: same trio
         └─ Button "CONFIRM"
```

Buttons: `custom_minimum_size = Vector2(96, 96)` for +/- and `Vector2(280, 88)` for CONFIRM (≥88px hit target for touch), plus font_size override ≥32 with the same outline helper pattern (Buttons take the same theme override names). +/- handlers just do `stake_amt = clampi(stake_amt ± 1, 0, GoldMineSystem.diamonds_balance)` and `crush_amt = clampi(…, 0, GoldMineSystem.BLAZE_DIAMOND_STACK_LIMIT)` — actual mutation only on CONFIRM via `stake_diamonds(stake_amt, days)` / `crush_blaze_diamonds(crush_amt)`.

Keep ui_left/ui_right working as accelerators (call the same handlers) so gamepad play isn't broken.

**GATE:** headless: instantiate vault, assert a `Button` named "CONFIRM" exists with `size.y >= 88` after layout. Fails now (no Button nodes exist — clerk is a text panel).

---

## T3 Long-range shards + chase

**Failure mode:** raising speed alone without checking lifetime — shard still despawns mid-arena at phase 1.

Numbers for a ~1200px crossing:

- `_throw_shards`: 170 + 40*(phase−1) → phase 1 = 170 px/s → needs **7.1s** to cross 1200px. Either raise base to **340 + 60*(phase−1)** (crosses in ~3.5s) and set lifetime ≥ **4.0s**, or keep speed and set lifetime ≥ 7.5s (too floaty — raise speed).
- `_throw_crystal_shards`: 260 + 50*(phase−1) → 4.6s at phase 1; with a 4.0s lifetime it also fizzles. Raise base to **400 + 60*(phase−1)** (~3.0s crossing).

**Caveat:** the projectile lifetime field/value isn't in the facts I was given — I don't know if it's a Timer in `boss_projectile.tscn` or a var in its script. Tell me where it lives; the requirement is `speed * lifetime >= 1300` (arena width + margin) at phase 1.

Chase: `MIN_PURSUE_SPEED = 345` is fine as a floor. If the boss "still isn't chasing" in the real Stage 2 arena, the suspect is the arena bounds the level passes to `_hover_pursue` clamping X before pursuit applies — verify the Stage 2 level sets bounds spanning the full 1200px, not the smaller test-arena values. I'd need the Stage 2 level file to confirm.

**GATE:** headless real-physics test: spawn boss + player 1200px apart, call `_throw_shards()` at phase 1, step physics; assert a projectile's `position.x` traverses ≥1200px before it is freed. Fails now (170 px/s × current lifetime < 1200, per founder observation).

---

## T4 Blunt slightly bigger

**Failure mode:** scaling `_spr.scale` without scaling the anchor offset — feet sink `(RENDER_SCALE−1)*tex_h/2` px into the floor.

In `lil_blunt_visual.gd`:

```gdscript
const RENDER_SCALE := 1.25

# in set_outfit / _measure, replacing _spr.scale = 1 and the position line:
_spr.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
_spr.position.y = FEET_LOCAL_Y - (tex_h * RENDER_SCALE) / 2.0 + _art_offset_y * RENDER_SCALE
```

The bottom of the sprite sits at `position.y + (tex_h*RENDER_SCALE)/2 = FEET_LOCAL_Y (+ scaled art offset)` — feet stay at local y=16. Do **not** touch the Player's 32px RectangleShape2D; visual is 1.25× only, collision unchanged. (Scaling `_art_offset_y` keeps per-outfit art tweaks proportional; if any offset was tuned in screen px rather than art px, leave it unscaled — tell me if offsets look off by ~2px.)

**GATE:** instantiate LilBluntVisual, call set_outfit, assert `_spr.position.y + (_spr.texture.get_height() * _spr.scale.y)/2.0 == 16.0` (approx) AND `_spr.scale.x >= 1.2`. Fails now (`scale == 1`).

---

## T6 Gold Scale instrument

**Failure mode:** rebuilding the scale as new custom-drawn geometry instead of wiring the founder Gold Scale art — explicitly forbidden ("wire it, don't invent").

Minimal nodes (in both Diamond Vault and Fort Knox — factor into one scene/`.tscn` or a builder func in shared code so it's identical):

```
Node2D "GoldScale"
├─ Sprite2D "ScaleBody"     # founder Gold Scale texture (static base/post)
├─ Node2D  "Beam"           # pivot at fulcrum; rotate for tilt
│  ├─ Sprite2D left pan region (or the beam portion of the art)
│  └─ Sprite2D right pan region
├─ Label "LeftValue"        # style_vault_label(l, 32) — outlined, big
└─ Label "RightValue"
```

Motion: `Beam.rotation = lerp_angle(Beam.rotation, clampf((right_val - left_val) * TILT_PER_UNIT, -0.35, 0.35), delta * 6.0)` in `_process` — smooth, readable, direction = heavier side dips. Position it clear of the clerk panel (top-center of the vault view), fixing complaint #5/#6 together if the oversized element is the old scale.

I need to know the founder Gold Scale asset path and whether beam/pans are separate images or one flat texture — if one flat texture, we rotate a `RegionRect`-sliced Sprite2D or the whole sprite; separate images are cleaner. Not provided in the facts.

**GATE:** headless: instantiate the vault, set left=0/right=10, step frames; assert `Beam.rotation != 0` and both value Labels have `outline_size >= 4`. Fails now (no GoldScale/Beam node exists; labels have no outline).