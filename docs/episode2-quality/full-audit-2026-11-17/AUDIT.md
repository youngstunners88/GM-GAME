# Episode 2 full audit - 2026-11-17

Brief: `PROMPT_EPISODE2_FULL_AUDIT_FIX_AND_SKILL_PACK_2026-11-17`. Branch `claude/peaceful-keller-jihmmn`.

## What was actually audited (read this first)

| Method | Coverage |
|---|---|
| Every Episode 2 headless gate run on unmodified master, fresh save dir each (`tests/ep2_*.tscn`, 107 scenes incl. the 380 s stress soak) | all 13 layers, to the depth the gates reach |
| Read in full | `session/ep2_session_root.gd`, `session/world_routes.gd`, `session/ep2_playtest.gd`, `chamber/interlude_base.gd` (the shared first-person room: movement, camera, weapons, HUD wiring, show sequencer), `ep2_entry.gd` (boot, access code, pause, retry, exit), the save / manual-checkpoint / resume path in `autoload/game_manager.gd`, `debug/harness_hooks.gd` |
| Read in part, following a lead | `gold_town.gd` (trade, pause, mount, departure, revisit), `lake_trail.gd` (setup, movement, horse, shore, fail / retry, departure adoption), `logans_lake.gd` (bounds, hand-overs), `river_cover.gd` (blocked state, dock, hand-off), `ep2_fps_hud.gd` (armory pause), `ep2_armory_state.gd` (shop chain) |
| Pattern scans over all of `src/episode2` | tree pause / unpause pairs, `Engine.time_scale`, `await` and timers, audio player lifetime, every `_resolve` / fail / retry site, every `_world_revisit` branch, every URL flag the shipped build reads |

**Not done, and not claimed:** a real-browser playthrough of Episode 2, any phone or tablet run, a visual review (layer 12: seams, floating
objects, T-poses, textures, poster density), listening to the mix (layer 9), and a line-by-line read of the remaining ~40,000 lines
(`smelting_facility`, `woods_quad`, `runner_view`, most of `gold_town` / `river_cover`, the actors). Those layers are covered here only by
their existing gates. This audit therefore cannot certify Episode 2 free of defects; it certifies what is listed below.

## Baseline (master `cdc8a7a`, before any change)

104 of 107 Episode 2 gates pass. The three that fail are stale assertions, none is a CI gate, none is touched here:

| Gate | Failing check | Why it is stale |
|---|---|---|
| `ep2_interlude_test` | "the moment it is built the door opens: the hideout resolves toward the lift" | written before the open-door portal (2026-10-24): the hideout now resolves when he walks through the doorway plane, not at `EXIT_POSITION`. Already noted in STATUS 2026-11-13. |
| `ep2_hideout_corrections_test` | 4 checks on Bull's own Winchester (`_bull_guard_rifle`) | the painted Bull model carries its rifle; the separate guard rifle is hidden by design (`Ep2BullHero.PAINTED_GLB`, `smelting_facility.gd:2077`) |
| `ep2_smelting_facility_test` | "Bull PBR keeps fur/leather nonmetal" | predates the painted Bull's own materials; listed as known in `scripts/ci-new-gates.txt` |

## Findings

Severity: P0 = the player cannot continue; P1 = progress, gear or access is lost or wrong; P2 = polish / needs a decision.

