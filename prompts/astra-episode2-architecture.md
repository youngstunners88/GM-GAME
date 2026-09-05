# Architecture review: Episode 2 "Gold Mine Runner + Protocol Chambers"

## What the project is

Lil Blunt Adventure is a shipped **2D pixel-art platformer in Godot 4.3**,
web-exported to itch.io (non-threaded HTML5), with a working CI + export +
security pipeline. The founder now wants **Episode 2** to be a **3D,
hyper-realistic over-the-shoulder minecart RUNNER** through a gold mine,
interleaved with **full 3D shooter/RPG "chambers"** that dramatize real DeFi
protocol mechanics (mining, staking, auctions, etc.). Reference art is
Unreal-quality cinematic 3D renders.

The founder's spec forces this pipeline: **Blender** (asset source of truth)
→ **blender-mcp** (agent drives Blender) → clean **GLB** → **Three.js**
runtime (or Godot 4.3) → polish. Aesthetic Law: "hyper-realistic, matches the
reference images exactly, cartoonish outputs rejected."

## The hard constraints you must reason within

1. **The build/agent environment has no Blender and no GPU** (`which blender`
   empty, `/dev/dri` absent). blender-mcp bridges to a live Blender process
   that doesn't exist there. So the forced Blender step cannot run in the
   agent's container. The founder can potentially provide a Blender+GPU host,
   or model locally and hand over GLBs.
2. The existing game, CI, web-export, and all tooling are **Godot 4.3**.
   Godot 4.3 has a competent 3D renderer and already web-exports.
3. Three.js is a clean-slate 3D web path but means a **second engine**
   alongside the shipped Godot game (two runtimes, two toolchains, two
   export/deploy paths).
4. This is a real-money-adjacent crypto project; protocol numbers are fixed
   by a white paper and already encoded as constants in the Godot codebase.

## The actual questions (answer each concisely, most important first)

1. **Engine decision: Three.js vs Godot 4.3 3D for Episode 2.** Given the
   shipped game + CI + economy code are all already Godot, but the founder
   named Three.js first and wants hyper-real 3D — which is the sounder call,
   and what's the decisive factor? Consider: reusing the existing
   `goldmine_system.gd` economy + game-state + mobile-input, one vs two
   deploy pipelines, GLB support (both load GLB), and the realistic ceiling
   on "hyper-real" in a web build that must boot on itch.io/mobile.
2. **The runner↔chamber mode switch.** Best architecture for a seamless
   "riding the track → enter chamber → 3D shooter/RPG → exit → resume track"
   loop in the chosen engine? Single scene with mode states, or separate
   scenes with shared player state? What are the failure modes?
3. **The hyper-real expectation gap.** The reference images are AI concept
   renders. Be blunt: is "matches the references exactly" achievable as
   real-time web-game assets at all, and if not, what is the honest,
   achievable fidelity ceiling for a Godot/Three.js web build that still
   boots on mobile? How should this be framed to the founder?
4. **Phasing.** Given one session already produced the folder scaffold, 6
   chamber design docs, and this architecture doc — what is the correct next
   milestone that produces something *playable and honest* fastest, without
   depending on the blocked Blender pipeline?

## Hard constraints on your answer
- Do not assume Blender is available to the agent. Do not hand-wave the
  2-engine cost. Do not claim hyper-real web assets are trivial.
- Keep each answer a few sentences. This is a decision aid, not an essay.

## Output format
Numbered answers 1–4, each with a clear recommendation + the one deciding
factor. End with a single "if I had to pick the next 1 week of work" line.
