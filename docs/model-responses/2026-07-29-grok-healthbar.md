<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-boss-healthbar.md
     files inlined: 0
     tokens: 1267 in / 1312 out
     cost: $0.0104
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Boss Health Bar Spec

## 1. Bar placement
**Verdict: Screen-anchored top-center via `CanvasLayer`.**

World-space bars jitter with boss movement, clip off-screen during jumps, and shrink under camera zoom—bad for 6–7 HP readability on mobile. Anchor a top-center bar below any stage title safe area; keeps it clear of bottom touch controls and legible over every backdrop.

## 2. Visual spec
**Verdict: `ProgressBar` + three `StyleBoxFlat`s (fill, background, optional frame `Panel`).**

| Role | Node / style | Properties |
|------|----------------|------------|
| Frame | `Panel` (parent) | `custom_minimum_size = Vector2(320, 28)`; `StyleBoxFlat`: `bg_color = #1A0A2E` (cc≈0.92), `border_width_* = 2`, `border_color = #C4F042`, `corner_radius_* = 4` |
| Track | `ProgressBar` background | `StyleBoxFlat`: `bg_color = #0D0818`, `border_width_* = 1`, `border_color = #5B3A8C`, `corner_radius_* = 2`, `content_margin_* = 2` |
| Fill | `ProgressBar` fill | `StyleBoxFlat`: `bg_color = #B8FF3D`, `border_width_* = 0`, `corner_radius_* = 2` |
| Bar control | `ProgressBar` | `size = Vector2(312, 20)`, `show_percentage = false`, `max_value` = boss max HP, `step = 1` |

Neon lime fill on deep purple track stays readable on both cyan caves and dark forest. 2px lime frame gives a hard silhouette without shaders.

**Phase fill colours** (swap `StyleBoxFlat.bg_color` on the fill box):
- Phase 1: `#B8FF3D` (lime)
- Phase 2: `#FFB020` (amber)
- Phase 3: `#FF3D6E` (hot pink-red)

## 3. Discrete segmentation
**Verdict: Yes — N pips via `HBoxContainer` of `ColorRect`s, not continuous fill.**

With max HP 6–7, a smooth bar hides individual hits. Replace (or overlay) the `ProgressBar` fill with:

- `HBoxContainer` (`separation = 3`), full width of the track interior.
- One `ColorRect` per HP (`size_flags_horizontal = SIZE_EXPAND_FILL`, min height 16px).
- Filled pip: `color =` current phase colour.
- Empty pip: `color = #2A1848`.
- On damage: set the lost pip to empty (or tween its `color.a` → 0 then set empty).

Threshold marks (Distributor 4 / 2, etc.): 2px-wide `ColorRect` dividers coloured `#E0A0FF` inserted in the `HBoxContainer` *after* the pip index that equals each threshold. No art, pure nodes.

If you keep `ProgressBar` for simplicity, set `max_value = hp`, `step = 1` and still overlay the threshold `ColorRect` markers at `x = width * (threshold / max_hp)`.

## 4. Damage feedback
**Verdict: Tween pip/bar + short flash; no shaders.**

On each hit (all via `Tween` on existing properties):
1. **Pip punch**: tween lost pip `modulate` → `#FFFFFF` (40 ms) → empty colour (80 ms).
2. **Bar shake**: tween frame `position` by `±4px` on x, 3 oscillations, 120 ms total (reset to origin).
3. **Fill flash** (if using `ProgressBar`): tween fill `StyleBoxFlat.bg_color` → `#FFFFFF` → phase colour, 100 ms.

Do not tween `size` of the whole bar (layout thrash on mobile).

## 5. Phase communication
**Verdict: Fill colour shift + permanent threshold markers — both.**

- **Colour**: on phase change, tween all remaining filled pips (or fill `bg_color`) to the phase colour over 200 ms. Phase 1 lime → 2 amber → 3 hot pink matches existing escalation.
- **Markers**: purple-pink threshold ticks (//3) stay always visible so players see “next enrage” before it happens.
- **Optional one-shot**: tween frame `border_color` → `#FFFFFF` → `#C4F042` on phase enter (150 ms) to mirror screen-shake/taunt beat.

## 6. Boss name label
**Verdict: `Label` above the bar, outlined, centered.**

- Text: boss display name (e.g. `THE AUDITOR`).
- `horizontal_alignment = CENTER`, width matches frame (320px).
- Font: default Godot font is fine if no pixel font is already in-project; **size 14**.
- `modulate` / font colour: `#E8FFA0`.
- Outline: `Label` theme overrides — `outline_size = 2`, `outline_color = #1A0A2E` (confirm project uses theme override keys available in 4.3; these are standard `Label` constants).
- Placement: 4px gap above the frame top edge, same `CanvasLayer` parent; does not move with boss.

**Auditor note:** promote `auditor.gd` onto the same bar path as `BossBase._setup_health_bar()` (or extract a shared `BossHealthBar` scene) so Stage 1 is not the only boss without UI.