---
name: ep2-jack-hammer-dialogue
description: Write, edit or voice the Jack Hammer thread's lines (Sheriff job ask, wanted notice, accomplice/jailor word, stable hand, trail bandits, auction cards) - one source, strict wording rules, the gate that enforces them. TRIGGER on "Sheriff dialogue", "bounty lines", "jailor line", "stable hand line", "bandit barks", "wanted poster text", "Jack Hammer VO", or any edit to Ep2JackHammer.LINES.
---

# Jack Hammer dialogue (ep2-jack-hammer-dialogue)

**One source:** `Ep2JackHammer.LINES` / `NOTICE` / `OBJECTIVES` in `src/episode2/story/ep2_jack_hammer.gd`. `design/ep2/jack_hammer/JACK_HAMMER_LINES.md` is the readable script of the same text. Never type a line into a room script: call `Ep2JackHammer.lines(beat)` and `toast_text(ln)`.
Format: `{id, who, text}`; `who` in capitals ("SHERIFF", "ACCOMPLICE", "STABLE HAND", "BANDIT", "LIL BLUNT"), empty for narration cards; `id` = the future voice file `ep2_jh_<id>.ogg` (mono 64k, `ep2-voice-barks`). Timed text like the jail scene: `_start_show([{"do":"call","fn":...},{"do":"wait","t":3.9}])`.

## Wording rules (all gated by `tests/ep2_jack_hammer_test.gd`)
- Say **Jack Hammer** in speech; **Jackson Mccree** only where it is the formal paper (the Sheriff naming the paper, the notice). No other main name.
- The reward is **gold, paid in XAUt**. Never dollars, percentages, yields, APY, digits, addresses, contract talk, ticker symbols.
- Spoken lines say **"coin"** ("half a coin"), never Bitcoin / BTC / crypto (the tender shows on the buy panel).
- No horse protocol: no stake, LP, yield. The horse is a horse; the stable hand is minimal.
- The town has no bears; the bears were "brought in". Do not make Jack Hammer the final boss or end the game (Fort Knox stays the climax).
- Short. The lock wants one clear line per beat, not a long interrogation. The Sheriff is a weathered lawman (dry, brief); the accomplice bargains, he does not confess everything; Lil Blunt speaks little.
- Respect `ep2-narrative-canon`: do not make a character re-tell what a film or an earlier beat already established (the Sheriff already handed over the auction map).

## Procedure
1. Edit the line in `LINES` (keep the `id` unless the meaning changes; a changed meaning gets a new id so voice files do not lie).
2. Mirror it in `JACK_HAMMER_LINES.md` (or regenerate the section from the data).
3. `godot --headless res://tests/ep2_jack_hammer_test.tscn` must end `EP2_JACK_HAMMER: ALL PASS`.
4. Voice pass (when a key exists): record per id, normalise loudness, add to `assets/audio-manifest.json`, then the room plays `vo_<id>` with the text toast as fallback (the pattern in `gold_town.gd _begin_carry_line`).
5. Jack Hammer himself has no voice or look yet (Doc: open). Do not write lines in his mouth until the founder supplies the character.
