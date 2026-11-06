---
name: ep2-world-common-sense
description: The founder's standing rule (2026-11-05) that the game world obeys common sense even where no brief spelled it out - people do not walk through each other or a praying minister, doors open before anyone goes through, a character does not walk away and straight back, a shot man falls off his raft, a shot raft takes damage. Use BEFORE building or changing ANY character movement, NPC route, dialogue staging, door, vehicle, prop, enemy, hit reaction or cutscene, and when reviewing one. TRIGGER on "stupid", "makes no sense", "walks through", "doors don't open", "nothing happens when I shoot it", "why would he do that", "use your logic", "I shouldn't have to tell you".
---

# The world obeys common sense

The founder (2026-11-05): "This is so stupid." He should never have to specify that a door opens, or that a man who is shot falls off his raft. **A brief describes what is special. Everything it leaves out still behaves as it would in the real world.** Silence in a brief never means "skip it".

"It runs and the test passes" is not done. Done means a player watching would believe it.

## Founder's reported examples: never ship these again
| What he saw | The broken logic | What should happen |
|---|---|---|
| People walk through Minister Mike Dean while he prays | Routes ignore who is standing there and what he is doing | They go round him and leave room. A praying man is not interrupted or walked into |
| Inferno, back from Blondie, walks to Lil Blunt beside the minister, says "let's grab a whiskey", walks to the quad, then walks back to ask the minister what happened | Beats play in script order, not in the order a person would think | He asks what happened while he is standing there, and only then goes for the whiskey |
| Saloon doors do not swing; people walk through them | The door is scenery, and the route ignores it | The doors swing for anyone going through, then settle back |
| Shot bandits stay on the raft | The death plays in place, with no regard for what he stands on | He falls into the water, and the raft carries on without him |
| Bullets do nothing to the raft | It is scenery, not a thing in the world | Hits show and register. It takes damage and can fail |

These are the founder's reports, recorded as examples. Check the current code before assuming any one is still open or already fixed.

**Built 2026-11-06 (branch `claude/ep2-common-sense-fixes`, not founder-verified):** all five are in code, with one shared system
each: `Ep2TownPeople.keep_clear` (the story cast as crowd obstacles), `GoldTownChamber._bull_body_spot` and `_bull_way_to` (Inferno talks
where he meets Lil Blunt and never walks back past a mark), `Ep2SwingDoor` (one door behaviour), and the raft's `Ep2CreatureHealth`
together with `RiverCoverChamber._overboard`. Gate: `tests/ep2_common_sense_test.tscn`. ADR: `docs/architecture/adr-ep2-common-sense-world.md`.
Still open in the same families: scripted actors (`Ep2Actor.walk_to`) do not avoid one another. A trail rider who is shot drops through
his saddle in one frame before sliding off (`lake_trail.gd`). The office and shop doorways have no leaves at all.

## The five questions: ask them before calling anything done
1. **Would a real person do this, in this order?** Remove pointless trips. Say the thing where you stand. Finish one errand before starting the next. Nobody turns around for no reason.
2. **What is physically in the way?** People, furniture, doors, animals and vehicles are solid. Nothing passes through anything, and nobody stands inside or floats above anything.
3. **What does this interact with?** A door opens. A chair is sat on. A horse is mounted from beside it. Hands reach what they hold. Whatever a character stands on matters when he dies.
4. **What happens if the player does the rude thing?** Shoot it, stand in its way, walk off mid-line, come back later, do it twice. Every visible thing needs an answer. A bullet that hits something with no reaction is a bug.
5. **Does everyone see the same world?** Characters react to what is true now: someone praying, a man down, gunfire, a dead horse. Use `ep2-npc-reality-awareness` for lasting facts.

## The same check by kind of thing
- **Moving characters:** avoid other people, and leave room around anyone who is praying, talking or working. Walk to a spot that makes sense for what they do next.
- **Conversations:** walk up, stop, face each other, talk, then leave. Nobody talks to empty air or walks away mid-sentence.
- **Doors and gates:** anyone going through opens them, player or not. Routes go through doorways, never walls.
- **Vehicles, rafts, mounts:** riders move with them. A dead rider comes off. A dead mount drops its rider. Damage to it shows.
- **Anything shootable:** impact, reaction, then consequence. Death suits the place: into the water, off the ledge, down the stairs.
- **Objects:** what is picked up leaves its old place, and what is dropped lies on the ground. Nothing pops in where the player can see.

## How to work
1. **Before building:** list what the brief leaves out, using the questions above, and build that too. Only ask the founder when the answer truly could go either way. Common sense is never a question for him.
2. **When you find one case, look for its family.** A door that does not swing means checking every door. Fix the shared system, not one instance, or he will report the next one.
3. **Watch it played.** Capture the whole action in the real game, not a still of the end pose (`see-it-yourself`). Ask of the capture: would a player find this stupid?
4. **Test the behaviour, not the code path.** Assert what a player would see: over the whole route, no walker comes within a body's width of the minister; the door angle changes as someone passes; the bandit ends up off the raft; the raft's health falls when hit. Confirm the check fails with the fix removed.
5. **Report what you did not check.** "I only tested the player's path, not the townsfolk" is useful. Silence is not.

## Limits
- Common sense does not override a founder lock or a story beat. If the two conflict, follow the lock and flag it.
- Fill gaps in the task you are doing. A logic bug you notice elsewhere gets reported, not silently folded into your diff. Fix it only if it is small and in code you are already touching.
- Humans stay on their own story systems. Weed content stays positive and chill. Common sense never adds gore or a new enemy type.
