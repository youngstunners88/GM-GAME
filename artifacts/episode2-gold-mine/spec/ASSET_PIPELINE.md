# Episode 2 — Asset Pipeline Decision Tree

Grounded in the founder-supplied research doc `spec/BLENDER_MCP_SETUP.md`
(a compass_artifact research brief) + this session's verified container facts.

## The hard fact that shapes everything

The popular community **`ahujasid/blender-mcp`** addon **requires Blender's
interactive GUI event loop** (it schedules onto the main thread via
`bpy.app.timers` and depends on the N-panel "Start MCP Server" operator). **It
will NOT run under headless `blender -b`.** (Research doc §Key Findings #2,
corroborated by the addon source + the Nous/Hermes practitioner note.)

This session's container has **no Blender, no GPU, no display** (verified:
`which blender` empty, `/dev/dri` absent, `nvidia-smi` missing). So this
container cannot drive blender-mcp **by any method** — not even Xvfb, because
GPU Cycles still needs a real GPU. The blocker is hardware + display, not
configuration.

## The four real paths (pick per fidelity + who runs Blender)

| Path | What it is | Runs where | Fidelity ceiling | Cost/effort |
|---|---|---|---|---|
| **A. Local GPU desktop** (research doc's "only reliable path today") | Founder runs Blender 4.5 LTS + community addon on their own RTX/Apple-Silicon machine; agent connects over `BLENDER_HOST`/`BLENDER_PORT` on a trusted LAN | Founder's machine | Highest (Cycles) | Founder time; trusted-network only (socket has no auth) |
| **B. Cloud GPU VM + virtual desktop** | RunPod/Paperspace RTX VM running Blender GUI under Xvfb or VNC/KASM | Cloud | Highest (Cycles) | Hourly GPU $$$; setup |
| **C. Official Blender-Lab MCP server** | Anthropic+Blender official connector, **supports background mode** (synchronous-only), Blender **5.1+** | A host with Blender 5.1+ | High | Newer; still needs Blender+GPU host, but headless-capable |
| **D. External generators → GLB** (no MCP at all) | Meshy / Tripo / Rodin(Hyper3D) / Hunyuan3D generate hero + props, export GLB; import to engine directly | Web services | Prototype→near-production; hero rigs still need human cleanup | Meshy ~$20/mo; per-asset |

## Recommendation (for founder sign-off)

- **Hero character (Lil Blunt 3D):** needs a human Blender pass regardless
  (both aesthetic review + this doc agree image-to-3D drifts off-model for a
  rigged hero). → Path A or B, or D+human-cleanup.
- **Props (minecart, beams, rails, lanterns, rocks):** Path D (generate →
  GLB → import) is the fast pragmatic route; blender-mcp assembly optional.
- **This agent's role:** own the **runtime integration** (the runner↔chamber
  loop, controls, camera, protocol logic, GLB import + placement, gates,
  web-export) — all of which is doable here with **zero Blender dependency**
  using engine primitives now and real GLBs when they arrive.

## Consequence for build order

Because none of the runtime/gameplay integration needs Blender, the correct
first build is a **graybox vertical slice in engine primitives** (see
`00_ARCHITECTURE.md` §7a). Assets drop in later via any path above without
reworking the loop. Grayboxing now de-risks the *gameplay* before any GPU
hour or Blender session is spent.
