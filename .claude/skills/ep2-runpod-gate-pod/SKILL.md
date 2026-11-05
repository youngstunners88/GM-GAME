---
name: ep2-runpod-gate-pod
description: Run GM-GAME's Godot 4.3 headless gates, CI block and real-renderer captures on a Runpod pod instead of the small laptop - when to fire one up, the price and stock reads, the SSH-key trap, gate_pod.sh, the idle guard, teardown. TRIGGER on "fire up Runpod", "make this job more fluid", "run the gates on the pod", a full --import or the Episode 2 test block being too slow locally, or a capture pass over several chambers. For Blender bakes and AI 3D jobs use ep2-cloud-gpu-runpod instead.
---

# Gates and captures on a pod

The founder's laptop has 7 GB of RAM and a 920MX. One full `--import` plus the Episode 2 gates swamps it. The repo is public, so a pod
clones it directly, holds no secrets, and only runs things. **Commits and pushes stay on the laptop.**

## Fire up
1. Follow the Runpod plugin: load `runpod:runpod-mcp`, then `runpod:pod-deploy`. A founder's "fire up Runpod" is the go; quote the $/h from
   the read in the same message. Read `list-pods` first: `2ctovlhajlrsxm` and `xw8jpdvnvbkwr2` are not ours, never touch them.
2. Stock moves between read and create (2026-11-04: RTX 4090 sold out on create, A40 went to NONE seconds later). Godot needs CPU far more
   than GPU, so take the cheapest class with stock and at least 8 vCPU. An RTX 3070 Community at $0.13/h gave 18 vCPU and 20 GB.
3. Create with image `runpod/pytorch:1.4.0-cu1281-torch280-ubuntu2404`, ports `22/tcp`, `/workspace` persistent 50 GB,
   `NVIDIA_DRIVER_CAPABILITIES=all`, `gpu.minCudaVersion` 12.8.
4. **Record the pod id in project memory at once**, marked OURS and "terminate when done". A session can die while it bills.

## The SSH trap
`~/documents` carries a passphrase, so it cannot be used unattended, and `startSsh` only injects the account's keys. Generate a dedicated key
(`~/.ssh/gm_pod_ed25519`, no passphrase) and pass it as `env.PUBLIC_KEY` on create. `update-pod` with `env` restarts the container and **the
direct SSH port changes**, so re-read `get-pod` and update the `gm-pod` Host entry in `~/.ssh/config`. The proxy `ssh.runpod.io` only takes
account keys and has no scp or rsync; use `ssh.direct`.

## Use
```bash
tools/ep2_runpod/gate_pod.sh setup <git-ref>                    # clone, apt, pinned 4.3, idle guard, import (run once)
tools/ep2_runpod/gate_pod.sh test ep2_river_cover ep2_lake_trail # sends your working tree, runs in parallel, prints PASS/FAIL counts
tools/ep2_runpod/gate_pod.sh ci                                 # CI's whole headless block (scripts/ci-gates-local.sh)
tools/ep2_runpod/gate_pod.sh shot tools/ep2_shots/x.tscn out/    # Compatibility + opengl3 under xvfb, like the web build
tools/ep2_runpod/gate_pod.sh import                             # after a new class_name or asset: runs the editor pass twice
NOSYNC=1 tools/ep2_runpod/gate_pod.sh test ...                  # leave the pod's tree alone (a clean baseline run)
```
- A new `class_name` is invisible until `import` has run: "not declared in the current scope" means re-import, not a code bug.
- A shot scene must take `out=<dir>` in its user args and write PNGs there, as the scenes in `tools/ep2_shots/` do.
- Captures use `gl_compatibility` because the web build does. Forward+ on the pod's real GPU proves nothing about the player's view.
- A test that hits a SCRIPT ERROR does not quit: Godot sits until the 320 s timeout, so a suite that "hangs" is usually a script error. Read its log.
- The pod is not the gate: push and read the CI run. The local pause tap-target difference may also show here.

## Money
`idle_guard.sh` stops the pod after 45 minutes with no `gate_pod.sh` call and no Godot running. Stop keeps `/workspace` and bills its
disk. **When the job is done, terminate with `delete-pod`, read `get-pod` to confirm it is gone**, delete the `gm-pod` Host entry, and
update the memory note. Report minutes and dollars from a billing read, and say so plainly if a pod is still running.
