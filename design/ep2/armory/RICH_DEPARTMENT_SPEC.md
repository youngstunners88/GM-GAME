# Rich's Armory — a dedicated shop off Main Street (department + arsenal + Utah)

status: **IN GAME (2026-10-17)** — Layer 3 + 4 + 5 landed on branch `feat/rich-armory-lock`. Every section below is
now build notes for what shipped, not a plan. Superseded decisions: the earlier draft was a Treasury counter, ammo-only,
paid in nuggets — all replaced by the founder lock. Still open: only the day-88 river set-piece itself (§9).

**Founder lock (canon): `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md`.**
Also read: `design/ep2/armory/CONVENTION.md` (personal armory — amended 2026-10-17: the Armory is the one PAID crypto source, see §7),
`design/ep2/armory/RICH_UTAH_LINES.md` (the voice-ready trade script, unrecorded), `PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md`,
`.claude/skills/ep2-surface-to-town/SKILL.md`, `.claude/skills/gm-game-gold-world/references/region-brief.md`,
`design/world/WORLD_BIBLE.md`, `src/episode2/chamber/ep2_gold_town.gd`, `src/episode2/chamber/ep2_armory_state.gd`.

**Build progress (2026-10-17).** Branch `feat/rich-armory-lock`:
`tools/ep2_blender/build_town_kit.py` defines `Bldg_Armory` (barred windows, muted `ARMS` sign, walk-in door, lean-to
loading shed) plus the interior/props (`Arm_Counter`, `Arm_Rack`, `Arm_Case`, `Arm_SniperCase`, `Arm_PowderKeg`) and
river gear (`River_Crate`, `River_Skiff`); placed down a side lane off the left row (off the Main Street sightline) in
`ep2_gold_town.gd`, dressed and furnished. The purchase contract is legalized (`GameManager.spend_coins`, CONVENTION
carve-out). The trade UI (`ep2_armory_shop.gd`) and both bodies ship — `tools/ep2_blender/build_armory_folk.py`
authors Rich and Utah headless in the in-repo Blender 5.2.1, one 20-bone skeleton and five authored clips each, played
by `Ep2TownFolk`. Gates: `ep2_gold_town_test`, `ep2_personal_armory_test`, `ep2_fort_knox_arc_test` ALL PASS.
**Still to build:** only the day-88 river set-piece (overlook, water, bears) and the voice pass.

FREEZE: no Pillar 5 / certificates / SWF. No CONFIDENTIAL items. No wallet or contract addresses.
No invented tokenomics and no invented protocol numbers.

## 1. Who — Rich, and Utah

**Rich** returns from Episode 1 education (the GOLD side; "**Rich the Claim Recorder**", voice `LNV6ahDtkAOqwn1X3R7a`).
He runs the Armory, knows Lil Blunt, is protocol-aware but practical, and has outfitted people longer than this gold
rush. Measured, world-weary, dry. He runs the sales conversation and the serious weapons (including the sniper).
He is a human cowboy. 2D source art: `src/assets/portals/companions/rich_the_claim_recorder.png`.

**Utah** is his partner in the Armory and the **river-linked character** of the day-88 sequence. Period-appropriate and
visually distinct from Rich (readable at a glance at the riverside later). Utah can demonstrate or hand over the river
gear. First proper visit: **both are present.**

Inferno Bull is not required in the Armory on the first visit (he may reappear at the river or after the purchase).

## 2. Purpose + player fantasy

The Armory is the town's **hard goods** shop: incredible period firearms, ammunition and river gear, sold for the
Episode 1 crypto Lil Blunt already carries. It is a **character location**, not the Treasury — the Treasury stays a
sovereign protocol chamber with no weapon racks. It is also the **spatial source of the day-88 river beat**: the sniper
and the river packaging are bought here, then used from a mountain overlook.

## 3. Where — off Main Street, deliberately not obvious

- **Not** on the primary street (Certificates, Saloon, Hotel, Auctions, Treasury). One block off / down a side lane or
  short side street. It should feel slightly hard-won: the **Sheriff** (after the draw), a **townsperson** (after the
  auction map), or a short **environmental clue** points the way — no giant ARMORY sign on the main drag.
