# ADR-0001: Episode 2 runtime engine — Godot 4.3, not Three.js

## Status

Accepted

## Date

2026-09-08

## Last Verified

2026-09-08

## Decision Makers

Founder (final call, 2026-09-08). Informed by two independent multi-model
reviews (2026-09-05 architecture review + aesthetic review) and by the
verified state of the Episode 2 codebase.

## Summary

Four Episode 2 specs in a row named **Three.js** as the runtime while every
working piece of Episode 2 was being built in **Godot 4.3 3D**, leaving the
runtime genuinely ambiguous across four sessions. The founder has now settled
it: **Episode 2 runs on Godot 4.3.** The runner is not to be rebuilt in
Three.js; Pascal Editor is a layout/authoring tool only (its GLB output is
imported into Godot); Three.js is permitted for optional future web
prototypes but is explicitly **not** the game runtime.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.3 (stable) |
| **Domain** | Core / Rendering |
| **Knowledge Risk** | LOW — Godot 4.3 is the version already pinned and shipping Episode 1 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `artifacts/episode2-gold-mine/spec/00_ARCHITECTURE.md` §7a; `docs/model-responses/2026-09-05-astra-episode2-architecture.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | 3D web export performance on target phones must be measured before art production — the shipping 2D export is **not** evidence that a 3D export performs. Still outstanding. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Episode 2 chamber implementation; Pascal → GLB → Godot asset pipeline |
| **Blocks** | None — this unblocks rather than blocks |
| **Ordering Note** | Supersedes the "engine undecided" caveats in `00_ARCHITECTURE.md` §6.1/§7 and in the V2/V3/V4 founder-prompt addenda. |

## Context

Episode 1 is a shipped 2D pixel-art Godot 4.3 platformer. Episode 2 is a 3D
over-the-shoulder minecart runner plus 3D chambers — a new rendering path, and
arguably a new product.

The founder's Episode 2 specs (V1–V4) each named Three.js, in one case as a
"forced" technical constraint. Meanwhile, all Episode 2 work that actually got
built and gated was Godot 4.3 3D:

- `src/episode2/runner/runner_graybox.gd` — auto-run, 3-rail switching, jump,
  duck, zip-line, and the arrow/boulder hazard model. 20/20 headless gate.
- `tests/ep2_runner_music_test.gd` — runner music via `AudioManager`. 5/5.
- `tools/blender/build_asset.py` + `tests/ep2_glb_pipeline_test.gd` — headless
  `bpy` → GLB → Godot import. 7/7.

Rather than silently ignore the specs or silently rebuild in Three.js, the
conflict was surfaced to the founder in writing on each spec intake, and the
decision was deferred to them.

Two independent model reviews had already recommended Godot on the grounds
that a second runtime buys no fidelity — both engines load the same GLB
assets — while costing a second deploy, input, and economy integration.

A late and decisive input: **Pascal Editor, adopted for chamber architecture,
exports GLB, which is engine-neutral.** That removed the last argument for
Three.js, because the chamber pipeline works identically either way.

## Decision

**Episode 2 runs on Godot 4.3.**

1. The Godot 3D runner and its hazard model stay as they are. They are not to
   be rebuilt in Three.js.
2. **Pascal Editor is a layout/architecture tool only.** Chambers are authored
   in Pascal, exported to GLB via its browser step, and imported into Godot.
   Pascal never runs as part of the game.
3. **Three.js is not the game runtime.** It remains permissible for optional,
   throwaway web prototypes only, and any such prototype is explicitly not on
   the path to shipping.
4. Godot 4.3 remains the single engine across both episodes, so the existing
   economy autoload (`goldmine_system.gd`), CI export, security gates, and
   itch.io deployment continue to serve Episode 2 unchanged.

## Consequences

**Positive**
- No rewrite. Every gated Episode 2 system stays valid.
- One engine, one deploy pipeline, one export target, one set of security
  gates across Episodes 1 and 2.
- The economy stays authoritative in `goldmine_system.gd` rather than being
  re-implemented in a second runtime.
- The Pascal chamber pipeline is unaffected — GLB imports into Godot natively.

**Negative / accepted trade-offs**
- Godot's 3D web export is heavier than a hand-rolled Three.js scene. The
  `index.pck` size gate (190 MB, added after the itch.io outage) becomes more
  important as 3D assets land.
- WebGPU-era Three.js effects are not directly available; Godot 4.3's web
  export is WebGL2-based and stays non-threaded (see the standing
  `variant/thread_support=false` rule — regressing it breaks itch.io).
- Any future desire for a React/R3F web frontend would mean revisiting this.

**Neutral**
- Pascal's own stack is React Three Fiber, but that is authoring-side only and
  imposes nothing on the runtime.

## GDD Requirements Addressed

Episode 2 runner + chamber loop (`artifacts/episode2-gold-mine/spec/00_ARCHITECTURE.md`
§3); chamber asset pipeline (`spec/CHAMBER_ARCHITECTURE_PLAN.md` §0-§1).

## Notes

The outstanding verification item is real: a Godot **3D** web export has not
yet been performance-tested on target phones. The 2D Episode 1 export passing
on mobile is not evidence for the 3D one. That measurement should happen
before any art production is authorised, per the original multi-model review.
