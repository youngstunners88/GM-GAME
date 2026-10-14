---
name: ep2-cloud-gpu-runpod
description: Use the founder's Runpod cloud GPU for the heavy Episode 2 asset work (Blender Cycles renders/bakes, AI 3D/image jobs, ComfyUI) instead of the CPU-only container. Pod facts, the exact setup + render commands from the founder's "GPU use" doc, cost rules, what is reachable from this container and what is not. TRIGGER on "cloud GPU", "Runpod", "render on the GPU", "bake", "Cycles", "OptiX", "pod", "need a GPU", a Blender render/bake that is too slow on CPU, or before starting/stopping/terminating any pod.
---

# Runpod cloud GPU (founder's doc "GPU use", 2026-10-14)

Source: the founder's Google Doc "GPU use" (a Perplexity chat, id `1PBgpWo2Lklh6nVw3__eon4jmZbNgkkTLJk-4CDt3MyI`) + Runpod's `agent-setup.md`
(plugin `runpod@runpod` is installed in Claude Code: skills `runpod:runpodctl`, `runpod:pod-deploy`, `runpod:pod-doctor`, `runpod:cost-audit`, ...; the hosted
MCP server needs the FOUNDER to sign in once: `/mcp` -> runpod -> Sign in with Runpod. OAuth cannot be done by the agent).

## What the doc says (all of it, condensed)
- The founder's own machine has no GPU. Cloud GPU = a **Runpod Pod**; the pod is Ubuntu, you drive it over SSH (Claude Code can run ON the pod).
- First purchase: **one RTX 4090 pod** (Blender/Cycles + general AI), 50-100 GB persistent volume at `/workspace`, PyTorch/CUDA template, SSH on.
  Step up to RTX 5090 / L40S only on VRAM limits. Billed per second, no ingress/egress fees.
- SSH: add the PUBLIC key (`~/.ssh/id_ed25519.pub`, never the `SHA256:` fingerprint) under Runpod -> Credentials -> SSH Public Keys. For `scp`/`rsync` use
  **SSH over exposed TCP** (the basic proxied SSH has no file transfer). `ssh runpod-gpu` via a `~/.ssh/config` Host entry (HostName = pod IP, Port = external port).
  `scp` takes `-P` (capital), `ssh` takes `-p`.
- Blender on the pod (headless, `-b`):
  ```
  apt update && apt install -y wget libx11-6 libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libxkbcommon0
  cd /workspace && wget https://download.blender.org/release/Blender4.5/blender-4.5.3-linux-x64.tar.xz
  tar -xf blender-4.5.3-linux-x64.tar.xz && mv blender-4.5.3-linux-x64 blender
  nvidia-smi && /workspace/blender/blender -b --version
  ```
- Render: `/workspace/blender/blender -b /workspace/x.blend --render-output /workspace/renders/frame_#### -F PNG -a -- --cycles-device OPTIX`
  (`OPTIX` on RTX cards, `CUDA` if OptiX is missing). Run long jobs inside `tmux` (detach `Ctrl+B D`) so an SSH drop does not kill them.
- Ask Claude Code on the pod for: render scripts with checkpoints, parallel camera variations, failed-frame reports, ComfyUI on port 8188.
- Cost rules: **stop** the pod when idle (container disk is LOST on stop, `/workspace` volume survives); **terminate** when finished (stopped storage still
  ~$0.20/GB/month); use a **network volume** to keep Blender, models and datasets across pods.

## Facts about THIS setup (checked 2026-10-14; keys by NAME only, never print values)
- Env has `RUNPOD_API` (REST key; `https://rest.runpod.io/v1/...` answers 200) and `RUNPOD_SSH_KEY`. Do not echo, log or commit either.
- The founder already has a pod: RUNNING, 1 GPU, `runpod/pytorch:1.4.0-cu1281-torch280-ubuntu2404`, 50 GB container disk, **no persistent volume**, $0.89/h,
  ports `22/tcp` + `8888/http`. A running pod bills until stopped - say so in every report and ask before leaving one on.
- From the agent's container, **raw TCP to the pod's SSH port is blocked** (proxy). `https://<podId>-8888.proxy.runpod.net` IS reachable (Jupyter). So
  the agent talks to a pod through Jupyter's HTTPS API (`tools/ep2_runpod/pod_run.py`), and the founder's own machine uses plain `ssh`/`scp`.
- No private SSH key lives in the container; the registered key belongs to the founder's laptop.

## Workflow
1. `python3 tools/ep2_runpod/pod_run.py status` - lists pods (id, state, $/h) from `RUNPOD_API`. Read-only.
2. Need a GPU job? Ship the input (a .blend / glb / script) with `pod_run.py put`, run with `pod_run.py exec "<cmd>"` (it wraps long jobs in `tmux`), fetch with
   `pod_run.py get`. First time on a pod: `pod_run.py setup-blender` (the doc's install block, idempotent).
3. Report: GPU used, minutes, $ (minutes x $/h), and whether the pod is still running. **Never create, restart, stop or terminate a pod without the
   founder's yes** (money + his data); a pod the founder started himself is his to stop unless he asks.
4. Use it for: Cycles bakes (high-poly Tripo -> 8-14k-face game mesh + 1K maps), turnaround renders for the reference-match loop, ComfyUI/diffusion jobs,
   anything over ~10 min on CPU. Do NOT use it for Godot captures (software GL in the container is fine) or for what Muapi/Tripo already sell per call.
5. The result still lands in the repo through the normal gates (pack budget < 190 MiB, `ep2-reference-match-loop`).
