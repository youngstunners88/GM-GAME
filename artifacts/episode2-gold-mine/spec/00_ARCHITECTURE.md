# Episode 2 — Gold Mine Runner + Protocol Chambers · Architecture

**Source of truth:** the founder prompt
`PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md` (verbatim copy in
`spec/FOUNDER_PROMPT.md`). This doc is the engineering plan derived from it.

**Status:** PLANNING. No runtime gameplay code written yet. This session
delivered: folder scaffold, reference art, the six chamber design briefs,
this architecture doc, the skill, and a multi-model design review. The
Blender/hyper-real asset pipeline is **blocked in this environment** — see
§5, which is the decision the founder needs to make before build starts.

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

## 5. ⛔ ENVIRONMENT BLOCKER — the pipeline can't run in this container

This is the decision gate. Verified this session, with evidence:

| Requirement (prompt) | Reality in this session | Evidence |
|---|---|---|
| `blender` installed | **Absent** | `which blender` → nothing |
| `blender-mcp` registered/working | **Cannot run** — bridges to a live Blender process that isn't here; the MCP is not in this session's tool set | tool list has `Three_js_3D_Viewer`, no blender MCP |
| GPU for hyper-real render | **Absent** | `/dev/dri` missing, `nvidia-smi` not found |
| `uvx` (to `uvx blender-mcp`) | Present | `which uvx` → `/root/.local/bin/uvx` |
| TRELLIS skill (prompt §2.5) | **Not in repo** | `find -iname '*trellis*'` → empty |
| `artifacts/episode2-gold-mine/` (prompt §5 "Already Created") | **Did not exist** — created this session | `ls` → not found |
| skill (prompt §5/§8 marked [x]) | **Did not exist** — created this session | `ls .grok/skills/...` → not found |

**What this means:** the prompt's step-1 ("confirm blender-mcp working") and
step-2 ("create first Blender scene") **cannot be executed here**, and no
automated pipeline in this container produces assets at the literal
"hyper-realistic, matches the references exactly" bar — the reference images
are AI concept renders, not real-time game assets. Pretending otherwise would
repeat this project's worst failure mode (claiming work that wasn't real).

**Founder decision required — pick a path (see §7).**

---

## 6. Open design questions (prompt does not specify — do NOT invent)

1. **Engine:** Three.js **or** Godot 4.3? The prompt allows either. Godot is
   already the repo's engine, has a working web-export + CI + security
   pipeline, and can do 3D; Three.js is a clean-slate 3D web path the prompt
   names first. This forks the entire build and is the founder's call.
2. **Runner controls:** auto-scroll with jump/duck + rail-switch? Tap-to-grab
   ziplines? Mobile touch + desktop keys? (Episode 1 already has a
   MobileInputHandler to reuse.)
3. **Fail/continue:** one-hit death, or health/lives? What ends a run?
4. **Chamber combat depth:** "full shooter/RPG" — what does Lil Blunt shoot
   (the prompt says pickaxe melee + shooting; what is the ranged weapon)?
   Are there enemies in every chamber or only some?
5. **Progression:** does Episode 2 unlock after the Episode 1 finale (the
   cutscenes just shipped), and is it one long run or six selectable chambers?

---

## 7. Recommended path forward (for founder sign-off)

Three honest options, cheapest-first:

- **Option A — Blender in a proper environment.** Stand up a session/host
  with Blender + GPU where blender-mcp can actually run, and do the asset
  pipeline there. Highest fidelity, matches the prompt literally, but needs
  infrastructure this container doesn't have.
- **Option B — Founder-supplied GLBs.** Founder (or a Blender artist) models
  in Blender locally, hands me clean GLBs; I own the runtime integration
  (Three.js or Godot 3D), the runner↔chamber loop, controls, and the
  protocol logic. Splits the work along the line each side can actually do.
- **Option C — Godot-3D, realistic-not-cinematic.** Build the whole loop in
  Godot 4.3's 3D renderer (already in-repo, already CI'd, already
  web-exports) with high-quality-but-honest 3D art. Ships fastest and stays
  in one engine/toolchain; does **not** hit the literal "hyper-real matches
  references exactly" bar, so it needs explicit founder acceptance of that
  tradeoff.

**My recommendation:** decide the engine first (§6.1), then Option B or C for
assets. Everything below the engine fork is built and waiting; everything
at/above it is blocked on your call.

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

**Not done (blocked or forks on the §7 decision):** any Blender scene, any
GLB, the minimal 3D movement+shooting runtime test. Held deliberately.
