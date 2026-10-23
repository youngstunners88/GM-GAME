---
name: ep2-weapon-selector-icons
description: The personal-armory selection tab cards (Winchester, Golden Remington, bow) rendered as transparent 640x320 icons that ALL show Lil Blunt's green arm, glove and cuff holding the weapon, from one shared studio. TRIGGER on "selection tab", "weapon icon", "armory card", "the Remington has no hand", "bow icon", "consistency in our designs", any edit to ep2_weapon_selector.gd ICONS.
---

# Weapon selector icons with Lil Blunt's hand (ep2-weapon-selector-icons)

Founder (2026-10-21): the bow card must show the bow WITH the hands holding it, and "the Golden Remington in the selection tab doesn't have Lil Blunt's hand on it the way the rifle has
his hands on it. We need to maintain consistency in our designs." `Ep2WeaponSelector.ICONS` maps each weapon id to a PNG; the HUD hold button reuses it.

## Source of each icon (`tools/ep2_blender/render_weapon_icons.py --which winchester|remington|bow`)
One studio for all three (the Winchester icon's own: neutral world 0.65/0.7, two area lights, orthographic side camera, Cycles CPU 32-96 samples no denoise, 640x320 transparent PNG, muzzle / arrow LEFT,
forearm to the lower right):
- winchester: `winchester_1886_founder.glb` (unchanged look).
- remington: **`golden_revolver_founder.glb`** = the founder's own hand-and-gun (green sleeve, dark glove, leaf-badged cuff). The old icon was rendered from `golden_revolver_gun.glb` (gun ONLY, made for the
  third-person director) - that is why it had no hand. Margin 1.32 so the muzzle stays clear of the card's key label.
- bow: `extras/bow/founder_bow.glb` posed in Blender at 80 % draw with the SAME maths as `Ep2BowView._pose_founder` (limb shape key, two string cylinders, nocked arrow, string hand turned to the forearm
  direction); the grown sleeve extensions are deleted (the arms end in their cut like the rifle's), emblem material matted for the studio, camera rolled 55 degrees so the tall bow fills the wide card.
Install: write over `src/episode2/assets/weapons/armory/<id>_icon.png`; the import is `compress/mode=1` lossy 0.85 (the pack margin is tiny - icons are in `index.pck`); `bow_icon.svg` is gone.

## Gate and proof
`tests/ep2_weapon_icons_test.tscn` (EP2_WEAPON_ICONS): an icon for every weapon, 640x320 rasters, each shows Lil Blunt's green sleeve (>= 1.2 % leaf-green pixels; the gun-only Remington had 0), the bow card is a PNG.
`tools/ep2_shots/weapon_selector_shot.tscn` renders the real tab (all three owned) in a 1600x900 SubViewport - look at it: the three must read as one set. Run `godot --headless --import` before the shot or it shows the
previous ctex.
