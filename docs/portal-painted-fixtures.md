# Painted portal fixtures

The previous stop coordinates and procedural decorations were authored for an empty room, then rendered on top of the painted maps. This change replaces all 11 mechanism fixtures, the reading/video/exam stations and return points with themed painted sprites, and removes the obsolete path lines, shelves, beams, geometric landmarks and neon floor plates.

## Placement and interaction

- `RoomLayout.gd` is the coordinate authority. Anchors are prop ground contacts on the 2800×1100 view, cropping the 2800×1200 source paintings by 50px at the top and bottom.
- Smoke: ring garden, lounge steps, well beside the eastern garden, reading lectern along the trail.
- Diamonds: bridge winch, gate brazier, supply scales and compression machinery on solid citadel terraces.
- Gold: treasury, clock and smelter beside the shop fronts; claim board and study stations on the street.
- Ground polygons follow the paintings. Player movement is constrained to them; the companion follows recent footsteps. Each fixture has a small solid footprint, with its approach point 28px in front.
- E operates the nearest station within 100px. Proximity labels replace permanent signs; guide dialogue is in a screen-space panel. Mechanism discovery, study gating, quiz content and scorecards retain their existing rules.
- A compact return waystone replaces the room-sized ladder overlay. Campaign entry ladders still enter the rooms; E at the waystone uses the existing PortalTravel return state.

## Assets

Built-in imagegen generated three RGBA atlases at 1774×887. Alpha is retained; Godot uses fractional 4×2 AtlasTexture regions with filtering clipped to each cell. The originals are copied unchanged into `src/assets/portals/fixtures/`. Cell assignments and display widths are in `RoomFixture.gd`.

The three checked-in texture import presets use Godot's high-quality lossy WebP mode at 0.92, retaining alpha and original resolution. Source PNGs remain unchanged. CI captures stay under runner.temp, outside res://, and the export also excludes portal-captures so review screenshots cannot inflate the playable pack.

## Verification

The portal room suite exercises real approach movement, solid prop footprints, E interactions, connected ground routes, study selection, exam gating, pass/fail grading and scorecard persistence. The capture tool records all three overview frames and every individual station at gameplay resolution. The full project script/scene compile test also runs locally.

## Generation prompts

## smoke

Use case: stylized-concept. Asset type: production transparent game sprite atlas, 2048x1024, exactly 4 columns x 2 rows of equal 512x512 cells. Reference image: palette, painted material texture, elevated camera and lighting ONLY; do not reproduce its background. Create eight separate highly detailed Warcraft-inspired painterly fantasy environment props for the SMOKE forest pagoda map. True transparent background, NO scenery, no text, no labels, no frames, no UI. Each prop fully contained within its own cell with 60px padding, centered horizontally, floor contact at cell y=410, upper-left soft light, same elevated 40-degree camera. Rustic dark timber, patinated bronze, mossy grey stone, restrained jade light and lavender haze; grounded small contact shadow, richly painted surfaces, no cartoon outlines or flat diagram shapes. Row1 left-to-right: (1) low circular stone ash brazier with bronze ring rim and a tiny pale purple smoke wisp; (2) beautifully woven broad wicker reserve basket with carved wooden base, folded sacks and coins, a pagoda-lounge supply basket; (3) mossy circular stone arbitrage well, bronze crank and bucket, subtly luminous jade water; (4) low timber reading lectern with open parchment folio and small amber lantern. Row2 left-to-right: (5) ornate bronze scrying mirror on a low wooden stand, purple glass, no play icon; (6) pagoda clerk's low carved wooden desk, open ledger, brass inkpot and small amber lantern; (7) compact ancient return waystone with an inset subtle gold upward chevron rune, mossy base; (8) small matching incense lantern. Preserve generous transparent gutters between each cell; no broad ground patches.

## diamonds

Use case: stylized-concept. Asset type: production transparent game sprite atlas, 2048x1024, exactly 4 columns x 2 rows of equal 512x512 cells. Reference image supplies painterly materials, elevated 40-degree camera and dark teal lighting ONLY. Eight distinct Warcraft-inspired detailed environment props that belong to this dark crystal citadel; no backdrop, TRUE TRANSPARENT alpha, no labels, no text, no frames. Each object confined to its cell, 60px clear gutters, centered horizontally, ground contact at cell y=410. Dark weathered basalt, aged bronze, crystalline jade and turquoise, warm amber highlights; natural painted facets and sculpted surfaces; soft compact contact shadows. Row1 left-to-right: (1) squat basalt furnace brazier with bronze grille and contained amber flame, the blaze mechanism; (2) small intricate brass balance scales on basalt pedestal, few turquoise cut gems in one pan, limited supply display; (3) squat mechanical crystal compression press with bronze screw, basalt jaws and glowing faceted gem; (4) low bridge-control winch of aged bronze with chains wrapped around spool on dark stone plinth. Row2 left-to-right: (5) dark stone reading lectern with open illuminated parchment book and amber candle; (6) circular bronze scrying lens with inset cyan crystal on squat basalt base, no play triangle; (7) compact basalt-and-bronze archivist desk, ledger, quill, tiny crystal lamp; (8) short carved basalt return waystone with restrained gold upward chevron rune. All share scale, elevated map view, light direction and painterly detail, no flat diagram linework, no broad ground islands.

## gold

Use case: stylized-concept. Asset type: production transparent game sprite atlas, 2048x1024, exactly 4 columns x 2 rows of equal 512x512 cells. Reference image is STYLE, MATERIAL, LIGHT and elevated 40-degree CAMERA reference only; do not reproduce its scenery. Eight beautifully detailed Warcraft-inspired painterly mining town props, true transparent background alpha. Every prop completely inside its own cell with 60px clear margin, centered horizontally, ground contact at cell y=410; same upper-left warm afternoon light, weathered timber and aged brass, ochre stone, small natural contact shadows. Row1 left-to-right: (1) short rugged brass clock mechanism mounted in a carved oak stand, readable analog face and exposed gears, vesting clock; (2) squat heavy iron-bound oak treasury chest open with neatly stacked gold bullion, substantial sculpted hinges; (3) compact ore-smelting workstation with stone crucible, warm molten gold, tongs and small anvil, furnace heat contained; (4) rustic timber claim noticeboard on two short feet with 3 pinned parchment sheets bearing only faint unreadable marks, no lettering. Row2 left-to-right: (5) low wooden book lectern with open parchment folio and brass oil lamp; (6) ornate vintage brass projection lantern with glass lens and small film reels on wooden base, no floating play symbol; (7) short wooden clerk's desk with open ledger, quill, small balance weights and brass lamp; (8) low ore-stone return waystone with gold upward chevron rune and timber brace. Hand-painted convincing materials, rich forms, no flat icons, no vector outlines, no UI frames, no labels or readable text, no scenery, no connecting shadows across cells.

