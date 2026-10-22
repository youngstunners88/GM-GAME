"""Skin the painted Hunyuan3D-2.1 bear onto the EXISTING game bear skeleton (src/episode2/assets/bear_rigged.glb). Headless.

  blender -b --python tools/ep2_forge/bear_hunyuan_to_rig.py -- [--rot-z DEG] [--tex-size 1024] [--out ...]

Thin wrapper over bull_hunyuan_to_rig.py (same grafting: Blender exports only mesh+skin, the original GLB's nodes,
inverse-bind matrices and the 7 clips stay byte-identical, so the Bull's walk/run/sit clip GLBs keep driving the bear by
bone name). Only the defaults differ: rig, painted OBJ, clip for the stretch sample, material name, 1024 textures
(pack budget 189.2/190 MiB: the GLB must be <= 3.5 MB; the old one is 4.7 MB).
Any extra args override the defaults (argparse: last wins).
"""
import sys, os
here = os.path.dirname(os.path.abspath(__file__))
user = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
D = "design/ep2/blender/character-work/"
defaults = ["--rig", "src/episode2/assets/bear_rigged.glb",
            "--painted", D + "bear_hunyuan_painted/textured_mesh.obj",
            "--out", D + "bear_hunyuan_painted_rigged_candidate.glb",
            "--clip", "Idle", "--mat-name", "bear_hunyuan_painted",
            "--tex-size", "1024", "--rot-z", "0", "--smooth", "6", "--fit-arms", "--envelope", "3"]
sys.argv = [sys.argv[0], "--"] + defaults + user
exec(compile(open(os.path.join(here, "bull_hunyuan_to_rig.py")).read(), "bull_hunyuan_to_rig.py", "exec"))
