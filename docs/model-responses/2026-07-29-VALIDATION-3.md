# Claude's validation — 2026-07-29 (third session) dispatches

P0-D torch flame throw. Two dispatches, both checked against the real files
(and, for the architecture correction, the real project structure) before
anything changed.

---

## Architecture correction, before either dispatch

The session prompt that generated this work asked for the torch attack to
extend `src/shooter/weapon_base.gd`. Checked first: that class belongs to the
standalone v1.2 "Blunt Force" shooter prototype room and its own
`shooter_player.gd` — a different playable mode, explicitly documented
elsewhere (this branch's own PR body) as never touching the main platformer's
`player.gd`. The main-game torch power-up (`src/powerups/torch_tool.gd`)
already exists and is driven through the main platformer's actual combat
system: `src/player/combat_handler.gd` + `src/combat/axe.gd` +
`src/combat/fire_breath.gd`, documented in `docs/architecture/
adr-combat-system.md`. Independently confirmed by the project's own
`.claude/context-manifests/default.md`, which already routes "Player /
movement / combat" work to exactly those two files — a second, unprompted
data point for the same conclusion. Built there instead.

## Grok → torch flame VFX brief
`x-ai/grok-4.5`, 1,317 in / 1,624 out, **$0.0124**
Source: `docs/model-responses/2026-07-29-grok-torch-vfx.md`

### Accepted, near-verbatim
- CPUParticles2D-driven visual instead of a sprite sheet (none exists) —
  same "no art dependency for a one-off cosmetic effect" pattern already
  proven in `lil_blunt_visual.gd`'s tool glow.
- Full palette (`#FFF1A8`/`#FF9F1C`/`#FF4D00`/`#B8FF3D`/`#5A6670`), size ramp
  (16→24→~18px), skip a `PointLight2D` on the flying projectile (HTML5/
  Android cost vs. a <1.2s lifetime), impact burst (12-16 particles), sparse
  trail (8-12), and the four SFX key names.
- Its own explicit re-statement of the constraint: "Do not extend
  `src/shooter/weapon_base.gd`" — it didn't need convincing, just the
  corrected brief up front.

### Adapted
- Kept the client's own original numbers for velocity/gravity/lifetime
  (300px/s, -50px/s initial vertical, 200px/s² gravity) for the shallow-arc
  feel, rather than Grok's suggestion to mirror axe's flat 620px/s throw —
  the arc is what makes the two moves read differently at a glance, which is
  worth the small inconsistency with axe's pure-flat convention.

---

## Kimi → post-implementation torch audit
`moonshotai/kimi-k3`, 5,410 in / 12,917 out, **$0.2100**
Source: `docs/model-responses/2026-07-29-kimi-torch-audit.md`

### CONFIRMED and FIXED
| Finding | How I verified | Fix |
|---|---|---|
| **Inverted fizzle condition** — `_despawn()`'s `_age < lifetime - 0.05` check is true for almost every impact too (impacts happen mid-flight, well before the 1.4s timer), so every hit was ALSO playing the no-hit "fizzle" SFX and spawning a second burst; the real timeout case (full flight, no hit) skipped fizzle entirely — backwards from the comment's stated intent | Re-read my own `_impact()`/`_despawn()` side by side: confirmed, `_impact()` calls `_despawn()` at its end, and the age check has no way to distinguish "just hit something" from "still early in flight" | Added an `_impacted` flag set in `_impact()`; `_despawn()` now fizzles only `if not _impacted`. |
| **Orphaned burst node on a null `current_scene`** — `_spawn_burst()` built the `CPUParticles2D` *before* checking `get_tree().current_scene == null`, so on that (rare, mid-scene-transition) path the node was constructed, never parented, and never freed | Confirmed by re-reading the function's order of operations | Moved the null check before node construction. |

### Noted, not acted on
- **Same-frame double-`_impact()`** if `body_entered` and `area_entered` both
  fire in one physics step. Kimi itself flagged this as "identical exposure
  exists in shipped `axe.gd` — pre-existing pattern, not a regression."
  Agreed; fixing it here alone would make torch inconsistent with the
  already-shipped, accepted axe behavior rather than actually resolving the
  underlying shared risk. Left as a follow-up for both files together, not
  in scope for this session.
- **"High (conditional)" on `fx_dot.png` existing** — Kimi correctly flagged
  this as unverifiable from its own inlined context (the file wasn't
  provided to it). Already independently confirmed earlier this session
  (used for the Smoke Lounge's ground smoke; checked its real pixel
  dimensions with PIL: 32x32). Non-issue.
- **Player scene's own collision layer not inlined** — same reasoning;
  Kimi flagged the gap honestly rather than asserting an unverified claim.
  Confirmed separately: the mask (36 = Enemies + Hazards) is copied exactly
  from the already-shipped, already-verified-safe `axe.gd`.

---

## Session spend
$0.0124 (Grok) + $0.2100 (Kimi) = **$0.2224**
