# Safe, spacious education rooms

The founder withdrew the Diamonds bridge falling/life-loss request after playing Claude's change. Education rooms now use the same ground constraint for Lil Blunt and the advisor. Campaign hazards are untouched.

## Changes

- Repainted the Diamonds plateau as a broad forecourt with a flush bridge junction. Machinery sits beside the route, not across it. The existing amber doorway is the mint-gate interaction; the duplicate brazier is removed.
- Distributed the Diamonds stations across both terraces and the foreground. Gold stations alternate along the street with smaller, environment-scaled props and clear approaches. Smoke's current 420 courtyard, artwork, haze and three walk-in lounges are retained.
- Anchored sprite feet, contact shadows and colliders to the same point. Removed detached projected silhouettes and oversize shadow pools that made furniture appear suspended.
- The advisor follows safe footsteps and spends its full movement budget across short trail segments, with modest catch-up speed when needed.
- Retired the ledge-fall skill's old instructions so they cannot silently restore the withdrawn behaviour.

## Validation

`portal_traversal_test.gd` walks real movement inputs on a collision-aware route from the entrance to every activity station, then presses E and checks the correct mechanism. It visits all three Smoke lounge interiors, traverses the Diamonds bridge in both directions, holds against its edge, checks lives/opacity/control, and verifies the advisor's ground position and following distance. This is now a blocking CI check alongside the existing learning, quiz and scorecard suite. Rendered close-ups and overviews are captured outside the export directory.

## New art

Built-in imagegen edited the previous Diamonds painting. The unmodified 1916×821 PNG is saved as `src/assets/portals/maps/map_diamonds_courtyard.png`; a checked-in 0.90 WebP import preset keeps the web package small. The old Diamonds JPEG is replaced. Map rendering normalizes source dimensions into the established 2800×1200 coordinates before the existing 50px crop. No key or external generation service is required.

Final generation prompt:

Use case: precise-object-edit. Edit the supplied overhead crystal-citadel game map. Preserve the EXACT castle identity, luminous turquoise crystals, amber main entrance, teal chasm, detailed realistic painterly materials, overhead camera, lighting and wide 2800x1200 aspect. Change the geography to make a genuinely spacious playable education courtyard: EXPAND the solid stone plateau toward the foreground and to the right, so the broad lower terrace spans approximately x34%-89%, y45%-85% of the whole image. Move the sheer cliff edge down to y88% through the right half. Keep the same elevated bridge from bottom-left toward the castle entrance, but make its clear walking surface broader, and merge its upper half flush into the terrace with no raised parapet or gap across the junction. The bridge should join an OPEN forecourt at x48% y67%; a clear route continues northeast to the existing amber doorway at x58% y37%. Add a broad paved apron to the LEFT of that approach at x36%-48% y50%-67%, connected at grade. Flat legible cracked flagstones throughout, low edging only along OUTSIDE cliff edge, occasional small crystal clusters confined to perimeter. Preserve castle in upper half and preserve generous right courtyard free of towers and boulders. NO furniture, props, machines, books, characters, signs or UI; movable activity stations will be placed afterward. Ground realism: matching slab scale, continuous stone joints through bridge transition, same perspective and natural weathering as reference; never a flat pasted rectangle. Keep open broad pathways in all directions across the new terrace. No oversized foreground rocks hiding floor. No text, no watermark, no border. The enlarged solid ground is the key change; do not merely resize the original.

