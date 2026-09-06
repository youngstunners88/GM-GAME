# FOUNDER PROMPT V2 ADDENDUM — Episode 2: Gold Mine Runner (2026-09-06)

> Verbatim copy of the updated spec the founder sent this session (as
> `PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md`), plus 5 inline
> reference images. Where this conflicts with the original
> `spec/FOUNDER_PROMPT.md`, this V2 wins. See that file's header note.
>
> **Claude Code's status annotations are marked like this** — inline,
> immediately after the section they apply to — so the verbatim spec below
> stays intact and the "what's actually true right now" read stays honest.

---

# FOUNDER PROMPT — Episode 2: Gold Mine Runner + Protocol Chambers (FINAL)

**GIVE THIS ENTIRE FILE TO CLAUDE CODE.**
This is the single source of truth. Path: `artifacts/PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md`

**Session type:** Architecture + planning + initial asset pipeline
**Lead:** Claude Code via OpenRouter (prefer latest strong planner / ChatGPT Astra class)

**Graphics & Asset Drivers (updated for Claude Code web constraints):**
- **Headless Blender** (NOT the GUI blender-mcp socket). Use `blender --background --python script.py` or `pip install bpy` + pure Python.
  Confirmed working path inside Claude Code web sandbox (no GPU, no persistent GUI, no custom MCP loading).
- **Three.js** for runtime / web prototype / GLB loading.
- Optional for hyper-realistic organic assets: external text-to-3D APIs (Meshy / Tripo / Rodin) once network allowlist permits.
- Reference research: headless GLB export works; geometry + PBR materials + export need no display/GPU.

> **✅ CONFIRMED, re-verified this session.** `pip install bpy` (bpy 5.0.1)
> imports and exports a real GLB headlessly in this container — no GUI, no
> GPU, no blender-mcp socket needed. This was already proven in a *prior*
> session (commit `2069198`, `tools/blender/build_asset.py` →
> `src/episode2/assets/{minecart,gold_nugget,rail_segment}.glb`, all three
> import into Godot 4.3 with real meshes, gate `tests/ep2_glb_pipeline_test.gd`
> 7/7 pass). This session re-ran the raw bpy cube→GLB smoke test standalone
> to confirm it's still true, independent of the existing pipeline script.
> **What's still NOT true:** "hyper-realistic 3D cinematic quality matching
> the founder reference images exactly" for organic/character work. bpy
> scripting is proven for primitive-geometry props (carts, rails, nuggets)
> with clumped/boxy proxy meshes — it is not a path to a hand-sculpted,
> rigged, hyper-real Lil Blunt or bear character. That still needs a human
> Blender pass or founder-supplied GLBs, per the skill's rail #3 and the
> architecture doc §7a's multi-model review (both models independently said
> the same thing before this spec arrived).

**Aesthetic Law (NON-NEGOTIABLE):**
Hyper-realistic 3D cinematic quality matching the founder reference images exactly.
Reference images are stored at:
`artifacts/episode2-gold-mine/references/`
- `IMG_2478.jpeg` — rear view in mine cart (core runner camera)
- `IMG_2479.jpeg` — zip-line travel from behind
- `IMG_2492.jpeg` + `IMG_2497.jpeg` — action shots with enemies

Lil Blunt = green leafy cannabis character, copper miner hard-hat with glowing headlamp, leather work gear, pickaxe, often with cigar.
Mine carts with cannabis-leaf gold emblems. Multi-rail tracks, wooden beams, glowing gold veins, lantern light, sparks, volumetric lighting, motion, dust, flying debris.
Hyper-realism required in **both** runner and chamber modes. Lower-quality or cartoon outputs are rejected.

