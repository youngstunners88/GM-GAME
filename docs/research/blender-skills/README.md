# Blender toolkit review and project installation

Reviewed upstream: https://github.com/EL4CTEO/blender-skills at
`71d031dab8bc6729504d11a78cbe91945401045f` (MIT, version 1.1.0).
All 148 tracked files were inventoried and read by the audit: 132 text/code files
and 16 presentation media files. `upstream-file-audit.json` records every path,
byte count, SHA-512, module functions and side-effect sites. Media are examples,
not evidence of GM-GAME quality. The audit includes the installers, plugin metadata,
shared helper, all 22 skill bodies/references, implementations, test fixtures and CI.

All 22 skills are installed as portable copies in both `.claude/skills/` and
`.agents/skills/`. No absolute symlinks, global home installation or overwrite of
existing project skills. Upstream's Bash installer removes a destination before
copying: every destination was checked absent first. Its broad “run scripts, do
not read scripts” guidance does not override the founder's requested code review.
The full clone is `/workspace/blender-skills`; runtime exports do not contain it.

## What was actually verified

- Skill validation: 22 valid; trigger routing: 25/25; shared helper consistency passed.
- Blender **5.2.2 LTS** suite: **47 passed, 0 failed, 3 GPU-dependent skipped**.
  Exact original log: `upstream-tests.log`. This is not a Godot acceptance test.
- The runner's `--blend`/factory-startup ordering was experimentally checked on
  Logan's saved source: the Armature remained present. No speculative fix applied.
- A real-asset defect escaped the upstream fixtures: `rig_check.py` stepped-sliced
  a Blender RNA collection and crashed above 2,000 vertices. The installed copies
  convert it to a list. Logan's 60,285 vertices now pass skin QA. Patch recorded in
  `installation.json`; upstream remains untouched.
- `run_checked.py` treats JSON `pass:false` or `ok:false` as failure. The upstream
  runner only forwards the process exit code, which is insufficient for QA scripts.
- `verify_install.py` checks both copies against the patched, pinned receipt.

## File-family findings and use decisions

| Upstream family | Useful for this task | Constraints found in code/references |
|---|---|---|
| core / shared `_bpyx` | runner, CLI argument/result protocol, bpy 5.x recipes | Set `BLENDER_EXE`; PATH finds this machine's older Blender first. Selection defaults can include unrelated objects. |
| scene-setup | inventory, paths, dimensions | Do not apply transforms blindly to an already bound skin; `--fix` mutates sources. |
| character-rigging | inspect weights/roots and stress poses | Existing 65-joint skin wins. Rigify fit only scales a metarig; it does not match joints. Proxy weights require deformation proof. |
| animation | slotted actions, baked engine clips | Baking may replace same-name actions, mute constraints and NLA tracks. Work on a copy and name clips explicitly. |
| facial-shapekeys | optional future expressions | ARKit scaffolding creates empty keys, not animated expressions. No automatic lip sync claim. |
| asset-qa | topology, contacts, ground, frame sheets | Parse `pass`, inspect warnings. `max_tris` skips expensive spatial tests above its limit. `weights_check.py` in prose is stale: use character-rigging/scripts/rig_check.py. |
| game-optimization | draw/texture budgets, mesh stats | `make_lods` can evaluate modifiers into a copied mesh. Never bake Logan's armature or lose skin/UVs to meet an arbitrary source-byte target. |
| export-pipelines | **godot** GLB preset, scale round trip | Generic `web` uses meshopt/WebP; quantization, Draco and KTX2 recipes are not Godot 4.3 safe defaults. Use plain GLB and actual engine import. |
| retopology-uv / sculpting | new static props only | Voxel/QuadriFlow/remesh and topology edits can discard UVs/weights/shape keys. Not used on supplied Logan. |
| hardsurface / geometry-nodes | timber dock, repeatable static construction | Apply only own modifiers, realize exported instances; GN runtime graph is not a Godot graph. |
| pbr-materials / texture-baking | colour-space discipline and portable Principled maps | Builders replace nodes; weather mutates shared materials. Data maps non-colour; albedo sRGB. Baking requires UVs and verified output. |
| lighting-lookdev / rendering | matching camera and light, CPU Cycles fallback | EEVEE/Workbench GPU checks skipped upstream; use actual Godot Compatibility captures for player acceptance. Turntable replaces its named collection. |
| time-of-day / weather-fx | measured atmosphere and low-cost engine adaptation | ENV cleanup replaces owned prefixes; don't collide with authored names. Blender volume/precipitation is not shipped as a huge animation/cache. |
| simulation | optional offline prop bake | No fluid simulation for this lake; avoid cache dependencies and experimental cloth on a bound character. |
| workflow-recipes | ordered production reference | Project task lock and game gates override generic recipes. |
| pipeline-automation | reproducible one-job processes, batch inventory | Batch returns per-file failures; check all records, don't trust a final exit alone. |
| addon-development + template | future tools only | No installation into Blender's user preferences; extension permissions and packaging are separate work. |
| install / tools / tests / CI / plugin metadata | installation and validation | Installers overwrite skill destinations. CI download example is not a substitute for verified official release checksums. Tests use small constructed assets. |
| docs assets / examples / comparison media | explanatory examples | Not copied into the web game; no claims that the videos prove Logan's motion. |

## Updating safely

Fetch to an external checkout, inspect the diff against the pinned commit, run the
suite on the pinned Blender, preserve the recorded patch until upstream fixes it,
and compare each installed file before replacement. Regenerate the receipt only
after reviewing changes. Never use `install.sh` over modified project directories.
MIT notice is preserved here in `LICENSE`.