- **Exterior:** weathered 1800s false-front or brick storefront, iron bars on the windows, a simple muted hanging sign
  (gun silhouette, or "**RICH & UTAH — ARMS**"). Reads quieter than the flashy protocol buildings.
- **Interior:** long counter, wall racks, glass cases, powder kegs, oil lamps, leather and brass. Dense but readable —
  stocked and dangerous, not a menu screen.
- **Build path:** a **new kit piece** in the Blender town kit (`tools/ep2_blender/build_town_kit.py`) plus a **new side
  lane** off Main Street (the living-town avenue work, `design/ep2/town/README.md`), and its own sign
  (`tools/ep2_forge/paint_town_signs.py`). Built once in `Ep2GoldTown` and drawn by both rooms at the same coordinates
  (single invisible cut, `ep2-no-blackouts`); interior only when `interiors == true`. Existing buildings and the duel
  lane keep their footprints; `Bldg_Treasury` is untouched.

Local frame (facing the door: x across the front, −z inside), measured against the built lane before placing:

| spot | local (x, y, z) | note |
|---|---|---|
| door gap | 0, 0, 0 | 0.75 half-width |
| lane approach | 0, 0, +4.0 | the side lane off Main Street |
| player spot | 0.2, 0, −3.2 | in front of the counter |
| Rich (behind counter) | −0.7, 0, −5.6 | facing the door; the sales side |
| Utah (working) | 1.1, 0, −6.4 | hauling a crate / cleaning a rifle |
| counter | 0, 1.05, −4.9 | long counter, blocks the walk |
| glass case | 1.9, 0.95, −4.9 | revolvers, on the counter |
| wall racks | back wall | rifles on racks; sniper in the lit case |
| powder kegs / cases | corners | powder, belts, accessories |

## 4. Verbs + beats

- **walk** off Main Street, down the side lane, into the Armory.
- **look** at the racks, the glass cases, the sniper, Rich and Utah, the river crates.
- **trade** (E at the counter): buy ammunition, firearms or river gear, with the Episode 1 crypto shown as the tender.
  Pauses the world like the weapon selector (`CONVENTION.md`) and never opens over a real pause.
- **leave**.

First-visit beats (from the lock §6; no fail state):
1. **Directed/find it:** after the draw (or the auction map), the tip sends Lil Blunt to the side lane.
2. **Enter:** Rich recognizes him (or sizes him up). Utah is present.
3. **Browse + buy:** ammunition; and specifically the **sniper / long rifle** for the river overlook.
4. **Seed the river:** Rich or Utah mentions a shipment that needs to move on the water, or that someone will need
   covering fire from the high ground.
5. **River gear:** Utah sells or prepares the boat / kayak / sealed buoyant packaging.
6. **Leave:** geared for the mountain + river sequence.

## 5. Inventory

Physical racks and cases in the room, not abstract UI icons alone. The **personal armory system** (quick slots, finite
ammo, FPS handling) stays the mechanical layer; the Armory is the place that feeds it.

| stock | maps to | note |
|---|---|---|
| Lever-action rifles (Winchester 1886 + variants) | `winchester_1886` | already in the personal armory |
| Single/double-action revolvers (Golden Remington 1875) | `remington_1875_gold` | |
| **Long-range sniper / scoped or open-sight rifle** | **NEW id** (e.g. `armory_sniper`) | the key day-88 purchase; period silhouette required |
| Shotguns, carbines, supporting sidearms | optional new ids | secondary stock |
| Ammunition by caliber (boxes / belts) | `rifle_round`, `revolver_round`, + sniper + shells | sold separately |
| Accessories: powder, cleaning kits, bandoliers, scopes/sights | items | era-appropriate only |

## 6. Payment — Episode 1 crypto only

Tender = **crypto Lil Blunt already collected in Episode 1** (`coins_collected` carries SOL / ETH / BTC / wBTC faces;
`ethereum_rings_collected` is the premium pickup). **No invented soft currency.** The quarter-Bitcoin whiskey already
established crypto as visible money in this town; the Armory continues that at higher stakes.