> **📸 Reference images — actual file state.** The spec names IMG_2478/2479
> (already on disk from a prior session, unchanged) and IMG_2492/2497 as
> new. Five images arrived inline in this session's chat (not as files on
> disk anywhere — recovered from the session transcript per the
> `founder-art-intake` skill). Two were byte-identical duplicates of the
> existing IMG_2478/IMG_2479 files (same reference art re-sent). The three
> genuinely new ones are saved as:
> - `IMG_2492_cart-jump_bears-arrows-boulders.jpg` — Lil Blunt leaping
>   cart-to-cart, 3 balaclava bears on a bridge firing arrows + pushing
>   boulders, daylight gold lighting.
> - `IMG_2497_broken-cart_bears-arrows-boulder.jpg` — a shattered cart mid-
>   collapse, 2 bears (one drawing a bow) on rock ledges, cooler blue-lit.
> - `REF_balaclava-bear-archer_turnaround.jpg` — isolated enemy character
>   reference on white, bow drawn, miner-helmet + red bandana + tool belt.
>
> **Also confirmed, per §2's honest bar (architecture doc §7a):** these are
> still offline path-traced concept renders, not real-time game assets. They
> lock down enemy design (bear identity, gear, arrow/boulder threat) — they
> do not become the in-game art via any pipeline available in this
> container. The Aesthetic Law's literal "matches exactly" is still rejected
> as a real-time acceptance bar by both prior multi-model reviews; the
> honest target remains "Uncharted-mobile / stylized realism," approved from
> an actual browser build, never from these renders.

---

## 1. Core Vision

Episode 2 is the **Gold Mine Runner**.

The entire episode is built around a continuous underground gold-mine track system. Gameplay alternates between two distinct modes:

### Mode A — Runner (Track Sections)
- Lil Blunt rides mine carts on multi-rail tracks and uses overhead metal zip-lines.
- **Enemies are large bears wearing balaclavas.**
  - They fire arrows at Lil Blunt.
  - They push boulders down the tracks to crush him.
- Lil Blunt must:
  - **Duck** inside the mining cart so the cart walls shield him from arrows.
  - **Jump from cart to cart**.
  - **Zip-line from line to line**.
- Camera is over-the-shoulder / from behind (exact match to references).
- Fast, cinematic, high-speed, chaotic feel with flying rocks, arrows, sparks, and collapsing track sections.

### Mode B — Chamber (3D Shooter / RPG Style)
- When the track leads into a chamber entrance, the game **switches into full 3D hyper-realistic shooter / RPG mode**.
- Lil Blunt has free movement, can aim and shoot, use pickaxe as melee, interact with protocol machines, fight enemies if present, and complete the chamber objective.
- This is a real 3D action/RPG encounter that still teaches and executes the real Gold Mine protocol mechanic.
- After the chamber objective is complete, Lil Blunt exits back onto the tracks and Mode A (Runner) resumes.

This runner ↔ chamber loop is the spine of the whole episode.

**Goal:** Make the Gold Mine protocol feel real, visitable, and exciting. Drive attention and on-chain activity for $GOLD / Diamonds / related assets.

> **✅ IMPLEMENTED this session (graybox, engine primitives, no art) —**
> `src/episode2/runner/runner_graybox.gd`. Duck / jump / zip-line and the
> arrow/boulder hazard pair are real, tested code now, per the design
> reviewed in `docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md`
> and audited in `docs/model-responses/2026-09-06-kimi-ep2-runner-hazards-audit.md`:
> - **Arrow** hazard: cleared ONLY by a held duck (≥0.10s, prevents
>   one-frame cheese) — jumping does NOT clear it (a flying projectile still
>   hits an airborne rider).
> - **Boulder** hazard: cleared ONLY by jump-height or lane-switch — ducking
>   does NOT clear it (it crushes low). Same rule as the pre-existing "box"
>   obstacle.
> - **Zipline**: a boolean mode over a scripted z-range (a different plane
>   of movement, not a fourth rail) — while active, lane-switch/duck/jump are
>   no-ops and cart-phase hazards don't apply (you're off the rails).
> - Bear enemy *behavior* (positioning, aim, boulder-push animation/timing)
>   is not yet modeled — only the hazards they'd produce (arrow/boulder
>   entities on the track) exist. The bears themselves are still a design
>   reference, not a spawned entity.
> `tests/ep2_runner_graybox_test.gd`: 16/16 pass (7 original + 9 new).

