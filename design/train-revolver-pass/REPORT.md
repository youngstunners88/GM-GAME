# Train and revolver asset pass — 2026-10-15

Status: **candidate assets generated; stopped at upstream release gate**.
Base: origin/master 26667644 (includes founder intake fcf6b735). No master push,
CI deployment or live capture is claimed for this pass.

## Release blocker

The export workflow for intake fcf6b735 failed at **Portal room gameplay and
rendered visibility**, with `PORTAL ROOMS: FAILURES 36`. Job logs report missing
portal textures, including `res://src/assets/portals/fixtures/gold.png` and
`res://src/assets/portals/companions/rich_the_claim_recorder.png`.

- Run: https://github.com/youngstunners88/GM-GAME/actions/runs/38741331206
- Job: 116443497361
- Observed using the actual GitHub API/logs, not inferred from commit messages.

Founder rule: "If a gate blocks you, stop and report — don't improvise around
it." The portal gate was not disabled or modified. Shipping stopped before
Godot import/compile, local web export, Stage 3 firing captures and deployment.
These checks remain **unrun** for the candidate, not passed or waived.

## Train

Blender 5.2.2 was downloaded from download.blender.org and checked against its
official SHA-256 manifest. The supplied 5.2 file cannot open in Blender 4.3.
`tools/ep2_blender/train_fidelity_pass.py` updates only the train model, its GLB,
and the alternate render. Successful headless render/export reports 15,300
triangles and 287 mesh objects. HDRI packed successfully. Open window frames,
funnel flare/lip, individual pilot slats, spoked wheels, offset crank/coupling
rods, tender coal and lettering replace the coarse components.

The main 1024/512/256 photoreal sprites and all distant_train code, riders,
span and parallax values are byte-for-byte unchanged. The model is still a
low-poly approximation, not a photographic reconstruction. Track and tender
remain part of the model. Godot GLB import is not verified yet.

## Revolver

Four large hand-card derivations retain the founder's brown glove, brass-studded
bracer, green vine arm and cylinder emblem. They are **assets only**; no HUD,
pickup, film or first-person runtime flow was changed. The 56x31 sprite now uses
a fresh +X render of the existing standalone Blender Remington (no hand and no
mirrored emblem), cropped proportionally to preserve its real grip. That 3D gun
has a grip emblem rather than the intake hand image's cylinder emblem; the
sources are not claimed identical. No hidden grip was painted into founder art.

The founder explicitly approved keeping 56x31 with the 14px minimum applying
only to larger cards/close-ups. Their measured glyph heights are 48.06, 24.03,
42.76 and 41.10 px. The shallow 0.12 hold angle and 78% hip anchor are unchanged.
Runtime head clearance and firing still require the Stage 3 capture/test.

The starter cutout had 925 visible near-white pixels (including matte and
enclosed background). The re-cut removes outside-connected neutral background
and enclosed white backdrop inside the trigger guard, then uses a 1px inset and
interior edge colours without blur. The final one-pixel visible rim has **zero
near-white pixels** (all RGB channels >230); see the reproducible receipt.

Fringe screenshots show the full cutout and 200% details of barrel, cylinder
rim and cuff against both required backgrounds:

- `design/train-revolver-pass/fringe_goldrush.png`
- `design/train-revolver-pass/fringe_near_black.png`
- `design/train-revolver-pass/revolver-derivation-receipt.json`

## Resume

Resolve the upstream portal gate through the owning session, fetch/merge master,
then run pinned Godot 4.3 import/compile, the Stage 3 revolver and affected stage
gates, train loop/rider verification and real captures. Check nonthreaded web
export against 190 MiB (new upstream source art/HDRI may need a deliberate
development-resource export policy). Run title lock and staged security gate.
Use ship-to-master.sh, prove successful CI/butler upload and public BUILD before
claiming the pass live. No locked front-page, portal, bow or Bull files changed.
