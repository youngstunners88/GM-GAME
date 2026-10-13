---
name: ep2-character-performance
description: Improve Inferno Bull and bear performance from guide timing through rest-aware skeletal motion, independent hand/prop contacts and real Godot evidence. Use for stiff/static movements, incorrect rifle grips, bow or magazine contact, quad hands, or the founder's BFS/Minimax-H3 character-swap transcript.
---

# Bull and bear performance

Read design/ep2/motion/TRANSCRIPT_ADAPTATION.md and CHARACTER_MOTION_CONTRACT.md in the same directory.
This package was requested as skills preparation. It does not implement a rig, clip or runtime fix.

This updates the existing character-performance skill rather than replacing its history. The 2026-10-01 facility/runner toolkit is retained in references/historical-performance-2026-10-01.md. Keep its useful choreography lessons: feet-origin pivots, visible giver-to-receiver item paths, receiver reactions, human offer timing and a single deterministic step entry point. Preserve Lil Blunt's existing facility/runner acting unless that task explicitly includes it. Historical static-body/whiskey-hand and body-scaling conventions are not current Bull/bear instructions.

## Route only the needed work

| Work | Skill |
|---|---|
| Guide performance, appearance lock, shot plan, continuity/audio | .claude/skills/ep2-performance-guides/SKILL.md |
| A-pose rig adaptation, timing, feet, export and skin diagnostics | .claude/skills/ep2-rest-aware-retargeting/SKILL.md |
| Rifle, bow, magazine, lever, leaves and quad contact | .claude/skills/ep2-prop-contact-animation/SKILL.md |
| Deterministic contact/temporal metrics and actual runtime captures | .claude/skills/ep2-character-motion-qa/SKILL.md |

Recover current master through smokerealm-resume before editing. Preserve Claude's living woods, mobile controls, acquisition/tutorial gates, founder rigs and later Fort Knox arc. Load only the listed source files for the action under review. The older ep2-motion-emotion runner conventions do not turn these walking characters into static statues.

## Work in this order

1. Inspect the current player-camera failure and the model's skin/rest pose; preserve baseline source SHA and guide/reference identities.
2. Copy references/clip-plan.template.json to a development job directory under design/ep2/motion/jobs/. Resolve guides, timing and rights; record missing inputs rather than inventing clips.
3. Choose existing approved clips or locally authored Blender motion before a provider rerig. Prove rest transfer, whole-limb skin integrity and neutral pose before adding extreme reaches.
4. Author phase-based body movement and independently measured contacts. Confirm reachability before timing the prop's transfer/release.
5. Run whole clips, transitions and interactions in the actual Godot Compatibility scene; inspect the player's view and diagnostic angles.
6. Integrate the smallest accepted patch, preserve other work, then use smokerealm-ship only for verified runtime changes.

Validate a job with:
    python3 .claude/skills/ep2-character-performance/scripts/check_motion_plan.py /path/to/clip-plan.json --repo .
Add --require-ready for the input-readiness gate. Exit 2 means valid but incomplete inputs; even exit 0 does not prove retargeting, animation quality, contact or gameplay. The template deliberately remains a draft.

## Plugins and fallback

The founder explicitly named Tripo 3D, Build 3D Game Rooms and Game Development Studio. Use their installed skills where their actual workflow applies:
- Tripo: reuse the founder assets; rig-check before an approved paid rig/retarget plan. Inspect current CLI/auth/network status without printing key values. No new body generation is needed merely to move a hand.
- Build 3D Game Rooms: independent support/attachment measurements, production camera and explicit gate evidence. This character job is not a new room; never label room Function/Form/Runtime approved from a motion plan. If rebuilding a room becomes necessary, follow the full room contract.
- Game Development Studio: inspect game-dev capabilities/doctor and the project adapter before using its capture/package routes. Follow actual command authorization requirements and existing session scope. If the CLI is absent, report that and use the repository's Godot/Blender captures when authorized; never fake a sealed game-dev run.
- Missing BFS/ComfyUI/MiniMax-H3 tools do not block local authored motion. Generated video can be reference, not a loaded game animation. Keep license/spend/input-transfer requirements for any optional provider run.

No paid jobs, generation, external model opinions or runtime visual approvals were performed to prepare this package. Do not infer fresh access from a historical tool-roster row. Jev/Microsoft can review measured candidate facts when reachable; they cannot see screenshots or supply motion clips.
