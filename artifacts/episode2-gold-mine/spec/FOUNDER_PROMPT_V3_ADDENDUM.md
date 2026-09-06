# FOUNDER PROMPT V3 ADDENDUM — Episode 2 Story-First Spec (2026-09-06)

> Verbatim copy of the founder's third Episode 2 prompt
> ("Story-First Spec"), sent alongside the two runner music tracks
> (`goldmine_dreams.mp3` / `goldmine_high.mp3`, see STATUS.md). Supersedes
> V1/V2 (`FOUNDER_PROMPT.md`, `FOUNDER_PROMPT_V2_ADDENDUM.md`) on narrative
> scope — this is a story bible, not just a runner+chambers feature spec.
> Claude Code's status annotations are inline, same convention as V2.

---

# FOUNDER PROMPT — Episode 2: Gold Mine Runner + Protocol Chambers (Story-First Spec)

**GIVE THIS ENTIRE FILE TO CLAUDE CODE.**
Path: `artifacts/PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md`
This is both the **overarching story vision** and the concrete architecture Claude Code must plan against.

**Session type:** Narrative architecture + section planning + initial asset pipeline
**Lead:** Claude Code via OpenRouter (prefer latest strong planner / ChatGPT Astra class)

---

## 0. What This Document Is

This is **not** a narrow feature ticket.
It is the **story bible + creative map** for Episode 2.

Claude Code must understand from the start:

- We are turning the **Gold Mine white paper** into a living, playable narrative experience.
- Different sections of the white paper become distinct **chambers / set-pieces** inside a larger journey.
- The journey moves between **underground mine environments** and potential **above-ground / surface / frontier** landscapes.
- The first major companion is the **Inferno Bull** (Blaze-linked), but the design must leave room for **additional companions** later.
- Antagonists start as balaclava bears, but the system must support **variations of antagonism** (different enemy types, bosses, environmental threats) as the story expands.
- The overall tone shifts from pure mine-cart runner into a **Wild West 1800s / Modern Warfare-style 3D shooter** once Lil Blunt is armed and accompanied.

Claude Code's job is to plan the sections so that every white-paper mechanic feels like a natural part of this creative world, not a bolted-on menu.

---

## 1. Overarching Story Vision

Lil Blunt descends into the Gold Mine on a high-speed cart-and-zipline run.
He is hunted by masked bears that fire arrows and roll boulders.
He must duck inside carts, leap between them, and zip-line across gaps.

After the opening runner stretch he enters the first chamber.
There he meets the **Inferno Bull** — the mascot of the Inferno protocol, which is explicitly "BULLISH ON BLAZE."
The Bull hands Lil Blunt his first long gun (Winchester 1886) and fights beside him.
From this point the experience becomes a **Wild West shooter** set inside and around the Gold Mine.

As Lil Blunt pushes deeper (and eventually surfaces or moves into new biomes), each major white-paper pillar becomes a chamber or landscape:

- Mining / vesting
- Fort Knox staking + Melt
- Gold Rush auctions
- Stockpile / liquidity
- Claim Certificates
- Treasury

These are not abstract UI screens. They are **places** Lil Blunt and his companions can walk, shoot, and interact with — underground shafts, vaults, auction halls, surface stockyards, frontier offices, etc.

The design must stay open for:
- More companions (future protocol mascots or characters)
- New antagonist varieties beyond the balaclava bears
- Mixed underground + above-ground landscapes
- Escalating set-pieces that still map back to real protocol mechanics

> **✅ Story outline written this session** — `spec/STORY_OUTLINE.md`
> sequences all six pillars into one journey per this vision, with the
> underground↔frontier arc reasoned through (not arbitrary), and the
> companion/antagonist "stay open" requirement turned into concrete design
> slots (see that doc §"Companion architecture" / §"Antagonist variety").

---

## 2. Core Gameplay Modes

### Mode A — Runner (Track Sections)
- Mine carts on multi-rail tracks + overhead metal zip-lines.
- Enemies: large balaclava-wearing bears (arrows + boulder pushes).
- Player verbs: **duck** (cart shields arrows), **jump cart-to-cart**, **zip-line**.
- Camera: over-the-shoulder / from behind.
- Feel: fast, chaotic, cinematic (sparks, debris, volumetric light).

