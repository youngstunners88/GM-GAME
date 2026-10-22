# Lil Blunt weapon grip and recovered bow — 2026-10-17

Base inspected: `70e90a9f71a3dbdb444f88385bd0b238e3752fb4`. Work branch: `codex/lil-blunt-weapon-grips-20261017`.

## What changed

The Remington retains the existing gold revolver and its separate ownership/ammo. Its replacement olive leather glove has a 19-joint skin, a trigger squeeze driven on the game clock, a smaller leather cuff, and a palm moved behind the actual walnut backstrap. Hip and ADS eye distances keep the hand visible instead of pushing it below the screen.

An archer corpse now records its actual bow separately from its remaining quiver. Searching it awards the recovered bow and finite arrows once. Generic arrow-only corpses do not award a bow. Slot 3 / D-pad up and the existing touch/controller armory choose it. A tap starts the visible 0.7-second draw; the release event spends one arrow and produces bow audio with no firearm flash/report. Switching, sprinting, opening the armory, loss of player control and checkpoint restore cancel an unfinished draw without spending it. Bow and arrows survive saves, room handoffs and existing checkpoints. Flying player arrows start at the actual nock, follow a gravity trajectory, sweep for the first bear/tree, and are removed on hit, ground, expiry or retry.

Bears and the player share an authored longbow with a continuous stave and draw morph, independent string/nock and a detailed shaft/head/feather arrow. Bear contacts were moved outside the torso after an actual capture exposed that the old inside-body frame could score zero contact error while remaining invisible.

## Tools and spending

Tripo CLI 0.7.0 installed; device authorization, region ov and API reachability verified. The authorized API balance is zero, so no paid generation/rig/retarget was submitted: **0 credits spent**. The supplied Drive/local gun image was inspected. Existing Flow access was verified with Nano Banana 2.1 selected; no new Flow image was needed for this reference. Geometry, finger rig and bow deformation were authored locally in headless Blender 5.2.1. The user's standing authority for available-credit spending, retries, release and Obsidian logging is recorded in `.agents/skills/lil-blunt-weapon-art/SKILL.md` and the personal installed skill.

## Evidence and checks

- Pinned Godot 4.3 Compatibility renders from the actual mine-lift player camera at 1280x720: hip, ADS, trigger start/recoil/recovery, bow nocked/half/full draw/release and the three-slot armory. These use explicit development-only ownership fixtures, not a player-visible free-weapon path.
- `09_bear_visible_draw.png`: isolated shipping bear rig and shared bow. The final pose is visibly outside the body; independent skinned paw test maximum is 0.0000 m in aim/shot at two headings. The seated-book check remains 0.0076 m at the rotated heading.
- `tests/ep2_bow_test.tscn`: arrow-only vs archer recovery, once-only claim, no spend before release, no double trigger/release, interrupted draw, JSON save round trip, checkpoint cancellation, separate draw hand/nock/arrow, limb morph, release visibility and imported 19-joint glove.
- Full existing local CI headless suite passed via `scripts/ci-gates-local.sh`. That script documents and tolerates only the three pause-menu tap-target differences reproduced on unchanged master. The shipping pipeline reruns its required gates on the final committed tree.
- Real nonthreaded Web export: **199180256 bytes** (limit **199229440 bytes**), no SCRIPT ERROR or Parse Error. A fresh-clone pack check is additionally required by the shipping script; the warm result alone is not the release acceptance.
- Both local and project skill metadata validate. Workflow YAML parses and `git diff --check` passes.
- Renderer material/RID teardown warnings also occur in the captured unchanged baseline; they are not presented as a new clean shutdown or silently fixed here.
- Jev/Microsoft opinions are not gameplay proof; no verdict is claimed without configured credentials and an actual response.

## Reproduce

```bash
blender -b --python tools/ep2_blender/build_remington_hand.py
blender -b --python tools/ep2_blender/build_bow_hands.py
blender -b --python tools/ep2_blender/build_bear_bow.py
python tools/ep2_blender/share_weapon_textures.py
.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --editor --quit
.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_bow_test.tscn
.godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-method gl_compatibility res://tools/ep2_shots/weapon_grip_shot.tscn -- out=/tmp/weapon-proof
```

The glove maps use existing lossy import settings, one shared olive map, and no unused first-person distance LODs. Keep those import sidecars when rebuilding. Runtime admission remains subject to full shipping checks and actual CI/butler/public BUILD verification; source publication alone is not a deployment receipt.

## Deployment receipt

Source `a13b767c7804befd5cff2e815b6b80d1e677c1ea` shipped through [CI run 39026261056](https://github.com/youngstunners88/GM-GAME/actions/runs/39026261056), all weapon gates and butler deployment successful. Actual upload log: `Pushed to https://youngstunners88.itch.io/smokerealm` at 10:56:32 UTC. Public browser boot and visible read-only overlay confirmed **BUILD 2026-10-17-a13b767**. CI artifact PCK: **199181600 B**. The existing Episode 2 access-code prompt is still enabled; no protected public playthrough is claimed. Changed gameplay was verified using the local real-camera fixtures and CI/native tests. Exact structured evidence: `release-receipt.json`. Decision-provider credentials were not configured, so no external model verdict is claimed.
