# FOUNDER PROMPT V5 ADDENDUM — Asset-generator lock + PlayCanvas verdict (2026-09-22)

> Verbatim copies of the founder's fifth and sixth Episode 2 prompts, filed at
> the paths the prompts themselves specify:
>
> - `artifacts/PROMPT_EPISODE2_3D_AI_ROUNDUP_TAKEAWAYS.md` (asset-generator lock)
> - `artifacts/PROMPT_EPISODE2_PLAYCANVAS_TAKEAWAYS.md` (engine non-decision)
>
> Both are **additive and non-superseding**. Neither changes the story (V3), the
> runner mechanics (V2), the chamber tooling (V4), or the runtime (ADR-0001).
> Together they close the last two open questions in the asset pipeline: *which
> generator authors a prop*, and *whether a second web engine enters the stack*.
>
> Claude Code's status annotations are inline, same convention as V2/V3/V4.

---

## 0. Why these two land as one addendum

They are the same decision viewed from two sides. The roundup prompt says
**which tool authors a mesh**; the PlayCanvas prompt says **which tool does not
author the game**. Both resolve to: *more authoring tools are welcome, a second
runtime is not.* Filing them together keeps that symmetry visible instead of
splitting it across two documents that a later session would read separately.

---

## 1. Runtime: unchanged, and now explicitly closed against PlayCanvas

**Locked runtime remains Godot 4.3.** PlayCanvas is a preview / splat / teaser
layer only — the same class as Pascal Editor (V4) and the Three.js smelting
demo, both of which are authoring- or marketing-side and neither of which runs
as the game.

> **✅ Confirmed, and ADR-0001 has been amended to name PlayCanvas by name.**
> The ADR previously closed the door on Three.js as a runtime but said nothing
> about PlayCanvas, which left the *next* web engine to be re-litigated from
> scratch. §3 of `docs/architecture/adr-episode2-runtime-engine.md` now reads as
> a class rule — browser engines are permitted as throwaway preview/prototype
> layers and are explicitly not on the path to shipping — so PlayCanvas, and
> whatever follows it, is answered without reopening the decision.
>
> The prompt's own assessment of PlayCanvas is accurate and is not the issue:
> it is a mature MIT engine with the strongest web Gaussian-splat stack. That is
> exactly why the *preview* use is granted rather than refused. The reason it is
> not the runtime has nothing to do with its quality — a second runtime buys no
> fidelity, because both engines load the same GLB, while costing a second
> deploy, input layer, and economy integration. That is the same reasoning the
> two independent model reviews gave for Godot over Three.js in ADR-0001.

**Forbidden, per the prompt and now per the ADR:** replacing Godot, reopening
the engine debate, building cart physics in PlayCanvas, or standing up a
parallel Episode 2 codebase in it.

**Granted, if and when asked for:** one small folder
`artifacts/episode2-gold-mine/playcanvas-preview/` with a single scene, loading
existing refs/GLBs. Not built this session — nothing has asked for it, and the
prompt is explicit that a preview is not to be started speculatively.

---

## 2. Generator lock — Tripo for the game, Meshy for the statue

This replaces the undifferentiated "Meshy / Tripo / Rodin / Hunyuan3D" list that
Path D of `ASSET_PIPELINE.md` carried since 2026-09-05. Path D had named four
generators as interchangeable; it now names one default and one exception.

| Asset class | Generator | Why |
|---|---|---|
| **Episode 2 props** — carts, rails, lanterns, pickaxe, crates, furnace pieces | **Tripo P2 + Smart UV** → GLB | Default. Smart UV unwraps organic *and* hard surface; P2 is out of beta with improved low-poly output |
| **Hero sculpts only** — Inferno Bull, Fort Knox ornamental plates | **Meshy 7.1 Ultra 4K** → decimate → Smart UV if needed → GLB | 4K detail as displacement/sculpt source. **Never dropped raw into the runner** |
| **Animation** | **Astra**, after a GLB exists | Mesh first. Animation does not block chamber authoring |
| **UV unwrap** | Smart UV unless a human unwrap is justified | Hunyuan Studio UV is explicitly **not** primary — slower and unstable |
| **Parked** | Miura 3D (no quality leap — ignore); HKTex (research, watch) | — |

> **✅ Adopted as specced, with one correction to the prompt's framing and one
> note on what this does not displace.**
>
> **Correction:** the prompt's flow diagram implies every Episode 2 prop routes
> through Tripo. It should not. **Path E (in-container headless `bpy`) stays the
> default for parametric hard-surface props** — rails, beams, crates, nuggets —
> because it is verified working in this container, free, deterministic, and
> re-runnable from a script in version control. The three GLBs already shipping
> in `src/episode2/assets/` were built that way and pass a headless Godot import
> gate. Sending a rail segment to an external paid service to get a worse,
> non-reproducible result would be a regression. **Tripo becomes the default for
> props that `bpy` primitive assembly genuinely cannot author** — anything
> organic, sculpted, or detail-dense. The two paths are complementary and the
> pipeline doc now says so explicitly.
>
> **Not displaced:** nothing here changes the hero-character finding that both
> prior aesthetic reviews reached — a rigged, on-model hero still needs a human
> pass, and image-to-3D drifts off-model. Meshy Ultra 4K at hero-only scope is
> consistent with that, not a replacement for it.

