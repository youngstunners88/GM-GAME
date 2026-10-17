# Rich's Armory — a dedicated shop off Main Street (department + arsenal + Utah)

status: draft for founder review (2026-10-17). Layer 2 of `ep2-layered-production` (wire spec).
No code, no assets yet. Superseded decisions: the earlier draft was a Treasury counter, ammo-only, paid in nuggets —
all replaced by the founder lock.

**Founder lock (canon): `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md`.**
Also read: `design/ep2/armory/CONVENTION.md` (personal armory — amended 2026-10-17: the Armory is the one PAID crypto source, see §7),
`PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md`, `.claude/skills/ep2-surface-to-town/SKILL.md`,
`.claude/skills/gm-game-gold-world/references/region-brief.md`, `design/world/WORLD_BIBLE.md`,
`src/episode2/chamber/ep2_gold_town.gd`, `src/episode2/chamber/ep2_armory_state.gd`.

**Build progress (2026-10-17).** Layer 3 started on branch `feat/rich-armory-lock`:
`tools/ep2_blender/build_town_kit.py` now defines `Bldg_Armory` (barred windows, muted `ARMS` sign, walk-in door,
lean-to loading shed) plus the first interior/props (`Arm_Counter`, `Arm_Rack`, `Arm_Case`, `Arm_SniperCase`,
`Arm_PowderKeg`) and river gear (`River_Crate`, `River_Skiff`); `town_kit.glb` rebuilt; placed down a side lane off
the left row (off the Main Street sightline) in `ep2_gold_town.gd`, dressed and furnished. The purchase contract is
legalized and tested. **Still to build:** the armory chamber + Rich/Utah bodies + trade UI, the sniper, and the day-88
river set-piece.

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
- **Open:** which exact counter is the tender (crypto-flavoured score `coins_collected` vs a true "bag" holding) — see
  `docs/design/economy_points_system_design.md` (it separates SCORE from protocol holdings). To confirm before coding.

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
  narrative and spatial source, not a replacement.
- No token balance / price / yield / `%` / `$` / `0x` / ticker in any player string; no `GoldMineSystem` write.
- **⚠ CONVENTION amendment needed:** `design/ep2/armory/CONVENTION.md` says *"ownership is earned"* and the armory
  never grants ammunition from a camera. Selling firearms for crypto contradicts that line. The lock wins, but the
  convention (and its tests, e.g. `ep2_personal_armory_test`) must be amended explicitly before the buy-a-sniper flow
  is built — otherwise the purchase will fight the existing contract.

## 8. The bodies — Rich + Utah (Layer 4 + 5 plan)

Work in `youngstunners88/GM-GAME`, not an isolated Blender file (`smokerealm-episode2-art`).

- **Reference (Layer 3 first):** Rich — his existing 2D art; Utah — a new design sheet (Tripo / Meshy / Blender).
  Generate front/side/back renders as Meshy multi-image inputs so the models match the art.
- **Model (Layer 4):** `ep2-meshy-studio` — multi-image-to-3d (Meshy-7 PBR) → remesh ~30–40k → `shrink_glb.py`
  (`--max 1024 --aux-max 256`) → `glb-shot.mjs` contact sheet → look before placing. Rich: long duster, wide hat, worn
  leather, brass ledger + stamp. Utah: period, leaner silhouette, distinct palette so the riverside read is instant.
- **Rig + clips (Layer 5):** `ep2-character-performance` — `idle`, `counter_idle` (hand over the case), `greet`; a
  `carry` for Utah hauling the crate. Prop contacts (ledger, a brass round, the rifle) must actually meet the hand.
- **Integration:** two `Ep2TownFolk` behind the counter, height ~1.78 (Sheriff convention), static with a stride bob
  unless a full idle ships.
- **Voice:** Rich reuses `LNV6ahDtkAOqwn1X3R7a`; **Utah needs a new ElevenLabs voice** (pick, record the id). Write
  3–5 trade barks each through `ep2-voice-barks`; encode small (voice 48k mono) for the pack gate.
- **Pack:** new textures `compress/mode=1` and FORCE-ADD their `.import` (`*.import` is gitignored); pck under
  190 MiB (`scripts/ep2-local-export.sh`).

## 9. Day-88 river handoff (seeded here)

- The day-88 pool = the **shorter, more exposed shipment on the river** (or a lake narrowing into one); the Fort Knox
  short-pool beat in place-form (canon `design/goldmine_protocol_design.md` Pillar 2). Success = the shipment reaches
  the dock that feeds the later **288-day and 2,888-day trains**.
- Lil Blunt covers it from a **mountain overlook** with the **Armory sniper**, shooting bears that try to stop or divert
  it. The shipment rides in the **Armory river gear** (boat / kayak / sealed buoyant crates — order the exact craft in
  the river prompt).
- **Utah** is the river-linked partner who appears at the riverside. Whether Utah or Inferno Bull rides/goes with the
  shipment is **not** locked here.

## 10. Acceptance gate (headless + capture)

- [ ] Building: a new armory kit piece stands on a **side lane off Main Street** with a `0.75` door; walk-in, no blackout.
- [ ] Exclusive placement: off the main sightline; Main Street keeps its buildings and its clear duel lane.
- [ ] Rich **and** Utah present behind the counter on the first proper visit.
- [ ] Inventory: the period weapon array + ammunition is visible in racks/cases and purchasable.
- [ ] Payment: purchases spend **Episode 1 crypto only**; no invented soft currency; no free first-entry loadout.
- [ ] Sniper: the long rifle is acquired here and is the weapon used in the day-88 overlook set-piece.
- [ ] River gear: boat/kayak/packaging is obtained here and used in the day-88 sequence.
- [ ] Treasury untouched: no weapon racks, no trade, no economy write in the Treasury chamber.
- [ ] Personal armory preserved: `ep2_personal_armory_test` (and its amendment) passes; no `GoldMineSystem` write.
- [ ] Strings: no digit, `%`, `$`, `0x`, ticker or address in any armory trade string.
- [ ] Bodies: gameplay-camera captures of Rich + Utah graded against their references (`ep2-reference-match-loop`).
- [ ] Pack: pck under 190 MiB after the models + clips land.

## 11. Open questions for the founder

1. **Tender:** which Episode 1 counter pays — the crypto-flavoured score (`coins_collected`: SOL/ETH/BTC faces) or a true
   holdings "bag"? (the economy doc separates the two)
2. **Sniper:** a specific real 1800s rifle (e.g. a Sharps/Buffalo or a scoped Winchester) or an original period silhouette?
3. **Utah on the water:** Utah, Inferno Bull, or both (Utah bank / Bull on the water)?
4. **Exclusivity:** just set apart on the lane, or **door gated** until Lil Blunt is armed / has the tip?
