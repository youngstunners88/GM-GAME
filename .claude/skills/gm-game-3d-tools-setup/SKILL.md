---
name: gm-game-3d-tools-setup
description: The founder's "Setting up more 3D tools" doc (2026-10-24) - CLI-Anything (HKUDS) harnesses incl. FreeCAD, FreeCAD itself, CozyClay previs - what each is good for in GM Game, where they live, what is installed and what is blocked. TRIGGER on "FreeCAD", "CAD", "CLI-Anything", "cli-hub", "CozyClay", "previs", or the founder's tools doc.
---

# 3D tools from the founder's doc

| Tool | What it is | Use in GM Game | State (2026-10-24) |
|---|---|---|---|
| FreeCAD 1.1.4 | parametric CAD (freecadcmd headless) | exact parametric pieces (stairs, balustrades, shelving joinery) exported OBJ/STEP -> Blender kit; not for stylized art | The Downloads AppImage is **aarch64** (wrong arch). x86_64 AppImage downloaded to `~/tools/freecad/FreeCAD.AppImage` (+ .sha256) - verify checksum before use. |
| CLI-Anything FreeCAD harness | 258-command JSON CLI over freecadcmd | agent-driven CAD | **Installed 2026-10-25**: venv `~/tools/venv-freecad` (`pip install -e ~/tools/cli-anything/freecad/agent-harness`), `freecadcmd` (extracted AppImage, `~/tools/freecad/squashfs-root`) linked into `~/.local/bin`. Run `PATH=$HOME/.local/bin:$HOME/tools/venv-freecad/bin:$PATH cli-anything-freecad --json ...`; create with `document new --name X -o p.json` (no `-p`). STEP export works; STL export writes a valid file but the harness wrongly reports "invalid STEP"; GLB export does not work - go STEP/STL -> Blender -> GLB. |
| CozyClay (NomaDamas, AGPL) | browser previs: block a scene, pose cast, cut cameras, export frame/greybox clip/prompt to an AI video model | cutscene/film previs before paid Seedance/video takes | Not installed. `npx cozyclay` (Node 22.19+, have 26.8); MCP: `claude mcp add cozyclay -- npx -y cozyclay mcp` (founder's call - changes Claude config). Does NOT export character animation. |

Rules: the doc itself notes CAD automates parametric geometry, not the Western look - the town's look still comes from Blender kit pieces + textures. Runpod pods need account balance (create-pod 402 on 2026-10-24); no MUAPI/OPENROUTER keys were in the environment that session.
