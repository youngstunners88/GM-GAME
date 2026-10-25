---
name: ep2-quickdraw-duel
description: The bar draw in the GoldMine town (spec 2026-10-14 section 5) - a witnessed first-person quick-draw for "a bitcoin or the map to the auction". Staging, the read-the-tell / draw-on-the-signal mechanic, outcomes, tests. TRIGGER on "draw", "duel", "quick draw", "showdown", "the map to the auction", "give me a bitcoin".
---

# Contract (founder's file wins: PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md)

- Trigger: someone in the bar notices Lil Blunt pay a quarter Bitcoin for his whiskey.
- Demand, verbatim: "Give me a bitcoin or I give you the map to the auction where they can get more intel."
- Stakes: die and pay BTC, or kill and get the map. Bull is NOT there. the Sheriff is the witness (`ep2-sheriff-jake`).
- Outcome handling is NOT locked: build the win (the map; the opponent down; the sheriff calls it) and a lose that RETRIES the draw
  (story death is never permanent; 3-heart cap; no second health system). Bull does NOT arrive at the draw (founder 2026-10-25 section 4: Mike Dean runs out, the street celebrates, the Sheriff's job; Inferno returns after the Gatling).

# Mechanic (first person, the equipped firearm in hand)

1. Stand-off: both step out (or square up across the room), the sheriff between and to the side, calling it.
2. Tension: slow look-around allowed, the rifle lowered (low-ready pose, still in frame - `ep2-rifle-always-visible`); the opponent's
   hand hovers; heartbeat + music ducked (`ep2-voice-duck`).
3. The signal: the town bell alone (founder, 2026-10-24); the sheriff instructs both men to listen for it after a seeded random delay; drawing BEFORE it = foul (the sheriff stops it,
   redo) - never instant death on a misclick.
4. Draw: raise + aim + fire; the opponent fires after his reaction time (tuned, ~0.45-0.7 s, harder on retries is NOT allowed: keep it
   fair). A hit on him first wins. Slow-mo on the decisive shot is fine (`ep2-cinematic-cutscene` two clocks, never leaking into play).
5. Seeded and deterministic in `step(delta)` so tests drive it.

Armory: the Winchester is the default; if the golden Remington 1875 is owned (`ep2-personal-armory`), a draw is its natural moment -
never silently swap weapons.

# Tests

Foul before the signal -> redo; draw after the signal and hit first -> WIN + map item + sheriff line; too slow -> LOSE -> retry from the
stand-off with hearts restored; Bull absent until the draw started; the sheriff present throughout.


## UPDATE 2026-10-14: the man he draws against is a COWBOY, not a bear
The stranger at the bar (and the barman) are **human** and **the town has no bears** (founder: "our man who draws with Lil Blunt is a cowboy and not a bear"). `cowboy.glb` =
Tripo multiview from the Muapi sheet `fort_knox_prep/cowboy_stranger` (black flat-brim hat, charcoal waistcoat, rust-red shirt, red neckerchief, gloves, gun belt with an empty right holster, spurs),
baked with two arm poses: `Idle` (arms down) and `Draw` (gun arm out, the revolver prop `Revolver` appears in his hand). On the bell he swaps to the Draw pose; when shot he tips over (`fall_dead`).
`Ep2TownFolk` is the actor; gate `tests/ep2_gold_town_test.tscn` asserts no `Ep2Actor` / bear node exists in the town.
