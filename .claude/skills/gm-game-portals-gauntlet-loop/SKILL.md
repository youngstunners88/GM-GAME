---
name: gm-game-portals-gauntlet-loop
description: Closed loop that keeps Protocol Portals OPEN until Jev ships all three pits. TRIGGER before any portal task is called done, and after every capture.
---


# Gauntlet loop


Max 3 repair rounds per stage. Then stop and report. Do not infinite-spend.








Legality: FIXED is illegal if Jev ship == block OR any defect score ≥ 0.6.
Unrecorded vote = did not happen.
Unpushed branch = did not happen.
Export denied = stop that command class, use a new output dir, do not sit on "go".


Dispatchers (no hand-rolled curl):
- `node scripts/or-call.mjs <model> <prompt> [out] [--dry-run] [--image path]`
- `node scripts/jev.mjs ...`
- `node scripts/opus-offload.mjs ...` with `anthropic/claude-opus-5.5:batch` when possible


Briefs live in `prompts/portals/`. Dry-run first. Log spend in `portals/STATUS.md`.
