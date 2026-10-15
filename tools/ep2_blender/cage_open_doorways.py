"""Open the mine-lift cage's two doorways (founder 2026-10-13: "why are they walking through the pole bars").

The Tripo cage (src/episode2/assets/mine_lift/mine_lift_cage.glb) carries baked grille bars across both door openings
(walkway side -z, surface side +z, game frame). Lil Blunt and Inferno walked straight through them. This deletes ONLY the
faces whose centroid lies inside each doorway volume (|x| < DOOR_HALF, 0.15 < y < 3.35, |z| > 1.45 in the game frame); the
door posts, the floor, the roof and the side walls stay. The game then hangs its own sliding gates in the openings.
Headless:  python3 tools/ep2_blender/cage_open_doorways.py <in.glb> <out.glb>
"""
import sys
import bpy
import bmesh

DOOR_HALF = 1.05
Y_LO, Y_HI = 0.15, 3.35
Z_IN = 1.45

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
removed = 0
total = 0
for ob in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    mw = ob.matrix_world
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    kill = []
    for f in bm.faces:
        total += 1
        c = mw @ f.calc_center_median()
        gx, gy, gz = c.x, c.z, -c.y                     # Blender Z-up -> game Y-up (glTF importer convention)
        if abs(gx) < DOOR_HALF and Y_LO < gy < Y_HI and abs(gz) > Z_IN:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    removed += len(kill)
    bm.to_mesh(ob.data)
    bm.free()
print("CAGE faces removed %d of %d" % (removed, total))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=False)
print("CAGE written", dst)
