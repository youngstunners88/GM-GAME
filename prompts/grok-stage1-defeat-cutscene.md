# Design brief: Stage 1 boss-defeat cutscene → Crystal Caverns

## What the game is

Lil Blunt Adventure (Godot 4.3, 2D platformer, web-exported to itch.io,
non-threaded HTML5). Hero is Lil Blunt — small, chill, cute, cowboy-themed
weed nugget, NOT aggressive. Stage 1 boss is the Auditor / "Tax Collector"
(IRS-suited antagonist, clipboard "TAX FORM 420", guards a "GOV VAULT" chest).
Stage 2 is already-built and already-named "Crystal Caverns"
(`level_02_crystal_caverns.tscn`) — mining/crystal theme, reached via a
mine-shaft drop. A pickaxe sprite (`sprite_item_pickaxe.png`) and a
"Lil Blunt as miner" sprite (`sprite_lil-blunt_miner.png`) already exist as
game assets — Lil Blunt has a pre-drawn mining-gear look, we are not
designing new art.

## What exists right now

- Boss death flow lives in `src/boss/auditor.gd::die()`. It already: sets
  DEFEATED state, plays a random "death" VO line for the boss (cooldown-free,
  forced), does score/ScreenShake/Web3 telemetry, then runs a 1s tween
  (scale to zero, spin, fade) on the boss node, then instantiates
  `victory_screen.tscn` (a separate Web3/leaderboard "Movie Layer" UI —
  claim NFT badge, submit score — explicitly optional/skippable) and frees
  the boss.
- Player input is already frozen for this entire window: `player.gd`'s
  `_physics_process` returns immediately unless `StateMachine.is_playing()`,
  and `die()` flips the global StateMachine to `LEVEL_COMPLETE` at the very
  top, before any of the above runs. So inserting more sequence time here is
  safe by construction — no new freeze-prevention code is needed, we just
  extend an already-frozen window.
- Boss VO: an existing category system (`BossVoiceSystem.say(boss, "tax",
  "death", true)`) with 2 pre-written randomized death lines
  ("I'll see you... in tax court...", "Appealing this... to a higher
  office..."). Those already played moments before our new cutscene starts.
  Our new cutscene needs its OWN one-off dialogue for a DIFFERENT beat (the
  vault being looted), not a third entry in that random pool.
- Founder-approved exact lines already chosen for this cutscene:
  - Tax Collector (defeated, reacting to vault being opened):
    "No... the vault...!"
  - Lil Blunt (triumphant, grabbing gear / about to jump):
    "Tax season's over, big man." AND/OR "Mining time."
- This project has a LONG history of shipped freeze/soft-lock bugs from
  scripted sequences (zero-scaling live colliders, coroutines that never
  resume after a node frees itself, timers not owned by the tree). Any new
  timed sequence must tolerate the boss node or player being freed/changing
  scene mid-sequence without hanging.

## Engine facts you must not "correct"

- Godot 4.3. Web export is HTML5, **non-threaded**.
- Godot 4.3's `VideoStreamPlayer` on HTML5 export only decodes **Ogg
  Theora**, and this project's one existing video use case ships it
  **muted** (`-an` at encode time) because audio-in-video was unreliable on
  this export target. A rendered MP4/WebM "cinematic" file is NOT a safe way
  to ship dialogue-critical audio in this game. Do not assume a movie-file
  approach — this beat must be buildable as an **in-engine scripted
  sequence** using existing 2D sprites, Tween/AnimationPlayer, and
  AudioStreamPlayer for the two VO lines, exactly like every other in-game
  narrative beat in this project (boss intros, stepped dialogue).
- Camera is a standard Godot Camera2D following the player; there is no
  cutscene-camera subsystem today.

## The actual question

Design the beat-by-beat cutscene as an IN-ENGINE sequence (not a rendered
video), using only assets that already exist or are trivial recolors/reuses
of them (the pickaxe sprite, the Lil Blunt miner sprite, existing smoke/VFX
particle nodes already used for Blaze Mode). Total runtime 12–15 seconds.
Beats, in order:
1. Final blow / boss staggers (smoke-themed finishing hit)
2. Boss collapses, drops hat/clipboard, defeated VO line plays
3. GOV VAULT chest opens, mining gear (pickaxe) revealed and "claimed" by
   Lil Blunt — swap or overlay to the existing miner sprite
4. A mine-shaft opens in the arena floor; Lil Blunt jumps in; screen
   transitions toward Crystal Caverns' color palette (cool blue/purple) as a
   clear "we are now headed to Stage 2" signal, distinct from the existing
   post-cutscene victory/leaderboard screen that still follows afterward.

For each beat give: exact duration in seconds, which existing node/sprite it
uses (or a plain ColorRect/Sprite2D placeholder if no exact asset fits — say
which), the Tween/AnimationPlayer property being animated, and where each of
the two VO lines fires (exact timestamp).

## Hard constraints

- No new shaders, no new external art pipeline, no new characters.
- Do not touch boss tuning (HP, speed, hitboxes) — this fires strictly after
  `current_state = State.DEFEATED` is already set.
- Do not redesign the existing `victory_screen.tscn` Web3/leaderboard flow —
  this cutscene plays BEFORE it, not instead of it.
- Keep Lil Blunt's and the Tax Collector's established designs exactly as
  drawn in existing sprites — no new outfit invented beyond the mining-gear
  swap that already exists as an asset.
- The whole thing must survive the boss node being freed/queued-free
  immediately after (this project's freeze-bug history is entirely about
  sequences that assumed a node would still exist a frame later).

## Output format

A numbered beat table: `# | start–end (s) | visual (node/sprite/animation) |
audio (VO line or SFX) | notes on failure-safety (what happens if this step
is skipped/interrupted)`. Keep total length under 15s. No prose padding.
