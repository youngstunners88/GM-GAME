Revise this Godot 4.3 GDScript file (web export, GL Compatibility renderer, no PointLight2D, no GPUParticles2D, no Thread). Output ONLY the full revised file wrapped exactly like:
=== FILE: src/protocol_portals/PortalLadder.gd ===
<contents>
=== END ===

A vision review of real gameplay screenshots (1280x720, game camera) found these defects. Fix ALL of them, keep every other behaviour, the exports, the signal, the group, the floor snap, the header comments and the "no solid collision" rule unchanged:
1. The "▼" character renders as a missing-glyph box in the game font. Remove ALL non-ASCII characters from every Label. Instead draw the down arrow as a Polygon2D chevron/triangle (pointing down, glow colour, ~26x18 px) placed left of the text, and make the label text "STUDY" (and "STUDY  [E]" when the player is in the zone).
2. No visible pulsing halo. Make the halo unmistakable: a soft radial glow built from a GradientTexture2D (fill = RADIAL, centre opaque glow colour → transparent edge) on a Sprite2D with CanvasItemMaterial blend ADD, ~260x260 px, centred on the shaft mouth, pulsing alpha 0.45..1.0 and scale 0.92..1.08 at ~1.4 Hz. Add a second thin bright ring (Line2D circle or ellipse, width 4, glow colour, closed) around the mouth that pulses in sync.
3. Low contrast on warm/gold backgrounds (Stage 3 gold glow blends into an orange mine). Put a DARK backing behind the portal: a near-black (Color(0.03,0.02,0.05,0.85)) rounded panel/ellipse ~120x60 px at the shaft mouth drawn UNDER the glow, and give the ladder rails/rungs a 2 px dark outline (draw a slightly wider dark line under each bright line). For protocol "gold" use a brighter, whiter gold Color(1.0,0.9,0.45) for the ring and rails so it separates from orange rock.
4. Label is too small and sits on a busy sky. Font size 22, outline_size 8 with near-black outline, and a dark rounded backing panel (StyleBoxFlat bg Color(0,0,0,0.6), corner radius 6, content margins 8/4) behind the text. Keep the label ~70 px above the shaft mouth.
5. Particles too sparse/faint: amount 28, larger (scale 3..5 px), glow colour with alpha fade-out via color_ramp, lifetime 1.4 s, upward velocity 40..80 px/s, emission rect the shaft width.
Keep z_index 5. Keep everything in code (the .tscn stays minimal).

CURRENT FILE:
@include src/protocol_portals/PortalLadder.gd
