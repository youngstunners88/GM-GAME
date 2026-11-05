# Wildlife and creature combat (founder 2026-11-05)

The spec named in the work order (`PROMPT_EPISODE2_WILDLIFE_VULTURE_BISON_CREATURE_COMBAT_2026-11-05.md`) was not on disk; this was built to the work order's Definition of Done.

Gate: `tests/ep2_wildlife_combat_test.tscn` (count pinned, in CI). Shots: `tools/ep2_shots/wildlife_combat_shot.tscn`. Captures: `docs/captures/wildlife-combat/`. Audio: `python3 tools/ep2_audio/synth_wildlife.py` writes `src/episode2/extras/audio/trail/`.

## Who owns hit points

| Creature | Lives in | Why |
|---|---|---|
| Vultures, bison, town and yard horses | `Ep2CreatureHealth` child node | Nothing else needs their state |
| Lil Blunt's own mount | `Ep2ArmoryState.horse_wounds` | It travels through rooms and saves; a second counter could only drift from it |
| Bears | Their own brain | Story state, searchable corpses, arrows and retry rules, with their own gates |
| People | Their own systems | Founder rule |

## Rules a change must keep

- The stampede raises no toast, banner, objective or map change. "TRAMPLED!" is damage feedback and stays. The gate fails if any of them comes back (checked by restoring each original line).
- The music duck carries its own timer, so tearing a herd down mid-charge cannot leave the music muted.
- `Ep2Stampede.step()` keeps running after `finished`: the fallen must finish falling and survivors must run out of sight.
- Town and yard horse models face +X, so their roll is the X axis. Trail and lake horses have a root facing +Z, so their roll is the Z axis. Using the wrong axis stands a dead horse on its nose.
- A dead yard horse loses its prop row AND its `YardBody` collider.
- `Ep2TownLaw` targets horses through `Ep2CreatureHealth.HORSE_GROUP`. A name match alone catches the model's inner `HorseRig`, which has no health, so the horse can never die.
- The flock is silent until the room sets `listener`, because rooms are prebuilt behind the current one.

## Known gaps

- A chasing bandit's horse has no hit capsule: bullets pass through it (`_bandit_ray_hit` covers only the rider above the saddle).
- The road cart's donkey (`Ep2RoadCart`) and the woods songbirds (`Ep2Wildlife`) have no shot path. The donkey also carries the farmer's journey, so killing it is a story decision.
- Town and yard horse deaths are not saved: a reload restores them. Lil Blunt's own mount does persist.
- The fallen trail horse's saddle is still the old boxy prop, which looks crude from behind.

## Not tested

Audio was checked by loudness and spectrograms, not by ear. The motion was judged from stills and measured stride numbers, not watched in play.
