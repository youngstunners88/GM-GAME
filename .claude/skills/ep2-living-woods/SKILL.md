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

Use the existing scripts/jev.mjs transport, POST https://openrouter.ai/api/alpha/decisions.
Models are ~typesafe/jev-latest and microsoft/microsoft-decision-1 (JEV_MODEL override), both text-only.
Read .claude/skills/jev-decision-gate/SKILL.md. Reuse OPENROUTER_API_KEY or a process-local alias from OPENROUTER_API; never print/store the value.
The founder requested both models. Preserve both returned outputs, precise model IDs, source SHA, input evidence, costs if returned, uncertainty and disagreement. Neither is a gameplay test or permission.

Start from references/decision-input.json beside this skill, whose baseline facts are inspected, not simulated. It asks for finite armory and local/delayed encounters. The CLI interprets a choice other than ship as BLOCK, so for design choices call its exported evaluate() or send the documented request schema and retain raw JSON; do not misreport that CLI exit as a design rejection.

A live attempt for each model on 2026-10-10 received proxy CONNECT 403; see design/ep2/LIVING_WOODS_DECISIONS.md. No model endorsed this package. When access changes, retry once per model with refreshed facts. Do not bypass network policy or replace either with an unrequested model. Error/uncertainty leaves review pending; continue independent skill/design work and label implementation decisions provisional.

For implementation tuning, first collect seeded bot/runtime results: switch latency and wrong-slot rate; ammo/loot conservation; hearing outcomes at near/mid/far and occluded landmarks; detection/arrival times; simultaneous attackers; clear/fail/quiet branch counts; retry digest equality; browser frame times and pack delta. Declare sample counts, conditions and candidate thresholds before calling either model. They choose between measured candidate conventions; they do not invent usability data, see screenshots or play the game. Inspect captures yourself. Disagreement calls for the smallest discriminating experiment, not averaging away a risk.

## Done

For skills-only work: verify frontmatter, links, routing and consistency; update STATUS.md, commit and push to master through the normal non-forced merge path. A skills-only commit does not need a game export and is not a new live feature.
For gameplay: meaningful deterministic/runtime tests, actual FPS captures, applicable range/session/Fort Knox/save/runner gates, nonthreaded Godot 4.3 web export under the current pack gate, then .agents/skills/smokerealm-ship/SKILL.md. Distinguish prepared, implemented, tested and live.
