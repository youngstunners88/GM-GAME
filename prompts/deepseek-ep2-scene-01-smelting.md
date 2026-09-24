# Episode 2 scene foundation — 01_smelting_facility

You are authoring the **foundation scene kit** for the First Chamber of Episode 2
of *Lil Blunt Adventure*: the **Smelting Facility**, where Lil Blunt meets
**Inferno Bull** and is handed a Winchester 1886.

Runtime is **Godot 4.3**. You own the FOUNDATION (scene spec, aesthetic lock,
Godot blockout notes). A later high-fidelity pass will raise it to production
meshes and materials — your job is to make sure that pass does not invent from
zero, and cannot drift off the founder's art.

## IMPORTANT — this scene is ALREADY BUILT and playable

This is not a greenfield brief. A working Godot blockout of this chamber shipped
on 2026-09-12: you can walk to the Bull, he speaks, he hands over the rifle, you
shoot a rack of casting molds, he falls in as companion. The full implementation
is inlined below.

So your deliverables must do three things, in this order of value:

1. **Lock the aesthetic** against the founder's reference images (attached) so a
   later fidelity pass has law to follow, not taste.
2. **Reconcile with what actually exists** — read the implementation and say
   where the built scene already agrees with the references and where it
   drifts. Be specific and cite the code (dimensions, positions, colours).
3. **Specify the foundation properly** for the parts that are still placeholder.

Do NOT propose rewriting the beat sheet, the economy behaviour, or the session
interface. Those are settled and tested.

## Attached images (the only source of art-direction truth)

1. `inferno_bull_smelting.jpeg` — **the exact staging for this scene.** Bull
   seated among molten gold, whiskey in hand, cigar lit, pour-crucibles behind.
2. `inferno_bull_armed.jpeg` — the combat/companion look: Winchester,
   bandoliers, red bandana, horned hard-hat, flame-lensed aviators.
3. `inferno_bull_whiskey.jpeg` — the relaxed look: overalls, pickaxe, whiskey.
4. `ep2_runner_ref_3_minecart_ride.jpg` — the wider mine's material language
   (rock, timber, brass, gold, lantern light) that this room must belong to.

## Hard constraints you must not violate

- **Godot 4.3.** The web build runs the **Compatibility** backend: no volumetric
  fog, no SSR/SSAO/SDFGI, and a metallic surface with **no reflection source
  renders near-black**. Do not specify any of those. Metallic must stay modest
  and metals carry through albedo + roughness + a little emission.
- **This chamber mints nothing.** No GOLD, no staking, no claim. It is a story
  set-piece; the economy starts at Fort Knox. Do not add a mechanic.
- **No live enemies here** — the design deliberately saves the rifle's first
  real use for the approach to Fort Knox.
- Lil Blunt = small green leafy miner. Inferno Bull = massive black bull miner.
  Both are currently PLACEHOLDER primitive silhouettes.
- Aesthetic is hyper-real gold mine + Wild West industrial weight. Not cartoon,
  not clean sci-fi, not generic fantasy dungeon.

## Deliverables — output EXACTLY these four sections, in this order

Use these literal headings so the output can be split into files mechanically.

### ===== FILE: SCENE_SPEC.md =====
- One-paragraph mood.
- Approximate dimensions in **metres** (state them as numbers; the built room is
  22 m wide x 30 m long x 10 m high — say whether that is right and why).
- Zones: entry, playable, interaction, exit — with metre coordinates on the same
  axis convention as the code (player enters at z = -8, Bull sits at z = +6,
  exit at z = +15).
- Key props, **named and counted**.
- Lighting: practical sources + mood, with intent per source.
- Camera and player start. The built scene pushes the camera in for the
  conversation and pulls back for the shooting — say whether that framing is
  right and give better numbers if not.
- Movement bounds.
- Companion anchor (the Bull) and where he sits in the composition.

### ===== FILE: AESTHETIC_LOCK.md =====
- Palette as a table: surface, hex, metallic, roughness, emission. Ground every
  row in the attached images.
- Surface language: wet rock, iron, timber, gold dust, heat.
- Which reference image each decision came from.
- **What is explicitly OUT of style** — be concrete, this is the most useful
  part of the file for a later pass.

### ===== FILE: GODOT_NOTES.md =====
- Suggested node hierarchy for the blockout, as a tree.
- Collision intent (what needs a body, what is decoration).
- Audio hook points, named against these existing VARCO stem sections:
  `ep2_smelt_furnace_roar_loop_01`, `ep2_smelt_heat_haze_loop_01`,
  `ep2_smelt_pour_oneshot_01`, `ep2_smelt_whiskey_pour_01`,
  `ep2_smelt_cigar_draw_01`, `ep2_smelt_leather_chain_01`,
  `ep2_smelt_workers_distant_loop_01`, `ep2_smelt_score_hymn_loop_01`.
  Say which beat each fires on.
- What can stay CSG/primitives vs what genuinely needs a real GLB later, and
  why.

### ===== FILE: REVIEW.md =====
At most **five** open questions for the founder. Only real ambiguities the
references do not settle. No process theater, no "please confirm you like it".

## Rules
- Concrete metres, counts and hex values. No vague poetry.
- If the references do not cover something, say "not covered by the references"
  and put it in REVIEW.md rather than inventing it.
- Do not restate the implementation back to me. Assess it.

---

## The shipped implementation

@include src/episode2/chamber/smelting_facility.gd

## The chamber design doc it implements

@include artifacts/episode2-gold-mine/chambers/00_SMELTING_FACILITY.md

## The shared Episode 2 palette the built scene draws from

@include src/episode2/art/ep2_palette.gd
