# Episode 2 — Asset Pipeline Decision Tree

Grounded in the founder-supplied research doc `spec/BLENDER_MCP_SETUP.md`
(a compass_artifact research brief) + this session's verified container facts.

## ✅ UPDATE (2026-09-05) — in-container headless GLB generation is VERIFIED

The founder's second research brief (headless 3D / GLB generation) was tested
end-to-end and its central claim **holds in THIS container**: the **`bpy` PyPI
wheel runs Blender headless with no GPU and no display**, and `bpy.ops.
export_scene.gltf(export_format="GLB")` produces valid GLBs — because GLB
export serializes geometry + materials and invokes **no render pass** (only
Cycles *rendering* needs a GPU).

**Evidence (reproducible):**
- Installed `bpy` 5.0.1 via pip (Python 3.11, in this sandbox).
- `tools/blender/build_asset.py` builds three parametric props headlessly and
  writes valid GLBs (glTF magic-byte checked):
  `src/episode2/assets/minecart.glb` (23708 B), `gold_nugget.glb` (3448 B),
  `rail_segment.glb` (13828 B).
- `tests/ep2_glb_pipeline_test.tscn` proves **Godot 4.3 actually imports and
  loads** all three into real `MeshInstance3D` scenes (minecart 7 meshes,
  gold_nugget 1, rail_segment 9) — **ALL PASS**, headless.

**What this changes vs. the four-path table below:** for **stylized,
hard-surface / parametric props** (minecart, rails, beams, lanterns, nuggets,
rocks) there is now a **fifth path that runs entirely in this container with
zero external infra** — call it **Path E (in-container headless bpy)**. It is
the fast route for prop blockouts and modest final props.

**What it does NOT change:** this is **not a generative model**. A
hyper-real, rigged, on-model **hero character (Lil Blunt 3D) still needs a
human Blender pass** (or image-to-3D + human cleanup) — both aesthetic reviews
agree, and a Python primitive-assembly script cannot author an organic hero.
The community `blender-mcp` addon is still a GUI dead end here (below); Path E
bypasses it by scripting `bpy` directly.

## ✅ LOCK (2026-09-22) — which generator authors which asset

Path D previously named "Meshy / Tripo / Rodin / Hunyuan3D" as interchangeable.
They are not. The founder's 3D-AI roundup intake
(`artifacts/PROMPT_EPISODE2_3D_AI_ROUNDUP_TAKEAWAYS.md`, annotated in
`FOUNDER_PROMPT_V5_ADDENDUM.md` §2) locks the choice:

| Asset class | Tool | Notes |
|---|---|---|
| **Parametric hard-surface props** — rails, beams, crates, nuggets, simple rock | **Path E (`bpy`)** ✅ | Stays the default. Free, deterministic, scripted in version control, gate-verified |
| **Props `bpy` can't author** — organic, sculpted, detail-dense (lanterns, pickaxe, furnace pieces, cart detailing) | **Tripo P2 + Smart UV** → GLB | The Path D default. Smart UV handles organic *and* hard surface |
| **Hero sculpts only** — Inferno Bull, Fort Knox ornamental plates | **Meshy 7.1 Ultra 4K** → decimate → Smart UV if needed → GLB | **Never drop raw Ultra 4K into the runner.** Displacement/sculpt source, not runtime geometry |
| **Animation** | **Astra**, only after a GLB exists | Mesh first. Animation never blocks chamber authoring |
| **Rigged hero character** | Still needs a human Blender pass | Unchanged finding — image-to-3D drifts off-model on a rigged hero |

**UV rule:** Smart UV unless a human unwrap is specifically justified.
**Hunyuan Studio UV is not primary** — slower and unstable.

**Parked:** Miura 3D (no quality leap over Tripo/Meshy — ignore). HKTex
(heat-kernel textures, no UVs — research only; Smart UV remains the game-engine
answer today). Kai Ninja / Snap3D (part-splitting — model not fully public,
license unclear; do not wait on public weights).

### Parts, not welded blobs

The mine cart, furnace doors, and Winchester lever must import as **separate
part meshes**, never one fused mesh — a lever that can't animate independently
of its receiver is useless to the Winchester hand-off beat.

