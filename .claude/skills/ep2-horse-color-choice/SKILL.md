---
name: ep2-horse-color-choice
description: Stable horses must come in the colours the founder specified (white, brown, black, mixed), each its own selectable horse, and the player picks the one he wants. Use for Dude's stable yard, any horse spawn or shop, and Episode 1 shared horse visuals leaking brown only. TRIGGER on "horses are all brown", "variation of colors", "only one horse can be selected", "Lil Blunt should be able to choose", "stable horses".
argument-hint: "audit | fix | proof"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Horses: real colour variety and a real choice

Founder 2026-11-15: "The horses at Dude are still all brown instead of the variation of colors I stated they should be and only one horse can be selected. Lil Blunt should be able to choose what he likes."
"Still" = the last attempt was never seen on screen. Prove it in a render.

Files: `src/episode2/chamber/ep2_stable_yard.gd` (`HORSES` spawn table ~L26-34 holds positions only, no colours; `build()`, horse actor setup ~L139+, `horse_bought`, `RIDE_MOUNT`, `MOUNT_SECONDS`), `src/level/stable_horses.gd` (Ep1 shared visuals; check for a brown-only material leaking in), `assets/stable-yard-assets.json`.

## Steps
1. **Find the colour source.** Which material/texture does each horse instance use? A shared `Material` resource (one instance for every horse) is the usual reason all are brown: set per-instance override materials or duplicate the material per horse. A baked brown albedo needs a tint/palette, not a recolour of the shared resource.
2. **Define the palette in data**: add a colour/coat field per horse entry (white, brown, black, plus a mixed/pinto if the founder listed one: check `PROMPT`/founder notes in `ep2-founder-intake` before inventing). Keep spawn positions unchanged.
3. **Free-fix first** (`ep2-build-logic` section 5): a per-instance albedo tint or a palette-swapped texture. No Tripo/Runpod credits until a tint cannot do it. White and black must stay readable (no flat blown white, no black crush): tune roughness/shading, check under the stable lighting.
4. **Selection**: each horse is its own target. Aim/near + prompt selects that horse (`horse_bought` carries which). Paying for horse N mounts horse N, not the first in the array. Show name or colour in the prompt. The player can change his mind before paying.
5. **Mount immediately after paying** (`ep2-npc-conversation-flow` rule 3).
6. Keep Episode 1 horses as they are unless the founder asked; verify no change (`feedback-no-unrequested-visual-changes`).

## Proof
- Real-renderer screenshot of the yard showing the colours side by side, plus one each of each horse mounted.
- Test: spawn all horses, assert each has a distinct material instance and the expected coat value; assert that buying index k emits `horse_bought` for k and mounts k.
- Pack margin: no new asset in the main pack (`scripts/pack-gate-fresh.sh`).
