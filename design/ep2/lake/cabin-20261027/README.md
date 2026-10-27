# Logan's woodland cabin — 2026-10-27

A small cedar cabin stands on a worn spur west of Logan's original lake route. Its open porch carries the canonical GM plaque/Goldmine wordmark and BTC medallion. A separate painted yard board reads **Be a liquidity provider.** The original RH and Jack Hammer wanted bills share a timber noticeboard. Two concave gold pans, seven pan nuggets, three exterior sorting-slate nuggets, ore sacks, a pick/shovel, BTC reserve coffer, stamped coins and ledger make Logan's gold-prospector/crypto-holder identity visible without adding a financial interaction.

The closed cabin is scenic; its courtyard and ramp/porch are reachable through ordinary movement. Terrain is padded and a spur joins the lake trail. Furniture/body collision, actual drawn terrain/deck contacts and tree clearance are checked. The supplied Logan, original boat/rowing, dialogue/staging/overlook, inventory and access/title contracts remain intact.

## Sources and spend

Meshy generated only the house shell: preview `01a17c58-94b8-7596-871d-d0907e4d2d62` (20), textured refine `01a17c5c-4927-7288-bf4b-a306c89cb919` (10). **30 credits total, balance542→512; no paid reruns.** See `MESHY_RECEIPT.json`. Raw source SHA512 is recorded in `SHA512SUMS`. No credentials or signed provider download links are stored here.

The shell was normalized to approximately6.20×4.60×4.80m and32,000 polygons, with1024px maximum maps. Local Blender4.3.2 authored the metre-scale porch/props/contact anchors; the documented5.2.2 and game-dev CLI were unavailable. Editable sources are in `sources/` (development-only `.gdignore`); scripts live in `tools/ep2_cabin/`. Measured coplanar shell slivers were moved3mm without repainting. Semantic cabin/pan/table QA passes; the shell retains46 hidden back-to-back pairs and one internal island, documented in `cabin-qa.json`, not presented as a perfectly clean scan. Real Godot Compatibility views were inspected.

Canonical art is reused unchanged: `assets/textures/logos/logo_gold_mine.png`, `assets/textures/tex_btc_coin.png`, and `extras/town/posters/poster_rh.png` / `poster_jack_hammer.jpg` beneath `src/episode2/`. The existing GM chained monogram supplies the brand; the wordmark and sentence are separately authored legible textures. Poster identity/reward text is inherited, not invented. New lettering uses the repository's OFL Rye/OldStandard fonts. The supplied full brand reference is not claimed to be a pixel-identical replacement for the existing canonical icon.

## Fine design skills

- `.claude/skills/ep2-logan-cabin/SKILL.md`: composition, scale, woodland clearance, preserving lake contracts.
- `ep2-logan-cabin-signage`: exact sentence, canonical marks/posters, physical backing, aspect ratios/readability.
- `ep2-logan-cabin-prospecting`: concave pans/nugget contact, supported reserve coins/ledger and period props.
- `ep2-logan-cabin-proof`: actual camera/contact, packed resources and verified release gates.

## Evidence

`captures/` contains seven actual player-camera views: approach, front, branding, wanted bills, panning station, reserves and return to the existing lake/boat. `tests/ep2_logan_cabin_test.tscn` passes26 checks, including actual triangle contact queries and ordinary movement. Existing lake art23, original story route, compile and save checks pass. `tools/ep2_cabin/check_pack.gd` checks the exact imports from an empty project, and `exported_cabin.gd` walks the cabin and original lake/rowing story from exported packs. Final export, hosted CI, upload and public-build evidence will be recorded in `RELEASE.md`; source integration is not a claim of deployment.
