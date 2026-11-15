---
name: ep2-npc-conversation-flow
description: How every Episode 2 talking NPC behaves - speaks on sight (never E-only), keeps speaking while the player trades/buys/mounts, stops politely or rudely if the player walks away, stays short. Covers Rich, Utah, Dude (stable), Logan (lake), Mike Dean and the auctioneer. Use for any dialogue, greeting, trade UI, speech-vs-UI conflict, or "slows down while talking" bug. TRIGGER on "keep speaking", "shouldn't prevent his speech", "wait for him to finish", "optional to speak", "once he sees Lil Blunt", "lingers", "rude", "goodbye", "glitching while speaking".
argument-hint: "audit <npc> | fix <npc> | slowdown"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Conversation flow rules (founder 2026-11-15)

> "When Rich is speaking while the player has pressed E to trade he needs to keep speaking. The trade shouldn't prevent his speech."
> "Don't make Lil Blunt wait for Dude to finish speaking before being able to mount. Once he pays he should be able to mount."
> "If Lil Blunt leaves while he's speaking Dude should say that's rude and goodbye."
> "Don't make Dude linger his speech so much. Don't make it optional to speak with Dude. Once he sees Lil Blunt the conversation should commence. The same goes for Logan."

## The five rules
1. **Auto-greet.** When the NPC sees the player (distance + facing/line of sight, a small cone), the greeting starts. E is for trade and extra info only. Fire once per visit; re-arm after the player has left the zone and returned.
2. **Speech and UI are independent.** Speech is a track on the voice player and the dialogue sequencer. Opening trade, tabs, a case view or a shop never pauses, cancels, restarts or ducks-then-forgets it. The UI must not call the sequencer's stop, clear the queue, or set a "busy" flag the line checks. Audio ducking follows `ep2-voice-duck`.
3. **Actions never wait for the line.** Paying, buying, picking a horse, mounting: available the moment the player is able. The line keeps playing over it or yields gracefully (a half-sentence finish, not a cut-off beep). Never gate a verb behind "speech finished".
4. **Leaving mid-line.** If the player walks past a leave radius (with hysteresis so a step back does not flap), cut the current line at a phrase boundary, then play one short exit line: Dude, rude and goodbye ("That's rude, partner. Fine, goodbye."). Unique to each NPC's voice; one line; do not replay the greeting.
5. **Short.** Each speech is as few lines as it takes. Greetings: 1-2 sentences. Lessons (Logan): exactly 3 sentences. Cut filler and repeated pitch. Pauses between lines are tuned, not default timers.

## Implementation checklist
- Find the single owner of the speech state: the NPC's dialogue state enum (or the sequencer) per file in the fix pack. If speech state is a stage enum that the shop also writes (e.g. `ep2_armory_intro.gd` stage vs `ep2_armory_shop.gd`), split them: shop state and speech state are separate fields.
- Replace `if talking: return` guards on buy/mount/trade with checks on the real precondition (paid, near, stock).
- Greeting trigger: Area3D or distance + view test in `_process`, with a `_greeted` latch and a cooldown. Not an interact-gated function.
- Leave handling: a `_speech_abort(reason)` that stops the voice player, clears the pending lines, plays the exit line once, then returns to idle.
- Dude: `ep2_stable_yard.gd` (`DUDE_VOICE`, `GREET`, `dude_ranch_*`, `RIDE_MOUNT`, `MOUNT_SECONDS`, `horse_bought`). Mount must follow `horse_bought` immediately.
- Logan: `logans_lake.gd` (`_logan`, `LOGAN_MARK`, talk/greet near L234). Greeting starts on sight; the liquidity lesson is exactly 3 newbie sentences: what a liquidity provider is (you put two coins in a pool so others can trade), what "still water" means here (a deep, calm pool means trades barely move the price), and why depth matters (more depth, less slippage, and fees go to the providers). Plain words, no jargon unexplained. Re-record the clips (`ep2-voice-id-lock`).
- Rich/Utah: line lengths set in `ep2_armory_intro.gd` (`SHARPS_LINES`, `SHARPS_REACH`, `SHARPS_TALK`).

## "Everything slows down" (item 2c)
A slowdown that starts at the conversation is a code smell, not a feel. Measure first: run the scene, record frame ms in the 3 s before talk, during the greeting, during trade. Likely causes to rule out: IK or pose solve running every frame at high cost during `ep2_armory_pose.gd`, a per-frame node search or `get_nodes_in_group`, shaders recompiling when the case lid opens, voice decode on the main thread, duplicated tweens stacking each time E is pressed, `_process` plus `_physics_process` both advancing the same clock. Report the measured cause, fix that, show before/after ms.

## Proof
- Scripted runs, each asserting the outcome: (a) trade open for the entire line, the line finishes; (b) pay during a line, mount succeeds the same frame; (c) walk away mid-line, exit line plays once, nothing replays; (d) walk in, greeting starts with no key press; (e) greeting never fires twice in one visit.
- Confirm (a)-(c) fail on the old code.
