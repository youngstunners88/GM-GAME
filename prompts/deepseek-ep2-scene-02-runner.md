# Episode 2 scene foundation — 02_runner_opening

You are authoring the **foundation scene kit** for the opening track section of
Episode 2 of *Lil Blunt Adventure*: the **mine-cart runner** that the player
rides before reaching the Smelting Facility.

Runtime is **Godot 4.3**. You own the FOUNDATION (scene spec, aesthetic lock,
Godot blockout notes). A later high-fidelity pass raises it to production meshes
— your job is to give that pass law to follow instead of taste.

## IMPORTANT — this section is ALREADY BUILT and playable

A working Godot blockout ships today: an enclosed tunnel with segmented walls
that open into a wide worked-out bay every fourth section, timber support
frames, sleepered track, scattered gold ore in the walls, warm lantern pools,
three rails, jump/duck, a zip-line stretch, and hazards (crate, boulder,
arrow) fired by balaclava bears. The implementation is inlined below.

Your deliverables must, in this order of value:

1. **Lock the aesthetic** against the founder's reference images (attached).
2. **Reconcile with what exists** — read the implementation and say where the
   built tunnel already agrees with the references and where it drifts. Cite
   specific numbers from the code.
3. **Specify the foundation** for what is still crude.

A recent expert review of a real screenshot of this exact scene returned
**OFF MODEL**, with these ranked findings. Treat them as evidence, not opinion,
and let them shape the lock:
   1. "The playable scene collapses into shadow" — cart edges, sleepers and
      obstacles occupy similar dark values.
   2. "The palette reads as brown timber rather than gold-bearing rock" — the
      references separate cool charcoal stone from warm wood and concentrated
      yellow-gold deposits.
   3. Track boundaries dominate while the actual railway disappears.
   4. "A rectangular shaft, not a cavern" — needs uneven openings and layered
      depth.
   5. Gold reads as isolated ochre tiles rather than clustered seams.

## Attached images (the only source of art-direction truth)

1. `ep2_runner_ref_3_minecart_ride.jpg` — the hero shot: cart on rails, gold
   veins, timber, lanterns, hanging baskets, depth.
2. `ep2_runner_ref_1_boulder_bandits.jpg` — the threat vocabulary: balaclava
   bears, boulders, arrows, carts, sparks.
3. `ep2_runner_ref_2_zipline.jpg` — the zip-line beat, steel cable, pulley
   sparks, cavernous depth below.

## Hard constraints you must not violate

- **Godot 4.3, Compatibility backend on web**: no volumetric fog, no
  SSR/SSAO/SDFGI, and metallic with no reflection source renders near-black.
  Metals carry through albedo + roughness + slight emission.
- Three rails. The camera looks down +Z; with +Y up that puts world +X on the
  player's LEFT, so lane order descends. Do not "fix" that.
- Hazards must stay readable in **under a second** at 12 m/s.
- Mesh budget matters: the current tunnel is roughly 600 MeshInstance3Ds and a
  software-rendered browser measured about 14 fps in the heavier chamber. Say
  where detail is worth its cost and where it is not.
- Enemies are balaclava bears, boulders, arrows. **Never weed-themed.**

## Deliverables — output EXACTLY these four sections, in this order

### ===== FILE: SCENE_SPEC.md =====
Mood paragraph; dimensions in metres (built: 12 m wide tunnel, 7-9 m high,
opening to 16.8 m wide bays every 4th 20 m segment, ~240 m long); zones (entry,
runner corridor, zip-line stretch, chamber gate); key props named and counted;
lighting; camera and player start; **movement bounds** — this is the key runner
problem: the look must be expansive while the playable corridor is narrow, so
say how; threat anchors.

### ===== FILE: AESTHETIC_LOCK.md =====
Palette table (surface, hex, metallic, roughness, emission) grounded in the
images and answering findings 1, 2 and 5 above; surface language; which
reference each decision came from; **what is explicitly OUT of style**.

### ===== FILE: GODOT_NOTES.md =====
Node hierarchy for the blockout; collision intent; audio hook points named
against these existing VARCO stems — `ep2_runner_bed_mine_loop_01`,
`ep2_runner_cart_rails_loop_01`, `ep2_runner_zipline_rush_01`,
`ep2_runner_duck_01`, `ep2_runner_jump_land_01`, `ep2_runner_arrow_flyby_01`,
`ep2_runner_boulder_roll_01`, `ep2_runner_bear_distant_01`,
`ep2_runner_score_drone_loop_01` — saying what triggers each; CSG/primitives vs
real GLB later, with the mesh budget in mind.

### ===== FILE: REVIEW.md =====
At most **five** real open questions for the founder.

## Rules
- Concrete metres, counts and hex values. No vague poetry.
- If the references do not cover something, say so and put it in REVIEW.md
  rather than inventing it.
- Do not restate the implementation back to me. Assess it.

---

## The shipped implementation

@include src/episode2/runner/runner_graybox.gd

## The shared Episode 2 palette it draws from

@include src/episode2/art/ep2_palette.gd
