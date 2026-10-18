"""Render the founder's untouched golden revolver GLB so the improvement has a baseline.
blender -b --python tools/ep2_blender/revolver_before.py -- <glb> <outdir>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import revolver_lib as L  # noqa: E402

glb, outdir = sys.argv[sys.argv.index("--") + 1:][:2]
m = L.load_main_mesh(glb)
lo, hi = L.bbox(m)
print("MAIN bbox", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
L.studio()
# imported orientation is unknown, so shoot three axis views + an iso
import bpy  # noqa: E402
L.VIEWS.update({"ax": (0.0, 0.0), "ay": (-90.0, 0.0), "az": (-90.0, 89.0), "iso": (-50.0, 25.0)})
L.render_views("before", outdir, views=["ax", "ay", "az", "iso"], samples=16)
