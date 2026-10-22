---
name: scenario-blender
description: Paid AI generation inside Blender via the Scenario extension (3D, PBR materials, HDRIs, images/video) plus its local MCP server for agents. TRIGGER on "scenario", "AI material", "PBR", "generate a 3D model", "AI HDRI/environment", or when Poly Haven + procedural Blender is not enough and the founder approves spend.
---
# Why (founder 2026-10-16)

Scenario for Blender (`scenario-labs/blender-plugin`, GPL-3.0, Blender 5.0+) puts
image / video / 3D / PBR-material / audio / 360-environment generation in the
viewport, with a local MCP server (`scenario-blender` at `127.0.0.1:9876/mcp`) and
a headless entry (`blender --background scene.blend --command scenario_blender`).
The plugin is free; GENERATIONS COST Creative Units on a Scenario account (API key +
secret). Nothing here runs without funded credits — that is the whole gate.

# Rules

1. **Money first.** No key/secret in chat, scripts, or commits (env credentials
   only). Check CU balance + the per-job estimate BEFORE Generate; record spend per
   asset in the commit. Free Poly Haven (skill pattern in `goldmine_train` README)
   stays the default — Scenario is the escalation, never the first try.
2. **Best-fit lanes for this game:** Materials (PBR hide/wood/metal sets for the
   horse, stable, revolver leather, bow limbs), Environment (360 HDRIs beyond the
   Poly Haven set), 3D (hard-surface props: trough, rails, firearms). Character/animal
   generation goes to `assetfurnace-pipeline` first (free, rigged); Scenario 3D is
   the backup when AssetFurnace's shape fails twice.
3. **MCP discipline:** local `scenario-blender` may read the scene and request paid
   work; arbitrary Python execution stays OPT-IN off. Treat the bearer token as a
   secret. Every agent-requested generation states cost first.
4. **License check per asset:** generated media inherits Scenario's terms — record
   them in `src/assets/models/<asset>/` next to the file (same provenance rule as
   AssetFurnace). Commercial-use clearance is verified per asset, never assumed.
5. **Headless use:** the repo's Blender work is headless (`blender --background
   --python`); Scenario headless goes through its own `--command scenario_blender`
   entry, NOT by driving the viewport GUI. GUI walkthroughs in their docs do not
   apply to agent sessions — translate to the MCP/headless call.

# Gate

- Estimate shown + approved before each paid generation; spend logged.
- Result vs prompt: side-by-side in commit; in-game capture before "done".
- No credentials in the repo (sentinel scans for them — `game-security-sentinel`).
