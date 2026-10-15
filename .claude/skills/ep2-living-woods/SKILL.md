---
name: ep2-living-woods
description: Coordinate the founder's personal armory, living bear AI, Inferno stealth and defensive panic, persistent corpse loot, surface checkpoint, and noisy mountain quad escape to a binocular lookout. Use for cross-system work in the hideout-to-woods escape; preserve concurrent Claude world foundations.
---

# Living woods job

Read design/ep2/LIVING_WOODS_CONTRACT.md first. It records founder requirements, precedence over harmless/Winchester-only interludes, verified current files and future acceptance. This skill does not authorize claiming a design as playable.

## Recover current work

Follow AGENTS.md and .agents/skills/smokerealm-resume/SKILL.md. Fetch once, inspect overlapping deltas, preserve Claude's forest, lift, founder Tripo bears and quad. Do not rebuild or replace them to add behaviors. Read PROMPT_EPISODE2_FORT_KNOX_AWESOMEX_FOUNDATION.md; this slice ends at the lookout, not the later decoy/vault/rescue. Read .claude/skills/ep2-interlude-chain/SKILL.md for actual chamber hooks.

## Build order and ownership

1. Armory state and checkpoint transaction interfaces before combat: ep2-personal-armory and ep2-encounter-checkpoints.
2. Bear population, routines, perception, attacks, corpses/loot: ep2-bear-awareness.
3. Bull lookout, alarm/protection, failure and hand-brushed camouflage: ep2-inferno-stealth.
4. Acoustic geography, quad pursuit, park/uphill/binoculars: ep2-mountain-quad-escape.
5. Run the complete branch matrix with finite resources, seeded variation and retry, then capture the real first-person flow.

Before another session edits, assign named files/functions and interfaces. Session root owns persistence/retry; armory owns inventory; bear logic owns awareness and death records; presentation does not refill or reroll either. Re-read shared woods/interlude/session functions immediately before narrow edits. No broad reformat or whole-file replacement. Delegation is optional; use the same ownership contract when explicitly delegated.

## Jev and Microsoft Decision

Use scripts/jev.mjs and the routed Jev 1.14 skill. The user-selected Jev route is now direct TypeSafe; Microsoft uses explicit OpenRouter POST https://openrouter.ai/api/alpha/decisions.
Models are jev-1.14 (direct TypeSafe) and microsoft/microsoft-decision-1 (JEV_PROVIDER=openrouter, JEV_MODEL override), Microsoft remains on the text decision path; route Jev 1.14 via `.claude/skills/jev-1-14-routing/SKILL.md` for current image capability requirements.
Read .claude/skills/jev-decision-gate/SKILL.md. Reuse OPENROUTER_API_KEY or a process-local alias from OPENROUTER_API; never print/store the value.
The founder requested both models. Preserve both returned outputs, precise model IDs, source SHA, input evidence, costs if returned, uncertainty and disagreement. Neither is a gameplay test or permission.

Start from references/decision-input.json beside this skill, whose baseline facts are inspected, not simulated. It asks for finite armory and local/delayed encounters. The CLI interprets a choice other than ship as BLOCK, so for design choices call its exported evaluate() or send the documented request schema and retain raw JSON; do not misreport that CLI exit as a design rejection.

A live attempt for each model on 2026-10-10 received proxy CONNECT 403; see design/ep2/LIVING_WOODS_DECISIONS.md. No model endorsed this package. When access changes, retry once per model with refreshed facts. Do not bypass network policy or replace either with an unrequested model. Error/uncertainty leaves review pending; continue independent skill/design work and label implementation decisions provisional.

For implementation tuning, first collect seeded bot/runtime results: switch latency and wrong-slot rate; ammo/loot conservation; hearing outcomes at near/mid/far and occluded landmarks; detection/arrival times; simultaneous attackers; clear/fail/quiet branch counts; retry digest equality; browser frame times and pack delta. Declare sample counts, conditions and candidate thresholds before calling either model. They choose between measured candidate conventions; they do not invent usability data, see screenshots or play the game. Inspect captures yourself. Disagreement calls for the smallest discriminating experiment, not averaging away a risk.

## Implemented (2026-10-13) - what exists, where

The founder asked in plain words ("the bears are not active ... not walking around, sleeping, reading magazines ... give them
movements and awareness ... personality and individual character ... drive for a while ... shooting off bears on the road. Some bears
fire back with their arrows ... the world much larger"). Built in `src/episode2/chamber/woods_quad.gd` on these pieces:

| Piece | File | What |
|---|---|---|
| Bear body + poses | `src/episode2/actors/ep2_bear_kit.gd` | `make_bear()`, `pose()` idle/walk/run/sit_read/sleep/wake/aim/shot/leap/stomp/hit/dead, magazine in the paws, world stump, z's, bow, "?"/"!" mark |
| Bear mind | `src/episode2/actors/ep2_bear_brain.gd` | routine (patrol/roam/read/sleep/watch/road) -> awareness (UNAWARE/SUSPICIOUS/INVESTIGATE/ALERT/SEARCH/DEAD) -> combat (brawler leap+swipe, archer draw+arrow) |
| Reading head/spine | `src/episode2/actors/ep2_bear_head_down.gd` | sits up straight, looks down into the magazine |
| Who is who | `SCOUTS`, `ROAD_BEARS`, `CAMP_BEARS` in woods_quad.gd | names, routines, sight/fov/eyes/ears/react/speeds/hp/arrows/height/voice pitch, Inferno's intro line |
| Pose sheet | `tools/ep2_shots/bear_poses_shot.tscn` | every pose side by side - LOOK at it after touching the kit |
| Living-woods captures | `tools/ep2_shots/woods_life_shot.tscn` | scouts in routine, spotted/charge/down, mount glide, road archer, arrow in flight |
| Gate | `tests/ep2_interlude_test.gd` sections 2-3 | stealth path silent, wake/see/roar/charge, Inferno defends, corpse stays, arrows, retry restores all |

Rules learnt building it:
- Sight = range x attention (asleep 0, reading 0.45) + field of view + dwell meter x exposure (still/walk/run) + trunks block
  (`_los_blocked` on the tree grid). Hearing = events with a radius x ears (asleep 0.35, reading 0.6); an unconfirmed sound gives a
  blurred PLACE. A roar reaches allies within 34 m. Engine: hear < 70 m, alarm < 40 m with a clear line.
- Positions are tuned so walking behind Inferno on the trail is silent; the test proves it. Moving a scout = re-run section 2.
- The library chair-sit keeps a man's chair height: a reading bear's body drops 26 % of his height onto a world stump (`SIT_DROP`).
- `get_meta(key, null)` with a null default ERRORS in 4.3 when the key is missing: use `has_meta`.
- Archers draw only with an attack token (`ARCHERS_AT_ONCE` = 2) and a clear line; arrows lead the quad and hit ~10-28 %.
- Corpses never free; retry frees ALL bears and respawns them from `_specs` (atomic restore with ammo + hearts + quad + leaves).

## Done

For skills-only work: verify frontmatter, links, routing and consistency; update STATUS.md, commit and push to master through the normal non-forced merge path. A skills-only commit does not need a game export and is not a new live feature.
For gameplay: meaningful deterministic/runtime tests, actual FPS captures, applicable range/session/Fort Knox/save/runner gates, nonthreaded Godot 4.3 web export under the current pack gate, then .agents/skills/smokerealm-ship/SKILL.md. Distinguish prepared, implemented, tested and live.