- Exact prices stay flexible for balance; the fiction is fixed (Episode 1 crypto is the tender).
- No free full loadout on first entry.
- **DECIDED (built 2026-10-17):** the tender is the crypto-flavoured score **`GameManager.coins_collected`** — the
  Episode 1 coin faces — debited through the new **`GameManager.spend_coins(count) -> bool`** (it emits
  `coins_changed`, never touches score, and refuses to overdraw). `ethereum_rings_collected` stays the unspent
  premium pickup; no second "bag" or holdings system was invented (`docs/design/economy_points_system_design.md`'s
  SCORE/holdings split is respected). The chamber owns the balance: it debits first and refunds if the state
  refuses (`gold_town.gd` `_spend` / `_refund`).

**F = feel value (free to tune).** No price, balance, percentage, APY or address is ever shown as protocol fact.

| name | value | unit | class | note |
|---|---|---|---|---|
| AMMO_PRICE_* | tune | crypto units | F | per box/belt |
| SNIPER_PRICE | tune | crypto units | F | the day-88 rifle |
| RIVER_GEAR_PRICE | tune | crypto units | F | boat / kayak / packaging |
| TRADE_PANEL_PAUSE | true | — | F | follows the weapon-selector pause |

## 7. Contract — hard rules (from the lock §8)

- **Armory ≠ Treasury.** No main weapon racks in the Treasury chamber; the Treasury stays a protocol chamber.
- Off Main Street — not the first building players see.
- Rich **and** Utah are both present for the first proper visit.
- Payment is **Episode 1 BTC / ETH / SOL only**; no invented currency.
- The **sniper** sold here is the weapon used in the mountain river-protection set-piece.
- **River gear** (boat / kayak / packaging) is sold or prepared here and used in the day-88 sequence.
- **No invented GoldMine protocol numbers** — map only existing whitepaper language when the shipment is described.
- **Preserve the personal armory system** (Winchester, Remington, ammo, pause/equip flow). This building is the
  narrative and spatial source, not a replacement. The long rifle is **not** a fourth quick-switch slot: it lives
  outside `Ep2ArmoryState.IDS` as `sniper_owned` + `sniper_rounds`, for the day-88 set-piece.
- **Strings:** the trade may show the game's own fiction — the three tenders exactly as the lock names them
  (BTC / ETH / SOL), the coin price of an item and the purse — because those are game facts the founder lock
  establishes (the town already spends crypto as money). What a player string may **never** show: an invented
  protocol number, a yield, a rate, an APY, a `%`, a `$`, a `0x` address, or a balance presented as a protocol
  fact. Spoken lines say "coin", never a ticker (see `RICH_UTAH_LINES.md`). No `GoldMineSystem` write.
- **✅ CONVENTION amendment landed (2026-10-17):** `design/ep2/armory/CONVENTION.md` now carries the carve-out —
  the Armory is *"the one PAID acquisition source"*, `purchase_firearm` / `purchase_ammo` (plus the Armory's own
  sniper/river APIs) are the only legal paid paths, and the calling room owns and debits the balance. The old
  "ownership is earned" line stands for every other source; `ep2_personal_armory_test` covers both readings.

## 8. The bodies — Rich + Utah (built 2026-10-17)

**Route change (recorded):** the Layer 4 plan assumed Tripo/Meshy multi-image-to-3d. That service is unavailable
(balance 0, no keys on this box), so both bodies were **authored on-box in the in-repo Blender 5.2.1, headless** by
`tools/ep2_blender/build_armory_folk.py` — no external calls, no textures to ship (solid material palette, ~450 KB
per GLB). Reference discipline was kept: Rich matches his existing 2D art, and a new Utah design sheet
(`captures/`) was written from the founder's Utah Drive reference before modelling.

- **One skeleton, two bodies.** Each figure is a single multi-material mesh (lofted from measured profiles) plus an
  authored armature — **20 bones** — with **procedural distance-weighted skinning** written by the script (Godot's
  `ARMATURE_AUTO` was not used). The shared skeleton drives both the mesh and the clips, so a hand prop binds to
  `Hand.L` / `Hand.R` and actually moves with the performance.