> **✅ Already built** (prior session, per `00_ARCHITECTURE.md` §5a) —
> duck/jump/zip-line and the arrow/boulder hazard pair are real, tested
> Godot-3D code (20/20 headless gate). **Now also carries real music** —
> `goldmine_dreams.mp3` / `goldmine_high.mp3` shuffle via
> `AudioManager.play_playlist()`, per this session's founder direction
> ("these 2 songs must play in the runner cart section on shuffle until
> further notice"). Gated: `tests/ep2_runner_music_test.gd`, 5/5 pass.

### Mode B — Chamber / Landscape (Wild West 3D Shooter + RPG)
- Free movement, aiming, shooting, cover, protocol machine interaction.
- First chamber introduces the Inferno Bull + Winchester 1886.
- Subsequent chambers / landscapes continue the shooter tone while delivering the white-paper mechanics as physical, interactive places.
- Environments can be fully underground or transition to surface / frontier / town-style spaces as the story requires.

> **Status: design-only, no code.** `chambers/01_CHAMBER_MINER_SHAFT.md`
> now has a full beat sheet for the Bull/Winchester introduction (see
> §"Story integration" in that file), merged with its pre-existing vesting
> mechanic rather than replacing it. Chambers 2-6 still have their original
> (pre-story-first) design briefs — the story-first framing (frontier vs.
> underground, tone escalation) is captured at the outline level in
> `STORY_OUTLINE.md` but not yet folded into each individual chamber doc.
> No chamber graybox exists — this is still "the next build step," same as
> before this session.

---

## 3. Inferno Bull Companion (First Companion)

**Protocol truth:**
Inferno is minted with TitanX, 8×24h cycles, 90% buy-and-burn. Docs state the bull is **"BULLISH ON BLAZE."** There is a real Blaze/Inferno relationship in the tokenomics.

**Story role:**
In the first chamber (gateway toward Fort Knox) the Inferno Bull appears.
He gives Lil Blunt the **Winchester 1886**, helps clear the bears, and becomes a temporary AI companion (cover fire, guidance, Western/bullish voice lines).

This is the **first** companion. The architecture must allow later companions without breaking the story or systems.

> **✅ Companion architecture designed** — `STORY_OUTLINE.md` §"Companion
> architecture" (Identity/Presence/Follow/Combat/Orders/Bark
> router/Grant table slots, Grok-reviewed). **Not implemented in code** —
> this is the design the eventual Chamber 1 graybox builds against, not a
> running system yet.

---

## 4. White-Paper → Creative Landscape Mapping

Claude Code must treat each of these as a **place** (chamber, landscape, or multi-room set-piece), not a menu:

| White-Paper Element | Creative Form (examples) | Notes |
|---------------------|--------------------------|-------|
| GOLD Mining (100-day vesting, Diamond burn) | Industrial miner shaft / underground works | Vesting as physical process, burn as visible fire |
| Fort Knox Staking + Melt | Massive fortified vault (underground or surface-adjacent) | Lock periods + melt furnace as interactive set-piece |
| Weekly Gold Rush Auctions | Auction hall / frontier town square | 7-day competition made spatial and competitive |
| Stockpile / Liquidity | Warehouse, surface stockyard, or rail depot | Matching & LP injection as physical actions |
| Claim Certificates | Formal office / claim office on the frontier | Certificate as tangible item |
| Treasury | Elegant sovereign vault or treasury building | Protocol-owned positions as viewable / light-interactable space |

Order and exact geography are flexible as long as the first chamber introduces the Bull + Winchester and the overall journey still feels like one continuous Gold Mine / frontier story.

> **✅ Sequenced** — `STORY_OUTLINE.md` puts all six in order with an
> underground/frontier justification for each (table in that doc).

---

## 5. Antagonism & Expansion Rules

- Starting antagonists: balaclava bears (arrows + boulders).
- Design must support **variations** (new enemy types, elite bears, environmental hazards, later bosses) without rewriting the core loop.
- Companions beyond the Inferno Bull are expected later; leave clean hooks (companion slot, voice, ability, visual).
- Landscapes may move between deep underground, mid-level shafts, and above-ground frontier / town / stockyard spaces.

> **✅ Antagonist behavior categories designed** — `STORY_OUTLINE.md`
> §"Antagonist variety": 4 chamber-combat behavior categories (thrower,
> melee rusher, cover camper, area-denial setter), explicitly separate from
> the runner's existing arrow/boulder hazards (which stay untouched). New
> antagonists = new art + one of these 4 patterns, not a new category per
> enemy.

---

## 6. Technical Constraints (Claude Code Web)

