# Episode 2 — Gold Mine Runner + Protocol Chambers · Architecture

**Source of truth:** the founder prompt
`PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md` (verbatim copy in
`spec/FOUNDER_PROMPT.md`). This doc is the engineering plan derived from it.

**Status (updated 2026-09-06):** Past pure planning. Real graybox gameplay
code exists and is headless-gated: `src/episode2/runner/runner_graybox.gd`
(auto-run, 3-rail switching, jump, duck, zipline, and a 3-way hazard model —
"box"/"arrow"/"boulder" — see §5a) and a proven headless
Blender(bpy)→GLB→Godot import pipeline (§5, corrected from the original
"blocked" verdict below — that verdict was about the GUI `blender-mcp`
socket, not the `bpy` Python module, and no longer describes reality).
The founder sent an updated ("FINAL") spec this session with new reference
images (balaclava-bear enemies, arrows, boulders) — verbatim copy +
Claude's status annotations in `spec/FOUNDER_PROMPT_V2_ADDENDUM.md`. Later
the same day, a third "Story-First Spec" escalated the brief into a full
story bible (Inferno Bull companion, Winchester 1886, Wild West shooter
tone shift) — verbatim copy in `spec/FOUNDER_PROMPT_V3_ADDENDUM.md`, story
outline in `spec/STORY_OUTLINE.md`, First Chamber beat sheet folded into
`chambers/01_CHAMBER_MINER_SHAFT.md`. Still planning-only — no chamber
*gameplay* code exists. The runner also now carries real music
(`goldmine_dreams.mp3` / `goldmine_high.mp3`, shuffled per founder direction).
A fourth spec (2026-09-07) adds **Pascal Editor** for the chamber interiors —
`spec/FOUNDER_PROMPT_V4_ADDENDUM.md` + `spec/CHAMBER_ARCHITECTURE_PLAN.md`.
Pascal authoring is proven headless here (`tools/pascal/build_fort_knox.mjs`
builds a validated Fort Knox shell); its **GLB export is browser-only**, so the
pipeline is: headless build script → `*.pascal.json` → open in the Pascal
editor → GLB. Pascal emits GLB, which loads in Godot or Three.js alike, so it
does **not** force the still-open engine question.

---

## 1. Vision (restated from the founder prompt)

Episode 2 is one continuous underground gold-mine track system with two
interleaved modes:

- **Mode A — Runner:** over-the-shoulder / behind-the-back minecart + zipline
  traversal on multi-rail track. Jump rails, dodge boulders/arrows/bandits,
  collect GOLD / Diamonds / BTC. Fast, cinematic.
- **Mode B — Chamber:** the track feeds into a chamber entrance and the game
  switches to a **full 3D shooter/RPG encounter** that dramatizes one real
  Gold Mine protocol mechanic. Objective complete → back onto the track,
  Runner resumes.

The runner ↔ chamber loop is the spine. Six chambers map 1:1 to the six
white-paper protocol elements (§3 of the founder prompt; detailed briefs in
`chambers/01..06`).

---

## 2. Hard reality this plan must respect

**Episode 1 is a 2D pixel-art Godot 4.3 platformer.** Episode 2 as specced
is a **3D, hyper-realistic, over-the-shoulder runner + 3D shooter/RPG**. That
is not a new level — it is effectively a new product built on a new rendering
path and (per the prompt) a new toolchain (Blender → GLB → Three.js/Godot).
This is a founder-authorized direction; recording the magnitude honestly so
nobody mistakes "Episode 2 planning shipped" for "a playable 3D episode
exists." It does not yet, and cannot in a single session.

**The economics are already real and already in the repo.** `src/autoload/
goldmine_system.gd` encodes the white-paper numbers as constants
(`MINER_VESTING_DAYS = 100`, `DIAMOND_BURN_PCT = 0.20`,
`MAX_MELT_RATIO = 3`, `MAX_MELT_BONUS_PCT = 9.00`, `CERT_SHARES_REQUIRED =
22000`, `CERT_PRICE_XAUT = 0.5`, the Fort Knox 88/288-day split, the treasury
splits). Every chamber brief cites these constants rather than inventing
numbers — satisfying the prompt's Hard Rule "Never invent protocol numbers."
The white paper itself is at `docs/whitepapers/GoldMine.md`.

