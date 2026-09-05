# Getting Blender Running for the "Lil Blunt" GLB Pipeline: A Practical Blender-MCP Setup Guide

## TL;DR
- **Install Blender 4.5 LTS on your own GPU-equipped desktop, run the ahujasid/blender-mcp addon inside the interactive Blender window, register the server with Claude Code via `claude mcp add blender uvx blender-mcp`, and point Claude Code at that machine — that is the only reliable path today.** The community blender-mcp addon requires Blender's interactive GUI event loop and will NOT run under a pure headless `blender -b` process, so a display-less sandbox/container cannot drive it directly.
- If Claude Code lives in a remote/cloud dev box, either (a) run blender-mcp on your local GUI machine and let Claude connect over the network via `BLENDER_HOST`/`BLENDER_PORT`, or (b) spin up a cloud GPU VM running a full virtual desktop (Xvfb or VNC/KASM) so Blender's GUI stays alive without a monitor. GPU Cycles rendering works fine under Xvfb.
- For "hyper-realistic" results, do not rely on Blender-MCP building meshes from scratch — pair it with its built-in Poly Haven (CC0 assets/HDRIs), Sketchfab, and Hyper3D Rodin / Hunyuan3D generators, or generate assets externally in Meshy/Tripo/Rodin and import the GLB. Blender-MCP is best at scene assembly, materials, lighting, and export, not photoreal hero-asset modeling.

## Key Findings

**1. What blender-mcp is.** It is a two-part, third-party (explicitly "not made by Blender") integration by Siddharth Ahuja that connects Blender to any MCP-capable LLM client (Claude Desktop, Claude Code, Cursor, VS Code, etc.). The two components are: (a) `addon.py`, a Blender addon that opens a JSON-over-TCP socket server inside Blender on port 9876; and (b) `blender-mcp`, a Python MCP server (run via `uvx blender-mcp`) that your client launches and which relays commands into that socket. It is one of the most popular MCP projects — 26.8k GitHub stars per star-history.com's tracker ("ahujasid/blender-mcp · Community plugin to control Blender 3D with any LLM of your choice · Python MIT · 26.8k"), globally ranked #1457.

**2. It requires the interactive Blender GUI.** The addon schedules command execution onto Blender's main thread via `bpy.app.timers.register(...)`, and its workflow depends on the N-panel "Start MCP Server" operator. It cannot run under `blender -b` background mode. This is the single most important constraint for an AI-agent pipeline.

