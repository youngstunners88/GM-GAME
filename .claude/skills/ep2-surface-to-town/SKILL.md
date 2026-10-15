---
name: ep2-surface-to-town
description: The founder's LOCKED surface-to-town sequence (2026-10-14) - quad ride out of the woods (bears thin out near town), Inferno leaves "to see a Blondie", the certificate office with the Sheriff, the bar (whiskey, a quarter Bitcoin, the draw, the sheriff as witness), Inferno arrives after the draw. READ FIRST for any work on the end of the quad ride, the town, the certificate office, the bar, the Sheriff, the draw or Bull's departure / return. TRIGGER on "town", "ride out of the woods", "certificate", "sheriff", "Jake", "JakeX", "TitanX", "bar", "saloon", "whiskey", "quarter bitcoin", "draw", "duel", "Blondie", "map to the auction".
---

# The file that wins

`PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md` (repo root, the founder's words verbatim, 2026-10-14). It **supersedes** "immediate town
arrival" and "direct Fort Knox express". It **preserves** the runner, the smelting-facility meeting, the Winchester hand-off and the
current quad beats (`ep2-interlude-chain`, `ep2-living-woods`). Everything after Bull reaches the bar is open. When this skill and the
file disagree, the file is right. Founder references: `artifacts/episode2-gold-mine/references/founder_2026-10-13_town/`
(`goldmine_town_target.jpg` = the look we ride toward, `founder_2026-10-14_cast/` = the Sheriff and Minister Mike Dean art).

# The locked beats -> where each lives in the game

| # | Beat (spec section) | Build it as | Notes |
|---|---|---|---|
| 1 | Surface exit + quad ride, bears attack, Lil Blunt shoots them | `woods_quad.gd` RIDE beat **as built** | No change to the combat. Bears THIN OUT toward town (fewer pickets in the last third, none in the last ~250 m). 1-2 distant riders / walkers who never interact. No meetings on the trail. |
| 1b | Out of the woods into gold-rush country | the road leaves the old growth: pines thin, dry hills, mesas, dust, golden hour | Look: `ep2-gold-rush-town`. One continuous road, no cut (`ep2-no-blackouts`). |
| 2 | Bull's departure: a Blondie to see, meet at the bar for a whiskey, get the sheriff to get you a certificate | **Founder 2026-10-14: Bull DROPS Lil Blunt off IN the town and RIDES OFF on the quad.** His line on the quad as they roll into town, the quad stops in the street, Lil Blunt hops off (eye glides down, no cut), Bull rides away down the street (engine fades) - still the ONE quad (`ep2-fort-knox-arc` rule 6: it is Bull's, not spent yet) | His FIRST deliberate disappearance. **Founder 2026-10-14: he is not running errands for Blondie - he is going to sleep with her.** Play it as a grown-up wink in his line (a grin, "a lady friend who's been waiting on me"), never shown, nothing explicit on screen; no other reasons explained (reputation without exposition). |
| 3 | Certificate office + the Sheriff | town chamber, building "CERTIFICATES" from the target image | the Sheriff + Minister Mike Dean = `ep2-sheriff-jake`. He DIRECTS (certificate path / next step); certificate mechanics faithful to the whitepaper, not resolved here; never invent protocol numbers. |
| 4 | Bar, Lil Blunt alone: orders a whiskey, pays a QUARTER Bitcoin, someone notices | saloon chamber | The payment is the visible spark. No extra tokenomics. |
| 5 | The draw: "Give me a bitcoin or I give you the map to the auction where they can get more intel." Die and pay BTC, or kill and get the map. The sheriff is his witness. | `ep2-quickdraw-duel` | Win = the MAP (to the auction: later, `ep2-fort-knox-arc` rule 5 "the Auction waits"). Lose = retry (never a permanent death; 3-heart cap). |
| 6 | Bull arrives after the draw starts / ends | Bull walks in | What he says / does is NOT locked - leave it for the next pass. |

# Rules

1. First person, the Winchester in his hands everywhere (CLAUDE.md shooter rule). Story rooms extend `Ep2Interlude`.
2. One motion: each hand-over is built behind the current room and swapped in one frame (`ep2-no-blackouts`).
3. Bull is NOT present at the certificate office or the early bar. Do not have him talk over those scenes.
4. No Diamonds mechanic (`ep2-fort-knox-arc` rule 4): the DIAMONDS mine in the town image is scenery the founder has not opened -
   leave its sign out until he says otherwise.
5. Lines: Inferno `uWE48TmsTuIjyh2ifoNL` (speed 1.2), Lil Blunt `HMGfKwZCRujgXyRDUW0b`; the Sheriff, Minister Mike Dean and the bar opponent need their
   own ElevenLabs voices (pick, record the id in the manifest note). Weed content stays positive; the cigarette is the founder's
   cast lock for the Sheriff and Minister, not a drug gag.
6. Another session (Codex) may be building part of this at the same time: before building, `git fetch`, read every new codex/* and master
   commit touching the woods / a town, and BUILD ON IT (CLAUDE.md parallel-session rule 3: keep both features).
7. The spy-on-the-bear-camp ending of the woods predates this lock. The ride now heads to TOWN; keep the camp as scenery the road passes
   (or move it) but the slice no longer ends at the spyglass unless the founder says so. Update `tests/ep2_fort_knox_arc_test.gd` and
   `tests/ep2_interlude_test.gd` with the new order, not around it.

# Done

Tests per beat (sequence, who is present, the line ids, the draw outcomes), real first-person captures of every beat graded against
`goldmine_town_target.jpg` (`ep2-reference-match-loop`), STATUS.md pointing at the spec file, then `always-ship-live`.

## Implemented (2026-10-14, after Codex d6e32b1)
- Woods: `WoodsQuadChamber` beats `SNEAK, REVEAL, MOUNT, RIDE, DROPOFF, DONE`; RIDE_TRAIL runs on to `Ep2GoldTown.DROP_POINT`; road pickets stay in the
  wood (`PICKET_ROAD_LEN`); `_grade_desert` warms the light by road distance; DROPOFF = Bull's two lines, Lil Blunt's eye glides off, Bull rides off
  (`_bull_ride_off`), then `next_chamber: gold_town` once the town is prebuilt.
- Shared set: `src/episode2/chamber/ep2_gold_town.gd` (layout, kit materials, signs, collision, `build_desert` - deterministic, so both rooms draw the
  same scrub/rocks/mesas), kit `tools/ep2_blender/build_town_kit.py`, signs `tools/ep2_forge/paint_town_signs.py`.
- Town room: `src/episode2/chamber/gold_town.gd` (`GoldTownChamber`): STREET, OFFICE, TO_BAR, BAR, SQUARE_UP, DRAW, WON, DONE. the Sheriff =
  `src/episode2/assets/town/sheriff_jake.glb` (Tripo multiview, decimated to 9k faces / 1K textures for the pack budget), static with a stride bob.
- Gate: `tests/ep2_gold_town_test.tscn` (in CI). Captures: `tools/ep2_shots/town_beats_shot.tscn`, `tools/ep2_shots/town_shot.tscn`.
- Pack budget: keep new textures `compress/mode=1` and FORCE-ADD their `.import` (`*.import` is gitignored; without it CI imports lossless).

- **No bears in town (founder 2026-10-14).** The stranger, the barman, the Sheriff, the farmer are all human; bears live in the woods only (pickets stop at the last pines). The farmer's donkey cart is on the
  road before town (`ep2-road-donkey-cart`); Bull's companion behaviour is `ep2-bull-companion-pacing`; the founder's Drive models are baked per `ep2-founder-model-bake`.
