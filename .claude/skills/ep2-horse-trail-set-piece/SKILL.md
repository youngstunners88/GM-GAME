---
name: ep2-horse-trail-set-piece
description: PLAN for the stable purchase and the ride-and-shoot trail to the auction (half a Bitcoin horse, bandits shooting him off it, horse-down fail branch, arrival). Not built yet - use it before writing the stable, the horse viewmodel or the trail chamber. TRIGGER on "buy the horse", "stable yard", "ride and shoot", "unhorse", "trail to the auction", "mounted combat", "horse set-piece".
---

# Stable + trail set-piece (ep2-horse-trail-set-piece) - PLANNING SKILL, nothing built

Locked by the Jack Hammer lock (`ep2-jack-hammer-narrative`): half a Bitcoin buys the horse at the Episode 2 surface stable; on the trail bandits try to shoot him off it; he arrives at the auction (mounted by default). Same size class as the **day-88 river mountain cover** - a bounded set-piece chamber, not an open-world horse RPG. Do not invent horse mechanics beyond that: no taming, no breeding, no stamina economy, no horse staking/LP/yield.

## Stable (small)
- Where: the Episode 2 surface stable (`gm-game-ep2-surface-set`: the old `feat/ep2-surface-set` lake/train/stable/horses work; **do not replace the 3D horses** - `Ep2TownLife` keeps them). One yard, one stable hand folk (`Ep2TownFolk`, `ep2-town-people` pipeline), one horse standing ready.
- Buying: a trade card like the Armory's (`ep2_armory_shop.gd`, `ep2-personal-armory`): price from `Ep2JackHammer.HORSE_PRICE_BTC`, tender BTC only, `Ep2JackHammerArc.buy_horse()` decides, the caller debits the Episode 1 purse; refusal line `jh_hand_refuse`; sold line `jh_hand_sold`. **Ruled 2026-10-21:** one BTC coin face = one Bitcoin; the stable takes one face and gives half a Bitcoin back as change (`Ep2JackHammerArc.buy_horse_with_face`). The trail ends at the edge of a second settlement in the next town.
- Autonomy for the hand: `ep2-armory-npc-autonomy` pattern, minimal (idle, greet, point to the horse).

## Trail (the set-piece)
- A `Ep2Interlude` chamber (the story-room base, `src/episode2/chamber/interlude_base.gd`): a fixed route (a spline) he rides at a speed he steers a little (lane offset), first-person with the Winchester / Remington / bow still selectable (`ep2-fps-shooter-feel`, personal armory rules: finite ammo, no free refills).
- Pressure: bandit riders / ambushers (`Ep2BearBrain` aware/telegraph patterns are the closest model; barks `jh_bandit_*`), telegraphed shots with a visible tell, a hit meter on the horse and on him. "Off the horse" = the unhorse event, not instant death (the game keeps the 3-heart cap rule).
- Fail branches (the Doc keeps them light): `Ep2JackHammerArc.lose_horse()` -> he finishes on foot; the arrival card changes (`jh_arrive_foot`), delay is recorded (`arrive(delay_s)`). No game over for losing the horse.
- No blackouts (`ep2-no-blackouts`): build the trail chamber behind the stable (`prebuild_requested`), swap in one frame.
- Pack: everything new streams (`ep2-streamed-extras-web`, `src/episode2/extras/`); the main pack margin is ~175 KB.

## Gates to add when it is built
Trail chamber test (route, bandits fire with a tell, unhorse + on-foot branch, arrival result carries `jack_hammer`), stable test (refuses short tender, one horse, no free), presence gate entries, live probe. Update `ep2_fort_knox_arc_test` if a town beat is added.