**3. An official alternative now exists.** As of April 28, 2026, Anthropic and the Blender Foundation shipped an official Blender MCP connector (Blender Lab's `blender_mcp`), part of "Claude for Creative Work." Anthropic's own announcement states: "The Blender developers have created an MCP connector, which is now officially available for Claude." The paired add-on is distributed from blender.org/lab/mcp-server/, and Anthropic joined the Blender Development Fund as a Corporate Patron (reported at a minimum of €240,000/year). This official server supports background mode (with a synchronous-only limitation) but requires Blender 5.1+.

**4. Current Blender version.** Per Blender's official release-notes page, Blender 5.2 LTS is the "current stable release - July 14, 2026," and Blender 4.5 LTS was released July 15, 2025 and is "supported until July 2027." Latest patches were both released August 25, 2026 (5.2.1 and 4.5.13). The community addon needs Blender 3.0+; the official Lab server needs 5.1+.

**5. Hyper-realism comes from assets + Cycles, not from AI meshing.** Blender-MCP's real value for realism is orchestrating Poly Haven/Sketchfab/Hyper3D/Hunyuan3D assets and setting up Cycles materials/lighting, then exporting GLB.

## Details

### How blender-mcp works (architecture and capabilities)
The dataflow is: **MCP client ⇄ (stdio/MCP) ⇄ blender-mcp server ⇄ (TCP socket, port 9876) ⇄ Blender addon**. Commands are JSON objects with a `type` and optional `params`; responses carry a `status` plus a `result` or `message`. `BLENDER_HOST` (default `localhost`) and `BLENDER_PORT` (default `9876`) configure where the server sends commands, and the same values must be set inside Blender's addon so both agree — this is also how you point the server at a Blender instance on another machine.

`claude mcp add blender uvx blender-mcp` writes an entry to Claude Code's MCP config telling the Claude host to launch `uvx blender-mcp` as a stdio MCP server named "blender." The client spawns its own server instance — you should NOT also run `uvx blender-mcp` manually in a terminal, because two instances fighting over the socket is the most common cause of connection failures.

Exposed capabilities include: two-way communication; object creation/modification/deletion; material and color control; scene inspection (scene graph, object details); viewport screenshots so the model can "see" what it built; and `execute_blender_code` to run arbitrary Python (`bpy`) inside Blender — powerful but a security risk (the server runs LLM-generated code with no sandbox, so isolating it, ideally in a VM, matters). Integrations that help achieve realism fast: **Poly Haven** (CC0 HDRIs, textures, models via API), **Sketchfab** (search/import), **Poly Pizza** (per Poly Pizza's homepage, "Build something beautiful with 10,600+ free models," including the rescued Google Poly archive — 2,294 models under the "Poly by Google" creator page), and AI generators **Hyper3D Rodin** and **Hunyuan3D** (Tencent). Asset/generation service keys (Sketchfab, Hyper3D, Hunyuan3D) are stored in the addon preferences or injected as env vars (e.g. `BLENDERMCP_HYPER3D_API_KEY`). Hyper3D ships a shared free-trial key with a small daily limit; get your own from hyper3d.ai / fal.ai for production.

### Installation requirements (all platforms)
Prerequisites: **Blender 3.0+**, **Python 3.10+**, and **uv** (install via the official installer — `brew install uv` on macOS, the `astral.sh` PowerShell script on Windows, the `astral.sh` shell script on Linux — NOT `pip install uv`, which may not create the `uvx` command clients need).

Steps:
1. Install uv.
2. Register the server with your client. Claude Code: `claude mcp add blender uvx blender-mcp`. Claude Desktop: add `{"mcpServers":{"blender":{"command":"uvx","args":["blender-mcp"]}}}` to `claude_desktop_config.json`. On Windows, GUI-launched clients often can't find `uvx` (spawn ENOENT) because they don't inherit your terminal PATH — wrap it as `"command":"cmd","args":["/c","uvx","blender-mcp"]` or use the full path to `uvx.exe`.
3. `uvx blender-mcp install-addon` (or download `addon.py` and install manually), then in Blender enable **Interface: MCP for Blender** under Edit → Preferences → Add-ons.
4. In Blender's 3D viewport press **N**, open the **MCP for Blender** tab, click **Start MCP Server**. Blender must stay open with this running before any tool call works — the missing "Start" step accounts for most "it connects but nothing happens" reports.

Blender itself is a desktop GUI app. Official system requirements: minimum a 4-core CPU with SSE 4.2, 8 GB RAM, and a GPU with OpenGL 4.3 / at least 2 GB VRAM; recommended an 8-core CPU, 32 GB RAM, and 8 GB+ VRAM. For **Cycles** (the ray-traced, photoreal engine) you need a supported GPU: NVIDIA (CUDA/OptiX; Blender 4.5 supports GeForce 400-series and newer, OptiX needs driver 535+), AMD (HIP, GCN 4th-gen+), Intel (oneAPI), or Apple Silicon (Metal). Note Blender 4.5 was the last release with an official Intel-macOS build. For realistic scenes, more VRAM is safer (running out forces slow system-memory fallback); RTX 40/50-series cards (e.g., the 4090's 24 GB, the 5090's 32 GB) are the current top Cycles performers.

### Headless / cloud / server rendering — the crux for an AI agent
Because the community addon needs the GUI event loop, a display-less container (typical for a cloud coding agent) cannot run it directly. There are three practical resolutions:

- **A. Run Blender on a machine with a real display (recommended).** Put Blender + addon on your local GPU desktop and let the agent connect. If Claude Code runs locally too, everything is `localhost:9876`. If Claude Code is remote, set `BLENDER_HOST` to your machine's reachable IP and `BLENDER_PORT`, and enable "Listen on all interfaces (0.0.0.0)" in the addon panel — but ONLY on a trusted network, since the socket has no authentication.

- **B. Cloud GPU VM with a virtual desktop.** On a headless Linux GPU VM, run Blender's full GUI under a virtual X display — `xvfb-run blender` (Xvfb) or a VNC/remote-desktop session (e.g., RunPod's KASM/Ubuntu-desktop template, or TurboVNC + VirtualGL). This keeps the GUI event loop and the N-panel operator alive with no monitor attached. Practitioner integration docs (Nous Research's Hermes skill) confirm the ahujasid addon "refuses to start under `blender -b`" and that the fix is `xvfb-run blender`, and that "GPU rendering works fine under Xvfb." GPU compute (CUDA/OptiX) itself needs no display at all; only Blender's OpenGL viewport needs the virtual display. Cloud options range from RunPod (RTX 4090 desktop templates at low hourly rates) to Paperspace/Vast.ai/Lambda; there are also managed "cloud computer" services (e.g., Vagon) that run Blender + Claude Desktop + the MCP server together on one cloud machine.

- **C. Use a fork/alternative that is genuinely headless.** If true headless automation is the goal, other projects launch Blender as a `blender --background --python` subprocess: `djeada/blender-mcp-server` and `sandraschi/blender-mcp` (FastMCP, spawns headless Blender automatically), plus the **official Blender Lab server** (background mode, "requires requests to complete synchronously and rejects deferred results," Blender 5.1+). These are different codebases from ahujasid's addon.

For pure batch rendering (no interactive agent needed), the classic CLI is `blender -b scene.blend -E CYCLES -o //output -f 1 -- --cycles-device OPTIX` (or `CUDA`). EEVEE does not render reliably headless without a display; Cycles does.

### Alternative / complementary AI 3D generation
For hyper-realistic hero assets faster than manual modeling, external text-to-3D / image-to-3D generators are the pragmatic route, all exporting GLB for Three.js/Godot:
- **Meshy** — most consistently usable output and best PBR textures; exports FBX/GLB/OBJ/USDZ/BLEND; auto-rigging + motion library; native Blender/Unity/Unreal plugins. Pricing (checked August 2026, meshy.ai/pricing): $20/month Pro (or $16/month annual / $240 billed annually), including 1,000 credits/month, unlimited downloads, private asset ownership and API access.
- **Tripo** — fastest generation, strong stylized look and image-to-3D iteration; GLB/FBX/OBJ.
- **Rodin / Hyper3D (Gen-2)** — highest geometric fidelity, best for hard-surface/mechanical objects (e.g., mine carts); integrated into blender-mcp.
- **CSM Cube 2** — best game-ready retopology out of the box.
- **Luma Genie, Kaedim, Sloyd** — additional options; Kaedim is art-directed/managed, Sloyd is parametric props.

Most AI-generated assets still need cleanup (retopology, UV, PBR channel checks) before production. A sensible hybrid: generate/import realistic assets (Meshy/Rodin/Poly Haven), then use Blender-MCP to assemble the scene, fix materials, light with Cycles, and export.

### GLB → Three.js / Godot export
glTF 2.0 (GLB binary) is the recommended interchange for both engines. In Blender: File → Export → glTF 2.0 (.glb). For **Godot 4.3+**, use Format: Binary (.glb); enable +Y Up (Godot is Y-up); Apply Modifiers; export UVs/Normals/Tangents; for animated rigs use the NLA-strip workflow and export deform bones only. Godot 4 imports GLB natively and also supports direct `.blend` import. For **Three.js**, load GLB with `GLTFLoader`; GLB packs geometry, materials, textures, and animation clips into one file and imports natively.

### Known bugs, limitations, and pitfalls
- **Must click "Start MCP Server"** — installing/enabling the addon is not enough.
- **Don't run `uvx blender-mcp` in a terminal** while the client also launches it — port conflict. (Confirmed in the ahujasid README workflow: press N → open the MCP for Blender tab → click Start MCP Server; "Do not run the uvx command in the terminal.")
- **PATH / spawn ENOENT** on GUI-launched clients — use the full `uvx` path or the `cmd /c` wrapper (Windows); fully quit and relaunch the client (Cmd+Q / system-tray quit) after config changes.
- **uv picking the wrong Python** (conda/pyenv/asdf) can break install — pin with `--python 3.11` and `UV_PYTHON_PREFERENCE=only-managed`, or `uv cache clean blender-mcp && uvx --refresh blender-mcp`.
- **Timeouts on complex scenes** — break requests into small sequential steps.
- **Poly Haven behavior is erratic**; Poly Pizza downloads can hit a Cloudflare bot challenge. Per the ahujasid README verbatim: "static.poly.pizza is behind bot protection and blocks datacenter, VPN and cloud IPs. Your API key is fine — the CDN never sees it. Retry from a normal connection, or download the .glb by hand and use File → Import → glTF 2.0." (This is especially relevant if your Blender runs on a cloud VM.)
- **Security** — `execute_blender_code` runs arbitrary LLM-generated Python with no guardrails; isolate in a VM and save often (tool calls can mass-delete).
- **Only one MCP server instance / one Blender addon** should hold the socket at a time.

## Recommendations

**Stage 1 — Get it working locally first (do this now).** On the user's own GPU desktop (Windows/macOS/Linux) with an NVIDIA RTX (or Apple Silicon) card: install Blender 4.5 LTS, install uv (official installer), run `uvx blender-mcp install-addon`, enable the addon, press N → Start MCP Server. Register with Claude Code: `claude mcp add blender uvx blender-mcp`. Verify with `/mcp` in Claude Code and a trivial prompt ("create a red cube on a gray floor with a sun lamp"). This is the fastest way to prove the pipeline before adding complexity. **Benchmark to proceed:** Claude Code lists the blender tools and a test cube appears in Blender.

**Stage 2 — Bridge the agent.** If Claude Code runs in a remote/cloud dev environment, keep Blender on the local GUI machine and connect over the network (`BLENDER_HOST`/`BLENDER_PORT`, "listen on all interfaces" on a trusted LAN/VPN only). If you need everything in the cloud, provision a single GPU VM (RunPod RTX 4090 desktop/KASM template, or Paperspace) running a VNC desktop, install Blender + addon + Claude there, and treat it as a local setup — remembering the Poly Pizza/Cloudflare caveat for datacenter IPs. **Threshold to move to the cloud VM:** your local GPU has <8 GB VRAM or Cycles renders are too slow for iteration.

**Stage 3 — Maximize realism.** Enable Poly Haven (CC0) and Hyper3D Rodin in the addon; get personal Hyper3D/Sketchfab keys. For hero assets (mine carts, character rig), generate in Meshy or Rodin Gen-2, import the GLB, then use Blender-MCP to place, scale, retopo-check, assign Cycles PBR materials, and light. Export GLB with the Godot/Three.js settings above. **Threshold:** if AI-meshed geometry is too dense or messy, run CSM Cube 2 or Blender's retopology tools before export.

**Stage 4 — Consider the official connector.** If you can move to Blender 5.1+/5.2 LTS, evaluate the official Blender Lab MCP connector (via Claude's Connectors directory / blender.org/lab/mcp-server/), which supports background mode and is maintained by Blender's own developers — potentially more robust for an automated agent than the community addon. **Threshold:** adopt it if headless/background operation becomes a hard requirement and the community addon's GUI dependency is blocking you.

## Caveats
- The community ahujasid/blender-mcp addon's GUI requirement is the central constraint; any "run it in a headless container" plan must use Xvfb/VNC to keep a GUI alive, or switch to a background-capable fork/the official server.
- The "addon refuses to start under `blender -b`" and "GPU rendering works fine under Xvfb" statements come from a practitioner integration doc (Nous Research's Hermes skill), corroborated by the addon's source code (`bpy.app.timers` main-thread scheduling) and the ahujasid README's GUI-driven workflow — treat as high-confidence but not vendor-certified. (A 2020 Blender devtalk thread confirms headless CUDA rendering and GPU detection under VNC/VirtualGL, with the caveat that you may need to explicitly set the device in your Python script for `-b` runs.)
- Cloud GPU pricing and provider reliability change fast, and some providers reclaim spot instances; verify current rates and terms before committing.
- AI 3D generators produce prototype-to-near-production quality; hero characters and animated rigs generally still need human cleanup. "Hyper-realistic" is achievable but is a function of asset quality + Cycles setup + render budget, not a one-prompt result.
- Running arbitrary LLM-generated Python in Blender is a genuine security risk; isolate the environment.