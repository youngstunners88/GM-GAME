---
name: gm-game-episode2-gold-mine-runner
description: Episode 2 of Lil Blunt Adventure — the 3D Gold Mine Runner + Protocol Chambers. Read this before any Episode 2 work (runner track sections, chamber shooter/RPG encounters, the Blender→GLB asset pipeline, or the runner↔chamber loop). Carries the founder brief, the environment blockers, and the rails that keep Episode 2 planning honest.
---

# Episode 2 — Gold Mine Runner + Protocol Chambers

Episode 2 is a **3D over-the-shoulder minecart RUNNER** through a gold mine,
interleaved with **full 3D shooter/RPG "chambers"** that dramatize real Gold
Mine white-paper protocol mechanics. This is a deliberate departure from
Episode 1 (a 2D pixel-art platformer) — effectively a new product on a new
rendering path.

## Read first
- `artifacts/episode2-gold-mine/spec/FOUNDER_PROMPT.md` — verbatim founder brief, single source of truth.
- `artifacts/episode2-gold-mine/spec/00_ARCHITECTURE.md` — the engineering plan, the environment blockers (§5), open design questions (§6), and the multi-model design review (§7a).
- `artifacts/episode2-gold-mine/chambers/01..06_CHAMBER_*.md` — the six 3D encounter briefs.
- `docs/whitepapers/GoldMine.md` + `src/autoload/goldmine_system.gd` — the REAL economics. Every number comes from here.

## Non-negotiable rails
1. **Never invent protocol numbers.** All economics come from
   `goldmine_system.gd` constants + the white paper. If a number isn't there,
   it's an open question, not a value to make up.
2. **"Matches the references exactly" is not a shippable acceptance criterion**
   for a mobile web build — the refs are offline path-traced concept art. The
   real bar is "Uncharted-mobile / stylized realism" (baked light, emissive
   gold, fake volumetrics). Fidelity is approved from a real browser build on
   target phones, never from offline renders. (Confirmed by both design-review
   models, 2026-09-05.)
3. **Blender/blender-mcp cannot run in the agent container** (no Blender, no
   GPU — verified). The hero character needs a human Blender pass or handed-over
   GLBs; image-to-3D is for prop blockouts only. Do not claim a Blender scene
   was produced here.
4. **Engine: Godot 4.3 3D is the recommended path** (one engine, reuse the
   existing economy/CI/export). Three.js means a second runtime — founder's
   call, not a default. Do not start a second engine without explicit sign-off.
5. **The runner↔chamber loop:** persistent session root + separate scenes +
   explicit transition states; economy/progression live outside disposable
   scenes. Guard: double-triggered rewards, stale input, duplicate player,
   wrong resume position, mobile memory.
6. **Do not touch Episode 1 residuals** while doing Episode 2 planning.
7. Standing project rules still apply: multi-model dispatch on substantial
   design decisions, security sentinel, gates before "works", STATUS + commit
   + push every session.

## Next build step (when founder confirms engine)
A Godot graybox vertical slice: short minecart run → one chamber (basic
move/combat + one real protocol interaction) → return to saved track
position. Engine primitives only, clearly temporary, phone-tested, wired to
the real economy constants. Needs no Blender/GPU, so it is unblocked. Record
load/frame/memory before authorizing art production.

## Note on paths
The founder prompt names `.grok/skills/gm-game-episode2-gold-mine-runner/`.
This harness reads skills from `.claude/skills/`, so the working copy lives
here. If a `.grok/` toolchain is later added, mirror this file there.