---

## 2. Technical Stack (Forced — Updated for Web Sandbox Reality)

1. **Headless Blender**
   - Install via apt or `pip install bpy` (PyPI is allowlisted).
   - Build assets with Python scripts: geometry, Principled BSDF materials, then `bpy.ops.export_scene.gltf(filepath='xxx.glb')`.
   - Command pattern: `blender --background --python build_asset.py`
   - No GUI, no socket MCP, no persistent process. One atomic script per asset.

2. **Three.js** — runtime rendering, GLB loaders, rapid web prototypes.

3. **Claude Code** owns the repo, STATUS.md, commits, and final integration.

4. Optional hyper-real organic assets: external text-to-3D APIs (Meshy etc.) once network is set to Custom/Full and the host is allowlisted.

**Pipeline:**
Founder reference images → Headless Blender Python scripts (or external 3D API) → clean GLB → Three.js or Godot 4.3 → polish.

> **⛔ Three.js — NOT authorized, still.** This spec names Three.js first
> again. The skill's rail #4 and the architecture doc §7a (two independent
> model reviews) both say: Godot 4.3 3D, not Three.js — a second runtime
> buys no fidelity (both load the same GLBs) and costs a second
> deploy/input/economy integration for no gain, and real build work (the
> runner graybox, the GLB pipeline, both headless-gated) is already sitting
> in Godot 3D. Starting Three.js now would fork the engine mid-build without
> the explicit founder sign-off the skill requires. **Nothing in Three.js
> was started this session.** If you want Three.js specifically — not just
> "a 3D web runner," which Godot already delivers — say so explicitly and
> we'll re-plan; otherwise Godot 4.3 3D stays the path and the existing
> graybox is what gets built on.

---

## 3. Runner Enemy & Traversal Spec (Critical)

**Enemies (must match updated images):**
- Large anthropomorphic bears wearing black balaclavas / ski masks.
- Armed with bows; fire arrows at Lil Blunt.
- Push large boulders onto the tracks to destroy carts and crush the player.
- Positioned on elevated wooden platforms, cliffs, and track-side ledges.

**Player responses:**
- **Duck** — press control to drop low inside the current mine cart. The cart walls block incoming arrows.
- **Jump cart-to-cart** — leap between adjacent or sequential mine carts on parallel or branching rails.
- **Zip-line** — grab overhead metal cables/hooks when no cart is available or to cross gaps / avoid boulder zones.
- Collectibles and boosts remain available during the chaos.

All of the above must feel weighty, readable, and cinematic (sparks under wheels, motion blur, flying debris, volumetric light shafts).

> **Status: hazard rules implemented (see §1 annotation above); "weighty,
> readable, cinematic" feel/juice is NOT — that's real art/animation/VFX
> work, blocked on the same organic-asset gap as the hero character.**
> Bear *entities* (spawn, positioning on ledges, aim/push behavior) are not
> yet built — only the arrow/boulder hazards they'd create. Enemy AI is a
> separate implementation pass, not covered by this session's hazard-model
> work.

---

## 4. Protocol Chamber Mapping (White Paper → Game)

Every chamber is a **3D hyper-realistic shooter/RPG space** that maps exactly to the real Gold Mine white paper. No invented economics.