---

## 3. The runner ↔ chamber loop (engine-independent design)

```
[Runner segment] --track--> [Chamber entrance trigger]
       ^                              |
       |                    switch to 3D encounter
       |                              v
       +---- exit portal ----  [Chamber objective]
```

- A **run** is a sequence: Runner → Chamber₁ → Runner → Chamber₂ → … Each
  runner segment is 30–60s (prompt §4.3). Each chamber is a self-contained 3D
  encounter with one protocol objective.
- **Shared player state** across both modes: GOLD / Diamonds / wBTC / XAUT
  balances (already modelled by `goldmine_system.gd`), health, and the
  pickaxe (traversal tool in Runner, melee/interact in Chamber).
- **Fail/continue and scoring are UNSPECIFIED in the prompt** and are called
  out as OPEN DESIGN QUESTIONS in §6 — not decided here.

---

## 4. Asset & rendering pipeline (as the prompt forces it)

Prompt §2 forces: **Blender** (source of truth) → **blender-mcp** (Claude
drives Blender) → clean **GLB** → **Three.js** runtime (or Godot 4.3) →
polish. Aesthetic Law: hyper-realistic, GLB-clean, "cartoonish outputs are
rejected."

---

## 5a. Runner hazard model (added 2026-09-06)

The founder's updated spec named specific enemies (balaclava bears) and
traversal responses (duck / cart-jump / zip-line) that the original spec
left generic ("dodge obstacles"). Dispatched to Grok 4.5 for the design
(`docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md`) and Kimi K3
to audit the resulting implementation
(`docs/model-responses/2026-09-06-kimi-ep2-runner-hazards-audit.md`) —
Kimi found 3 real bugs in the first cut (a float-precision edge on the duck
hold timer, duck cover incorrectly surviving a zipline segment, and a
~0.3s free-clear + jump dead-window right after a zipline ends), all fixed
and each verified fail-before/pass-after with a dedicated regression test.

- **Hazard types are deliberately opposite, not palette swaps:** "arrow"
  (bears firing) is cleared ONLY by a held duck (≥0.10s, epsilon-guarded
  against float accumulation) — jumping does not help, a flying projectile
  still hits an airborne rider. "boulder" (bears pushing rocks) is cleared
  ONLY by jump/lane-switch — ducking does not help, it crushes low. Same
  rule as the pre-existing generic "box" obstacle.
- **Zipline is a boolean mode over a scripted z-range**, not a fourth rail —
  a genuinely different plane of movement. While active, lane-switch/duck/
  jump are no-ops and cart-phase hazards don't apply. Dismount snaps the
  cart back to the rail floor immediately (no residual fall time).
- **Not yet built:** bear *entities* — spawn position, aim, boulder-push
  animation/timing. Only the hazards they'd produce (arrow/boulder track
  entities) exist. Enemy AI is a separate pass.
- Gate: `tests/ep2_runner_graybox_test.gd`, 20/20 pass (7 original mechanics
  + 9 new hazard/duck/zip behaviors + 4 Kimi-audit regressions).

## 5. Headless Blender/GLB pipeline — CORRECTED, no longer a blocker

**This section originally said the pipeline was blocked. That was wrong for
`bpy` specifically, and has been proven wrong twice now** — once in the
prior session (commit `2069198`: `tools/blender/build_asset.py` built real
minecart/gold_nugget/rail_segment GLBs, all import into Godot 4.3 with real
meshes, `tests/ep2_glb_pipeline_test.gd` 7/7 pass) and re-verified
standalone this session (`pip install bpy` already present, bpy 5.0.1,
cube→material→GLB export succeeds headlessly, no GUI/GPU/blender-mcp
needed). The original blocker table below is kept for its still-true rows
(no GPU, no blender-mcp socket, no TRELLIS) — only the "blender-mcp
required" framing was the error: **`bpy` as a plain Python module was never
blocked, the GUI-bridging `blender-mcp` MCP server was, and the founder's
own two specs conflated them.**

