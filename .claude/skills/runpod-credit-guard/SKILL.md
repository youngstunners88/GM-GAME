---
name: runpod-credit-guard
description: Use Runpod GPUs heavily for a build without running the founder's credits out - pod creation rules, the in-pod credit guard (runtime cap + balance floor), spend checks, stop vs terminate, which pods are ours. Use whenever a Runpod pod is created, started or left running, or the founder says "smash Runpod", "spend credits" or "turn it off before we run out".
---

# Runpod credit guard (founder 2026-10-27)

Founder: "smash runpod for this next build ... if you know that we are going to die from credits then turn off runpod just before
that happens". Heavy use is approved; running dry is not. Pair with `ep2-cloud-gpu-runpod` (access), `ep2-runpod-motion-lab` and
`tools/ep2_runpod/hunyuan/` (jobs).

## What we can see
- The Runpod MCP (`mcp__runpod-key__*`) works. `get-organization` is 403 on this account, so there is NO balance read from here.
  `list-billing` (hour/day buckets) gives spend. Never read a Runpod key out of `~/.claude.json` or any file.
- Inside a pod, `RUNPOD_API_KEY` and `RUNPOD_POD_ID` are injected and `runpodctl` is installed: the pod can stop itself and may read
  the balance (GraphQL `myself { clientBalance currentSpendPerHr }`). `tools/ep2_runpod/credit_guard.sh` does both.

## Rules
1. Before creating: read stock (`list-gpu-types` with availability), state the hourly price, pick the cheapest GPU that fits (A40
   48 GB at about $0.40-0.59/h for Hunyuan/SDXL/text-to-motion; a 4090 when a model needs speed, not VRAM).
2. Create with a `/workspace` volume (results survive a stop), `PUBLIC_KEY` = `~/documents.pub` (SSH; the account's registered
   "horse-job" key is not on this box), and a `JUPYTER_PASSWORD` you generate and keep in `~/.config/gm-game/pod_jupyter.pw` (600)
   for `tools/ep2_runpod/pod_run.py` (`POD_JUPYTER_PASSWORD`).
3. First command on every new or restarted pod: copy `credit_guard.sh` to `/workspace` and start it
   (`nohup bash /workspace/credit_guard.sh <max_hours> <min_balance_usd> &`). Default 3 h, $3. Check `credit_guard.log` says
   whether the balance is readable; if it is not, the runtime cap is the only automatic brake - check `list-billing` every hour.
4. Stop when a job ends (GPU billing stops; the volume bills at the stopped rate). Terminate when the build no longer needs it.
   Read the pod back after every stop or terminate.
5. Only pods this conversation created are ours. `2ctovlhajlrsxm` (gm-town-motion-b) and `xw8jpdvnvbkwr2` (average_coffee_vole)
   belong to earlier work: never start, stop or delete them without the founder naming them.
6. Report to the founder: pod id, GPU, $/h, hours run, `list-billing` total for the build.
