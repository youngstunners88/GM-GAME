"""Inferno Bull inspection (headless): bone list + neutral turnaround renders. No set, no volumes - cheap and safe on 8 GB.
    blender -b design/ep2/blender/inferno-bull-pbr_v3.blend --python tools/ep2_blender/bull_inspect.py -- --out design/ep2/blender/renders/bull_insp
Writes <out>_front.png / _side.png / _back.png and prints the armature hierarchy (name, parent, head, tail)."""
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=None): return argv[argv.index(n) + 1] if n in argv else d
OUT = arg("--out"); W = int(arg("--w", 560)); H = int(arg("--h", 800)); SAMPLES = int(arg("--samples", 12))
def log(*a): print("[bull_inspect]", *a, flush=True)

S = bpy.context.scene
for img in bpy.data.images:
    if img.size[0] > 2048: img.scale(2048, 2048)
arm = bpy.data.objects["Armature"]; bull = bpy.data.objects["char1"]
log("bull verts", len(bull.data.vertices), "polys", len(bull.data.polygons), "vgroups", len(bull.vertex_groups), "mods", [m.type for m in bull.modifiers])
log("armature bones", len(arm.data.bones), "pose_position", arm.data.pose_position)
for b in arm.data.bones:
    h = arm.matrix_world @ b.head_local; t = arm.matrix_world @ b.tail_local
    log("BONE", b.name, "parent", b.parent.name if b.parent else None, "head", [round(x, 3) for x in h], "tail", [round(x, 3) for x in t])
anim = arm.animation_data.action.name if arm.animation_data and arm.animation_data.action else None
log("action", anim, "frame_range", S.frame_start, S.frame_end)

# lean stage: hide hero-scene extras, neutral light, flat floor
for o in S.objects:
    if o.name.startswith(("HS_", "Floor", "Key", "Fill", "Rim_", "FaceKicker")): o.hide_render = True
if "char1_LOD1" in bpy.data.objects: bpy.data.objects["char1_LOD1"].hide_render = True
S.render.engine = 'BLENDER_EEVEE'; S.eevee.taa_render_samples = SAMPLES; S.eevee.use_raytracing = False
S.view_settings.view_transform = 'Standard'
S.world.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.08, 0.09, 1); S.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
for loc, e in (((-3, -4, 4), 700), ((4, -3, 2), 250), ((0, 4, 3), 300)):
    d = bpy.data.lights.new("L", 'AREA'); d.energy = e; d.size = 3; o = bpy.data.objects.new("L", d); S.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.1)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
cam_d = bpy.data.cameras.new("IC"); cam_d.lens = 60; cam = bpy.data.objects.new("IC", cam_d); S.collection.objects.link(cam); S.camera = cam
S.render.resolution_x = W; S.render.resolution_y = H; S.render.resolution_percentage = 100
for name, loc in (("front", (0.4, -6.2, 1.1)), ("side", (6.2, 0.2, 1.1)), ("back", (-0.4, 6.2, 1.1))):
    cam.location = loc; cam.rotation_euler = (Vector((0, 0, 1.1)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    S.render.filepath = f"{OUT}_{name}.png"; bpy.ops.render.render(write_still=True); log("rendered", name)
log("done")
