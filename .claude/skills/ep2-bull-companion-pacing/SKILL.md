---
name: ep2-bull-companion-pacing
description: How Inferno Bull behaves as a companion in the woods and on the quad - rare, varied, random lines instead of "walk soft / follow me" on a timer; he lets Lil Blunt scout ahead and carries on (an adult), looks back and waits only a few seconds when Lil Blunt lags, and fires to cover Lil Blunt when he is struggling. TRIGGER on "Bull feels mechanical", "keeps repeating", "walk soft", "follow me", "waits for me", "doesn't help", "shoot when I struggle", any edit to _tick_sneak, _tick_bull_defence, _tick_bull_ride_cover, _bull_chat or the BULL_* line pools in woods_quad.gd.
---

# Inferno Bull as a grown-up companion (founder 2026-10-14)

> "Inferno Bull is feeling a bit mechanical as he constantly repeats walk soft and follow me. The intervals are too sudden. If Lil Blunt goes on ahead he should
> acknowledge it as an adult and shouldn't wait for Lil Blunt to come back to him to proceed. I understand him turning around and waiting, but let's not make him
> too rigid. Also if bears come he should shoot if he sees Lil Blunt is struggling."

## Rules (all in `src/episode2/chamber/woods_quad.gd`, gate `tests/ep2_companion_cart_test.tscn`)
1. **One voice budget.** Unprompted lines go through `_bull_chat(pool, cd_min, cd_max)`: nothing while he is speaking or a show runs, nothing until the random
   cooldown is over, and the pool rotates (`_line_idx`) - never the same line twice running. Pools: `BULL_AHEAD`, `BULL_WAIT`, `BULL_EASY`, `BULL_QUIET`, `BULL_COVER`.
   After the opening line the first murmur is 22-34 s away; "easy" murmurs are 40-75 s apart. The urgent hiss when a bear hears a runner is the only thing that
   cuts in (14 s cooldown, rotating `BULL_QUIET`). "Walk soft" is ONE line of three now, not the heartbeat of the walk.
2. **Trail progress, not distance.** `_trail_s()` gives each walker's arc position on the sneak trail; `gap = player_s - bull_s`.
   - `gap > 3.5` (Lil Blunt is AHEAD): he keeps walking at a brisk 2.3 m/s, never stops, and now and then says an `BULL_AHEAD` line ("Go on, scout ahead, I've got your back").
   - `dist > 8` and `gap < -2` (Lil Blunt LAGS): stop, face him, a `BULL_WAIT` line after 0.8 s, wait at most 3.8 s, then **stroll on** at 1.25 m/s for 16 s
     (`_bull_wait_lock`) before he will wait again. He is never rigid and never abandons him for good.
   - at the thicket (end of the trail) he does wait: the reveal is theirs together.
3. **He covers Lil Blunt.** "Struggling" = hearts below max OR a hostile bear within 13 m of Lil Blunt. In the woods `_tick_bull_defence` scores bears by distance minus a
   14 m bonus when they press Lil Blunt, fires faster (1.0-1.4 s vs 1.6-2.2 s) and straighter (72% vs 55%), calls `BULL_COVER` instead of "he's seen us" on the last heart,
   and with no clear line of fire he steps toward Lil Blunt. On the quad `_tick_bull_ride_cover` lets off a round over his shoulder (2.6 s apart; 1.7 s when hurt; archers
   only when hurt) - he is driving, not a turret. No arm IK (the sculpted elbow tears): the rifle pivots in his fist (Codex's `Ep2BullHero.fire_at`).
4. **Voice**: ElevenLabs Inferno voice `uWE48TmsTuIjyh2ifoNL`, speed >= 1.0, lines in `assets/audio-manifest.json`. After `scripts/generate_audio.py`, delete the strays it also makes:
   `rm -f src/assets/sounds/ep2_woods_ambience.mp3 src/assets/sounds/voice/film_*.mp3`. Re-encode new clips mono 64k (pack budget < 190 MiB).
5. Never add a scripted "wait here" gate that holds Inferno until Lil Blunt returns; a new beat that needs him must have him carry on after a few seconds.
