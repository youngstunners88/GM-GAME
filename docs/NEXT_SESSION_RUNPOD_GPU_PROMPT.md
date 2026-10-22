# Prompt for the next Claude Code session (paste everything below the line)

---

You are continuing work on GM-GAME (Lil Blunt, Godot 4.3, Episode 2). Read `CLAUDE.md` and
`.claude/context-manifests/default.md` first, then `.claude/skills/ep2-cloud-gpu-runpod/SKILL.md` and
`.claude/skills/runpod-signin/SKILL.md`. Do not load the whole repo.

## Goal
Use the founder's Runpod cloud GPU to raise the **visual quality** of Episode 2. His machine has no GPU
(Omarchy laptop, 8 GB RAM, GeForce 920MX). The source is his Google Doc "GPU use"
(id `1PBgpWo2Lklh6nVw3__eon4jmZbNgkkTLJk-4CDt3MyI`, already condensed into `ep2-cloud-gpu-runpod`).

## State at hand-off (verified 2026-10-15, local machine)
- Repo: `master` = `origin/master`, includes `e6033db`. Tree clean. A 605 MB zip of the old damaged tree is at
  `~/gm-game-backup-2026-10-15/` (safe to delete once the founder is happy).
- Runpod MCP: the plugin `runpod@runpod` is installed, but its OAuth sign-in **cannot work from the desktop app**
  (`redirect_uri is not allowed`). A working server named **`runpod-key`** (API key, read-only) was added with
  `claude mcp add ... runpod-key`. Check: `claude mcp list | grep runpod-key` -> Connected. If this session
  was started AFTER that, its tools are `mcp__runpod-key__*`. Ignore `plugin:runpod:runpod` ("Needs authentication").
- The founder's pod: **average_coffee_vole**, id `xw8jpdvnvbkwr2`, 1x RTX 4090, Secure Cloud EUR-IS-1,
  50 GB container disk, **no persistent volume**, **$0.89/h**, status **EXITED** (only disk billed).
  Stopping loses container disk, so Blender must be reinstalled on every restart unless a network volume is used.
- SSH key on this laptop: private `~/documents`, public `~/documents.pub` (ed25519, comment `runpod`).
  `~/.ssh` does not exist. It is NOT confirmed that the public key was pasted into Runpod -> Settings -> SSH keys.
  Use `ssh -i ~/documents ...` and `scp -i ~/documents -P <port>`. Never print the key.
- This laptop has NO `RUNPOD_API` / other keys in its environment (those were in the cloud container).
  `tools/ep2_runpod/pod_run.py` needs `RUNPOD_API`; prefer the `runpod-key` MCP tools, or plain `ssh`/`scp`
  from this laptop (raw TCP to the pod is only blocked from the cloud container, not from here).

## Hard rules (money and safety)
1. **Never start, restart, create, stop or terminate a pod without the founder's explicit yes in chat**,
   after telling him: GPU, $/h, expected minutes, expected cost, and what happens to the disk.
2. Report GPU, minutes and $ after every job, and say whether the pod is still running. Stop it when idle.
3. Never print, log, commit or echo any key. Never read the key out of `~/.claude.json`.
4. Do not touch the founder-locked front-page files (see CLAUDE.md). Spell it "Runpod".
5. Pack budget is tight: 189.2 MiB of 190. Any new asset needs a trim (`ep2-asset-forge`, `decimate_textured.py`).
6. Visual work is proven with `ep2-reference-match-loop` (screen vs his target on one board) and scored with
   Jev numbers (`jev-decision-gate`), not by eye. Jev is text-only. Astra grades pictures.
7. Ship through `scripts/ship-to-master.sh` only after gates pass; say "live" only after CI + butler proof.

## What to do, in order
1. **Confirm connectivity (read-only):** list pods through `runpod-key`. Confirm the SSH public key is registered
   (ask the founder to confirm in the Runpod console; do not assume).
2. **Pick the jobs worth a GPU** from `STATUS.md` (current weak spots, with honest scores):
   - Inferno Bull is "still trash": head/arm fixed, soft Tripo sculpt not at reference. Higher-detail regenerate + Cycles bake.
   - Woods forest: Astra 4/10 (canopy cards planar, light too even). Needs an irregular layered canopy, trunk relief bakes.
   - Mine lift: Astra 4/10 (narrow, even brown light). Needs lantern pools, rust, wider cavern.
   - Cycles bakes of high-poly Tripo/Meshy to 8-14k-face game meshes with 1K maps; turnaround renders for the match loop.
   Ask the founder which one first. Recommend Bull, since he called it out most.
3. **Cost-gate:** present the estimate, wait for yes, THEN start the pod. Prefer a small **network volume**
   (about $0.07/GB/month; 50 GB is a few dollars a month) so Blender 4.5.3 and models survive stops.
4. **Pod bring-up** (the doc's block, idempotent): install deps, download Blender 4.5.3 to `/workspace/blender`,
   `nvidia-smi`, `blender -b --version`, render with `-- --cycles-device OPTIX` (fallback CUDA), long jobs in `tmux`.
5. **Run the job, pull the result, stop the pod**, then integrate through the normal gates.
6. Update `STATUS.md` (short), commit, push, ship. Add what you learned to `ep2-cloud-gpu-runpod`.

## Known traps (already paid for)
- Desktop-app OAuth to Runpod fails permanently; use the API-key route in `runpod-signin`.
- A server added mid-session is invisible to that session's tools; use a fresh process or restart.
- Driving the `claude` CLI by tmux keystrokes is blocked by the auto-mode classifier; do not try.
- `git pull` here is configured to rebase; use `git merge --ff-only origin/master`.
- `gdparse` is syntax-only; the security sentinel scans `git ls-files` (see the manifests).
- Previously the working tree had ~2,600 zero-byte files (an interrupted operation on 2026-10-10); if you see
  zero-byte tracked files, `git checkout -- <path>` restores them; check `git status` before building.

## Report format
Short. Founder tokens are limited. End with one line recommending which Claude model to use next (CLAUDE.md MODEL-ADVICE RULE).
