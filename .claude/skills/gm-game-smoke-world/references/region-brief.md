# Smoke region brief

## Identity
- Room: The Reading Ring; examiner: Ember the Archivist; companion: Pauly The Smokest.
- Target: smoky forest archive with hedge paths and neon lounge alcoves. Use strategy-RPG readability and discovery as inspiration; create original architecture rather than copying Warcraft assets.
- Palette: moss #334E3C, slate #354149, warm stone #87775E; emerald lamps #64E986; restrained purple #8B6FC4. These are proposed authoring colors, not sampled brand constants.
- Hero: an ash-ring archive rotunda. Ground: mossy cobblestone, garden soil, clipped hedges, broken stone walls.

## Reference interpretation
Reference 01 supplies settlement density and winding paths, not lava in SMOKE. 02 supplies emerald/purple brand accents and relaxed attitude, not a giant logo floor. 03 supplies clipped hedge geometry, not literal text-shaped hedges. 04 supplies a purple lounge alcove and forest silhouette. The first section MUST visibly read as smoky.

## Baseline anchors
ash_ring (720,310): circular archive court; lounge_basket (1120,760): hedge lounge pavilion; arb_well (1560,300): stone arboretum well; paper (2050,720): sheltered reading terrace; video (2380,330): neon viewing alcove; exam (1450,610): Ember’s central desk.

Start at the existing shaft x=240. Read its actual arrival and exit y positions rather than guessing. Keep main paths distinct from trim or decorative rings. Retain map bounds until a tested layout change is justified. Allow scenic depth beyond the player boundary only when it remains visually contained and camera safe.

## Asset family
Prioritize three hedge modules with corner pieces; archive rotunda; masonry well; small lounge canopy; green brass reading lamp. Reuse modules with rotation/variants. Keep at most one dominant hero per camera view.

For each proposed prop, record: purpose, supporting surface, dimensions in world pixels and optional model metres, semantic front, top-down footprint, collision/decorative status, attachment face, source references, prompt, target atlas/triangles, pipeline/model, estimated cost and acceptance evidence. Require readable silhouette and a grounded base; reject fused objects, arbitrary text, cropped supports and mismatched camera perspective.

Prompt starter: “Isolated {prop}, smoky forest archive with hedge paths and neon lounge alcoves, stylized hand-painted 2.5D game asset, fixed orthographic three-quarter view matching the production camera, moss #334E3C, slate #354149, warm stone #87775E; emerald lamps #64E986; restrained purple #8B6FC4, complete grounded base, clear separated silhouette, no letters, logos, people or surrounding scene.” Refine against the actual camera before generation. A texture prompt instead describes a tileable ground material, flat lighting and no baked perspective/landmarks.

## Reject on review
Reject opaque green wash; featureless black woodland; corridor-maze dead ends; combat or smoke that hides prompts. Also reject landmarks that promise interactions they do not have, hidden stop labels, loss of official study access, or a scene that reads as the other two regions with a tint.

## Exercise this skill
- “The background is still black even after adding art”: diagnose draw order using live source before proposing more generation.
- “Make it expansive like the reference”: preserve the four-direction controller and learning gates; produce districts and traversable loops, not a first-person conversion.
- “Use the numbers from the reference poster”: preserve approved bank/copy facts; image lettering is not protocol authority.
- “Meshy timed out; run it again”: reconcile the existing task before any new paid submission.
