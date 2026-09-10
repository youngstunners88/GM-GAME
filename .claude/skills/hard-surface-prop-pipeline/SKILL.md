---
name: hard-surface-prop-pipeline
description: Build stylized hard-surface props (mine cart, rails, lanterns, beams, boulders, gold) as GLB files headlessly with the bpy PyPI wheel, no GPU and no GUI, then import and wire them into Godot 4.3. Use for any Episode 2 prop that is parametric or made of primitives. Not for organic rigged characters — that is hero-character-pipeline.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Hard-Surface Prop Pipeline (Path E — in-container, zero infra)

## What this is

`bpy` — Blender as a **PyPI wheel** — runs headless in this sandbox with no GPU
and no display, because `bpy.ops.export_scene.gltf()` serializes geometry and
materials and **invokes no render pass**. Only Cycles *rendering* needs a GPU.
That makes prop authoring a normal Python script with a normal test gate.

It is **not** a generative model. It assembles primitives. That ceiling is real
and this skill does not pretend otherwise — see `hero-character-pipeline`.

The community `ahujasid/blender-mcp` addon is a dead end here and always will
be: it schedules onto Blender's interactive GUI event loop via
`bpy.app.timers` and the N-panel operator, so it cannot run under `blender -b`.
Do not try to wire it. Path E bypasses it by scripting `bpy` directly.

## Setup (every fresh session — the container is ephemeral)

```bash
pip install "bpy==4.3.0" "numpy<2"
```

**The numpy pin is not optional.** `pip install bpy` alone pulls numpy 2.x,
whose C ABI bpy 4.3 was not built against. Every import then dies with
`numpy.core.multiarray failed to import` **while `bpy.app.version_string` still
answers correctly**, which sends you looking for a Blender problem that does not
exist.

## Build

```bash
python3 tools/blender/build_asset.py all src/episode2/assets     # everything
python3 tools/blender/build_asset.py lantern src/episode2/assets/lantern.glb
```

Current props: `minecart`, `lantern`, `wood_beam`, `boulder`, `rock_chunk`,
`rail_segment`, `gold_nugget`, `gold_pile`, `lil_blunt_placeholder`.

Adding one: write a `build_<name>()` using the `_box` / `_cyl` / `_ico` helpers,
register it in `BUILDERS`, and **add it to `ASSETS` in
`tests/ep2_glb_pipeline_test.gd` in the same commit**. A prop with no line in
that gate is a prop nothing ever proved Godot can open.

## Conventions that are load-bearing

| Rule | Why |
|---|---|
| Output goes to `src/episode2/assets/*.glb` | The existing convention. `res://` paths in the runner point there; `artifacts/` is now **excluded** from the export, so a prop parked there never reaches the game. |
| Materials mirror `src/episode2/art/ep2_palette.gd` | Nothing links a Python dict to a GDScript table but a comment. A prop whose materials disagree with the palette reads as a prop from a different game. |
| **No RNG.** Index arithmetic for scatter, jitter and piles | Two builds of the same asset must be byte-comparable, or a diff cannot tell you whether anything changed. |
| Albedo runs brighter than the reference photo samples | A lit photograph's dark midtones are not an albedo texture. The first generation of props sampled straight from the references and vanished into the tunnel — that was the top finding of two consecutive fidelity reviews. |
| Blender is Z-up, glTF is Y-up | Blender +Z becomes glTF +Y; Blender +Y becomes glTF **-Z**. The runner travels +Z, so a cart built facing Blender +Y needs `rotate_y(PI)` in engine. Put emblems on more than one face and the ambiguity stops mattering. |

## Import into Godot

```bash
GODOT="$(scripts/bootstrap-godot.sh | tail -1)"
"$GODOT" --headless --import          # generates the .glb.import sidecars
```

Use `--headless --import`. **`--editor --quit` aborts the import scan** and
reports zero files imported, silently.

**Commit the `.glb` only.** `.gitignore` line 57 ignores `*.import` repo-wide,
so the sidecars are deliberately NOT tracked — CI regenerates them with its own
`--headless --import` pass. Do not "fix" that by force-adding them; a committed
sidecar that disagrees with CI's regenerated one is a conflict waiting to
happen. (`export_presets.cfg` is ignored for the same reason: CI writes its own
from the heredoc in `.github/workflows/export-game.yml`.)

Default GLB import settings are correct for these props (+Y up, UVs, normals and
tangents preserved), which is why nothing needs to be carried across.

## Wire it into a scene

Instance through `_prop()` in `runner_graybox.gd`, which is the pattern to copy:

```gdscript
if _prop(BOULDER_MODEL, Vector3(x, 0.7, z), 1.0) == null:
    # primitive fallback — a GLB that fails to load must degrade to a VISIBLE
    # box, never to nothing. An invisible hazard is this episode's worst bug.
    var b := SphereMesh.new()
    ...
```

Every prop keeps its fallback. That rule is not decoration: hazards that were
pure data with no mesh shipped once already.

## The gate — necessary AND not sufficient

```bash
"$GODOT" --headless res://tests/ep2_glb_pipeline_test.tscn
```

It asserts each GLB loads as a `PackedScene`, instantiates with real meshes,
**and carries materials** — that last one because a GLB can import with meshes
and no material, pass every other assertion, and render as a white blob, which
is indistinguishable from "art not done yet".

**Green here does not mean it looks right.** Finish with a real browser capture
and an Astra review (`art-direction-fidelity-check`), then report the exact
`index.pck` byte count against the 199,229,440 gate — measured, not estimated.

## Cost

Free. No API, no GPU, no allowlisting. All eight current props together are
about 250 KB of GLB and moved the pck by well under a megabyte.