- Headless Blender only (`blender --background --python` or `bpy`). No GUI blender-mcp.
- Three.js for runtime / GLB.
- Hyper-realistic aesthetic matching the founder references in `artifacts/episode2-gold-mine/references/` (including `inferno_bull.png`).
- Prefer clean GLB assets.

> **Corrections, same as V2:**
> - Headless `bpy` **is proven** (prior session + re-verified 2026-09-06) —
>   not a blocker for prop-style assets. Organic/character assets (a
>   rigged Bull, rigged bears) still need a human Blender pass — bpy
>   scripting doesn't sculpt or rig.
> - **Engine is Godot 4.3 3D, not Three.js** — real work (runner graybox +
>   hazard model, GLB pipeline) is built there, backed by two independent
>   model reviews. This spec names Three.js again; it was **not** started
>   this session, consistent with V2's decision. Starting it now would fork
>   mid-build without the explicit sign-off the project's rails require.
> - **`inferno_bull.png` does NOT exist on disk.** This spec's reference
>   list claims it does (same overclaim pattern as V1's original "already
>   created" scaffold claim). Only the spec text file and the 2 mp3s
>   actually arrived as attachments this turn — no image. If the founder
>   has a Bull reference image, it needs to be sent (as an attachment, or
>   pasted inline — either lands, per this project's `founder-art-intake`
>   skill) before any Bull-specific visual work can start.

---

## 7. Immediate Planning Tasks for Claude Code

1. Internalize the overarching story above before writing any code.
2. Produce a short **Episode 2 story outline** (1–2 pages) that sequences the runner sections and chambers / landscapes, showing how each white-paper pillar appears as a place.
3. Design the First Chamber beat in detail (Bull entrance, Winchester hand-off, bear fight, exit toward Fort Knox).
4. Confirm headless Blender pipeline with a minimal GLB test.
5. Keep STATUS.md updated with Episode 2 narrative + planning progress only.

> **Task-by-task status:**
> 1. Done (this document + the design docs it points to).
> 2. ✅ `spec/STORY_OUTLINE.md`.
> 3. ✅ `chambers/01_CHAMBER_MINER_SHAFT.md` §"Story integration" —
>    8-beat sheet, merged with the pre-existing vesting mechanic.
> 4. Already proven (V2 session); re-confirmed still true, no new test
>    needed since nothing about the pipeline changed.
> 5. ✅ `STATUS.md` updated this session.

---

## 8. Hard Rules

- Lil Blunt is the only playable protagonist. Companions are AI / narrative support.
- Never invent Gold Mine protocol numbers or mechanics.
- First chamber = Inferno Bull + Winchester 1886 + transition into Wild West shooter.
- Architecture must stay open for more companions and antagonist variety.
- Environments can be underground, transitional, or above-ground as the story needs.
- Aesthetic fidelity to the founder references is law.
- Claude Code owns the repo and STATUS.md.

---

## 9. Success Criteria for This Planning Phase

- [x] This document gives Claude Code the full story vision + concrete constraints.
- [x] Written Episode 2 story outline exists that maps white-paper sections to creative places.
- [x] First Chamber (Bull + Winchester) is fully designed.
- [x] Headless Blender path is proven.
- [x] Room is clearly left for additional companions and antagonist variations.

> **All five now checked** — the last two ([ ] in the original) were
> already true (Blender proven V2 session) or completed this session
> (companion/antagonist design slots in `STORY_OUTLINE.md`). This is
> planning completion, not implementation completion — no chamber code
> exists yet; see §2 status note above.

**The gold rush is a story. The white paper becomes places. The Bull is bullish on Blaze. Plan the journey first, then build the mine.**

---

*References on disk:*
`artifacts/episode2-gold-mine/references/IMG_2478_rear_cart.jpg`
`artifacts/episode2-gold-mine/references/IMG_2479_zipline_rear.jpg`
`artifacts/episode2-gold-mine/references/IMG_2492_cart-jump_bears-arrows-boulders.jpg`
`artifacts/episode2-gold-mine/references/IMG_2497_broken-cart_bears-arrows-boulder.jpg`
`artifacts/episode2-gold-mine/references/REF_balaclava-bear-archer_turnaround.jpg`
`artifacts/episode2-gold-mine/references/inferno_bull.png` — **does not exist, see §6 correction above.**

*Protocol sources:* Gold Mine white paper + docs.inferno.win (Inferno "BULLISH ON BLAZE").
