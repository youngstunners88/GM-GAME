# Rich & Utah — the Armory trade script

**Status: UNVOICED (2026-10-17).** No voice key is configured on this box, so none of the lines below are recorded
audio — the Armory trade currently speaks through on-screen text only (the leather/brass trade panel and the HUD
objectives/toasts), and every string that actually ships is quoted verbatim in §2. The dialogue in §3 is the
recorded pass, written now so a later voice session reads it verbatim against the built performances
(`Rich.Counter` / `Utah.Counter` hold clips, `tools/ep2_blender/build_armory_folk.py`).

Founder lock: `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md` · wire spec: `RICH_DEPARTMENT_SPEC.md` · conventions:
`CONVENTION.md`.

## 1. Voice plan (when a key exists)

| who | voice | note |
|---|---|---|
| **Rich** | reuses `LNV6ahDtkAOqwn1X3R7a` | his Episode 1 "Rich the Claim Recorder" GOLD voice — same man, same drawl |
| **Utah** | **to be picked** (new) | older, drier, river-worn; record the id here when chosen |

- Files land as `ep2_rich_armory_<beat>.ogg` / `ep2_utah_armory_<beat>.ogg`, voice-grade 48 kHz mono, trimmed tight —
  the pack has a 190 MiB gate (`scripts/ep2-local-export.sh`) and the trade is a small room.
- Trigger points are already wired as text beats: counter entry (`Beat.ARMORY`), each purchase
  (`buy_requested` → `buy()`), each refusal (`purchase_result(false)` → panel flash), leave (`_close_shop`),
  and the `GEARED` hand-off. A voice pass replaces or layers those strings; it does not need new gameplay beats.

## 2. Shipped strings (exact text, single-sourced)

Panel (`src/episode2/chamber/ep2_armory_shop.gd`) — every word here is live in the build:

| where | text |
|---|---|
| title | `RICH & UTAH` / `ARMS` |
| tender bar | `TENDER: EPISODE 1 CRYPTO  ·  BTC  ·  PURSE 3` (tender cycles BTC / ETH / SOL) |
| price | `3 BTC` (price + chosen tender, from `Ep2ArmoryState.SHOP` — never the label's own arithmetic) |
| owned | `OWNED` |
| can't afford | `NOT ENOUGH CRYPTO` |
| flashes | `SOLD` · `NOT ENOUGH CRYPTO` · `NOT FOR SALE` |
| stock lines | `LONG RIFLE — SET TRIGGER - FOR THE OVERLOOK` · `LONG-RIFLE CARTRIDGES — A BOX OF TEN` · `REPEATER CARTRIDGES — A BOX OF TWENTY-FOUR` · `SIXGUN CARTRIDGES — A BOX OF EIGHTEEN` · `RIVER GEAR — SKIFF AND SEALED CRATES` |

HUD (`src/episode2/chamber/gold_town.gd`):

| beat | text |
|---|---|
| TIP objective | `Rich keeps an armory down the side lane off the left row. Find it.` |
| TIP toast | `AN ARMORY DOWN THE SIDE LANE` |
| ARMORY objective | `Trade with Rich at the counter [E].` |
| GEARED objective | `Geared for the river. TO BE CONTINUED.` |
| GEARED toast | `ARMED FOR THE RIVER SHIPMENT` |

**String rules that bind the recorded lines too** (lock §5 + spec §6):

- **No invented GoldMine protocol numbers.** When the shipment is described, map only existing whitepaper language.
- Prices and the purse are the game's own coin counts (feel values, free to tune). No line or label states a yield,
  rate, APY, `%`, `$`, `0x` or an address.
- The three tenders are named exactly as the lock names them — BTC / ETH / SOL — and only on the panel.
- **Spoken lines say "coin", never "Bitcoin"/"crypto"/tickers.** The town already treats the coin as money (the
  quarter-Bitcoin whiskey); the mouths use the town's word, the panel shows the tender.
- Rich never promises "free"; every line prices the iron.

## 3. The recorded pass (read verbatim)

Counter entry — Lil Blunt walks in past the barred windows:

1. **RICH** — "You found the lane. Most don't."
2. **UTAH** — "River rises tomorrow. Something rides it down."
3. **RICH** *(hand on the long case)* — "Iron's on the wall. Coin's the only tongue I take."

Buying the long rifle:

4. **RICH** — "Set trigger. It reaches clean across the water."
5. **UTAH** — "From the high rocks you'll see the whole bend. Take the high rocks."

Buying cartridges:

6. **RICH** — "Lead's sold by the box. It never comes cheap and it never comes free."

Buying the river gear:

7. **UTAH** — "Skiff's sound, crates are sealed. She'll ride wet and ride heavy."

Refusals — no coin, or the wrong coin:

8. **RICH** *(wrong tender)* — "That don't spend here. Bring the coin you earned."
9. **UTAH** *(purse too light)* — "Come back when the purse sits heavier."

Leaving without buying:

10. **RICH** — "Mind the lane on the way out."

The `GEARED` hand-off (both, as the room hands him to the day-88 build):

11. **UTAH** — "Be on the overlook by first light. I'll be at the water."
12. **RICH** — "And bring it back empty. That's how I know it worked."

## 4. Not yet written

- Threat barks, bear lines at the river, and anything past the hand-off belong to the day-88 river build — they are
  **not** scripted here.
- Utah's casting (voice id) is the only open casting call. When it lands, record it in §1 and the spec's §8.
