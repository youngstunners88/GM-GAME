#!/usr/bin/env python3
"""SOURCE-LEVEL GUARD: no soft, translucent, green-dominant VFX.

Why
---
The founder reported "green smudges" across every stage and Blaze Rush for
weeks. Every hunt went through the backdrop ART and found nothing, because the
art was clean. The culprit was `effects/smoke_puff.gd`, which drew the Blaze
Mode auto-puff as Color(0.8, 0.9, 0.8, 0.6) — soft-edged, translucent and
green-dominant — straight onto `get_tree().current_scene`, i.e. on top of every
backdrop in the game.

An image gate cannot reliably catch this: the puff only exists while the player
is in Blaze Mode, so a scripted capture that never picks up a power-up screens
clean. The defect has to be caught at the SOURCE.

The rule
--------
A VFX colour that is BOTH
  * green-dominant (G beats R and B by a clear margin), and
  * translucent (alpha < 1.0, so it washes over whatever is behind it)
reads as a smudge on this game's purple / cyan / amber backdrops. Opaque green
is fine — that is a character, a platform lip, a badge, a token, readable art.
It is the soft translucent wash that looks like dirt on the screen.

Allowlist
---------
`shooter/smoke_projectile.gd` is exempt: green smoke there is an explicit
founder request (the smoke-bomb explosion VFX), not an accident.

Exit code 1 on any violation, so CI blocks it.
"""
import glob
import os
import re
import sys

COLOR = re.compile(r'Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*(?:,\s*([0-9.]+)\s*)?\)')
# Deliberate, themed greens. Each needs a reason, not just a quiet skip.
ALLOW = {
    # Green smoke here is an explicit founder request (smoke-bomb explosion VFX).
    "src/shooter/smoke_projectile.gd",
    # The Blaze PORTAL is the green gateway by design - it is the thing you walk
    # into, not a wash over the scene.
    "src/dashmode/blaze_portal.gd",
    # Weed-themed bonus room; green is the palette there, on brand.
    "src/level/secret_realm.gd",
    # The hint path is a deliberate on-demand guide line the player opts into.
    "src/level/level_base.gd",
}
SKIP_DIRS = ("src/ui/",)   # UI text/borders are sharp art, not backdrop washes
GREEN_MARGIN = 0.08   # G must beat R and B by this. NOT 0.10: the real bug was
                      # Color(0.8, 0.9, 0.8) and 0.9-0.8 == 0.0999... in float,
                      # which slipped under a 0.10 test. Verified to catch it.
ALPHA_MAX = 0.80      # a genuine translucent WASH; above this it is solid art
ALPHA_MIN = 0.01      # alpha 0.0 is a tween start value, invisible, not a smudge


def main() -> int:
    bad = []
    # .tscn too: a month of green smudges survived because this gate only read
    # .gd code, while smoke_cloud_platform.tscn and dash_trail.tscn set their
    # translucent green in the SCENE file (founder, 2026-09-23).
    paths = glob.glob("src/**/*.gd", recursive=True) + glob.glob("src/**/*.tscn", recursive=True)
    for path in sorted(paths):
        norm = path.replace("\\", "/")
        if norm in ALLOW or norm.startswith(SKIP_DIRS):
            continue
        with open(path, encoding="utf-8", errors="replace") as fh:
            for lineno, line in enumerate(fh, 1):
                if line.lstrip().startswith("#"):
                    continue
                for m in COLOR.finditer(line):
                    r, g, b = (float(m.group(i)) for i in (1, 2, 3))
                    a = float(m.group(4)) if m.group(4) else 1.0
                    if (ALPHA_MIN < a < ALPHA_MAX
                            and g - r >= GREEN_MARGIN and g - b >= GREEN_MARGIN):
                        bad.append((path, lineno, r, g, b, a, line.strip()[:88]))

    # IDLE TRANSITION OVERLAY MUST BE INVISIBLE. scene_transition.gd is an
    # autoload CanvasLayer in front of EVERY screen. Its wipe shader used to
    # leave permanent smoke blobs at progress == 0 (smoothstep edge0 < 0 where
    # the noise mask is low) - the founder's "green smudges", 2026-08-20..09-23.
    sh = open("src/effects/transition_wipe.gdshader", encoding="utf-8").read()
    st = open("src/autoload/scene_transition.gd", encoding="utf-8").read()
    if "step(0.001, progress)" not in sh:
        bad.append(("src/effects/transition_wipe.gdshader", 0, 0, 0, 0, 0,
                    "idle wipe not forced to alpha 0 at progress 0 (missing step guard)"))
    if "_wipe_rect.visible = false" not in st or "_wipe_rect.visible = v > 0.001" not in st:
        bad.append(("src/autoload/scene_transition.gd", 0, 0, 0, 0, 0,
                    "wipe overlay is drawn while idle (must be hidden at progress 0)"))

    if not bad:
        print("[green-vfx] OK - no soft translucent green-dominant VFX colours; idle transition overlay hidden")
        return 0

    print("[green-vfx] FAIL - soft translucent GREEN VFX will read as a smudge "
          "over the game's purple/cyan/amber backdrops:\n")
    for path, lineno, r, g, b, a, src in bad:
        print(f"  {path}:{lineno}  Color({r}, {g}, {b}, {a})  "
              f"[G beats R by {g-r:.2f}, B by {g-b:.2f}]")
        print(f"      {src}")
    print("\n  Fix: make it neutral (e.g. Color(0.86, 0.86, 0.88, 0.55)), or add the")
    print("  file to ALLOW in this script if the green really is intended.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
