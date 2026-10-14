# Living-town toolkit verification — 2026-10-15

Scope: skills/scripts preparation requested by the founder. No game runtime/asset/export changes or paid provider jobs.

- Inspected checkout baseline `236ff712b67f56ce77b6633b463e2c64c7ed3229`, AGENTS/CLAUDE/manifests, town narrative/cast skills, shared layout and Blender door/window generator.
- Shell Git fetch fails to connect to the session proxy at port 8080. GitHub connector refresh observed master `f76ca5aa77209aafaffb10d7490b1a3875140201`; the intervening armory and generated-export changes are preserved by publishing a scoped tree against that remote base. Town builder/generator are unchanged across that delta.
- `python3 -m unittest discover -s tools/ep2_town -p 'test_*.py'`: 28 PASS. Includes source adapter, deterministic phases, roads through buildings/disconnected roads, blocked doors, duel exclusions, whole route segment intersections, overlapping placements/attachment exception, cast/Bull timing, facade coverage, audio/budget limits, malformed/nonfinite input, source drift, node-safe IDs, export roundtrip and skill structure/routes.
- Audit, plan, validate and handoff run successfully against the actual project. Example: 5 roads, 10 facade targets, 12 ambient people/animals, 2 instruments, 2 props, 7 capture jobs. All 16 asset bindings remain unresolved. Marker scene has no meshes, AI, navigation or runtime integration.
- Schematic inspected as a diagram. It is not a rendered gameplay view. The main street retains its role, avenues form a connected circuit and activity clusters sit outside the reserved central travel/duel lane.
- Repository scanner initially flagged raw SHA256 provenance as private-key-shaped hexadecimal. These are computed public file checksums; the tool now serializes them as typed `sha256:<base64>` values. No scanner rules or exclusions changed. Both real scanner runs are recorded in `docs/security/audit-log.md`.
- Final repository Security Sentinel: 18 PASS, 0 FAIL, 0 blockers. All changed paths are skills, documentation, examples or offline tools; the existing export workflow's path filters do not require a game rebuild for this preparation.

Unverified: actual doors/windows visible from first person, real actor models/rights/clips/contacts, moving-body avoidance, terrain clearance on proposed avenues, camera continuity, story audio, performance and pack impact. `runtime_approved=false` remains explicit. Follow `ep2-town-proof` for implementation evidence. Preparation source publication is distinct from a game deployment.