This is **already enforced, not just intended**: `tests/ep2_glb_pipeline_test.gd`
fails if the minecart collapses below 5 meshes. Current: minecart 7,
rail_segment 9, gold_nugget 1 (correct — no moving parts). The furnace and the
Winchester get the same assertion when they are authored.

### Per-asset provenance is mandatory

Every Episode 2 mesh records its generator in
`src/episode2/assets/GODOT_NOTES.md` before it counts as done.

## The hard fact that shapes everything

The popular community **`ahujasid/blender-mcp`** addon **requires Blender's
interactive GUI event loop** (it schedules onto the main thread via
`bpy.app.timers` and depends on the N-panel "Start MCP Server" operator). **It
will NOT run under headless `blender -b`.** (Research doc §Key Findings #2,
corroborated by the addon source + the Nous/Hermes practitioner note.)

This session's container has **no Blender, no GPU, no display** (verified:
`which blender` empty, `/dev/dri` absent, `nvidia-smi` missing). So this
container cannot drive blender-mcp **by any method** — not even Xvfb, because
GPU Cycles still needs a real GPU. The blocker is hardware + display, not
configuration.

## The four real paths (pick per fidelity + who runs Blender)

| Path | What it is | Runs where | Fidelity ceiling | Cost/effort |
|---|---|---|---|---|
| **A. Local GPU desktop** (research doc's "only reliable path today") | Founder runs Blender 4.5 LTS + community addon on their own RTX/Apple-Silicon machine; agent connects over `BLENDER_HOST`/`BLENDER_PORT` on a trusted LAN | Founder's machine | Highest (Cycles) | Founder time; trusted-network only (socket has no auth) |
| **B. Cloud GPU VM + virtual desktop** | RunPod/Paperspace RTX VM running Blender GUI under Xvfb or VNC/KASM | Cloud | Highest (Cycles) | Hourly GPU $$$; setup |
| **C. Official Blender-Lab MCP server** | Anthropic+Blender official connector, **supports background mode** (synchronous-only), Blender **5.1+** | A host with Blender 5.1+ | High | Newer; still needs Blender+GPU host, but headless-capable |
| **D. External generators → GLB** (no MCP at all) | **Tripo P2 + Smart UV** for props, **Meshy 7.1 Ultra 4K** for hero sculpts only — export GLB, import to engine directly. Generator choice is **locked** — see §"LOCK (2026-09-22)" above | Web services | Prototype→near-production; hero rigs still need human cleanup | Tripo ~20 credits/asset; Meshy ~$20/mo |
| **E. In-container headless `bpy`** ✅ VERIFIED | Script `bpy` directly (no MCP, no GUI); build parametric/hard-surface props + export GLB in this sandbox | **This container** | Stylized props (not organic hero) | **Free, in-session, zero infra** |

## Recommendation (for founder sign-off)

- **Hero character (Lil Blunt 3D):** needs a human Blender pass regardless
  (both aesthetic review + this doc agree image-to-3D drifts off-model for a
  rigged hero). → Path A or B, or D+human-cleanup.
- **Props (minecart, beams, rails, lanterns, rocks):** **Path E** (in-container
  headless `bpy` → GLB → import) is now the fast pragmatic route — **verified
  working this session**; Path D (external generators) or blender-mcp assembly
  remain options for higher-fidelity or organic props — and when Path D is used,
  the generator is **not** a free choice: **Tripo P2 + Smart UV** for props,
  **Meshy Ultra 4K** for hero sculpts only, per the LOCK section above.
- **This agent's role:** own the **runtime integration** (the runner↔chamber
  loop, controls, camera, protocol logic, GLB import + placement, gates,
  web-export) — all of which is doable here with **zero Blender dependency**
  using engine primitives now and real GLBs when they arrive.

## Consequence for build order

Because none of the runtime/gameplay integration needs Blender, the correct
first build is a **graybox vertical slice in engine primitives** (see
`00_ARCHITECTURE.md` §7a). Assets drop in later via any path above without
reworking the loop. Grayboxing now de-risks the *gameplay* before any GPU
hour or Blender session is spent.
