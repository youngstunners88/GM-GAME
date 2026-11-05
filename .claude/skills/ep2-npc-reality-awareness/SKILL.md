---
name: ep2-npc-reality-awareness
description: Give Episode 2 characters awareness of what has really happened, so they react to the current state instead of a fixed script - the horse wounded or gone, the player hostile, day or night, who is on foot. Covers Ep2WorldFacts, tagging lines with what they need, where lasting state must live, and the gate. TRIGGER on "characters should know", "they are just bots", "he said X after that already happened", a line that contradicts the world, "shoot the horse" after it is shot, day/night awareness, any new bark or NPC line that assumes a state, or any state that must carry between rooms.
---

# Characters know what has happened

The founder's rule (2026-11-04): characters understand what changes in their reality and act on it, "so that they are not simply bots that dont
know if it's day or night". A line or behaviour that contradicts what the player can see is a bug.

## The pattern
1. **The state lives where it travels.** A fact that outlives a room belongs on `Ep2ArmoryState` (in every hand-over and in `snapshot()`/`restore()`, so
   in every save) or on `GameManager`. A field on a chamber dies with that chamber. That is exactly how the horse lost its wounds: `_horse_hp`
   was a trail variable, reset by every new room. A new save field must default to the old behaviour when an old save lacks it.
2. **`Ep2WorldFacts.now(armory, on_horse, sun, player_hostile)` is the picture of the moment.** Read it when you choose; never cache it across a beat.
   Facts today: `horse_sound`, `horse_wounded`, `horse_down`, `on_horse`, `night`, `player_hostile`. Add a fact here, not as a private flag in a room.
3. **A line says what it needs.** Add its id to `Ep2WorldFacts.LINE_NEEDS`. Choose with `Ep2WorldFacts.fitting(ids, facts)`, which keeps order and drops
   what no longer fits. Always handle an empty result: saying nothing beats saying something false.
4. **Then let them act on it,** not only talk. Logan names the shot horse and the horse will not go to the water; Dude patches it when he is brought to it.

## Worked example: the horse (founder: "they should acknowledge that")
| Where | What it does |
|---|---|
| `lake_trail._hurt_horse` | `armory.wound_horse()` |
| `lake_trail._bandit_bark` | "Shoot the horse..." needs `horse_sound`; "get him off that horse" needs `on_horse` |
| `logans_lake._on_setup` | `hurt`: stands where he got down, no drinking, no mounting. `gone`: no horse at the lake |
| `logans_lake` Beat.STAGE | Logan says `HORSE_SHOT_LINE` or `HORSE_GONE_LINE`, once |
| `gold_town` / `lake_trail._dude_treats_horse` | walking up to Dude clears it. The trail's retry and Logan's respawn are also at Dude's, so they clear it |

## Rules that come with it
- **Consequences must be escapable.** State that blocks something needs a way out in the world and a prompt that names it: "The horse is shot: it needs Dude, not water".
- **Voice:** a new line for a voiced character needs recording in that character's voice (`scripts/generate-town-audio.mjs`; `env-secrets-and-apis` on which ElevenLabs key owns it).
  Until it is recorded, `Ep2TownVoiceBank.id_for` finds no take and Logan's line shows in his text box. Barks have no text box, so a bark with no recording simply is not played. Filtering still works, because it is by id.
- **Day and night:** the game has no clock yet. `is_night(sun)` reads the room's own sun, so when a room goes dark the fact is already right. Nobody branches on `night` yet; that is the next line to write, not a feature to claim.
- Do not branch on a raw `armory.horse_wounds` in dialogue. Go through the facts, so there is one place to read what a character believes.

## Gate
`tests/ep2_horse_and_logan_test.tscn` (in CI): the state through JSON and an old save, bark filtering, trail and lake behaviour, Logan's rule, the whole loop back
through Dude's and on to the ridge. For a new line, add a check that it is absent in the reality it contradicts.