| # | Chamber | White Paper Element | Chamber Gameplay (Shooter/RPG) |
|---|---------|---------------------|--------------------------------|
| 1 | **Miner Shaft** | GOLD Mining (100-day vesting @ 1%/day, 20% permanent Diamond burn, early claim forfeits unvested) | 3D industrial chamber. Start miner, choose payment (ETH/Diamonds), defend/interact while vesting progresses, optional early claim. |
| 2 | **Fort Knox Vault** | Fort Knox Staking + Melt Bonus (locks up to 2,888 days, melt up to 3× for up to 1,000% share multiplier) | Massive fortified vault. Stake GOLD, choose lock length, feed GOLD into Melt furnace under possible combat pressure. |
| 3 | **Gold Rush Auction Hall** | Weekly 7-day auctions for XAUT | Grand hall. Deposit GOLD into the live auction pool while dealing with threats or timers. |
| 4 | **Stockpile Depot** | Gold Stockpile / Liquidity | Warehouse. Match forfeited GOLD with wBTC, decide burn vs LP injection. |
| 5 | **Claim Certificate Office** | Gold Claim Certificates (0.5 XAUT + 22,000 Fort Knox shares) | Formal office. Claim non-transferable certificate if requirements met. |
| 6 | **Treasury / Sovereign Vault** | Protocol Treasury & concentrated liquidity (Phase 2) | Elegant treasury. View/interact with protocol-owned positions. |

Detailed notes live in `artifacts/episode2-gold-mine/spec/01_CHAMBER_*.md` … `06_CHAMBER_*.md`.
Claude Code must expand each of those files with the full 3D shooter/RPG encounter description.

> **✅ Already done, prior session** — `chambers/01_CHAMBER_MINER_SHAFT.md`
> through `06_CHAMBER_TREASURY_SOVEREIGN_VAULT.md` exist, each mapped to
> this exact table and citing the real `goldmine_system.gd` constants. No
> new chamber design work landed this session — the new spec's chamber
> table is unchanged from V1, and it already matches what's on disk.

---

## 5. Asset Priorities (First Sessions)

1. **Lil Blunt** fully rigged (miner helmet + headlamp + pickaxe + cigar) with:
   - Runner animations: cart ride, duck, jump cart-to-cart, zip-line hang/travel, land.
   - Shooter/RPG animations: aim, shoot, melee, interact.
2. **Mine Cart** with cannabis-leaf gold emblem (exact match to references) — empty and gold-filled variants.
3. **Zip-line trolley / cable system**.
4. **Balaclava Bears** (enemies) with bow, arrows, and boulder-pushing pose.
5. **Boulders**, broken rails, wooden platforms, arrows as projectiles.
6. One complete Runner Segment (30–60 s) featuring the full duck / jump / zip-line / arrow / boulder loop.
7. One complete Chamber in full 3D shooter/RPG form (start with Miner Shaft or Fort Knox).
8. Environment kit: rock walls with gold veins, wooden beams, multi-level rails, lanterns, hanging ore baskets, gold piles, dust, sparks.

All assets must be hyper-realistic and export as clean GLB.

> **Status:** #2 (mine cart), partial #5 (rail segment, gold nugget as a
> stand-in collectible) exist as real GLBs already (prior session). #1
> (rigged hero), #4 (bears) need a human Blender pass — not startable here.
> #6 (a full runner segment with the loop) is now buildable in graybox form
> given this session's hazard/duck/zip work — the *gameplay* for it exists;
> assembling it into one continuous scripted 30-60s segment with real
> pacing is the next graybox step, not yet done. #7/#8 untouched this
> session.

---

## 6. Folder Structure

```
artifacts/episode2-gold-mine/
├── spec/                 ← architecture + chamber docs
├── assets/               ← exported GLBs
├── blender/              ← headless Python build scripts
├── threejs/              ← prototype loaders
├── chambers/
├── runner/
└── references/           ← founder images (IMG_2478, 2479, 2492, 2497 already placed)

.grok/skills/gm-game-episode2-gold-mine-runner/SKILL.md
```

> **Note:** actual asset-build scripts live at `tools/blender/build_asset.py`
> (not `artifacts/episode2-gold-mine/blender/`) and the working skill is at
> `.claude/skills/gm-game-episode2-gold-mine-runner/SKILL.md` (this harness
> reads `.claude/skills/`, not `.grok/skills/` — noted in the architecture
> doc since the prior session).

---

## 7. Immediate Tasks for Claude Code (Execute in Order)

