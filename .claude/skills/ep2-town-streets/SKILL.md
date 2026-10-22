---
name: ep2-town-streets
description: Design connected avenues and service yards around Episode 2's existing GoldMine buildings while preserving arrival, office, saloon and duel routes. Use for one-block layouts and empty ground.
argument-hint: "audit | plan | validate"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Streets and meaningful space

## Phase 1: Inspect and plan

Before writing, use the user's existing task authorization as approval; ask only for missing necessary inputs. Preparation writes are authorized; a plan is not a runtime implementation.

Start with `ep2-living-town`. Source adapter: `tools/ep2_town/town_tool.py`; layout: `src/episode2/chamber/ep2_gold_town.gd`. Its buildings are shared by `woods_quad.gd` and `gold_town.gd`: preserve identical world coordinates across the invisible handover. Do not independently move one town copy.

1. Audit current source; map building footprints and open doors. Existing x=+-9 fronts are not empty lots. Do not place a road through their backs.
2. Generate the plan. The starter has main street plus cross streets at z=1401/1458, west avenue x=-30 and east avenue x=32. This is a proposal in current world metres, not a universal street generator.
3. Inspect the SVG and walk the proposed junctions at eye height after implementation. Keep readable views toward CERTIFICATES, SALOON and Fort Knox. Give side roads returning routes, worn ground, drains, fences and yard functions; a painted strip alone is not an avenue.
4. Leave existing building geometry fixed in the initial pass. Expansion buildings/market stalls require explicit new footprint/collision entries and another plan check; never infer a new playable interior from a facade.
5. In a runtime pass, add geometry and collision through the shared builder, reconcile the desert scrub exclusion (currently around x=+-26) for wider streets/yards, and update both build users. No rocks/shrubs through a new lane, no road continuing into the fort hill. Reuse kit materials and chunk visibility ranges.

## Phase 2: Validate and hand off

Validate every segment against full footprints plus half road width. The tool treats centreline intersections as junctions and checks connectivity; actual terrain grade, character clearance, pathfinding and ride-off still require Godot tests. PASS means proposal connectivity/clearance, not engine navigation. Run existing town/interlude/arc tests after integrating, preserving the mounted departure and free movement through both open doors. Next step: `ep2-town-facades` and `ep2-town-proof`.
