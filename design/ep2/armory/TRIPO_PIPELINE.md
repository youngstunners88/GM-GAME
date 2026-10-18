# Tripo pipeline — Rich + Utah (Episode 2 Armory bodies)

status: prepared 2026-10-17. Tripo CLI is the agreed path for the armory character
bodies, updating the Meshy-only note in `RICH_DEPARTMENT_SPEC.md` §8. Reference art
stays the match target (`ep2-reference-match-loop`); Tripo supplies geometry + rig.

## Environment (verified)

- `tripo-cli@0.7.0` installed globally (Node v26.8.2).
- Signed in as profile **`default`**, region **`ov`** (`tripo whoami`).
- `tripo doctor`: node, api key, config permissions (0600) and api reachability all pass.
- **Blocker:** account balance is **0 credits** (`tripo balance`). Run **`tripo topup`**
  once, then the commands below run. `--dry-run` is free and already validated the chain.

## Validated chain

`--for game-pc --then "texture,rig" -p rig_type=biped` plans:

1. `image-to-model` (Rich) / `text-to-model` (Utah) — model `v3.1`, PBR, detailed texture
2. `texture` — model `v3.0`
3. `rig` — model `v2.5`, **biped**
4. deliverables: **FBX + GLTF**

`--dry-run --json` reports `valid: true` for both inputs with no upload, no submit, no credits.

## Rich — his existing 2D art

```bash
cd /home/kofibeatz/GM-GAME
tripo make src/assets/portals/companions/rich_the_claim_recorder.png \
  --for game-pc --then "texture,rig" -p rig_type=biped \
  -o tripo-out/rich --name rich --yes
```

## Utah — text (a leaner silhouette + palette distinct from Rich's duster)

```bash
tripo make "Full-body game character: Utah, a lean weathered 1800s American frontier \
river trader and gunsmith's partner, mid-30s, sun-darkened skin, short dark hair under a \
flat-brim hat, rolled shirt sleeves, leather vest, canvas trousers, boots; distinct earthy \
teal-and-rust palette to read instantly at a river bank; neutral A-pose, even lighting, \
isolated on plain background" \
  --for game-pc --then "texture,rig" -p rig_type=biped \
  -o tripo-out/utah --name utah --yes
```

## After generation

- `tripo anim check` for riggability; `tripo mesh retopology` / `decimate` toward the
  ~30–40k target in `RICH_DEPARTMENT_SPEC.md` §8.
- Shrink textures + contact sheet (spec §8), grade against the references, then integrate
  as `Ep2TownFolk` behind the counter (height ~1.78).
- Land under `src/episode2/assets/` and prove it with gameplay-camera captures before it
  counts as done.

## Notes

- `tripo mcp` exposes make/task/balance/history over stdio if an MCP-driven workflow is wanted.
- Keep `tripo-out/` out of the pack (working output only).