**What `bpy` proves and doesn't:** proven for primitive-geometry props
(carts, rails, nuggets) — procedural boxes/cylinders with materials, no
sculpting, no rigging, no organic shapes. **Still NOT a path** to a
hand-sculpted, rigged, hyper-real Lil Blunt or bear character — that
still needs a human Blender pass or founder-supplied GLBs, unchanged from
the multi-model review's original conclusion in §7a below.

Original verification table (still accurate for what it actually tested):

| Requirement (prompt) | Reality in this session | Evidence |
|---|---|---|
| `blender` installed | **Absent** | `which blender` → nothing |
| `blender-mcp` registered/working | **Cannot run** — bridges to a live Blender process that isn't here; the MCP is not in this session's tool set | tool list has `Three_js_3D_Viewer`, no blender MCP |
| GPU for hyper-real render | **Absent** | `/dev/dri` missing, `nvidia-smi` not found |
| `uvx` (to `uvx blender-mcp`) | Present | `which uvx` → `/root/.local/bin/uvx` |
| TRELLIS skill (prompt §2.5) | **Not in repo** | `find -iname '*trellis*'` → empty |
| `artifacts/episode2-gold-mine/` (prompt §5 "Already Created") | **Did not exist** — created this session | `ls` → not found |
| skill (prompt §5/§8 marked [x]) | **Did not exist** — created this session | `ls .grok/skills/...` → not found |

**What this means, corrected:** the prompt's step-1 ("confirm headless
Blender/bpy working") **is done** — see above. What's still true: no
automated pipeline in this container produces assets at the literal
"hyper-realistic, matches the references exactly" bar for organic/character
work — the reference images are AI concept renders, not real-time game
assets, and `bpy` scripting doesn't sculpt or rig. Pretending otherwise
would repeat this project's worst failure mode (claiming work that wasn't
real) — so the hero/enemy-character gap below is still honestly open, just
narrower than the original "nothing can run here" framing implied.

**Founder decision still open — pick a path for organic/character assets
(see §7).** The engine decision (§6.1/§7a) is de-facto resolved by now
having real work in Godot 3D (runner graybox + GLB pipeline); re-opening it
would mean discarding that, not just "picking."

---

## 6. Open design questions (prompt does not specify — do NOT invent)

1. **Engine:** ~~Three.js or Godot 4.3?~~ **De-facto Godot 4.3 3D** as of
   2026-09-06 — the founder's V2 spec named Three.js first again, but the
   skill's rail #4 and both multi-model reviews (§7a) say Godot, and real
   work (runner graybox, GLB pipeline, both headless-gated) is already
   built there. Three.js was NOT started this session; starting it now
   would fork mid-build without the explicit sign-off the skill requires.
   Still nominally the founder's call to override, but "pick one" is no
   longer the honest framing — it's now "confirm Godot, or explicitly
   authorize discarding the Godot work to start over in Three.js."
2. **Runner controls:** ~~auto-scroll with jump/duck + rail-switch?~~
   **Resolved in code, 2026-09-06** — auto-scroll (fixed forward speed) +
   discrete lane-switch/jump/duck + a separate zip-line mode, per §5a. Still
   open: mapping these to actual input devices (Episode 1's
   MobileInputHandler is a candidate for touch, unused so far — the graybox
   only exposes the methods, no InputMap/touch UI yet).
3. **Fail/continue:** one-hit death, or health/lives? **Partially
   resolved in code:** the graybox uses `START_HEALTH := 3` (lives-style),
   not one-hit death — but this was an implementation default for testing
   hazards, not a founder-confirmed design decision. Still open: what ends
   a run for real (return to hub? retry the segment? lose progress?).
4. **Chamber combat depth:** "full shooter/RPG" — what does Lil Blunt shoot
   (the prompt says pickaxe melee + shooting; what is the ranged weapon)?
   Are there enemies in every chamber or only some? **Still fully open** —
   no chamber graybox exists yet (see §8).
5. **Progression:** does Episode 2 unlock after the Episode 1 finale (the
   cutscenes just shipped), and is it one long run or six selectable
   chambers? **Still fully open.**
