# Blender revolver and western selector (2026-10-15)

The founder supplied a square image of an engraved golden Remington 1875 with curved walnut grip, long barrel, ejector/web and Bitcoin medallions. It is visible in the conversation but has no local uploaded-file path. Geometry was authored in Blender against that visual reference; this is not a downloaded reference image or a paid Tripo/Meshy result. The founder explicitly requested Blender.

`remington_1875_gold.blend` preserves the high detail source: real bore, fluted cylinder, curved frame/grip, trigger/guard/hammer/sights, floral curves and raised medallions. `remington_grip_hand.blend` preserves the fitted right hand and sewn bracer. The current hand is a fixed contact pose, not an articulated reload/finger animation. The founder Winchester mesh/textures are unchanged; its icon includes its original integrated hand.

Reproduce, from repo root, in separate headless Blender processes:

```sh
blender -b --python tools/ep2_blender/build_remington.py
blender -b --python tools/ep2_blender/bake_remington_game.py
blender -b --python tools/ep2_blender/build_remington_hand.py
blender -b --python tools/ep2_blender/render_winchester_icon.py
```

The first command authors the editable high source and gun icon; the bake command produces the compact runtime GLB (9,556 triangles, three meshes). Floral geometry bakes into portable colour/normal textures. Metallic base colour is baked through emission, avoiding the black panels caused by a diffuse-only metallic bake. Runtime hand: 4,307 triangles, four meshes. Finite position/normal and hash checks are in `game-asset-validation.json`. Source and game axes: +Z muzzle, +Y up, metres. FPS carry exposes the side; ADS and muzzle remain separately aligned.

The dedicated PNG import presets use high quality WebP, preserving alpha; mesh presets disable unnecessary LOD/shadow copies. The Latin Bookman subset uses MSDF for portrait scaling, with original license in FONT-LICENSE.txt. Recreate the subset with:

```sh
pyftsubset /usr/share/fonts/opentype/urw-base35/URWBookman-Demi.otf --unicodes=U+0020-007E,U+00B7,U+2013-2014 --output-file=src/episode2/assets/weapons/armory/western_bookman.otf
```

Actual Godot Compatibility renders are in `../captures/`; the studio PNG is source-art evidence only. Baked micro-engraving is intentionally less detailed than the editable source to fit web delivery. No claim of an exact photographic match or live deployment follows from the Blender render.
