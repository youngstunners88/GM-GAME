Revise these two Godot 4.3 GDScript files (web, GL Compatibility, no PointLight2D/GPUParticles2D/Thread/JavaScriptBridge/network). Output ONLY full files wrapped exactly like:
=== FILE: <path> ===
<contents>
=== END ===
Never use ``` fences. Keep every public method, node name (WhitepaperPlate, VideoShrine, Examiner, AscentShaft, Divider), URL, quiz/overlay behaviour, test_run API and comment intact. Change ONLY what fixes these defects, found by a vision review of real 1280x720 web captures:

1. DIVIDER HIDDEN: the "Divider" Line2D sits at x=640 exactly behind the centre ladder shaft, so no dividing line is visible. Keep the shaft centred at x=640, but make the ascent-shaft ladder end at y=360 (rails no lower than that), and draw the Divider from y=372 to y=620 at x=640, width 4, glow colour at 85% alpha, with a 10 px faint glow copy (same line, width 12, 18% alpha) underneath — one crisp line, no doubled hard edge. The shaft's AscentShaft Area2D stays reachable: position it at the shaft base (y~330-380) AND extend its rect down to the floor so a player standing under the shaft can interact.
2. "CLIMB BACK  [E]" label is at bottom-centre near the player; move it to sit just ABOVE the top of the visible shaft rails (y~110), centred, with the dark backing panel.
3. SMOKE PLATE: the "culture + sink" sub-line is partly covered (by the CLIMB BACK pill / a grey backing rectangle). In SmokePlate.gd keep all text inside the disc and above the lower rim, and make sure no panel/label from StudyRoom overlaps the plate area (plate centre x~300; keep labels above y of the plate top).
4. GOLD EXAMINER (Claim Recorder) reads as a featureless pale block. Give him a readable clerk silhouette: head with visor/eyeshade (green), face with two dot eyes, shoulders + sleeves with arm garters, a desk in front with an open ledger (two pages with ruled lines) and a red rubber stamp, and a small pocket-watch/vest-clock chain. Keep it Polygon2D/Line2D only, ~140 px tall, colours contrasting with the brown/gold room.
Nothing else changes.

@include src/protocol_portals/StudyRoom.gd
@include src/protocol_portals/SmokePlate.gd