---

## 3. Parts, not welded blobs — already gated for the cart

The prompt requires the mine cart, furnace doors, and Winchester lever to be
**part meshes**, not one fused blob, and to prefer Kai Ninja / Snap3D over a
single TRELLIS merge once those are usable.

> **✅ Already true for the cart, and already enforced by a gate — not a plan.**
> `tests/ep2_glb_pipeline_test.gd` asserts the minecart imports as **≥5 separate
> meshes** (hull / rim / wheels / emblem) and fails the gate if it collapses to
> one. Current counts: minecart 7 meshes, rail_segment 9, gold_nugget 1
> (correctly a single mesh — a nugget has no moving parts).
>
> **Outstanding:** the furnace doors and the Winchester lever are not built yet,
> so the rule is recorded in `src/episode2/assets/GODOT_NOTES.md` as a build
> requirement rather than claimed as satisfied. When either is authored, it gets
> the same ≥N-mesh assertion the cart has, because a lever that cannot animate
> separately from the receiver is useless to the Winchester hand-off beat in the
> First Chamber (V3 story).
>
> **On Kai Ninja / Snap3D:** noted and not adopted. The prompt itself says the
> Kai Ninja model is not fully public and its license is unclear, and instructs
> not to wait on public weights. Authoring parts separately in Tripo (or `bpy`)
> is the standing method until that changes.

---

## 4. Per-asset generator provenance is now recorded

The prompt requires that a generated or commissioned mesh has its tool choice
written into the scene kit's `GODOT_NOTES.md`.

> **✅ Created at `src/episode2/assets/GODOT_NOTES.md`** — no such file existed
> anywhere in the repo before this session, so the requirement was unmet rather
> than partially met. It carries a per-asset table (asset → generator → path →
> part-count → gate status) covering the three shipping GLBs, plus the pending
> entries for the Bull, the Winchester, and the furnace with their assigned
> generator pre-committed. Every future Episode 2 mesh adds a row before it is
> considered done.

---

## 5. Scope discipline — what was deliberately not done

Both prompts explicitly warn against over-building on intake. Honoured:

- **No new integrations stood up.** No Tripo, Meshy, Astra, or PlayCanvas API
  wiring. The prompt says "do not stand up six new integrations this session"
  and there is nothing to integrate *against* until a mesh is actually
  commissioned.
- **No PlayCanvas project created.** Granted-if-asked, not started.
- **No engine-debate essay in STATUS.** The STATUS entry states the lock and
  points at the ADR.
- **No PR check-in loops.**

---

## 6. One factual discrepancy to flag

Both prompts reference skills under a **`.grok/skills/`** directory:

- `.grok/skills/gm-game-episode2-playcanvas-preview/SKILL.md`
- `.grok/skills/gm-game-episode2-tripo-meshy-pipeline/SKILL.md`

**Neither exists in this repository — there is no `.grok/` directory at all.**
This is not treated as an error in the prompts: they read as having been
authored in a separate Grok workspace that maintains its own skill tree. It is
flagged because the repo's own manifest rule is that a path which 404s gets
fixed rather than left to send the next agent hunting. No skills were invented
to fill the gap — the locks live in this addendum, the ADR, `ASSET_PIPELINE.md`,
and `GODOT_NOTES.md`, all of which are real paths in this repo. If those Grok
skills should be mirrored here as Claude skills, that is a one-line ask.

---

## 7. Success criteria — status

**From the roundup prompt:**

- [x] Episode 2 props have a named generator (Tripo vs Meshy vs `bpy`) in their notes → `GODOT_NOTES.md`
- [x] UVs come from Smart UV unless a human unwrap is justified → recorded in `ASSET_PIPELINE.md` Path D
- [x] Cart planned **and gated** as parts, not one mesh; furnace / gun recorded as a build requirement
- [x] Astra queued for animation only after a GLB exists → no animation work started

**From the PlayCanvas prompt:**

- [x] Runtime statement unchanged: Godot 4.3
- [x] PlayCanvas mentioned only as preview/splat/teaser → ADR-0001 §3, amended to a class rule
- [x] No parallel Episode 2 codebase in PlayCanvas

---

**Tripo for the game. Meshy for the statue. Astra for the motion. `bpy` for
anything parametric. Godot for the game itself — that one is closed.**
