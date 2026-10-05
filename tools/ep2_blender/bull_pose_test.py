"""Inferno Bull re-pose experiment (headless): bake the current Idle_02 pose, drop the action, then apply rotation offsets to chosen bones
and render head / body crops so we can see which axis does what (bone axes on this Tripo rig are not intuitive).
    blender -b design/ep2/blender/inferno-bull-pbr_v3.blend --python tools/ep2_blender/bull_pose_test.py -- --out <prefix> --tests "Head:x:-20,Head:x:20,Head:z:20"
Each test renders <prefix>_<bone>_<axis>_<deg>.png (head close-up if bone is neck/Head, full body otherwise)."""
import bpy, sys, math
from mathutils import Vector, Matrix, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=None): return argv[argv.index(n) + 1] if n in argv else d
OUT = arg("--out"); TESTS = [t.split(":") for t in (arg("--tests", "")).split(",") if t]
SAMPLES = int(arg("--samples", 10))
def log(*a): print("[bull_pose]", *a, flush=True)

S = bpy.context.scene
for img in bpy.data.images:
    if img.size[0] > 2048: img.scale(2048, 2048)
arm = bpy.data.objects["Armature"]; bull = bpy.data.objects["char1"]
dg = bpy.context.evaluated_depsgraph_get()
arm_ev = arm.evaluated_get(dg)
baked = {pb.name: pb.matrix_basis.copy() for pb in arm_ev.pose.bones}      # pose at frame 1 as evaluated from Idle_02
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'
    m = baked[pb.name]; loc, rot, sc = m.decompose(); pb.location = loc; pb.rotation_quaternion = rot; pb.scale = sc
bpy.context.view_layer.update()
log("baked pose for", len(baked), "bones; action cleared")

for o in S.objects:
    if o.name.startswith(("HS_", "Floor", "Key", "Fill", "Rim_", "FaceKicker")): o.hide_render = True
if "char1_LOD1" in bpy.data.objects: bpy.data.objects["char1_LOD1"].hide_render = True
S.render.engine = 'BLENDER_EEVEE'; S.eevee.taa_render_samples = SAMPLES; S.eevee.use_raytracing = False
S.view_settings.view_transform = 'Standard'
S.world.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.08, 0.09, 1); S.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
for loc, e in (((-3, -4, 4), 700), ((4, -3, 2), 250), ((0, 4, 3), 300)):
    d = bpy.data.lights.new("L", 'AREA'); d.energy = e; d.size = 3; o = bpy.data.objects.new("L", d); S.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.1)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
cam_d = bpy.data.cameras.new("PC"); cam = bpy.data.objects.new("PC", cam_d); S.collection.objects.link(cam); S.camera = cam
S.render.resolution_percentage = 100

def shot(name, head):
    if head:
        cam_d.lens = 85; loc = Vector((0.5, -3.4, 2.35)); tgt = Vector((0, 0, 2.25)); S.render.resolution_x = 700; S.render.resolution_y = 700
    else:
        cam_d.lens = 55; loc = Vector((0.4, -6.2, 1.1)); tgt = Vector((0, 0, 1.1)); S.render.resolution_x = 560; S.render.resolution_y = 800
    cam.location = loc; cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    S.render.filepath = f"{OUT}_{name}.png"; bpy.ops.render.render(write_still=True); log("rendered", name)

shot("base_head", True)
for bone, axis, deg in TESTS:
    pb = arm.pose.bones[bone]; q0 = pb.rotation_quaternion.copy()
    rot = Euler((math.radians(float(deg)) if axis == "x" else 0, math.radians(float(deg)) if axis == "y" else 0, math.radians(float(deg)) if axis == "z" else 0)).to_quaternion()
    pb.rotation_quaternion = q0 @ rot          # local-space rotation on top of the baked pose
    bpy.context.view_layer.update()
    shot(f"{bone}_{axis}_{deg}", bone in ("Head", "neck"))
    pb.rotation_quaternion = q0
log("done")
