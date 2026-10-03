---
name: ep2-seamless-transition
description: Hand-offs between game modes (boss 3 -> Episode 2, and any future one) must be seamless - no blue wipe, no long freeze. Route them through the TransitionDirector autoload (prewarm early, go() later) and its state machine. TRIGGER on "takes forever to load", "blue screen", "transition", "loading", any new scene hand-off, any SceneRouter.load_scene into Episode 2 or another heavy scene, edits to transition_director.gd, claim_jumper.gd/bandit_boss.gd die(), or ep2_entry.gd access gate.
---
# Why it was broken (founder 2026-10-03)
Boss 3's win called `SceneRouter.load_scene(EPISODE2, DIAMOND)`. On web that is a SYNCHRONOUS `change_scene_to_file` behind the dark-blue DIAMOND wipe: the whole of Episode 2 (scene, ~40 GLBs, textures, audio, ep2_entry.gd compiling the whole runner = 450 ms+) was read and built in front of the player, then the Episode 2 access-code screen appeared.
# The rule
NOTHING HEAVY HAPPENS IN FRONT OF THE PLAYER. Heavy work hides behind a film, a death tween or the loading card.
# The system (`src/autoload/transition_director.gd`, autoload `TransitionDirector`)
States: `IDLE -> WARMING -> READY -> COVERING -> LOADING -> SWAPPING -> REVEALING -> IDLE` (signal `state_changed`, `progress`, `finished`).
1. `TransitionDirector.prewarm(path)` as EARLY as the destination is known (boss `die()`): loads the scene's dependency tree + the preset dirs (`PRESETS`) ONE resource at a time inside `BUDGET_MS` per frame, held in `_hold` (the cache only keeps referenced resources). Scripts/scenes (`gd/tscn/scn`) are held back in `_late` for the card.
2. `TransitionDirector.go(path)`: black-violet loading card (title, bar; never blue) fades in 0.22 s, finishes the warm-up with a moving bar, swaps from the loaded PackedScene (instant), keeps the card over the new scene's `_ready` for 3 settled frames, fades out 0.55 s. `StateMachine`: TRANSITIONING at the cover, PLAYING at the reveal; a failed swap `recover_from_transition()`s instead of soft-locking.
3. Earned entry: `GameManager.ep2_story_unlocked = true` (memory only) skips Episode 2's access-code screen for the story hand-off; the menu entry still asks (switch: `GameManager.EP2_STORY_BYPASSES_CODE`).
# Adding a hand-off
Add the destination to `PRESETS` (dirs, exts, files, title/subtitle), call `prewarm` when known, `go` when the player should leave. Never `SceneRouter.load_scene` into a heavy scene; never a wipe whose colour you have not looked at.
# Gate and proof
`tests/transition_director_test.tscn` (incremental warm, no frame over 250 ms in front of the player, states, StateMachine, card colour not blue, bosses route through the director). Real render: `tools/ep2_shots/transition_shot.tscn` (blue stand-in "level" so a blue flash would show). Measured with software GL: go -> finished 1.9 s, covered frames hide the 600 ms spike.
# Locked file note
`src/ui/main_menu.gd` is founder-locked: its Episode 2 button still uses SceneRouter. Route it through the director only with the founder's say-so.
