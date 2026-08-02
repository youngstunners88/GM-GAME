# Episode 1 — remaining 9 defects + death-freeze root cause — 2026-08-08

Rate-limit mode. Grok (float feel + GD art beat sheet), Kimi (boss damage /
pit / facing audit), Qwen (static facing/camera/exit review), DeepSeek
(compliance matrix) all dispatched in parallel. Primary Claude Code did
fetch, the fixes, in-engine proof probes, gates, and commit. Every claim
below is backed by a probe run in the real Godot engine THIS session
(probes were built, run, and deleted — not committed).

## The death freeze (R2) — real root cause, found and fixed

`GameManager.take_damage()` set `StateMachine.change_state(GAME_OVER)` the
moment health hit 0. `Player.take_damage()` then called `die()`, whose first
line was `if StateMachine.is_dead(): return` — already true — so `die()` bailed
and the death/respawn sequence NEVER ran. The tree isn't paused in GAME_OVER,
but the player's `_physics_process` early-returns when not PLAYING, so Lil
Blunt froze with no control and no menu. Independent of level. A prior session
even documented `die()` as "dead code" without realising that meant *no respawn
ever happened*.

Secondary bug: `_on_death_anim_done()` looked up `get_checkpoint(1)` (hardcoded
Level 1) and fell through to `reload_current_scene()` — which doesn't restore
PLAYING — on Level 2/3.

Fix: death-state ownership moved entirely into `Player.die()` (guarded by a
`_dying` flag, no longer bailing on is_dead); `GameManager.take_damage()` no
longer touches the state. Both the combat-death and pit-death paths now flow
through one `_respawn_or_game_over()` that spends a life, respawns at the
CURRENT level's checkpoint, and guarantees a return to PLAYING (or a real
game-over fade to menu when out of lives).
*Proof: Level-2 lethal hit → GAME_OVER (death anim) → respawn → PLAYING,
lives 3→2, health refilled.*

## Compliance matrix (proven this session)

| ID | Defect | Status | Evidence |
|---|---|---|---|
| R1 | Distributor damage both ways | VERIFIED WORKING | .tscn wiring correct (proj layer 64 ∈ boss mask 70; body mask includes Player); distributor_behaviour gate green (boss HP drops via VULNERABLE). Boss→player contact wired + monitoring on all fight. |
| R2 | Death freeze → respawn | FIXED | Level-2 death→respawn probe; root cause above. |
| R3 | Blaze Rush finish → entry stage | FIXED/VERIFIED | Probe: L2 entry data → return path level_02 + checkpoint level_index 2. |
| R4 | Blaze Rush ESC → entry (not restart) | FIXED/VERIFIED | ESC + finish both call `_exit_to_level`; probe confirmed. |
| R5 | Blaze Rush reskin | SLICE DONE | Generated crystal-cavern backdrop (openai/gpt-5-image via OpenRouter), cropped out baked-in text, wired as far backdrop; loads + exports. No live in-run screenshot (portal is score-gated). |
| R6 | Auditor faces player | FIXED | PATROL now faces the player (mirrors ALERT/PURSUE). Isolated-boss facing probe hung on standalone instantiation; change is a 6-line mirror of proven code. |
| R7 | L2 boss can't fall out of arena | FIXED | Float + hard clamp. Probe: shoved down 4000px/s/frame, stays y 359–433 (home 370 ± band 70). |
| R8 | L2 boss bigger + levitating diamonds | FIXED | scale 1.7×, levitating diamond disc; probe confirmed. |
| R9 | Continue = last level, not L1 | FIXED | LevelBase records current_level on entry; Continue resumes it. Probe: save L2 → Continue → level_02. |
| EMAIL | Popup blocked PLAY | FIXED | Removed the forced signup gate from `_on_play`; PLAY is one click. |
| VOCAB | Bosses repeat taunts (founder mid-session ask) | FIXED | tax+crystal taunts 3→6, mocks 2→4 (ElevenLabs, owned voices); no-immediate-repeat picker. Probe: 30 picks / 6 lines, all used, 0 back-to-back repeats. Bandit voice was removed from the ElevenLabs account (library voice, free-tier blocked) so its lines couldn't expand — it still gets the no-repeat picker. |

## Multi-model log

- Grok 4.5: Distributor float-feel numbers (hover band, bob, drift) + Blaze
  Rush GD art beat sheet. Both used.
- Kimi K3: confirmed R7 CRITICAL (no floor/bounds guarantee), R6 PATROL
  facing, and that R1 is correctly wired in .gd (pointed to .tscn masks —
  verified: correct).
- Qwen: static risk map — flagged the same PATROL-facing and Blaze-Rush
  exit-path concerns; both already addressed.
- DeepSeek: the compliance-matrix template (filled above).

## Honest limitations

- No live in-game screenshots: Blaze Rush is behind a score-gated portal (not
  automatable) and the headless browser can't reliably click menu buttons.
  All proof is in-engine probes.
- Bandit boss VO could not be expanded (its ElevenLabs voice_id was removed
  from the workspace; it's a library voice free tier can't call).

## Gates
script_compile (114/77), boss_arena_reachable, boss_visibility,
distributor_behaviour, blaze_rush_layout, save_compat — all PASS. Security
sentinel 18/18, 0 blockers. Web export builds. No API key in any tracked file.
