---
name: ep2-logans-lake
description: Build Logan's Lake - the Episode 2 liquidity still-water, Logan as the liquidity-provider face, Lil Blunt INVESTIGATES (no fishing), one stage/protect interaction, handoff into the day-88 river (founder lock PROMPT_EPISODE2_LOGANS_LAKE_LIQUIDITY, 2026-10-18). TRIGGER on "Logan", "Logan's Lake", "liquidity", "still water", "LP face", "investigate", "stage the depth", the lake feeding the river, or before reporting this beat done.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Logan's Lake (Episode 2 surface, liquidity beat)

Source: Google Doc `1N5tfMsKgjMUSGY5MqI1EcGYejLd23m4IPIH7mP1IplY` ("PROMPT_EPISODE2_LOGANS_LAKE_LIQUIDITY"). Read it again at the start; quote it in the ledger (`ep2-design-verify`) and never paraphrase a rule weaker. One-line lock: **Logan holds the depth. Lil Blunt investigates. The river runs from the still-water. Fishing stays out.**
Companions: `ep2-logan-character` (the model), `ep2-lake-water-build` (the water + dock + outflow), `ep2-narrative-canon`, `ep2-layered-production`, `ep2-interlude-chain`, `ep2-founder-intake`.

## The nine rules, as testable statements
1. Lake != town Stockpile building (`artifacts/episode2-gold-mine/chambers/04_CHAMBER_STOCKPILE_DEPOT.md` is the formal chamber: pairing rig, BURN / LP INJECT). Do not build burn/LP routing, pairing or raiders here.
2. No fishing verb, no cast/catch, no fish item or XP, and Logan fishing is never the centre of the beat. A fish is allowed only as a one-second bank flavour prop.
3. Lil Blunt's verb is investigate; Logan's is provide / stage / protect.
4. The lake hands off to the day-88 river (shipment leaves the still-water). The river overlook, Utah, sniper and bears are NOT built here.
5. No invented protocol numbers: no %, fees, APR, weekly timers, token formulas, soft currency. Canon constants live in `design/goldmine_protocol_design.md` Pillar 4 (`STOCKPILE_LP_MATCH_PCT`); this beat shows the idea only.
6. Home is the Episode 2 surface path. Never Level 3 (`src/level/distant_lake.gd` stays untouched).
7. One strong visit. No Logan campaign, no multi-quest.
8. Preserve Rich Armory, surface-to-town draw, Utah river link, Fort Knox downstream locks (and "no Diamonds" in Episode 2: `ep2-fort-knox-arc`).
9. STATUS.md names Logan's Lake as an Episode 2 surface location, Logan as the LP face, and says it is not Level 3 content.

## What already exists (verified against master `1f81ead2`)
- **No Episode 2 lake on master.** A scenery lake (rect x 42-184, z 1030-1380 beside the ride road, `lake_water.gdshader`, `Ep2SurfaceSet`) exists only on unshipped `feat/ep2-surface-set` (`d6891958`, worktree `~/Documents/GitHub/GM-GAME-ep2set`). On master: the scenery river (22 m ribbon at z 1522, `water_river.gdshader`, `Ep2TownLife`) and the railway (z 1546).
- **Old Still Water card CONFLICTS with the lock:** `design/world/regions/11_still-water-lake.md` + `design/ep2/lake/WIRE_SPEC.md` (draft, gated on a founder target image that never came) give the player a `fish/wait` verb, a 100-notch vesting pole, 60/40 basins, a "20% sinks" shard drop (diamond shards: forbidden in Episode 2), Bull absent, and no Logan. Treat the new lock as superseding verbs and beat; reuse only geography/assets (dock, mist, train on the horizon, water shader). **Do not implement the old wire spec.** Founder decision #1 below.
- Chain: `Ep2SessionRoot.CHAMBER_SCENES` (`ep2_session_root.gd:35`) -> `woods_quad` -> `gold_town`; a chamber resolves with `next_chamber` or `end_session`. `gold_town.gd` Beat.DONE currently ends the slice: `{"end_session": true, "to_be_continued": true, ... "river_gear": armory.river_gear}` (~line 604), and `tests/ep2_gold_town_test.gd` asserts that.

