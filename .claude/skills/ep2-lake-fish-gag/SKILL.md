---
name: ep2-lake-fish-gag
description: The huge-fish comedy beat at Logan's Lake (founder 2026-11-28) - when Lil Blunt has Logan fishing in clear view, an absurdly oversized fish bursts out on one side of the skiff, sails over Logan's head and belly-flops in on the other side with two splashes; Logan flinches and keeps fishing; once per visit. TRIGGER on "huge fish", "fish jumps over Logan", "splash at the lake", "the fish gag spams / never fires", or edits to src/episode2/art/ep2_lake_fish_gag.gd.
---

# The huge fish (flavour, never gameplay)

## Files
- `src/episode2/art/ep2_lake_fish_gag.gd` (`Ep2LakeFishGag`) - primitive cartoon fish (`LENGTH` 2.8 m: olive back, cream belly, gold
  flank stripe - Logan's "liquidity" - goggle eyes, "O" mouth, forked prism tail that thrashes), parabolic arc in **boat space**
  (child of `Ep2LoganSkiff.boat`), two splashes (CPUParticles3D droplets + an expanding foam ring + `extras/audio/river/body_splash.ogg`
  when the streamed pack has it). Advanced by the lake's delta, so hidden rooms and the armory pause freeze it.
- `src/episode2/chamber/logans_lake.gd` - `_tick_fish_gag`, `fish_gag_in_view()`, `_fire_fish_gag()`; constants `FISH_GAG_RANGE` (42 m),
  `FISH_GAG_CONE` (~30 deg), `FISH_GAG_LOOK` (0.6 s steady view). `fish_gag_fired` is re-armed only in `_on_setup` (a new visit).

## Rules
1. Fires only when `Ep2LoganSkiff.is_fishing_settled()` (rod up, bobber down) and the boat has been in view for `FISH_GAG_LOOK` with
   player control. One-shot per visit: camera wiggles never re-fire it.
2. The arc is centred over `head_local()` and peaks `~0.95 m` above his head centre: a near miss, never a hit, never clipping him.
3. Logan reacts with `flinch()` (lean back + boat rock, 1.1 s) and stays in FISH. No VO line unless a recorded take exists
   (founder no-subtitles rule: an unrecorded line would show a box).
4. Nobody catches it. No prompt, no Tabs/purse item, no stats. The lake lock's "a fish is pure flavour for a second" is the frame.
5. Comedy scale is the point - do not "fix" it to a realistic trout.

## Proof
`tests/ep2_logan_fishing_test.gd::test_logan_lake_huge_fish_jumps_once_with_splash` and the default run of
`tools/ep2_shots/logan_fishing_shot.tscn` (frames 02-07: out, rising, over head, down, belly-flop, back fishing).
