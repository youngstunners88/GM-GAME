---
name: ep2-founder-fix-pack-1027
description: The founder's 2026-10-27 Episode 2 fix pack (collisions, locked story order, draw and blood, Dude's ranch and horse path, town life and audio, consequences, Sheriff James, Renegade, Jack Hammer, Gatling and Tabs). Use when working any item of that pack, dispatching it to Kimi K3.1 Pro, or checking its definition of done.
---

# Episode 2 founder fix pack (2026-10-27)

The brief is `docs/founder-feedback/2026-10-27_fix_pack.md`. Read it first; this skill is how to work it.

## Order of work
1. P0 collisions and transitions, then the locked story order, then draw and blood. These gate everything else.
2. P1 Dude's ranch, town life and audio, consequences.
3. P2 characters and assets, Gatling and Tabs, audio polish.

Ship each P0 slice on its own (`scripts/ship-to-master.sh`) so the founder can hard-refresh it. Do not batch the whole pack into one ship.

## Dispatch to Kimi K3.1 Pro
- Model: `moonshotai/kimi-k3.1-pro` through `scripts/or-call.mjs` (1M context; the brief plus the files it touches fit).
- Write a self-contained brief per slice: the item text from the fix-pack doc, the files to read, the acceptance check. Kimi writes
  the change; Claude reviews the diff, runs the gates and owns the commit. Never accept an unreviewed change into master.
- Needs `OPENROUTER_API_KEY` in the environment. If it is missing, stop and ask the founder to set it; do not look for it in files.

## Working rules
- Add or extend a gate in `tests/` for each item (CI runs them). A gate that passes on the wrong code is a bug: check it fails first.
- Visual items (Dude, bar, Gatling, blood) need before/after captures on the real renderer (`tools/ep2_shots/*.tscn`, opengl3).
- Anything large or a new model goes through `ep2-expert-delegation` and the streamed extras rule (`ep2-streamed-extras-web`).
- The pack is at its size gate; check `scripts/check-ep2-extras-pack.sh` and the fresh-import margin before any ship.
- Runpod: only for GPU work (Hunyuan/SDXL-class character passes). Create the pod, do the job, terminate it. Never touch
  `2ctovlhajlrsxm` or `xw8jpdvnvbkwr2`. Stop before spend risk and tell the founder.

## Definition of done
Use the checklist at the end of the brief. Claim FIXED only after the founder's hard refresh proves the named beat.
