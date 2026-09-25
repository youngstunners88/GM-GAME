Godot 4.3 GDScript 2D platformer, HTML5 non-threaded export, GL Compatibility. Fix two Stage 2 (diamonds) defects in the Protocol Portals feature. Keep changes minimal and local; do not touch locked title-screen files, quiz JSON, PortalSession/PortalSignals/QuizBank, or src/level/ladder.gd.

1. BLACK FRAME: in the web build, loading Stage 2 with the debug warp `?stage=2&spawn_x=3050` renders a fully black frame, reproducibly; x=2950 and x=3150 render normally, and before the latest PortalLadder change the same x rendered fine. The latest change added a `MouthRingOutline` Line2D child of `_ring` with `show_behind_parent = true` in PortalLadder._build_ring(), and the ladder sits at x=3300 in Stage 2 with an EnterZone Area2D. Find the cause by reading the code (level_base spawn warp, PortalLadder snap/return logic, PortalTravel.consume_return, level_02 geometry near x 3000-3100, secret walls, kill zones, camera limits) and fix it. If the cause is the portal code (e.g. a return/warp firing, the floor snap moving the player, a camera limit, or a descent triggering), fix it there. Explain the root cause in a code comment at the fix site.
2. ASSAY TRIO: in StudyRoom.gd the diamonds examiner reads as "three identical flat grey diamond/teardrop shapes with cyan dot heads, centre one overlapping the player; label tight against the divider". Redraw as three DISTINCT crystal jurors (CUT: tall faceted blue with a chisel; WEIGH: wide violet with a small balance scale; STAMP: short pale-cyan with a stamp), each with eyes, outlined, standing in a row between x=700 and x=860 on the floor, clear of the player spawn (move the room's player spawn left of the divider if needed) and with the label centred above them and >=24 px from the divider.

Keep all headless tests passing.

@include src/protocol_portals/PortalLadder.gd
@include src/protocol_portals/PortalTravel.gd
@include src/protocol_portals/StudyRoom.gd
@include src/level/level_02_crystal_caverns.gd
