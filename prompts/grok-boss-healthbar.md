ROLE: UI/UX designer specifying a boss health bar for a Godot 4.3 2D platformer.

CONSTRAINT (non-negotiable): Do not invent Godot APIs, node types, file paths,
or theme properties that do not exist in Godot 4.3. If you are unsure whether a
property exists, say so explicitly rather than asserting it.

## Correction to the brief you may have been given

A previous planning document assumed bosses have NO health bar and one must be
built from scratch. That is wrong, and I verified it against the real code
before writing this. The actual situation:

- `src/boss/boss_base.gd` ALREADY creates a health bar in `_setup_health_bar()`:
  a plain `ProgressBar`, `size = Vector2(200, 20)`, `position = Vector2(-100, -50)`
  (world-space, parented to the boss body so it floats above the boss),
  `modulate = Color(1.0, 0.2, 0.2, 1.0)`, no theme/StyleBox applied at all —
  so it renders with Godot's DEFAULT grey ProgressBar look, tinted red.
- Bosses 2, 3, 4 (`distributor.gd`, `claim_jumper.gd`, `bandit_boss.gd`) extend
  `BossBase` and therefore have this bar.
- **Boss 1, the Auditor (`auditor.gd`), extends `CharacterBody2D` directly, NOT
  `BossBase` — so the FIRST boss every player meets has no health bar at all.**
- All four bosses ALREADY have working 3-phase escalation (speed increases,
  attack-pattern changes, voice taunts, screen shake) driven by HP thresholds.
  `BossBase.current_phase` / `auditor.gd`'s `phase` hold the current phase.

So the real design need is: **restyle the existing bar to look intentional
instead of default-engine, and specify how phase state is communicated.**

## Game context

- Art style: chill, 420-friendly, neon greens/purples, crypto aesthetic, 16-bit
  pixel-art sprites over painted backdrops.
- Bosses: Auditor (Stage 1, 6 HP, 3 phases), Distributor (Stage 2, 7 HP,
  thresholds at 4 and 2), Claim Jumper (Stage 3), Bandit Boss.
- Note the LOW max HP values — 6 and 7. A bar with 6 discrete hits reads very
  differently from a 100-HP bar. Factor that into your design.
- Rendering: HTML5 (non-threaded) + Android. Base viewport 1280x720,
  `canvas_items` stretch.
- The existing bar is parented to the boss in world space, so it moves with the
  boss and scales with camera zoom. A screen-anchored bar (CanvasLayer) is the
  alternative. Recommend one and say why.

## Deliverable (keep it tight, max 600 words)

1. **Bar placement**: world-space-above-boss (current) vs screen-anchored top.
   Pick one, justify in one or two sentences.
2. **Visual spec**, expressed as concrete Godot 4.3 constructs — `StyleBoxFlat`
   properties (bg_color, border_width_*, border_color, corner_radius_*),
   sizes in px, and colors as hex. Cover fill, background/track, and border.
3. **Discrete segmentation**: given 6-7 max HP, should the bar show N distinct
   pips/segments rather than a continuous fill? If yes, how, using only
   ColorRect/StyleBox (no external art).
4. **Damage feedback**: what happens visually on each hit. Must be achievable
   with Tween on existing properties.
5. **Phase communication**: how the player perceives a phase change on the bar
   itself (colour shift? segment marks at the thresholds? both?).
6. **Boss name label**: font size, colour, outline, placement.

## Hard constraints

- Godot 4.3 built-in UI nodes only (`ProgressBar`, `TextureProgressBar`,
  `ColorRect`, `Panel`, `Label`) + `StyleBoxFlat`. No external image assets.
- No custom shaders.
- Must stay legible over BOTH a bright cyan crystal cave and a dark purple
  forest backdrop.
- Mobile: must not sit under the on-screen touch controls (bottom of screen).

## Output format

Markdown. Lead each numbered section with a one-line verdict, then the
reasoning. No preamble.
