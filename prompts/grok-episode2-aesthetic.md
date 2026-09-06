# Aesthetic-fidelity review: Episode 2 gold-mine runner art pipeline

## Context

Lil Blunt Adventure is a shipped 2D pixel-art Godot 4.3 web game. The founder
wants Episode 2 to look like three specific reference images: **hyper-realistic
cinematic 3D** — a green leafy cannabis character in a copper miner hard-hat
with a glowing headlamp, riding wooden minecarts (cannabis-leaf gold emblems)
and metal ziplines through a gold mine with glowing gold veins, wooden beams,
lanterns, sparks, volumetric lighting. Think Uncharted-mine-cart-chase look.
The references are Midjourney/Unreal-quality renders. "Cartoonish outputs are
rejected. Hyper-realism required."

The forced pipeline is Blender → GLB → Three.js/Godot. **But the build
environment has no Blender and no GPU**, and the game must web-export and boot
on itch.io + mobile browsers (so a real-time budget, not an offline render
budget).

## The actual questions

1. **Reality check on the aesthetic bar.** Can a web game that boots on mobile
   realistically reproduce that cinematic reference look in real time? Where is
   the honest ceiling, and what specific techniques close most of the gap
   (baked lighting, trim sheets, emissive gold veins, fog/volumetrics fakes,
   post FX) without a cinematic per-frame budget?
2. **Art direction that survives downscaling.** If true hyper-realism isn't
   web-real-time-feasible, what art direction *reads as* the references at a
   distance and in motion (a fast runner) — i.e. what does the eye actually
   need at 60fps in a minecart, vs. what's wasted detail?
3. **Character fidelity.** How to keep the exact character identity (leafy
   cannabis miner + copper headlamp + pickaxe) recognizable and on-model
   across a 3D rig with runner + shooter animations, given Episode 1's Lil
   Blunt is a 2D sprite (no existing 3D model)?
4. **Pipeline pragmatics.** Given no in-container Blender: is image-to-3D
   (e.g. TRELLIS-class tools) good enough for hero/prop assets, or is
   hand-modeling in Blender by a human unavoidable for the hero character?

## Constraints
- Be blunt about what is and isn't achievable; the founder has (rightly)
  rejected overpromises before.
- Keep answers concise and concrete — techniques and tradeoffs, not theory.

## Output format
Numbered answers 1–4, each ending in a one-line concrete recommendation.
