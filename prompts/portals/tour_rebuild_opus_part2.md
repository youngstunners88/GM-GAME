You are implementing the founder's Protocol Portals TOUR REBUILD in a Godot 4.3 GDScript 2D platformer (HTML5 non-threaded export, GL Compatibility, viewport 1280x720). The founder brief below is the authority. Summary of hard requirements:
- Protocol ladder = a TALL climb shaft using the EXISTING player climb API: on body_entered call player.enter_ladder_zone(self), on body_exited player.exit_ladder_zone(self). The player reads move_down/move_up itself (see player.gd _update_climb and how src/level/ladder.gd cooperates with it — mirror whatever ladder.gd exposes that player.gd calls back into). NO "interact" key path, NO "STUDY [E]" text anywhere in the ladder. Label may read "STUDY" with the drawn down-chevron.
- Descent is VISIBLE: the shaft extends >= 4 player-heights (>= 320 px) below the mouth into the ground with visible rungs; the camera follows the player down (lift/extend the player's Camera2D bottom limit while in the shaft and restore it on exit). When the player reaches the shaft bottom (a trigger Area2D at the bottom), THEN call PortalTravel.descend(...) which may fade to the tour scene as the last step.
- Tour scene per protocol (rework StudyRoom.gd/.tscn and the three skins in rooms/*): a WALKABLE strip >= 2560 px wide, flat floor, Camera2D horizontal follow clamped to the strip (use the player's own camera with limits 0..strip_width, 0..720). Arrival shaft at the far left: the player appears at its BOTTOM as if climbing down, and climbing UP it (move_up in the shaft zone, same enter/exit_ladder_zone API; reaching the top trigger) calls PortalTravel.ascend() to return to the same world x (existing return logic).
- Named STOPS as places spaced 500-800 px apart, each a pedestal prop + dark rounded label + short companion line when the player arrives (Area2D). Stops per protocol exactly as the brief lists (SMOKE: Ash Ring, Lounge Basket, Arb Recycle Well, Ember's Desk; DIAMONDS: BLAZE Mint Gate, Tight Float, Vault / Crush, Handler Bridge, Assay Bench; GOLD: Vest Clock, Knox Window, Melt Stamp, Rush Board, Recorder Desk) PLUS the official whitepaper stop (jump-on plate -> existing whitepaper overlay with the official Gitbook URL) and the official X video stop (existing shrine overlay, DONE after 8 s). Keep the existing overlay/quiz/result/ScorecardGrant code paths; the quiz starts at the LAST stop (the examiner's desk/bench).
- Stop lines must be voice only and restate ONLY the locked pillar text given in the brief (no new numbers, APYs, addresses, dates). Use short lines <= 70 chars.
- COMPANION: a Node2D "Companion" with a Sprite2D using the founder leader still (res://src/assets/portals/leaders/leader_stage1.png / _stage2.png / _stage3.png — already background-cut, 540 px tall; scale to ~110 px tall, texture_filter linear), standing on the floor, following the player's x with an offset (~ -90 px, lerp), flipping to face the player, bobbing slightly while moving, and a talk balloon (Panel+Label) above it at stops. Name label above: Ember the Archivist / The Assay Trio / The Claim Recorder. The Stage 2 still shows ONE figure: use it once plus two smaller tinted escorts (same texture, scale 0.7, modulate cyan/violet) so it reads as a trio. Delete the Polygon2D examiner builders.
- Keep: PortalSession, PortalSignals, QuizBank, quiz JSON, token ids, ScorecardGrant, official URLs, portal_copy.json (you may add stop lines there under a new "stops" key per protocol), PortalTravel return logic. Do not touch src/level/ladder.gd/.tscn, Vault/Knox/Blaze/Lounge code, locked title-screen files, level_base.gd unless strictly required.
- The protocol ladder instances stay in the three stage .tscn files at the same positions.
- (Tests are a separate job — do NOT write tests now.) Former tests note: (headless, extends SceneTree, preload by path): update tests/portal_ladder_test.gd and tests/portal_room_test.gd to the new design; NEW checks: PortalLadder.gd source contains no "interact" and no "STUDY  [E]"/"STUDY [E]"; each tour scene's strip width >= 1800; each skin has a node named Companion with a Sprite2D whose texture path contains "leaders/leader_stage"; each skin has >= 3 stop nodes in group "portal_stop"; the room test_run() quiz API still passes (7/11 pass, retry, proceed, scorecard eligibility). tests/protocol_portals_test.gd must still pass untouched.
- Web constraints: no Thread, no OS.execute, no JavaScriptBridge, no HTTPRequest, no PointLight2D, no GPUParticles2D, ASCII-only label text.

FOUNDER BRIEF:
@include docs/founder_briefs/2026-09-25/tour_rebuild_brief.md

ART NOTES (vision read of the leader stills and the founder's reference images):
@include prompts/portals/tour_art_notes_opus.out.md

THIS JOB (part 2 of 3): the ladder is DONE (PortalLadder.gd below — reuse its climb-shaft pattern for the tour's arrival/ascent shaft). Write ONLY:
  src/protocol_portals/StudyRoom.gd (the walkable tour; keep the existing public test API test_run(choices) and the overlay/quiz/result/ScorecardGrant/PortalTravel paths),
  src/protocol_portals/Companion.gd (the leader-still companion Node2D),
  src/protocol_portals/TourStop.gd (a named stop: pedestal, label, Area2D, group "portal_stop", emits reached(stop_id)),
  src/protocol_portals/data/portal_copy.json (add a "stops" array per protocol: {id,name,line} with lines restating only the locked pillars),
  and the three skin .tscn files ONLY if their exported properties must change.
Be economical: no long comment essays, keep StudyRoom.gd under ~900 lines.

CURRENT FILES:
@include src/protocol_portals/PortalLadder.gd
@include src/protocol_portals/PortalTravel.gd
@include src/protocol_portals/StudyRoom.gd
@include src/protocol_portals/StudyRoom.tscn
@include src/protocol_portals/rooms/diamonds/PressureStudy.tscn
@include src/protocol_portals/WhitepaperJump.gd
@include src/protocol_portals/VideoShrine.gd
@include src/protocol_portals/ScorecardGrant.gd
@include src/protocol_portals/PortalSession.gd
@include src/protocol_portals/PortalSignals.gd
@include src/protocol_portals/QuizBank.gd
@include src/protocol_portals/data/portal_copy.json
