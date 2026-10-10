"""Headless look at the GAME Inferno Bull GLB (inferno_bull_rigged.glb): front/side ortho renders + island report.

  python3 tools/ep2_blender/bull_game_inspect.py <glb> <out_prefix> [--clip Idle_02] [--frame 1] [--islands]

Uses CYCLES CPU at 12 samples (no EGL in the container); no GUI (blender-headless-render-safety).
Prints the bone heads (world, metres) and, with --islands, the 25 largest connected islands with bbox + main bone.
"""
import sys, math, argparse
import bpy, bmesh
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("glb"); ap.add_argument("out")
ap.add_argument("--clip", default=""); ap.add_argument("--frame", type=float, default=1.0)
ap.add_argument("--islands", action="store_true"); ap.add_argument("--res", type=int, default=640)
ap.add_argument("--views", default="front,side,back")
ap.add_argument("--clip-glb", default="", help="take --clip from this armature-only GLB (walk / run / sit)")
ap.add_argument("--lock-arms", action="store_true", help="arms at rest (Ep2BullHero locks them at idle/walk)")
ap.add_argument("--stretch", action="store_true", help="print edge stretch stats (posed vs bind) = the melted-arm measure")
ap.add_argument("--zoom", default="", help="x,z,ortho_scale: close-up centre (Blender metres)")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.data.objects if o.type == "MESH")
if a.clip_glb:
    have = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=a.clip_glb)
    for o in set(bpy.data.objects) - have:
        bpy.data.objects.remove(o, do_unlink=True)
    print("ACTIONS", [x.name for x in bpy.data.actions])
if arm.animation_data:
    if a.clip:
        act = bpy.data.actions.get(a.clip) or next((x for x in bpy.data.actions if x.name.startswith(a.clip)), None)
        arm.animation_data.action = act
        # Ep2Actor._drop_bone_translations: only Hips keeps translation keys at runtime
        for fc in [f for f in act.fcurves if f.data_path.endswith("location") and '"Hips"' not in f.data_path]:
            act.fcurves.remove(fc)
        if a.lock_arms:
            for fc in [f for f in act.fcurves if any('"%s"' % b in f.data_path for b in ("LeftShoulder", "LeftArm", "LeftForeArm",
                       "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"))]:
                act.fcurves.remove(fc)
    else:
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.matrix_basis.identity()
if a.stretch:
    import numpy as np
    me0 = mesh.data
    ev = np.array([e.vertices[:] for e in me0.edges])
    co0 = np.array([v.co[:] for v in me0.vertices])
    L0 = np.linalg.norm(co0[ev[:, 0]] - co0[ev[:, 1]], axis=1)
    worst = []
    rng = bpy.context.scene.frame_end if not arm.animation_data or not arm.animation_data.action else int(arm.animation_data.action.frame_range[1])
    for f in range(1, max(2, rng), 3):
        bpy.context.scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        me1 = mesh.evaluated_get(dg).to_mesh()
        co1 = np.array([v.co[:] for v in me1.vertices])
        L1 = np.linalg.norm(co1[ev[:, 0]] - co1[ev[:, 1]], axis=1)
        r = L1 / np.maximum(L0, 1e-5)
        worst.append(((r > 2.0) & (L0 > 1e-4)).sum())
        mesh.evaluated_get(dg).to_mesh_clear()
    print("STRETCH frames=%d edges>2x: mean=%.1f max=%d" % (len(worst), float(np.mean(worst)), int(np.max(worst))))
bpy.context.scene.frame_set(int(a.frame))
bpy.context.view_layer.update()
for pb in arm.pose.bones:
    h = arm.matrix_world @ pb.head
    print("BONE %-14s %6.3f %6.3f %6.3f" % (pb.name, h.x, h.y, h.z))

if a.islands:
    dg = bpy.context.evaluated_depsgraph_get()
    me = mesh.evaluated_get(dg).to_mesh()
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    seen = set(); isl = []
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; comp = []; seen.add(v.index)
        while stack:
            x = stack.pop(); comp.append(x.index)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen: seen.add(o.index); stack.append(o)
        isl.append(comp)
    isl.sort(key=len, reverse=True)
    print("ISLANDS", len(isl))
    vg = {g.index: g.name for g in mesh.vertex_groups}
    src = mesh.data
    for k, comp in enumerate(isl[:25]):
        co = [mesh.matrix_world @ bm.verts[i].co for i in comp]
        lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
        hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
        w = {}
        for i in comp[:: max(1, len(comp) // 400)]:
            for g in src.vertices[i].groups:
                w[vg[g.group]] = w.get(vg[g.group], 0) + g.weight
        top = sorted(w.items(), key=lambda t: -t[1])[:3]
        print("ISL %2d n=%6d lo=(%.2f %.2f %.2f) hi=(%.2f %.2f %.2f) %s" % (k, len(comp), lo.x, lo.y, lo.z, hi.x, hi.y, hi.z,
              " ".join("%s:%.0f" % t for t in top)))

sc = bpy.context.scene
sc.render.engine = "CYCLES"                      # no EGL here: Workbench/EEVEE cannot render headless
sc.cycles.device = "CPU"; sc.cycles.samples = 12; sc.cycles.use_denoising = False
sc.view_settings.view_transform = "Standard"
for ang, e in ((( 50, 0, 30), 3.5), ((60, 0, -140), 2.0)):
    L = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); L.data.energy = e
    L.rotation_euler = [math.radians(x) for x in ang]; sc.collection.objects.link(L)
sc.render.resolution_x = a.res; sc.render.resolution_y = a.res
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True; sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.35, 0.37, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.9
sc.camera = cam
# glTF +Z forward (character faces +Z in Godot) == Blender -Y after import
views = {"front": (Vector((0, -6, 1.25)), (math.radians(90), 0, 0)),
         "back": (Vector((0, 6, 1.25)), (math.radians(90), 0, math.radians(180))),
         "side": (Vector((6, 0, 1.25)), (math.radians(90), 0, math.radians(90))),
         "lside": (Vector((-6, 0, 1.25)), (math.radians(90), 0, math.radians(-90)))}
for v in a.views.split(","):
    cam.location, cam.rotation_euler = views[v][0].copy(), views[v][1]
    if a.zoom:
        zx, zz, zs = (float(t) for t in a.zoom.split(","))
        cam.data.ortho_scale = zs
        cam.location.z = zz
        if v in ("front", "back"): cam.location.x = zx
    sc.render.filepath = "%s_%s.png" % (a.out, v)
    bpy.ops.render.render(write_still=True)
print("DONE")