6. **Bear enemy AI (new, from V2 spec):** positioning on ledges, aim
   timing, boulder-push animation/timing — none of this is modeled yet,
   only the arrow/boulder hazards a bear would produce. Is bear AI a
   graybox priority before or after the first chamber?

---

## 7. Recommended path forward (for founder sign-off)

**Engine fork is resolved by inertia + both model reviews: Godot 4.3 3D.**
What's still open is organic/character assets. Three honest options,
cheapest-first — unchanged in substance from the prior session, since bpy
proving out props doesn't change the character-asset gap:

- **Option A — Blender in a proper environment.** Stand up a session/host
  with Blender + GPU + a live `blender-mcp` bridge for interactive sculpting/
  rigging, and do the hero/enemy character pipeline there. `bpy`-headless
  (proven, §5) already covers procedural props; this option is specifically
  for the organic character work `bpy` scripting can't do.
- **Option B — Founder-supplied GLBs.** Founder (or a Blender artist) models
  the hero/bear characters in Blender locally, hands over clean rigged GLBs;
  I own the runtime integration (Godot 3D), the runner↔chamber loop,
  controls, and the protocol logic. Splits the work along the line each side
  can actually do.
- **Option C — Godot-3D, realistic-not-cinematic.** Ship with
  high-quality-but-honest stylized-realism art (per §7a's "Uncharted-mobile"
  bar) instead of chasing the literal "hyper-real matches references
  exactly" law — needs explicit founder acceptance that the Aesthetic Law's
  literal wording won't be hit on a mobile web build.

**My recommendation, updated:** don't wait on this to keep building — the
next graybox milestone (a chamber, or assembling the runner segment end-to-
end, see §8) needs no character art at all, same as the runner did. Decide
A vs. B vs. C whenever real character art becomes the bottleneck, not before.

### 7a. Multi-model design review (2026-09-05) — strong convergence

Dispatched per the prompt's Task 6. Raw responses:
`docs/model-responses/2026-09-05-astra-episode2-architecture.md` (strong
planner) and `…-grok-episode2-aesthetic.md` (aesthetic). Both, independently:

- **Engine → Godot 4.3 3D**, not Three.js. Deciding factor (Astra): naming
  Three.js first doesn't justify a *second* runtime/deploy/input/economy
  integration, and it buys no guaranteed fidelity — both load GLB. Keep
  `goldmine_system.gd` as economy authority; reuse mobile-input. Verify a 3D
  export on real phones early (the 2D export is not proof of 3D perf).
- **"Matches the references exactly" must be rejected as an acceptance
  criterion** (both, bluntly). The refs are offline path-traced concept art;
  a mobile-web real-time ceiling is "Uncharted-mobile / stylized realism":
  baked lightmaps, emissive gold veins + lanterns, fake volumetrics (height
  fog, dust motes, screen-space god-rays), trim sheets, budgeted GPU sparks,
  cheap bloom + color grade. Fidelity gets **approved from an actual browser
  build on agreed target phones**, never from offline renders.
- **Runner↔chamber:** persistent session root + separate runner/chamber
  scenes with explicit transition states; economy/progression live *outside*
  disposable scenes; mask swaps with a tunnel/door/fade. Guard the exact
  failure set: double-triggered rewards, stale input, duplicate player, wrong
  resume position, mobile memory pressure.
- **Character:** no reusable 3D hero exists (Ep 1 is 2D sprites). Lock a 2D
  model sheet + turnaround first; one mid-poly hero, one skeleton, shared
  runner+shooter anim set; lamp as emissive child; leaf body as clumped
  cards/stylized mass, not hundreds of animated leaflets. Image-to-3D is fine
  for **prop blockouts only** — the hero needs a human Blender pass or it
  drifts off-model.
- **Next milestone (both):** a **Godot graybox vertical slice** — short
  minecart run → one chamber (basic move/combat + one real protocol
  interaction) → return to saved track position, engine primitives only,
  clearly temporary, phone-tested, wired to the real economy constants.
  Record load/frame/memory before authorizing any art production.

