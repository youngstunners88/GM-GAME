Godot 4.3 GDScript project (web, non-threaded). Part 3 of the Protocol Portals tour rebuild: TESTS + CAPTURE SCRIPT only. Do not modify src/.
Write:
1. tests/portal_ladder_test.gd (extends SceneTree, headless, preload scripts by path, await 2 process frames after adding scenes): for each stage scene res://src/level/level_01_smoke_realm.tscn / level_02_crystal_caverns.tscn / level_03_gold_rush.tscn: exactly one node in group "protocol_portal" with correct protocol/stage_id; its x < the BossTrigger CollisionShape2D global x; no StaticBody2D descendants; shaft depth (bottom_y()-top_y()) >= 320; source of PortalLadder.gd contains no "interact" and no "STUDY [E]" / "STUDY  [E]"; source contains "enter_ladder_zone" and "exit_ladder_zone".
2. tests/portal_room_test.gd: for each skin res://src/protocol_portals/rooms/smoke/ReadingRing.tscn, rooms/diamonds/PressureStudy.tscn, rooms/gold/ClaimOffice.tscn: instance, await frames; strip width >= 1800 (use whatever StudyRoom exposes — read the file); node "Companion" exists with a Sprite2D whose texture resource_path contains "leaders/leader_stage"; >= 3 nodes in group "portal_stop"; whitepaper and video stops exist; test_run(correct key from QuizBank answer_key()) -> passed, 11/11; fresh room all-wrong -> not passed; proceed_without_pass -> eligible; ScorecardGrant.mark_eligible writes token portal_smoke/diamonds/gold with minted false; PortalTravel.room_scene_for mapping; no src/protocol_portals/*.gd contains "OS.execute", "JavaScriptBridge", "HTTPRequest". Unpause tree at end. Print [PASS]/[FAIL] lines and "PORTAL ROOMS: ALL PASS" / "PORTAL LADDERS: ALL PASS" or FAILURES n; quit(0/1).
3. scripts/capture-portals.mjs (Playwright, keep its current launch/boot logic): for stages [1,2100,'smoke'],[2,3300,'diamonds'],[3,3100,'gold']: (a) ladder shot at spawn_x=x-250; (b) climb shot: spawn_x=x, wait for boot, hold ArrowDown for 700 ms, screenshot `${p}_climb.png` while still holding (player mid-shaft), keep holding until the tour loads (up to 8 s), release; wait 3 s; screenshot `${p}_tour_start.png`; then hold ArrowRight 2.5 s, screenshot `${p}_tour_mid.png` (companion + a stop in frame). Log console error counts. 1280x720.

@include src/protocol_portals/PortalLadder.gd
@include src/protocol_portals/StudyRoom.gd
@include src/protocol_portals/Companion.gd
@include src/protocol_portals/TourStop.gd
@include src/protocol_portals/PortalTravel.gd
@include src/protocol_portals/ScorecardGrant.gd
@include src/protocol_portals/QuizBank.gd
@include tests/portal_room_test.gd
@include scripts/capture-portals.mjs
