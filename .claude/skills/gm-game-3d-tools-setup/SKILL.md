---
name: gm-game-3d-tools-setup
description: The founder's "Setting up more 3D tools" doc (2026-10-24) - CLI-Anything (HKUDS) harnesses incl. FreeCAD, FreeCAD itself, CozyClay previs - what each is good for in GM Game, where they live, what is installed and what is blocked. TRIGGER on "FreeCAD", "CAD", "CLI-Anything", "cli-hub", "CozyClay", "previs", or the founder's tools doc.
---

# 3D tools from the founder's doc

| Tool | What it is | Use in GM Game | State (2026-10-24) |
|---|---|---|---|
| FreeCAD 1.1.4 | parametric CAD (freecadcmd headless) | exact parametric pieces (stairs, balustrades, shelving joinery) exported OBJ/STEP -> Blender kit; not for stylized art | The Downloads AppImage is **aarch64** (wrong arch). x86_64 AppImage downloaded to `~/tools/freecad/FreeCAD.AppImage` (+ .sha256) - verify checksum before use. |
| CLI-Anything FreeCAD harness | 258-command JSON CLI over freecadcmd | agent-driven CAD | Cloned (sparse) to `~/tools/cli-anything`; `pip install -e freecad/agent-harness` into `.venv` was **blocked by the auto-mode classifier** - founder can run `! cd ~/tools/cli-anything && python3 -m venv .venv && .venv/bin/pip install -e freecad/agent-harness`. Needs `freecadcmd` on PATH (extract the AppImage). |
| CozyClay (NomaDamas, AGPL) | browser previs: block a scene, pose cast, cut cameras, export frame/greybox clip/prompt to an AI video model | cutscene/film previs before paid Seedance/video takes | Not installed. `npx cozyclay` (Node 22.19+, have 26.8); MCP: `claude mcp add cozyclay -- npx -y cozyclay mcp` (founder's call - changes Claude config). Does NOT export character animation. |

Rules: the doc itself notes CAD automates parametric geometry, not the Western look - the town's look still comes from Blender kit pieces + textures. Runpod pods need account balance (create-pod 402 on 2026-10-24); no MUAPI/OPENROUTER keys were in the environment that session.
