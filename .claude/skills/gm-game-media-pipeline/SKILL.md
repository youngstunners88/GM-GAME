---
name: gm-game-media-pipeline
description: Generate all portal assets — MuAPI for 2D imagery (scorecard plates, examiner portraits, room backdrops, ladder glow sprites), Meshy MCP for 3D scorecard NFTs, headless Blender for cleanup. TRIGGER when any portal/NFT asset needs to be created, remeshed, or re-exported.
---

# Media Pipeline — MuAPI (2D) + Meshy MCP (3D) + Blender (cleanup)

## 0. Keys
- `MESHY_API_KEY` and `MUAPI_API_KEY` are ALREADY SET in the environment /
  client settings. Read them from the environment. NEVER ask the founder to
  paste a key into chat. NEVER commit keys. If a key is missing, stop and
  report which env var is absent — do not improvise.

## 1. MuAPI — 2D imagery
Install once (skills registry):
```
npx skills add SamurAIGPT/Generative-Media-Skills --all
# or a single skill:
npx skills add SamurAIGPT/Generative-Media-Skills --skill muapi-media-generation
npx skills add SamurAIGPT/Generative-Media-Skills --list
```
Docs: https://muapi.ai/docs/agent-skills#next-steps
Deliverables:
- Scorecard front plate per protocol: official protocol logo + grade +
  protocol colors, clean front-facing 2D (this feeds Meshy, so no text the
  model must extrude — keep the plate graphic-dominant, grade as flat overlay).
- Examiner portraits: Ember the Archivist, The Assay Trio, The Claim Recorder.
- Room backdrop plates: Reading Ring (neon green), Pressure Study (cyan
  facet), Claim Office (gold lantern).
- Ladder glow sprite sheet (pulsing emissive frames, readable at gameplay zoom).
Naming: `assets/portals/<protocol>_<asset>.png`. Creative prompt drafting may
be delegated to the muse lane; keep official logo usage faithful (Jev gate
`nft_matches_protocol`).

## 2. Meshy — 3D scorecard NFTs
MCP server: https://github.com/meshy-dev/meshy-mcp-server
API docs: https://docs.meshy.ai/en/api
Transport: HTTP -> https://mcp.meshy.ai/mcp  (env MESHY_API_KEY)
Configure in Claude Code:
```
claude mcp add --transport http meshy https://mcp.meshy.ai/mcp
```
Flow per scorecard (meshy-7):
1. `meshy_image_to_3d` from the clean 2D plate (step 1.1).
2. Remesh to 15k-30k tris.
3. Download GLB.
NEVER import raw meshes into the runtime — cleanup first.

## 3. Blender — headless cleanup
```
blender --background --python tools/nft/cleanup_scorecard.py
```
Script must: origin to center, consistent up-axis, decimate, apply scale,
export `portal_smoke.glb`, `portal_diamonds.glb`, `portal_gold.glb`.
Output lands in the NFT metadata pipeline (see gm-game-icp-scorecard-nft).

## 4. Presentation rule
Y-spin 0.4-0.7 rad/s ONLY in web viewers (smokegame.win, Smoke Lounge, claim
page). NEVER in the 2D stage camera.

## 5. Fallbacks
TRELLIS.2 only if Meshy fails Jev. Hyper3D last resort. A fallback asset must
still pass the Jev gates — fallback is never a reason to lower the bar.

## 6. Cost discipline
Media generation is stateful and expensive: dry-run prompts via the
delegation charter lanes where possible, batch independent generations, and
record spend per asset in `portals/STATUS.md`.
