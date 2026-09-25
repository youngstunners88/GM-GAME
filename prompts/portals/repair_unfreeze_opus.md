REPAIR ONLY — Godot 4.3 GDScript 2D platformer, HTML5 non-threaded, GL Compatibility. Do NOT rebuild the Protocol Portals feature, do NOT touch PortalSession/PortalSignals/QuizBank/quiz JSON, do NOT add any interact/E movement. Keep every existing public API and test hook (StudyRoom.test_run etc.). Output full revised files only for those you change. Be economical: no essays in comments.

FOUNDER PLAYTEST of the live web build:
1. Lil Blunt is FROZEN in the tour room; arrow keys do nothing.
2. Companion does not walk or speak.
3. Wrong names. Required display names EXACTLY: smoke = "Pauly The Smokest", diamonds = "Kane The Blaze Mechanic" (ONE figure; delete the trio/escort sprites), gold = "Rich the Claim Recorder".
4. Room is an empty void with pedestals, not a place.

P0 UNFREEZE (most important). Likely root: PortalLadder shaft mode zeroes velocity / strips collision / sets process flags, and those persist across the scene change, or StudyRoom never restores them. In StudyRoom, when the player is spawned/arrives, RESTORE the player: collision_layer/collision_mask to the player's normal gameplay values (read defaults from player.gd/player.tscn conventions, player is on layer 2 and collides with world layer 1), process_mode = PROCESS_MODE_INHERIT, set_physics_process(true), set_process_input(true), _climbing = false, _ladder_zones = 0 (use set() guarded by "in"), velocity = Vector2.ZERO, and make sure get_tree().paused is false and no overlay/Control with MOUSE_FILTER_STOP or focus is swallowing input. Also make PortalLadder undo EVERY change it made to the player whenever shaft mode ends (including on scene exit / tree_exiting). Also check PortalTravel/static state that might keep a "descending" flag. The camera must follow the player across the strip (Camera2D limits 0..strip_width, not locked on the shaft). Acceptance: standing in The Reading Ring, holding the right arrow moves Lil Blunt from the arrival shaft past Ash Ring to Lounge Basket with normal player.gd movement (move_left/move_right/jump).

P0 COMPANION IS A GUIDE: Companion.gd gets display_name + texture per protocol:
  smoke    -> "Pauly The Smokest",       res://src/assets/portals/companions/pauly_the_smokest.png
  diamonds -> "Kane The Blaze Mechanic", res://src/assets/portals/companions/kane_the_blaze_mechanic.png  (single figure, no escorts)
  gold     -> "Rich the Claim Recorder", res://src/assets/portals/companions/rich_the_claim_recorder.png
Replace every "Ember", "Assay Trio", "The Claim Recorder"-only name string used as the companion/examiner name in StudyRoom/Companion (keep quiz JSON untouched). Companion follows player.x on the floor (lerp, offset ~ -90 px, faces the player, small bob while moving) EVERY physics frame, and when the player enters a TourStop the companion calls say(line) showing a talk balloon with that stop's line from portal_copy.json "stops" for ~4 s. Optional: if a file res://src/assets/portals/vo/<protocol>_<stop_id>.mp3 exists (ResourceLoader.exists), play it with an AudioStreamPlayer; silence is fine otherwise.

P1 ROOM IS A PLACE (cheap, code-drawn, no new art files): dress the existing strip per protocol with Polygon2D/Line2D:
  smoke    — ash-ring floor band, lounge-basket prop, recycle well
  diamonds — faceted floor, mint-gate arch, crush press (look-only)
  gold     — plank floor, vest clock face, knox window (look-only)
Stops become glowing FLOOR MARKS you walk onto (a lit plate on the floor + a sign post), not floating chips. Add simple back-wall layers (2 parallax-ish bands) so it is not a void.

Keep the existing headless tests passing (tests/portal_room_test.gd and tests/portal_ladder_test.gd may need their name expectations updated — you may edit them for the new names only).

@include src/protocol_portals/PortalLadder.gd
@include src/protocol_portals/StudyRoom.gd
@include src/protocol_portals/Companion.gd
@include src/protocol_portals/TourStop.gd
@include src/protocol_portals/PortalTravel.gd
@include src/player/player.gd
