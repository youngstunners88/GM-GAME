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

## FreeCAD -> game, proven (2026-10-25, founder's CAD pass)
- Pipeline: a `freecadcmd` script builds real solids (Part revolve/extrude/loft, fillets, chamfers, cuts) grouped by (piece, kit material) and
  tessellates each group to one OBJ with per-shape deflection (heroes fine, crowds coarse); a Blender script imports the OBJs, assigns the
  armory_kit material by name, welds seams, smooths by angle and exports one GLB (one root per piece). `freecadcmd` swallows unknown `--flags`:
  pass options as env vars (`GATLING_CAD_OUT`, `SMELTER_CAD_OUT`). Examples: `tools/ep2_cad/gatling_cad.py` + `tools/ep2_blender/build_gatling_cad.py`,
  `tools/ep2_cad/smelter_kit_cad.py` + `tools/ep2_blender/build_smelter_kit.py`; profile renders `tools/ep2_blender/review_kit.py`.
- Draw side profiles as (y, z) outlines and CHECK them in a side render before the engine: the first CAD Colt's grip came out as a sliver with
  the backstrap floating behind it (coordinate order mix-up), only a profile render showed it.
- Instanced pieces (rounds, chain links) need coarse tessellation (~400-450 tris); a default fine pass made one cartridge 2,000 tris.
- **Colour trap**: armory_kit writes colours as if sRGB but glTF stores baseColorFactor LINEAR, so in Godot every kit colour shows about a stop
  brighter. Approved rooms (Armory, yard Gatling) keep the bright look; a room with an sRGB palette (the hideout) dresses kit pieces with
  `Ep2Pbr.dress(root, extra, [], true)` (kit_tone = shown colour converted back). Symptom: blued steel reads silver, walnut reads ivory.
- Photo-scanned sets differ in what their ORM carries: only `Ep2Pbr.METAL_MAPS` sets have a real metal channel; `UNIFORM_ROUGH` overrides a
  scan whose roughness reads wrong (painted iron 0.42 = wet paint). Measure a set's channel means before trusting it
  (`magick orm.jpg -separate -format "%[fx:mean] " info:`).
