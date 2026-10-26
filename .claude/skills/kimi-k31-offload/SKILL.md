---
name: kimi-k31-offload
description: Run large, well-specified coding packets on Kimi K3.1 Pro (moonshotai/kimi-k3.1-pro on OpenRouter, 1M context) in parallel with the session - brief format, one worktree per packet, serialized Godot verification, review and integration, cost. Use when the founder asks to "give load to Kimi", run work in parallel, or offload a long implementation.
---

# Kimi K3.1 Pro offload

Kimi writes code; Claude owns the repo. A Kimi change is a proposal until Claude has read the diff, run the gates and committed it.

## Facts (checked 2026-10-27)
- Model `moonshotai/kimi-k3.1-pro`: 1,048,576-token context, up to 943k output, $2 / M in, $10 / M out, text + image + video in,
  supports `reasoning_effort`. Live price check: `node scripts/or-call.mjs ... --dry-run` or the public `/api/v1/models`.
- Key: `~/.config/gm-game/openrouter.key` (mode 600, created by the founder with `read -s`). `scripts/kimi-offload.sh` loads it
  into its own process only. Never print it, cat it into chat, or write it anywhere else.
- Runner: `scripts/kimi-offload.sh` -> `scripts/opus-offload.mjs` (whole files between `=== FILE: path ===` / `=== END FILE ===`,
  written only under `--allow`, the only command run is your `--verify`, every call logged to `.farm/offload-log.jsonl`).

## One packet
1. **Worktree per packet**, branched from the integration branch, so packets never write over each other or over the session:
   `git worktree add ../GM-GAME-kimi-<slug> -b kimi/<slug> <branch>`, then link `.godot-cache` and copy `.godot` (about 1 GB).
2. **Brief** in `design/ep2/kimi/<slug>.md` (commit it): the founder's words for the item, what exists (file + function names you
   checked), exactly what to build, which files it may write (`--allow`), the acceptance test to add or pass, and the house rules
   (Godot 4.3 GDScript, tabs, typed vars, doc comments, no new autoloads, no edits to front-page locked files, web export stays
   non-threaded). `@include` every file it must read; a missing path aborts before any spend.
3. **Verify** with the packet's own gate, serialized - the box has 7 GB of RAM and two Godot runs at once can OOM:
   `--verify "flock /tmp/gm-godot.lock timeout 400 .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/<gate>.tscn"`.
4. **Run in the background** (`run_in_background`), several packets at once; the API time overlaps, the Godot runs queue on the lock.
5. **Review**: read the whole diff (`git -C ../GM-GAME-kimi-<slug> diff`), reject anything outside the brief, rerun the gate yourself,
   then cherry-pick or copy the files into the integration branch and commit with the attribution line. Log the packet's cost.

## Choosing packets
- Good: a new module with a clear interface and its own test; a self-contained file (the Gatling post); a bug with a repro test.
- Bad: big edits to a file the session is also editing (merge pain); anything that needs the real renderer to judge; credentials.
- Packets that need a hook in a shared file (gold_town.gd): Kimi writes the module and a short hook note; the session adds the hook.

## Cost guard
Each round costs about (input tokens x $2 + output x $10) / 1M. Check `.farm/offload-log.jsonl` after each wave; tell the founder
the running total. Stop a packet after 3 failed rounds and take it back.
