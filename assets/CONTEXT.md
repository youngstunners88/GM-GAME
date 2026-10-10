# Assets Workspace (art, 3D, audio direction + manifests)

Where the LOOK and SOUND of the game are decided and tracked: manifests, reference intake, art/audio direction. The actual game
files live in `src/` (Godot loads only from there); this workspace holds the source-of-truth lists and the rules. Read this before
generating, importing or replacing any model, texture or sound. (Workspace pattern: founder's coach, "The Lesson 3.1" - one
CONTEXT.md per workspace, kept current by skill `context-md-upkeep`.)

## What lives here
- `audio-manifest.json` - every ElevenLabs SFX / voice id -> prompt -> file (`python3 scripts/generate_audio.py --force <ids>`;
  it also generates ANY missing id, so delete untracked strays after a run).
- `art-manifest.json`, `boss-voices.json`, `ep2-voice-bank.json`, `pixellab/`, `keyart/` (front-page key art is LOCKED).
- Founder references are NOT here: they go to `artifacts/episode2-gold-mine/references/founder_<date>/` (excluded from the web pack).

## Episode 2 art standard (the founder's, 2026-10-10: "the realism edge as a standard")
- Photoreal first-person shooter: Lil Blunt's green arm + glove + leaf bracer on HIS rifle (`winchester_1886_founder.glb` = the
  founder's Tripo "rifle 3d.glb"), Inferno Bull and the bears are the founder's Tripo models. Never a Meshy/primitive stand-in once
  he has sent his own.
- The GM logo: chain + green GM on dark enamel, flush, never a ring/bezel, never enlarged (skill `ep2-winchester-logo`).
- Every visual change is graded against his reference with numbers (`tools/ep2_forge/ref_metrics.py`), decided by Jev +
  microsoft-decision-1 on those numbers, and reviewed by Astra on the pictures (skill `ep2-set-piece-forge`).

## Pipelines (which tool for what)
| need | tool | skill |
|---|---|---|
| reference still / texture / keyed card | Muapi GPT Image 2 (`tools/ep2_forge/muapi_ref.py`, or `muapi` CLI) | `ep2-hyperreal-scene-pipeline` |
| image -> 3D | Tripo H3.1 / Meshy via Muapi (`tools/ep2_forge/muapi_3d.py`) | same |
| modular kit / clean-up / bake | headless Blender (`tools/ep2_blender/*`), `tools/ep2_forge/ai_prop_to_game.py` | `ep2-set-piece-forge` |
| founder's own GLB (Drive) | curl the Drive id, decimate, retarget broken Tripo rigs onto our skeletons | `ep2-founder-asset-swap` |
| SFX / voices / ambience | ElevenLabs (`scripts/generate_audio.py`, `elevenlabs` CLI) | `game-audio-forge`, `ep2-voice-barks` |

## Import rules (every new asset, same commit)
- `.glb.import`: `meshes/generate_lods=false`, `create_shadow_meshes=false`. Textures: `compress/mode=1` (lossy), mipmaps ON for
  anything tiled in 3-D. `git add -f` the `.import` files.
- Web pack gate 190 MiB (CI prints `index.pck = N MB`; 186 MB on 2026-10-10). Log additions in `docs/pck_budget_doc.md`.
