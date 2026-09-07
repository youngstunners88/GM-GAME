# FOUNDER PROMPT V4 ADDENDUM — Pascal Editor for Chambers (2026-09-07)

> Verbatim copy of the founder's fourth Episode 2 prompt
> (`PROMPT_EPISODE2_PASCAL_CHAMBERS_DESIGN_SPEC.md`), sent with the Pascal
> repo link (https://github.com/pascalorg/editor). This one is **additive**,
> not superseding: it introduces a tool for the chamber interiors and does not
> change the story (V3) or the runner mechanics (V2).
>
> Claude Code's status annotations are inline, same convention as V2/V3.
> Everything asserted below about what Pascal can do was **verified by running
> it**, not read off the README — see `CHAMBER_ARCHITECTURE_PLAN.md` §0.

---

## 1. Purpose

Pascal Editor is a Three.js / React Three Fiber / WebGPU architectural editor.
It is excellent for buildings, rooms, vaults, halls, and formal interiors.
It is **not** the right tool for free-form mine tunnels, multi-rail tracks, zip-lines, or organic rocky landscapes.

> **✅ Confirmed, and the division of labour is right.** Pascal is real
> (React 19 / Next.js 16 / Three.js WebGPU, published on npm as
> `@pascal-app/*`). Its vocabulary is levels, walls, openings, zones and
> catalogue items — exactly the chamber problem, and nothing like the runner
> problem. Adopted as specced.

---

## 2. Chambers Assigned to Pascal

1. **Fort Knox Vault** · 2. **Claim Certificate Office** · 3. **Gold Rush
Auction Hall** · 4. **Treasury / Sovereign Vault** · 5. **Stockpile Depot
(interior)**

The **First Chamber** (Inferno Bull introduction + Winchester 1886 hand-off) can be a hybrid: rocky/mine entrance built in Blender, formal interior transition built in Pascal if it helps.

> **✅ All five specced** in `CHAMBER_ARCHITECTURE_PLAN.md` §2, with footprints,
> named zones, one primary interaction point each, and per-chamber signature
> cover. **Fort Knox is actually built** — not a plan, a validated Pascal scene
> at `assets/chambers/fort_knox/fort_knox_shell.pascal.json`.
>
> **First Chamber hybrid decision (Task 3): build it WITHOUT Pascal first.**
> Its identity is a rough mine shaft — rock, timber, ore chutes — which is the
> half Pascal explicitly isn't for. It's also the story-critical Bull/Winchester
> beat, and shouldn't wait on an asset pipeline. Add a Pascal-built rig room
> inside it later only if that room needs real architectural fidelity.
> Reasoning in `CHAMBER_ARCHITECTURE_PLAN.md` §4.

---

## 3. Technical Integration Plan

### 3.1 Pascal → Game Pipeline
1. Build chamber in Pascal Editor (local or via CLI).
2. Export as **GLB**.
3. Place exported GLB into `artifacts/episode2-gold-mine/assets/chambers/`.
4. Load the GLB in the main Three.js (or R3F) runtime alongside runner assets.
5. Add collision, interaction hotspots, lighting, and shooter gameplay on top in the game code.

> **⚠️ Step 2 does not work headlessly — this is the one real correction in
> this document.** Pascal's own `export_glb` tool returns:
> `{"status":"not_implemented","reason":"GLB export requires the Three.js
> renderer, which is browser-only"}`. Its `exportSceneToGlb()` takes a live
> rendered `THREE.Object3D` and calls `requestAnimationFrame` +
> `WebGPUTextureUtils`, so it needs the editor running in a browser with
> WebGPU. This container has no GPU.
>
> **What DOES work headlessly — and it's the more valuable half:** authoring.
> `tools/pascal/build_fort_knox.mjs` drives Pascal's MCP server over stdio and
> builds the entire Fort Knox shell — level, 12 walls, 3 cut openings, 4
> labelled zones — then `validate_scene` returns
> `{"valid":true,"errors":[]}`. So the corrected pipeline is:
>
> ```
> build script (headless, in repo)  ->  *.pascal.json  ->  open in Pascal
> editor (browser, one click)  ->  GLB  ->  assets/chambers/  ->  engine
> ```
>
> This is arguably better than the original plan: the layout lives in git as
> reproducible, reviewable code instead of a hand-dragged scene. Only the final
> render/export step needs a browser — which is a thing you can do on your own
> machine in about a minute per chamber.

### 3.2 Runtime Expectations
- Pascal chambers are static or lightly interactive architectural shells.
- Gameplay logic lives in the main game layer, not inside Pascal.
- Keep scale consistent with the runner.

> ✅ Agreed and specced. All layouts use human scale (Lil Blunt ~1.7m for
> door/ceiling purposes) and every entry apron is ≥4m to accept the cart on
> 2.5m rails.

### 3.3 Claude Code Web Constraints
- Pascal has MCP support — useful if running locally or in an environment that loads MCP.
- In pure Claude Code web sandbox, prefer: plan the chamber layout in text/nodes → produce build instructions or scripts → export GLB when a suitable environment is available.
- Do not block the whole Episode 2 on Pascal if the web sandbox cannot run it.

> **✅ This section was exactly right, and better than expected.** The MCP
> server *does* run in this sandbox (46 tools) — I didn't need it registered as
> a harness MCP server, I drove it directly over stdio JSON-RPC. Two upstream
> bugs had to be worked around first, both in `@pascal-app/mcp@0.3.2` and both
> documented in `tools/pascal/build_fort_knox.mjs`:
> 1. **`zod` must be pinned to `4.3.5`** — on 4.5.4 every node-creating tool
>    fails with `Duplicate discriminator value "undefined"`. Reproduced under
>    both node and bun.
> 2. The package ships **179 extensionless relative ESM imports** while being
>    `"type": "module"` — valid under a bundler, invalid under plain Node ESM.
>    Run under `bun`, or with `tools/pascal/ext-resolver.mjs`.
>
> Nothing about Episode 2 is blocked on Pascal.

---

## 4. Design Requirements per Chamber (Pascal)

Fort Knox (massive/secure, entrance + staking + melt + exit, cover and sight
lines), Claim Office (formal, desk focus, tighter), Auction Hall (grand, open,
central pool), Treasury (clean, prestigious, readable positions).

> ✅ All four translated into metre-accurate zone tables in
> `CHAMBER_ARCHITECTURE_PLAN.md` §2, each with the one primary interaction
> point placed deliberately for the fight around it (e.g. Fort Knox's melt
> furnace sits at the *back* of its alcove, so committing a melt costs you
> position while the Bull holds the hall).
>
> On "hyper-realistic aesthetic": Pascal produces clean architectural
> geometry, not hyper-real art. Materials/lighting/props are a separate pass,
> and the honest real-time bar is still the "Uncharted-mobile / stylized
> realism" one both prior model reviews set — see `00_ARCHITECTURE.md` §7a.

---

## 5. Immediate Tasks for Claude Code — status

| # | Task | Status |
|---|---|---|
| 1 | Read this + the main Episode 2 story spec | ✅ |
| 2 | Chamber Architecture Plan (footprint, zones, interactions, entry/exit) | ✅ `CHAMBER_ARCHITECTURE_PLAN.md` |
| 3 | Decide First Chamber hybrid approach | ✅ Build without Pascal first — §4 of that doc |
| 4 | Asset folder convention | ✅ `assets/chambers/{fort_knox,claim_office,auction_hall,treasury,stockpile_interior}/` |
| 5 | If Pascal runs: minimal Fort Knox shell + test GLB | ⚠️ **Half done, honestly.** Fort Knox shell **built and validated** as a Pascal scene. **Test GLB not produced** — browser-only, see §3.1. |
| 6 | If Pascal can't run: document the node/layout spec | ✅ Superseded by #5 — you get an executable build script, not just a text spec |
| 7 | Update STATUS.md with the Pascal plan only | ✅ No Episode 1 residuals touched |

---

## 6. Hard Rules

- Pascal is for **architectural chambers only**. ✅ Observed — no rails/tunnels in Pascal.
- All final gameplay runs in the main Three.js runtime. ⚠️ **See the engine note below.**
- Maintain hyper-realistic fidelity and consistent scale. ✅ Scale enforced; fidelity is a later art pass.
- Bull + Winchester remains the first-chamber story beat, tooling secondary. ✅ Explicitly preserved.
- Prefer GLB as the exchange format. ✅ And usefully, **GLB is engine-neutral.**
- Claude Code owns the repo and STATUS.md. ✅

### ⚠️ The engine question, asked plainly (third time it's come up)

Three specs in a row have now assumed a **Three.js** runtime. I have not
started Three.js, and I want to be straight about why rather than keep quietly
noting it in a doc:

- Everything actually built for Episode 2 — the runner graybox, the
  duck/zip-line/arrow/boulder hazard model (20/20 gated), the music, the
  headless `bpy` GLB pipeline (7/7 gated) — is **Godot 4.3 3D**.
- Two independent model reviews recommended Godot over Three.js, on the
  grounds that a second runtime buys no fidelity (both load the same GLBs)
  while costing a second deploy/input/economy integration.
- **Pascal does not force the answer.** It emits GLB, and GLB loads in Godot
  and Three.js alike. So this Pascal plan is valid either way — nothing here
  is wasted whichever engine you pick.

So the question is genuinely yours, and it is not urgent for the chamber work:
**do you want Three.js specifically** (in which case the Godot runner work gets
rebuilt, and I'd want you to say that explicitly), **or is "a 3D web game" what
you meant** — which Godot already delivers, exporting to the same web target?
Until you say otherwise I'll keep building on Godot, because that's where the
working, tested code is.

---

## 7. Success Criteria

- [x] Clear written plan for which chambers use Pascal vs pure Blender/Three.js — `CHAMBER_ARCHITECTURE_PLAN.md` §1.
- [x] Folder structure for chamber GLBs created.
- [x] At least one chamber has a detailed zone + interaction layout — all five do; Fort Knox is built.
- [x] Integration path documented **and testable** — `tools/pascal/build_fort_knox.mjs` runs end-to-end and exits 0.
- [x] No attempt made to build runner tracks inside Pascal.

**Pascal builds the buildings. Blender + Three.js build the mine. The story holds them together.**

---

*Source:* `https://github.com/pascalorg/editor` ·
`@pascal-app/{cli,core,mcp,nodes,viewer}` on npm (cli 0.1.5, core 0.9.2,
mcp 0.3.2, nodes 0.1.1, viewer 0.9.2 as of 2026-09-07).
