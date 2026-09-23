# ADR-0003: Episode 2 runner — sim/view split, one cart per rail, earned ziplines

## Status

Accepted

## Date

2026-09-23

## Last Verified

2026-09-23 — real local web export (CI preset), both legs played in Chromium to the
chamber at full health; all Episode 2 headless gates green.

## Decision Makers

Founder (gameplay direction, 2026-09-23). Implementation choices recorded here.

## Summary

The runner was a working simulation drawn as grey boxes. It is now split into a pure
**simulation** (`runner_graybox.gd`, unchanged file/class name to avoid churn), a
**view** (`runner_view.gd`) that only reads the sim, and a **layout** in data
(`tracks/episode2_tracks.gd`). Three rules changed by founder direction: boulders are
escaped only by hopping carts, ziplines must be jumped for, and archers can be shot once
the Winchester is in hand.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.3 — web export uses the Compatibility (WebGL2) renderer |
| **Domain** | Gameplay / Rendering |
| **Knowledge Risk** | LOW — only long-standing nodes (MultiMesh, OmniLight3D, CPUParticles3D, Label3D, SurfaceTool) |
| **Verification Required** | Frame rate on real phones. Not measurable here: the only browser available renders on the CPU (SwiftShader) and runs the sim at roughly a third of real time, which says nothing about a phone GPU. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Godot 4.3 runtime) |
| **Enables** | Adding legs and hazards as data; restyling without touching gates |
| **Blocks** | None |

## Decision

1. **Sim / view split.** The sim never reads the view. The view reads `get_obstacles()`,
   `get_archers()`, `get_zip_segments()` and listens to signals. Every rule stays
   headless-testable; the view can be restyled with no gate at risk.
2. **One cart per rail.** A lane change is Lil Blunt *hopping between carts* (reference
   IMG_2492), not one cart sliding. The sim is unchanged by this; `$Cart` is the rider.
3. **Hazard verbs are one-to-one:** box → jump, arrow → duck (or shoot its archer),
   boulder → hop carts. Boulders were previously jump-clearable; the test that asserted
   that now asserts the opposite, plus a new test proves the hop.
4. **Ziplines are earned.** Airborne at the cable's start hooks it; a jump within 6 m of a
   cable's end swings to the next in a chain. A miss or drop costs **one** health for the
   whole remaining chain, never one per cable.
5. **Shooting is gated on the Winchester** (granted in Chamber 0, STORY_OUTLINE.md): leg
   1 is unarmed, leg 2 armed. A shot drops the nearest archer 4–45 m ahead and cancels its
   arrows; 0.35 s lever cooldown.
6. **Layout is a `.gd` const, not JSON.** The web export's `include_filter` ships only two
   named JSON files; a track `.json` would be missing live while every test passed.
7. **`LANE_X = [2.5, 0, -2.5]`.** The camera looks down +Z, so +X is screen-left. The old
   `[-2.5, 0, 2.5]` made every hop go opposite to the key pressed — invisible to headless
   tests, found in the first browser playtest.

## Consequences

**Positive**
- Each hazard carries a floor strip and a floating verb in its lane, colour-coded by the
  action that clears it. Both legs were cleared in a real browser at full health.
- Legs and hazards are added by editing data.

**Negative / accepted trade-offs**
- Two Meshy characters cost ~3.1 MiB of pack; ~3.9 MiB of headroom remains under the itch
  gate before the Chamber 0 assets (Bull, Winchester, furnace) land.
- Characters are static meshes (no rig). Hop/duck/zip are conveyed by position, scale and
  lean. Proper animation waits on Astra, per the asset lock.
- The headless dummy renderer prints `Parameter "m" is null` per primitive mesh. This was
  already the case before this change (71 lines on the untouched runner test); the view
  simply makes more meshes. It is noise, not a failure.

## GDD Requirements Addressed

Runner half of the runner↔chamber loop (`spec/00_ARCHITECTURE.md` §3); founder brief
2026-09-23 (duck arrows, hop carts from boulders, shoot archers, axe onto ziplines, chain
ziplines, return to the cart after each chamber).