- **Authored clips are baked into the GLB** and played by `Ep2TownFolk`:
  **Rich** — `Counter` (hand on the long case, head up to the customer), `Greet`, `Idle`, `Point`, `Walk`;
  **Utah** — `Carry` (hauls the crate), `Greet`, `Idle`, `Point`, `Walk`.
  `_bind_clips()` detects a rigged GLB, `set_pose()` routes to real clips, and the statue sway/breath is skipped for
  rigged folk (the stride bob still runs while walking). Behind the counter: Rich `hold_clip("Counter")`, Utah
  `hold_clip("Idle")`; both turn to whoever walks in.
- **Props as built:** Rich holds the **claim book and brass stamp in the left hand** (his Ep1 "Claim Recorder"
  identity; bound to `Hand.L`), wears the leather duster, dark miner's helmet with brass headlamp, gold aviator
  shades, cigar, red neckerchief, GM medallion, tool belt, chaps and tall boots. Utah: brown felt hat, dark shades,
  grey goatee, open black leather jacket with **star badge**, dark vest, tooled belt with **twin low-slung
  holsters**, rope coil, charcoal jeans, two-tone boots.
- **Heights:** Rich **1.86 m** built and standing; Utah built at 1.80 m and stood at **1.74 m** by the town folk
  convention (`Ep2GoldTown` const `UTAH_HEIGHT`; `Ep2TownFolk.setup()` rescales to the requested height).
- **Voice:** Rich reuses `LNV6ahDtkAOqwn1X3R7a`; **Utah needs a new ElevenLabs voice** (pick, record the id). The
  voice-ready trade script (barks, refusals, the hand-off line) lives in `design/ep2/armory/RICH_UTAH_LINES.md`;
  none of it is recorded — the room currently speaks through the panel + HUD text quoted there. Encode barks small
  (voice 48k mono) for the pack gate when recorded.
- **Pack:** the folk GLBs carry no new textures (palette-only materials), so the 190 MiB pck gate is untouched by
  the bodies; `scripts/ep2-local-export.sh` still verifies it at export.

## 9. Day-88 river handoff (seeded here)

- The day-88 pool = the **shorter, more exposed shipment on the river** (or a lake narrowing into one); the Fort Knox
  short-pool beat in place-form (canon `design/goldmine_protocol_design.md` Pillar 2). Success = the shipment reaches
  the dock that feeds the later **288-day and 2,888-day trains**.
- Lil Blunt covers it from a **mountain overlook** with the **Armory sniper**, shooting bears that try to stop or divert
  it. The shipment rides in the **Armory river gear** (boat / kayak / sealed buoyant crates — order the exact craft in
  the river prompt).
- **Utah** is the river-linked partner who appears at the riverside. Whether Utah or Inferno Bull rides/goes with the
  shipment is **not** locked here.
- **As built (2026-10-17):** the long rifle and the river gear are real stock — `Ep2ArmoryState.SHOP` ids `sniper` /
  `sniper_ammo` / `river_gear`, state `sniper_owned` + `sniper_rounds` + `river_gear` — and the town room's last beat
  is their consequence: `GEARED` fires when Lil Blunt walks out holding the rifle, its cartridges **and** the river
  gear, and the ending payload carries `armory_visited`, `sniper`, `sniper_rounds` and `river_gear` into the next
  room. The river set-piece itself (overlook, water, bears, the craft order) is the **next** build; nothing about it
  is claimed here beyond what the counter sells.

## 10. Acceptance gate (headless + capture)

Status as of 2026-10-17 (branch `feat/rich-armory-lock`). Each ✅ names the evidence that holds it up.

- [x] Building: `Bldg_Armory` stands on a **side lane off Main Street** with a walkable door. `build_town_kit.py`
      gains the piece; `ep2_gold_town_test` walks the lane and enters.
- [x] Exclusive placement: off the main sightline; no existing building moved, the duel lane untouched
      (`ep2_gold_town_test` lane walk + placement assertions).
