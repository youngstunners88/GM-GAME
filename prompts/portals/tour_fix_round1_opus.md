Godot 4.3 2D platformer, web build. The Protocol Portals climb-down shaft (PortalLadder.gd) FAILS in the real web export. Playwright held ArrowDown (the move_down action) for up to 8 s standing at the shaft mouth. Vision notes of the real frames:
- Stage 1 (smoke, ladder x=2100): player stays at the very TOP of the shaft, feet at platform line; a "HOLD DOWN" hint shows; never descends.
- Stage 2 (diamonds, x=3300): player climbs partway down below the platform line, camera follows, then stops mid-shaft and never reaches the bottom; the tour never loads.
- Stage 3 (gold, x=3100): during the hold the player DIES ("YOU DIED / Respawning") — likely falls/is pushed into a kill zone or hazard, or the camera/limits/ground leave him in a death trigger.
Root-cause from the code (player climb logic in player.gd: _update_climb, enter/exit_ladder_zone, how climbing interacts with floor collision; LevelBase ground building and kill zone; PortalLadder shaft zones/bottom trigger) and fix it so that in all three stages: pressing/holding move_down at the mouth makes the player climb down THROUGH the ground (disable/ignore floor collision only while in shaft mode, e.g. collision_mask bit toggle or a one-way/no-floor segment under the shaft, restored on exit), the camera follows, the bottom trigger fires reliably within ~3 s of holding down, and the player can never die/fall into the kill zone while in the shaft. Do not change other player behaviour. Keep the 39/75/155 tests passing.
Allowed edits: src/protocol_portals/*, and src/player/player.gd ONLY if strictly required (minimal, commented, guarded so ordinary ladders are unaffected).

@include src/protocol_portals/PortalLadder.gd
@include src/player/player.gd
@include src/level/ladder.gd
@include src/level/level_base.gd
