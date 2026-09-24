Revise this Godot 4.3 GDScript file. Output ONLY the full file wrapped exactly like:
=== FILE: src/protocol_portals/StudyRoom.gd ===
<contents>
=== END ===
Never use ``` fences. Change ONLY the examiner drawing for "smoke" and the examiner x placement; keep everything else byte-identical in behaviour (node names, URLs, overlays, test_run, divider, shaft, plates).

Jev BLOCKED Stage 1 because a vision review of the real web capture says: "The 'Ember the Archivist' name label is present but no examiner figure is drawn under it (only a small green dot-on-stem marker), so the examiner slot reads as empty." The smoke room background is deep green, so a dark robe vanishes.
Fix: draw Ember the Archivist as a clearly readable ~150 px tall standing figure on the floor (y=620) directly UNDER the name label: a warm parchment/cream hooded robe (Color(0.92,0.86,0.72)) with a darker brown outline (Line2D width 3, closed), a face opening with two dark dot eyes and small round spectacles (Line2D circles), a long grey beard triangle, one arm holding up a green lantern (lantern body Polygon2D Color(0.35,1,0.45) + additive radial glow sprite 90 px, GradientTexture2D RADIAL, CanvasItemMaterial BLEND_MODE_ADD) and a closed book under the other arm (brown rectangle with a gold spine line). Also add a dark ground shadow ellipse under the figure.
Also: in the diamonds room the third Assay Trio figure is overlapped by the video shrine panel edge. Move ALL examiners' anchor x so the whole figure (and its label) sits between x=700 and x=860 with >=20 px gap from the video shrine's left edge (read the shrine geometry in this file and compute it). The label must be centred above its own figure.

@include src/protocol_portals/StudyRoom.gd