- [x] Rich **and** Utah present behind the counter on the first proper visit — and rigged, moving on authored clips
      (`ep2_gold_town_test` both-present + rigged-clip checks).
- [x] Inventory visible in racks/cases and purchasable: counter, wall racks, revolver case, lit long-rifle case, keg
      (`build_town_kit.py`), trade panel (`ep2_armory_shop.gd`), single-source stock (`Ep2ArmoryState.SHOP`).
- [x] Payment: purchases spend **Episode 1 crypto only** (`coins_collected`, debited via `GameManager.spend_coins`);
      no invented soft currency, no free first-entry loadout, unlisted tenders refused (`ep2_gold_town_test` +
      `ep2_personal_armory_test`).
- [x] Sniper: the long rifle is acquired at this counter for the day-88 overlook; it is not a quick-switch slot
      (`sniper_owned` / `sniper_rounds` outside `IDS`) and the ending carries it (`ep2_personal_armory_test` +
      `ep2_gold_town_test` GEARED fields).
- [x] River gear: skiff + sealed crates sold here, carried into the day-88 sequence (`river_gear`, same gates).
- [x] Treasury untouched: `ep2_fort_knox_arc_test` ALL PASS with the extended beat list; no weapon racks and no
      economy write in the Treasury chamber.
- [x] Personal armory preserved: `ep2_personal_armory_test` ALL PASS including the amended CONVENTION reading and
      the new catalogue/sniper/river/snapshot checks; no `GoldMineSystem` write anywhere in the Armory flow.
- [x] Strings: every shipped string is quoted in `RICH_UTAH_LINES.md` §2 and obeys §7 — no invented protocol number,
      no yield/`%`/`$`/`0x`/address; the panel's coin counts and the three tenders are game fiction the lock names.
- [ ] Bodies, gameplay-camera captures: Blender judgment renders of the **shipped GLBs** are in the repo —
      `design/ep2/armory/captures/` — Rich `rich_idle_front` / `rich_greet_front` / `rich_counter_three` /
      `rich_walk_three`, Utah `utah_idle_front` / `utah_idle_side` / `utah_greet_front` / `utah_carry_three`, graded
      against `utah_ref.jpg` and Rich's founder art (`rich_the_claim_recorder.png`). They are Blender renders — a true
      **in-game gameplay-camera** capture is still open on this box (the local gate script skips the xvfb render
      stage — needs apt/xvfb).
- [ ] Pack: pck under 190 MiB — re-verify at export (`scripts/ep2-local-export.sh`); the folk GLBs add no textures
      (palette-only, ~450 KB each), so no pack risk is expected.

## 11. Open questions — resolved as implemented (2026-10-17)

The lock left four questions and gave authority to resolve them by building. All four are answered; each answer is
now what the code and docs actually do.

1. **Tender — `coins_collected`, through `spend_coins()`.** The crypto-flavoured Episode 1 score pays; the chamber
   debits first and refunds on refusal; `ethereum_rings_collected` stays unspent premium pickup; no second holdings
   system was invented (see §6).
2. **Sniper — an original period silhouette, no licensed model name.** Octagon-barrel long rifle, walnut stock,
   brass tube sight (built in `build_town_kit.py`; `Arm_SniperCase`). Mechanical stats stay balance-tunable per the
   lock (line: "period silhouette is required; mechanical numbers can follow balance").
3. **Utah on the water — Utah is the riverside partner; who rides stays open.** The lock makes Utah the river-linked
   character and the founder's prompt has him appear riverside later; what rides with the shipment (Utah, Inferno
   Bull, or both) stays deferred to the day-88 river build. This room locks only the counter, the craft order and
   the send-off (scripted, unrecorded: `RICH_UTAH_LINES.md` §3).
4. **Exclusivity — positional, not gated.** The door is never locked; the shop is findable-but-off-street (side
   lane off the left row), the trade opens **only at the counter** (`_at_armory_counter()`: `Beat.ARMORY` +
   `ARMORY_TRADE_R`) and only once the tip beat has pointed the way, and buying anything requires Episode 1 crypto
   in the purse.