| # | Sev | Where | Reproduction | Broken | Expected | Skill that should have caught it | State |
|---|---|---|---|---|---|---|---|
| 1 | P0 | `chamber/gold_town.gd` `can_mount_departure`; `session/world_routes.gd` `park`/`travel` | Mount at Dude's, ride north up the street into town, walk back to Dude's rail on foot (horse left at the lake / shot), press E on "Mount horse" | The town resolves (`_running = false`) but its `chamber_cleared` was disconnected when it was parked: the screen freezes for good | No second first-departure mount on a revisit; the trail owns Dude's ranch | none (`ep2-state-transition-audit` covers only the forward chain) | FIXED, gated (A) |
| 2 | P0 | `session/world_routes.gd` `tick` | Mount at Dude's, ride north into town ("or turn back to town" is the trail's own objective), then try to go back to the lake | No boundary leads from the revisited town to the lake trail (the woods' branch to it was unreachable code). The lake, the ridge and the auction can never be reached again | The street hands him back to the trail on the same line he crossed | none | FIXED, gated (A, B) |
| 3 | P1 | `chamber/logans_lake.gd` hand-over at `WALK_ON_Z`; `chamber/river_cover.gd` `BLOCKED` | Buy the Shipment but not the Sharps (the town only requires the Shipment), ride to the lake, check the cargo, climb to the ridge marker | "The day-88 run needs the Sharps" and the only action is E = end the session; "play again" restarts from the mine cart. There is no way down from the ridge | He is turned round at the lake's overlook, where the trail back to Rich & Utah's is open | none | FIXED, gated (D) |
| 4 | P1 | `session/world_routes.gd` `park`/`travel` | Ride to the lake, leave the horse drinking, walk back up the trail and into town | The routes still held `mounted = true` from the ride in: saddle eye height, riding pace 7 m/s, and the (hidden) horse node dragged through town | A walker is a walker | none | FIXED, gated (C) |
| 5 | P1 | `session/world_routes.gd` `travel`/`tick`; `gold_town.gd:2728` | Any return to town after the first departure | The town kept the saddle eye height (2.18 m) the mount animation left; a horse ridden into town stayed parented to the town's streets, so back on the trail it would be drawn 1,230 m away | Own eye height on foot; the one horse returns under the trail | none | FIXED, gated (A, B) |
| 6 | P1 | `chamber/lake_trail.gd:1583` `_retry_trail`; snapshot taken once at `:866` | Buy anything at Rich's or Logan's after the ride began, come back onto the trail, get shot down (or shot by Logan: `respawn_at_dude`) | The retry restores the armory of the ride's first minute: the new gear is gone, the BTC stays spent | A retry restores what he carried on this leg | none | FIXED, gated (E) |
| 7 | P1 security | `ep2_entry.gd` `_debug_unlock_requested` (removed) | Open the live game with `?ep2=1&ep2unlock=1` | The founder's Episode 2 access code is skipped and the unlock is remembered on the device. `check-harness-hooks.py` only knew `ep2gate` and `bosskill` | Inert on the shipped build, like the other harness flags | `ep2-security-and-trust-audit` / the harness checker (list was incomplete) | FIXED in code + checker; live check pending |
| 8 | P1 (latent) | `session/world_routes.gd` `travel` | Arrive on the trail from anywhere but the lake | The lake's rotation was added to his gaze for every arrival (only the lake is rotated) | Gaze kept from town / woods | none | FIXED, gated (B) |
| 9 | P2 | `tests/ep2_interlude_test.gd:558`, `tests/ep2_hideout_corrections_test.gd:125-`, `tests/ep2_smelting_facility_test` | run them | 6 stale assertions fail on master | assertions match the shipped design | `test-flakiness` / `regression-suite` | OPEN (not CI gates; each needs its owner's intent) |
| 10 | P2 | `ep2_entry.gd:547` | Press Esc during a film or a scripted beat (the pointer is free then) | Leaves Episode 2 for the menu at once, no confirmation; everything since the last manual Save is gone | a founder decision: confirm, or open the pause card | - | OPEN (documented behaviour: "retain the existing exit") |
| 11 | P2 | `ep2_session_root.gd` `capture_section_checkpoint`; `world_routes.gd` `travel` | Save from the pause card after walking back into a finished room, or after buying something | The Save is the SECTION START checkpoint: purse and armory as they were on entering the last story room, and the room is the last one entered through the story chain | by design (`docs/episode2-quality/pause-save-20261027/DESIGN.md`); the label says "section start" | - | OPEN (design) |
| 12 | P2 | `world_routes.gd` `tick` (the ridden horse in the woods / town) | Ride into town and into a building | The horse goes indoors with him (Rich's counter, the saloon); there is no dismount in town | common sense says tie it outside; needs a rule from the founder | `ep2-world-common-sense` | OPEN |
| 13 | P2 | `ep2_session_root.gd` `_respawn_at_dude` | Continue a save made at the lake, shoot at Logan, ride back | A NEW lake is built (Logan's story from the top); when the trail was already there, the OLD lake is returned to mid-story | one behaviour | - | OPEN |
| 14 | P2 | `ep2_entry.gd:362` | `?playtest=...`, then Esc while "waiting for the streamed extras" | `get_tree()` is null after the node left the tree: an error line, no player effect | guard the wait | - | FIXED (one-line guard) |
| 15 | P2 | `ep2_session_root.gd` `_teardown_active` | Fail a run inside a chain while the next room is being prebuilt | the half-built room and its viewport live (and render) until Retry | free them with the run | - | OPEN |
| 16 | P2 hardening | `ep2_entry.gd` `_begin` / `_plan` | `?ep2leg`, `?ep2chamber`, `?ep2bot` after the access code | skip legs / autopilot on the live build | acceptable while GOLD is simulated; re-audit when it is not | `ep2-security-and-trust-audit` section 5 | ACCEPTED |

Layers that produced no finding under the methods above: runner input and lanes, weapon handling / reload / ADS / ammo / Tabs, combat
(bears, bandits, vultures, bison, stampede, raft men), audio buses and crossfades, the pause card / map / certificates, the license and
draw state machines, the Fort Knox arc guards, save format and hand-edited saves. "No finding" means their gates pass and the shared code
read clean - not that they were play-tested.

## Fix log

| File | Change | Before | After |
|---|---|---|---|
| `src/episode2/session/world_routes.gd` | new `tick` rule town -> trail (`TOWN_LINE_Z`, `TOWN_LINE_BACK`); woods -> trail when the trail exists; dead branch removed | no way back to the lake from a revisited town | the street hands him to the trail 2 m below the line he crossed, every time |
| same | `park`: `mounted` / `horse` set from the trail being left (both ways); `travel`: cleared and the horse reparented on return to the trail | a stale saddle carried a walker; the horse stranded in the town's streets | saddle state is the trail's, the one horse comes home |
| same | `travel`: on foot in woods / town -> `FPS_EYE_HEIGHT`, own pace (`_foot_pace`) | 2.18 m eyes, 7 m/s after any ride through | his own height and pace |
| same | `travel`: lake rotation applied to the gaze only for lake -> trail | gaze turned on every other arrival | gaze kept |
| same | `travel`: the trail's retry snapshot retaken on every arrival | a retry wiped gear bought since the ride began | a retry keeps it |
| `src/episode2/chamber/gold_town.gd` | `can_mount_departure` closed on `_world_revisit` | E at the rail froze the game | no prompt; the trail owns the ranch |
| `src/episode2/chamber/logans_lake.gd` | the ridge hand-over needs `armory.sniper_owned`; objective + toast once per climb (`_sharps_told`); `_wants_handoff` likewise | the ridge ended the run | "The day-88 run needs the Sharps buffalo gun from Rich & Utah's counter. Ride back to town for it." |
| `src/episode2/ep2_entry.gd`, `src/debug/harness_hooks.gd`, `scripts/check-harness-hooks.py` | `ep2unlock` moved behind `gm_harness` (`ep2_remembered_unlock_requested`), added to the checker's `PARAMS` and sanctioned calls | live URL skipped the access code | inert on the shipped build; the checker fails if it is ever read elsewhere |
| `tests/ep2_audit_1117_test.gd` / `.tscn` (new, in CI) | 22 checks, sections A-E | - | `EP2_AUDIT_1117: ALL PASS` |
| `tests/ep2_logans_lake_test.gd`, `tests/ep2_horse_and_logan_test.gd` | fixtures own the Sharps before the ridge; one new check for the turn-round | reached the ridge without it | match the real path |
| `.github/workflows/export-game.yml` | the new gate after the world-routes gate | - | CI blocks a regression |

## Residual evidence table

| Boundary / rule | Headless gate | Failed before the fix? | Local web export seen? | Live hard-refresh seen? | Status |
|---|---|---|---|---|---|
| 1 frozen mount at Dude's on a revisit | `EP2_AUDIT_1117` A (4 checks) | yes: `active=GoldTown town running=false resolved=true` | no | no | GATED |
| 2 town -> lake trail | `EP2_AUDIT_1117` A, B | yes: `active=GoldTown pos=(-12, 0, 1239.7)` after 30 s of riding | no | no | GATED |
| 3 Sharps before the ridge | `EP2_AUDIT_1117` D; `LOGANS_LAKE` new check | yes (mutant): 2 checks fail, objective stays "Meet Logan at the shore" | no | no | GATED |
| 4 stale saddle | `EP2_AUDIT_1117` C | yes (mutant): `eye=2.18 pace=7.0` | no | no | GATED |
| 5 eye height / horse home | `EP2_AUDIT_1117` A, B | yes (mutant): eye `2.18`, horse not the trail's | no | no | GATED |
| 6 retry keeps gear | `EP2_AUDIT_1117` E | yes (mutant) | no | no | GATED |
| 7 `ep2unlock` inert | `CHECK_HARNESS_HOOKS: ALL PASS`, `HARNESS_HOOKS_INERT` | n/a (static) | no | no | IN CODE + checker |

Mutation check: with each fix reverted in place (constants kept so the test still parses) the gate prints `EP2_AUDIT_1117: 22 checks,
13 failed`; on the fixed code `22 checks, 0 failed`. After the fixes the whole battery (111 scenes: every `ep2_*` plus harness-inert,
script-compile, save-compat, manual-checkpoint) shows the same three stale failures as master and nothing else.

Nothing in this table is FIXED in the founder's sense until the last two columns are filled. Hard-refresh path:
`https://youngstunners88.itch.io/smokerealm` -> Ctrl+Shift+R -> `?playtest=dude` -> buy the horse -> mount -> ride north up the street
into town -> turn round and ride back past Dude's toward the lake -> repeat on foot after leaving the horse at the water. And once with
`?ep2=1&ep2unlock=1` in a private window: the access-code screen must appear.