## Placement in the story (founder: "as the founder sequences")
Recommended, because the lock says do not force the armory after the lake and the river follows the gear: `gold_town` (GEARED) -> **`logans_lake`** -> (future) river. Concretely: GEARED/DONE resolves `next_chamber: "logans_lake"` carrying the same keys; the lake resolves `end_session` + `to_be_continued` with its own keys (`lake_investigated`, `depth_staged`, `river_ready`) until the river chamber exists. Re-point the gold-town ending test to the lake (a new capability, not a loosened check). Alternative (ask first): lake before the town on the desert approach. Founder decision #2.

## Build shape
- New `src/episode2/chamber/logans_lake.gd` (+ `.tscn`), `class_name LogansLakeChamber extends Ep2Interlude` (first person, Winchester/armory viewmodel as every story room; **never** a third-person follow camera). Register in `CHAMBER_SCENES`; `prebuild_requested.emit("logans_lake")` from gold-town's late beats so the hand-over is one cut, no black (`ep2-no-blackouts`).
- Beats (proposal): ARRIVE -> MEET -> INVESTIGATE -> STAGE -> HANDOFF -> LEAVE, driven by `FacilityShow` steps (`say` with `id` + `len`, `walk`, `face`, `wait`, `call`) so the headless test plays the whole beat with `step(dt)`.
- **The one interaction** (STAGE) - options, recommend A:
  - A. *Stage the marker crate*: Lil Blunt sets one sealed crate/marker at the staging post on the shore (`River_Crate` kit piece already ships); Logan confirms the depth holds and the outflow can run. Works whether or not he bought river gear (Logan's line varies on `river_gear`); never spends the crypto purse.
  - B. *Clear the drain*: move one drift snag blocking the outflow so the shore does not drain; shows "protect".
  - C. *Confirm a contribution already earned*: avoid - drifts into soft currency / numbers.
- Dialogue: short, grounded, slightly proprietary ("this depth stays deep"), not a cartoon fisherman. Write every line in `design/ep2/lake/LOGAN_LINES.md` first (as `design/ep2/armory/RICH_UTAH_LINES.md` does), then `assets/audio-manifest.json` ids `vo_logan_*`. No voice key on this box: text + subtitles ship, VO stays unrecorded and says so. Teach through contact (why the pool matters, why you do not empty it, how it feeds the river), per `gm-game-portal-educator-dialogue`.
- Logan model/rig/clips: `ep2-logan-character`. Water, dock, shore, outflow channel into the existing river: `ep2-lake-water-build`.

## Gates (write them first; each maps to a success box in section 11 of the lock)
`tests/ep2_logans_lake_test.tscn`: chamber exists and resolves into the chain; Logan present on arrival; investigate dialogue plays; exactly one stage interaction and it changes state; **negative tests** (no input action or verb named fish/cast/catch, no fish item, no `%`/APR/"weekly" in any Logan or lake string, no "diamond"); result keys carry the handoff; Stockpile building untouched (`LAYOUT` unchanged); the existing armory, draw and Fort Knox tests still pass. Run the pinned Godot 4.3 headless, then `scripts/ci-gates-local.sh`, then `scripts/pack-gate-fresh.sh`.

## Proof and ship
Ledger rows IN CODE / WIRED / SEEN / SHIPPED. SEEN = real captures from the Episode 2 camera at eye height (arrival, Logan at the shore, the stage action, the outflow leaving toward the river), saved under `docs/episode2-quality/logans-lake-<date>/`; judge look against `Logan.JPG` and the founder's references with `ep2-reference-match-loop`. Worktree per branch (suggest `feat/logans-lake`); the user runs `scripts/ship-to-master.sh`; verify CI + butler + `[BUILD]` tag before saying live. Vault: log in `GM Game/Work Log/<date>.md` + a Projects note.

## Founder decisions to ask (do not guess)
1. Does Logan's Lake supersede the old Still Water region (verbs, beat) or sit beside it? (Recommend: supersede; keep geography.)
2. Chain slot: after the armory gear (recommended) or on the approach before the town?
3. Look: the Logan image is a **southern bayou** (cypress, Spanish moss, rowboats); the lock says calm **Western** surface. Match the picture or the desert?
4. Pack: Logan + lake need bytes and the margin is ~467 KB; which visible art may be trimmed, if any? (`ship-visual-proof`: never trim silently.)
5. Does Logan appear later at the Stockpile building? (Lock: optional, not this pass.)
