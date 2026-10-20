"""THE WEAPON-SELECTOR ICONS WITH LIL BLUNT'S HANDS (founder 2026-10-21: "reconfigure the graphic in the selection tab so that the bow with the hands holding it can
be selected ... also reconfigure the Golden Remington in the selection tab as it doesn't have Lil Blunt's hand on it the way the rifle has his hands on it. We need to
maintain consistency in our designs"; skill ep2-weapon-selector-icons).

  blender -b --factory-startup -P tools/ep2_blender/render_weapon_icons.py -- --which remington|bow|winchester [--out <png>] [--samples 48]

The three icons share ONE studio (the Winchester icon's own: neutral world 0.65 / 0.7, two area lights, orthographic side camera, 640 x 320 transparent PNG, muzzle /
arrow to the left) so the three cards read as a set:
  winchester  src/episode2/assets/weapons/winchester_1886_founder.glb (unchanged recipe, kept here so all three live in one script)
  remington   golden_revolver_founder.glb = the founder's own hand-and-gun (his green arm, glove and leaf-badged cuff). The old icon came from the GUN-ONLY copy, so no hand.
  bow         extras/bow/founder_bow.glb posed in Blender at 80 % draw with the SAME maths as Ep2BowView._pose_founder: limbs `draw` shape key, two string segments, the
              nocked arrow, the string hand turned to its forearm direction.
Prints the output path and the opaque-pixel bounds.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WHICH = argv[argv.index("--which") + 1] if "--which" in argv else "remington"
SAMPLES = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 48
DRAW = float(argv[argv.index("--draw") + 1]) if "--draw" in argv else 0.8
OUT = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(ROOT, "src/episode2/assets/weapons/armory/%s_icon.png" % {"remington": "remington", "bow": "bow", "winchester": "winchester"}[WHICH])

bpy.ops.wm.read_factory_settings(use_empty=True)
CONV = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))        # game (x, y, z) -> blender (x, -z, y)


def g2b(v):
    return CONV @ Vector(v)


def load(path):
    bpy.ops.import_scene.gltf(filepath=path)


def mesh_points(objs=None):
    pts = []
    for o in bpy.data.objects:
        if o.type != "MESH" or (objs and o not in objs):
            continue
        dg = bpy.context.evaluated_depsgraph_get()
        eo = o.evaluated_get(dg)
        me = eo.to_mesh()
        pts += [eo.matrix_world @ v.co for v in me.vertices]
        eo.to_mesh_clear()
    return pts


if WHICH == "winchester":
    load(os.path.join(ROOT, "src/episode2/assets/weapons/winchester_1886_founder.glb"))
    cam_dir, ortho_k, tilt = Vector((1.6, 0.04, 0.42)), 1.42, True
elif WHICH == "remington":
    load(os.path.join(ROOT, "src/episode2/assets/weapons/armory/golden_revolver_founder.glb"))
    # the founder hand-and-gun: muzzle toward -x in the file; the icon camera looks at its right flank so the muzzle is on the left, like the rifle's
    cam_dir, ortho_k, tilt = Vector((0.0, -1.0, 0.12)), 1.30, True
else:
    load(os.path.join(ROOT, "src/episode2/extras/bow/founder_bow.glb"))
    objs = {o.name.split(".")[0]: o for o in bpy.data.objects}
    # --- pose exactly like Ep2BowView._pose_founder (game frame, then to blender)
    rest, full = objs["Nock_Rest"].location.copy(), objs["Nock_Full"].location.copy()           # blender-frame empties
    e = DRAW
    nock = rest.lerp(full, e)
    limb = e
    tips = {"Limb_Up": objs["Tip_Up"].location.copy(), "Limb_Low": objs["Tip_Low"].location.copy()}
    for n in ("Limb_Up", "Limb_Low"):
        for kb in objs[n].data.shape_keys.key_blocks:
            if kb.name == "draw":
                kb.value = limb
    bend, shorten = 0.13, 0.02
    ends = []
    for n, sign in (("Limb_Up", 1.0), ("Limb_Low", -1.0)):
        t = tips[n]                                              # blender frame: (x, -z_game, y_game)
        ends.append(Vector((t.x, t.y + bend * limb, t.z - sign * shorten * limb)))
    for o in (objs["Arrow"], objs["RightHand"]):
        o.location = nock
    # the string hand's forearm: turn FOUNDER_HAND_AXIS onto FOUNDER_FOREARM_DIR (game frame) about the nock
    axis_g, dir_g = Vector((-0.549, 0.712, -0.438)).normalized(), Vector((-0.28, -0.42, -0.86)).normalized()
    qg = axis_g.rotation_difference(dir_g)
    rb = CONV @ qg.to_matrix() @ CONV.transposed()
    objs["RightHand"].rotation_mode = "QUATERNION"
    objs["RightHand"].rotation_quaternion = rb.to_quaternion()
    # the string: two thin cylinders tip -> nock
    for i, end in enumerate(ends):
        d = nock - end
        bpy.ops.mesh.primitive_cylinder_add(radius=0.0035, depth=d.length, location=(end + nock) / 2, vertices=8)
        c = bpy.context.object
        c.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        sm = bpy.data.materials.new("String")
        sm.diffuse_color = (0.76, 0.70, 0.55, 1)
        sm.use_nodes = True
        next(n for n in sm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.76, 0.70, 0.55, 1)
        c.data.materials.append(sm)
    # the studio's bright world washes a glossy emblem out at icon size: matte it and let the neon read (the in-game material is untouched)
    em = bpy.data.materials.get("GM_Emblem")
    if em is not None:
        bs = next(n for n in em.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bs.inputs["Metallic"].default_value = 0.0
        bs.inputs["Roughness"].default_value = 0.95
        bs.inputs["Emission Strength"].default_value = 3.0
        bs.inputs["Base Color"].default_value = bs.inputs["Base Color"].default_value
    # the grown sleeve extensions are for the first-person view (they run off-screen there); on the card the arms end in their cut, like the rifle's forearm
    for n in ("BowArm", "RightHand"):
        ob = objs[n]
        keep = [i for i, m in enumerate(ob.data.materials) if m and m.name == "SleeveCloth"]
        if keep:
            import bmesh
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in keep], context="FACES")
            bm.to_mesh(ob.data)
            bm.free()
    # arrow to the left, string hand to the right: camera on the bow's +x flank (screen right = game -z = toward the archer); rolled so the tall bow fills the wide card
    cam_dir, ortho_k, tilt = Vector((1.0, 0.0, 0.10)), 1.20, True
    ROLL = math.radians(float(argv[argv.index("--roll") + 1]) if "--roll" in argv else 55.0)

pts = mesh_points()
lo = Vector(tuple(min(p[k] for p in pts) for k in range(3)))
hi = Vector(tuple(max(p[k] for p in pts) for k in range(3)))
center = (lo + hi) * 0.5
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = False
sc.cycles.device = "CPU"
sc.world = bpy.data.worlds.new("White neutral studio")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.65, 0.65, 0.65, 1)
sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
for loc, power, size in [((0.7, -0.3, 1), 60, 1), ((-0.5, 0.4, 0.6), 40, 0.7)]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    l = bpy.context.object
    l.data.energy = power
    l.data.size = size
    l.rotation_euler = (Vector((0, 0, 0.15)) - l.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add(location=center + cam_dir.normalized() * 3.0)
cam = bpy.context.object
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.type = "ORTHO"
# fit: the longer of the width/height (640 x 320 frame) with a margin
dv = (center - cam.location).normalized()
right = dv.cross(Vector((0, 0, 1))).normalized()
up = right.cross(dv).normalized()
if WHICH == "bow":
    q = Quaternion(dv, ROLL)                                     # roll the camera about its view axis
    right, up = q @ right, q @ up
    cam.rotation_euler = Matrix((right, up, -dv)).transposed().to_euler()
ws = [(p - center).dot(right) for p in pts]
hs = [(p - center).dot(up) for p in pts]
w, h = max(ws) - min(ws), max(hs) - min(hs)
cam.data.ortho_scale = max(w, h * 2.0) * {"remington": 1.32, "bow": 1.12, "winchester": 1.10}[WHICH]      # the card's key label sits top-left: the revolver keeps clear of it
cam.location = center + cam_dir.normalized() * 3.0 + right * ((max(ws) + min(ws)) / 2) + up * ((max(hs) + min(hs)) / 2)
sc.camera = cam
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 640, 320, 100
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("ICON_DONE", WHICH, OUT, "w/h", round(w, 3), round(h, 3))