**Updated recommendation (backed by both models):** **Godot 4.3 3D**, and the
next build step is the graybox vertical slice above — it needs **no Blender
and no GPU**, so it is the one substantial build task that is *not* blocked by
§5 and proves the whole loop before a dollar of art is spent. The engine call
is still yours to confirm; if you say Godot 3D, I can start the graybox slice
immediately. If you want Three.js, or want to hold for the Blender/asset
decision first, say so and I'll hold.

---

## 8. What exists after this planning session

- `artifacts/episode2-gold-mine/` scaffold (all subdirs).
- `references/IMG_2478/2479/2480` — the founder reference stills, preserved.
- `spec/FOUNDER_PROMPT.md` — verbatim brief.
- `spec/00_ARCHITECTURE.md` — this doc.
- `chambers/01..06_CHAMBER_*.md` — six 3D shooter/RPG encounter briefs, each
  citing real `goldmine_system.gd` constants.
- `.claude/skills/gm-game-episode2-gold-mine-runner/SKILL.md` — the working
  skill (the prompt's `.grok/skills/...` path does not match this harness,
  which reads `.claude/skills/`; noted, and placed where it actually loads).
- `docs/model-responses/2026-09-05-*-episode2-*.md` — multi-model design
  review.

- `spec/BLENDER_MCP_SETUP.md` + `spec/ASSET_PIPELINE.md` — the founder's
  Blender-MCP research brief and the resulting asset-pipeline decision tree
  (the community addon needs a live GUI/GPU and cannot run headless; four
  real paths incl. the official Blender-Lab background server and external
  GLB generators).
- **`src/episode2/runner/runner_graybox.{gd,tscn}` + `tests/ep2_runner_graybox_test`**
  — the first real Episode 2 build: a Godot-3D runner graybox (engine
  primitives, no Blender) proving auto-run, 3-rail switching, jump-to-clear,
  obstacle collision, and the `chamber_reached` entrance trigger + halt.
  Headless gate: 7/7 pass. This is the runner half of the loop, in code.
- **`tools/blender/build_asset.py` + `src/episode2/assets/{minecart,gold_nugget,rail_segment}.glb`**
  — the headless bpy→GLB pipeline, proven end-to-end.
  `tests/ep2_glb_pipeline_test.gd`: 7/7 pass.

### 2026-09-06 session additions (founder V2 spec + hazard model)

- **`spec/FOUNDER_PROMPT_V2_ADDENDUM.md`** — verbatim copy of the founder's
  updated spec (balaclava bears, arrows, boulders, duck/cart-jump/zip-line),
  annotated inline with what's actually true now vs. what's still open.
  `spec/FOUNDER_PROMPT.md` points to it where the two conflict.
- **3 new reference images** in `references/`:
  `IMG_2492_cart-jump_bears-arrows-boulders.jpg`,
  `IMG_2497_broken-cart_bears-arrows-boulder.jpg`,
  `REF_balaclava-bear-archer_turnaround.jpg` (recovered from the session
  transcript per the `founder-art-intake` skill — 2 of the 5 images sent
  this session were byte-identical duplicates of the existing
  IMG_2478/2479 files and were not re-saved).
- **Runner hazard model** — duck, zip-line, and the arrow/boulder hazard
  pair, per §5a. `docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md`
  (design) and `…-kimi-ep2-runner-hazards-audit.md` (code audit, found 3
  real bugs, all fixed with fail-before/pass-after regression tests).
  `tests/ep2_runner_graybox_test.gd`: 20/20 pass.
- **This doc** — corrected the stale "Blender/bpy blocked" verdict (§5),
  logged the hazard model (§5a), updated the open-questions list (§6),
  narrowed the founder-decision options to the character-asset gap only
  (§7), and this inventory (§8).

**Not done:** any organic/character GLB (hero, bears) — still needs a human
Blender pass or founder-supplied models, per §7. The **chamber half** of the
loop (a 3D shooter/RPG encounter + the persistent session root that swaps
runner↔chamber on `chamber_reached`) has no graybox yet — six chamber
*designs* exist (see above) but none are playable code. Assembling the
runner graybox's mechanics into one continuous scripted 30-60s segment
(vs. the current isolated per-mechanic test cases) also hasn't happened.
Neither needs the character-asset decision to start.