1. Confirm headless Blender works: install via apt or `pip install bpy`, then run a minimal cube → GLB export test and commit the result.
2. Place / verify the four founder reference images in `artifacts/episode2-gold-mine/references/`.
3. Write the first headless Blender Python script that builds a gold-mine tunnel segment + single mine cart + Lil Blunt rear-view placeholder matching IMG_2478. Export GLB.
4. Expand every chamber design doc so it describes the full 3D shooter/RPG encounter.
5. Produce a minimal Three.js (or Godot 4.3) test that loads a GLB and supports basic third-person movement + duck/jump.
6. Update STATUS.md with Episode 2 planning status only. Do **not** touch Episode 1 residuals.

> **Task-by-task status:**
> 1. ✅ Re-verified this session (raw bpy smoke test); was already proven
>    prior session with the real asset pipeline.
> 2. ✅ Done — see §"Reference images" annotation above (3 new + 3 pre-existing).
> 3. Not done this session — no new Blender scene was built (the existing
>    minecart/rail_segment/gold_nugget GLBs from the prior session already
>    cover the prop side of this ask; a "tunnel segment + Lil Blunt
>    placeholder" specifically was not attempted).
> 5. ✅ Godot 4.3 (not Three.js, see §2 annotation) — the runner graybox
>    already supports third-person auto-run + duck/jump, extended this
>    session with the hazard/zipline work.
> 6. This document + `STATUS.md` (updated this session) cover it.

---

## 8. Hard Rules

- Lil Blunt is the only playable protagonist and the only companion voice.
- Never invent protocol numbers or mechanics. Visualize only what the white paper states.
- **Chambers = full 3D hyper-realistic shooter/RPG mode.**
- **Runner = cart + zip-line + duck + jump-cart-to-cart, under fire from balaclava bears pushing boulders and shooting arrows.**
- Aesthetic fidelity to the four founder reference images is law. Hyper-realism required throughout.
- Prefer GLB assets produced by headless Blender scripts (or approved external 3D APIs).
- Claude Code owns the repository and STATUS.md.
- Do not rely on GUI blender-mcp or any custom MCP server inside the web sandbox — they are not loaded.

---

## 9. Success Criteria

- [x] This file is the single clear prompt Claude Code can be given.
- [x] Reference images are in `artifacts/episode2-gold-mine/references/`.
- [x] Chambers defined as 3D shooter/RPG.
- [x] Runner enemies and traversal (bears, arrows, boulders, duck, cart-jump, zip-line) are specified.
- [x] Headless Blender GLB pipeline proven with a test export.
- [ ] First runner segment + first chamber design exist.

> **Corrected checklist, honestly, as of this session:**
> - Headless Blender GLB pipeline: **proven** (prior session + re-verified
>   this session).
> - First runner *segment*: hazard/duck/zip **mechanics** proven in graybox
>   (16/16 headless tests); assembled into one continuous scripted 30-60s
>   segment: **not yet**.
> - First chamber design: **exists** (all six, prior session) as design
>   docs; a playable chamber graybox (the "next build step" the skill and
>   architecture doc both point to): **not yet**.

**The gold rush has begun. Build the mine that players will actually want to ride — and fight inside while dodging arrows and boulders.**

---

*References (already on disk):*
- `artifacts/episode2-gold-mine/references/IMG_2478_rear_cart.jpg`
- `artifacts/episode2-gold-mine/references/IMG_2479_zipline_rear.jpg`
- `artifacts/episode2-gold-mine/references/IMG_2480_action_jump.jpg`
- `artifacts/episode2-gold-mine/references/IMG_2492_cart-jump_bears-arrows-boulders.jpg`
- `artifacts/episode2-gold-mine/references/IMG_2497_broken-cart_bears-arrows-boulder.jpg`
- `artifacts/episode2-gold-mine/references/REF_balaclava-bear-archer_turnaround.jpg`
- Official Gold Mine white paper
- Headless Blender research (direct `blender --background --python` / bpy path)
