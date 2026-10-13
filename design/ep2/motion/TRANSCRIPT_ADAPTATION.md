# From the supplied video workflow to game motion

Source: founder-pasted Pasted text.txt, archived verbatim as WORKFLOW_TRANSCRIPT.txt beside this file.
Original shared document: https://docs.google.com/document/d/1OYg2D8H7C4NK_VKNhO4bIqKL8f2vABh5ayW5PzWUwI0/edit
Archive/analysis date: 2026-10-14 (Asia/Seoul). The Google URL was blocked; the supplied attachment was read in full.
The transcript links https://huggingface.co/Alissonerdx/Minimax-H3-ComfyUI and its workflows/minimax_h3_character_swap_workflow.json. Those remote model/workflow/license files have not been fetched or executed here.
MiniMax-H3 in this video workflow is distinct from Tripo's H3.1 3D generation model. Do not interchange their model names, APIs, settings or outputs.

## What it actually demonstrates

BFS character-swap LoRA with optional shot planner, aligned video-guide conditioning, a separate character reference, optional audio conditioning, masks and shot continuity. It generates video frames. It does NOT emit a game skeleton, a motion-capture solve, foot contacts or rifle grips. References to future reinforcement learning are research proposals, not production guarantees.

| Transcript time | Demonstrated principle | Adaptation for Bull/bears |
|---|---|---|
| 00:45, 03:29 | Guide is performance/scene; reference is appearance | Separate action/timing input from immutable founder-model identity |
| 01:13, 07:08 | 12 s start, ~7 s diagnostic, 15 s not guaranteed; smaller shots cost less memory | Review bounded action clips; do not hardcode 12 s for a lever or gun cycle |
| 01:58–03:03 | Global prompt/reference, explicit functional details; placeholders are ordinary text | One identity/costume/prop contract; record hands, rifle/bow function and anatomy explicitly |
| 03:29–04:36, 05:54 | Soundtrack preservation and audio conditioning differ | Track voice playback separately from jaw/lip/timed animation; no lip-sync claim from muxing |
| 04:36, 08:04 | Last 17 frames passed across shots; hidden clothing continuity not guaranteed | Record source FPS/overlap; align pose/velocity without duplicating playback or assuming costume consistency |
| 05:30 | Native reference without aligned guide can drift in pose/timing | Validate event times against guide; still-image resemblance is not motion fidelity |
| 08:33 | VLM caption is editable; connected values can override UI | Audit actual input precedence and missing accessories before production |
| 09:14–10:24 | Dominant subject selection is imperfect; mask only for a concrete problem | Isolate target actor and compare masked/unmasked guides; watch hand/horn/coat seams |
| 10:59–11:25 | Functional details must be stated; non-human anatomy is harder | Describe palm/claw/weapon constraints; prove A-pose/Bull proportions rather than assume human transfer |
| 12:11–13:08 | RL direction unproven; change one variable/seed-controlled comparisons | Bounded baseline/candidate experiments; no new training pipeline required |
| 13:58 | Check actual commercial model license | Keep model/video/guide rights explicit before optional external generation/extraction |

## Usable path with the tools available

Inspect the current rig -> pick approved source performance or author a Blender action -> retarget in the target's rest frame -> author prop contacts -> prove all phases and transitions in Godot.
Optional video swaps may provide a visual target but cannot replace those stages. Tripo can supply checked rig/clips if the actual provider plan is needed and authorized. Build 3D Game Rooms contributes support/contact and production-camera checks. Game Development Studio can seal captures if installed and authorized; otherwise use the project's native capture/test tools.

This executor has Blender 4.3.2 and checksum-verified Godot 4.3. Bare game-dev/tripo CLIs and Xvfb were absent when inspected. No paid model/clip generation was run. Package-source refresh encountered a proxy denial; no Xvfb package was installed. These are observations of this executor, not claims those tools are absent on the owner's PC or in another session.
Current cloud policy is restricted; docs.google.com and OpenRouter/provider destinations are not in its observed custom list. Credential metadata reports unknown readiness. Never repeat the earlier mistake of interpreting a present key or an old successful cloud call as current network/API authorization.

## Deliverable boundary

The founder's latest message asks to build the necessary skills. This package documents and prepares motion work; it does not claim the characters were reanimated, grips repaired, model licenses verified, new clips rendered, or the game redeployed.
