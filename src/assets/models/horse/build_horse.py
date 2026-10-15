import bpy, math, os
from mathutils import Vector

# Rigged horse, bone-parented parts (no weight painting), posed procedurally:
# walk = lateral-sequence 4-beat (LH 0, LF .25, RH .5, RF .75), graze, stand.
# Facing +X, up +Y. Side profile camera on +Z.

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name, color, roughness=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    try: bsdf.inputs["Roughness"].default_value = roughness
    except: pass
    return m

coat  = mat("Coat", (0.42, 0.23, 0.11))
coatF = mat("CoatFar", (0.34, 0.18, 0.09))
dark  = mat("Points", (0.12, 0.07, 0.05))
eyeM  = mat("Eye", (0.02, 0.02, 0.02), 0.2)

# ---------- armature ----------
bpy.ops.object.armature_add(location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "HorseRig"
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
eb["Bone"].name = "root"
def addbone(name, head, tail, parent="root"):
    b = eb.new(name); b.head = head; b.tail = tail; b.parent = eb[parent]
    return b
addbone("spine", (0, 1.32, 0), (0.15, 1.34, 0))
addbone("neck", (0.52, 1.45, 0), (0.66, 1.64, 0), "spine")
addbone("neck2", (0.66, 1.64, 0), (0.80, 1.84, 0), "neck")
addbone("head", (0.80, 1.84, 0), (1.04, 1.98, 0), "neck2")
addbone("tail1", (-0.62, 1.38, 0), (-0.72, 1.10, 0))
addbone("tail2", (-0.72, 1.10, 0), (-0.76, 0.82, 0), "tail1")
legs = {}
for tag, x, z in (("FL", 0.44, 0.13), ("FR", 0.44, -0.13), ("HL", -0.44, 0.13), ("HR", -0.44, -0.13)):
    up = addbone(f"{tag}_up", (x, 1.18, z), (x, 0.68, z))
    lo = addbone(f"{tag}_lo", (x, 0.68, z), (x, 0.20, z), f"{tag}_up")
    ho = addbone(f"{tag}_ho", (x, 0.20, z), (x + 0.03, 0.06, z), f"{tag}_lo")
    legs[tag] = (up.name, lo.name, ho.name)
bpy.ops.object.mode_set(mode='OBJECT')
for _b in arm.pose.bones:
    _b.rotation_mode = 'XYZ'

def part(name, prim, material, bone, **kw):
    if prim == 'sphere':
        bpy.ops.mesh.primitive_uv_sphere_add(radius=kw.get('r', 0.2), location=kw.get('loc', (0, 0, 0)))
    elif prim == 'cube':
        bpy.ops.mesh.primitive_cube_add(location=kw.get('loc', (0, 0, 0)))
    elif prim == 'cyl':
        bpy.ops.mesh.primitive_cylinder_add(radius=kw.get('r', 0.1), depth=kw.get('d', 0.4),
            location=kw.get('loc', (0, 0, 0)), vertices=14)
        if 'rot' in kw: bpy.context.active_object.rotation_euler = kw['rot']
    elif prim == 'cone':
        bpy.ops.mesh.primitive_cone_add(radius1=kw.get('r', 0.06), depth=kw.get('d', 0.2),
            location=kw.get('loc', (0, 0, 0)))
        if 'rot' in kw: bpy.context.active_object.rotation_euler = kw['rot']
    o = bpy.context.active_object
    o.name = name
    if 'dim' in kw: o.dimensions = kw['dim']
    o.data.materials.append(material)
    _skin(o, bone)
    return o


def tube(name, p1, p2, r, material, bone):
    """Cylinder strung from world point p1 to p2 (rest pose)."""
    v1, v2 = Vector(p1), Vector(p2)
    d = v2 - v1
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, vertices=12)
    o = bpy.context.active_object
    o.name = name
    o.location = (v1 + v2) / 2
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    o.data.materials.append(material)
    _skin(o, bone)
    return o

def _skin(o, bone):
    """Rigid skin: whole island weighted 1.0 to one bone (survives the join)."""
    g = o.vertex_groups.new(name=bone)
    g.add([v.index for v in o.data.vertices], 1.0, 'REPLACE')

# Torso (parented to spine; local offsets relative to bone heads get baked as parent-inverse)
barrel = part("Barrel", 'sphere', coat, "spine", r=0.3, loc=(0, 1.30, 0)); barrel.scale = (2.1, 1.05, 0.95)
part("Chest", 'sphere', coat, "spine", r=0.27, loc=(0.52, 1.28, 0))
part("Rump", 'sphere', coat, "spine", r=0.29, loc=(-0.52, 1.32, 0))
# Neck + head
tube("NeckLo", (0.50, 1.40, 0), (0.66, 1.64, 0), 0.145, coat, "neck")
tube("NeckHi", (0.66, 1.64, 0), (0.82, 1.84, 0), 0.115, coat, "neck2")
part("Head", 'cube', coat, "head", loc=(0.90, 1.85, 0), dim=(0.36, 0.20, 0.17))
part("Muzzle", 'cube', coatF, "head", loc=(1.08, 1.78, 0), dim=(0.16, 0.15, 0.14))
part("EarL", 'cone', dark, "head", r=0.035, d=0.12, loc=(0.78, 2.02, 0.06), rot=(math.radians(-90), 0, 0))
part("EarR", 'cone', dark, "head", r=0.035, d=0.12, loc=(0.78, 2.02, -0.06), rot=(math.radians(-90), 0, 0))
part("EyeL", 'sphere', eyeM, "head", r=0.025, loc=(0.95, 1.90, 0.10))
part("EyeR", 'sphere', eyeM, "head", r=0.025, loc=(0.95, 1.90, -0.10))
part("Forelock", 'cube', dark, "head", loc=(0.80, 1.96, 0), dim=(0.10, 0.12, 0.10))
# Mane ridge along upper neck
for i, (mx, my) in enumerate([(0.68, 1.78), (0.73, 1.86), (0.78, 1.94)]):
    part(f"Mane{i}", 'cube', dark, "neck2", loc=(mx - 0.06, my + 0.08, 0), dim=(0.10, 0.16, 0.07))
# Legs: upper/cannon tinted near/far, hooves dark
for tag, x, z in (("FL", 0.44, 0.13), ("FR", 0.44, -0.13), ("HL", -0.44, 0.13), ("HR", -0.44, -0.13)):
    cm = coat if z > 0 else coatF
    tube(f"{tag}Upper", (x, 1.18, z), (x, 0.68, z), 0.075, cm, f"{tag}_up")
    tube(f"{tag}Cannon", (x, 0.68, z), (x, 0.20, z), 0.048, cm, f"{tag}_lo")
    tube(f"{tag}Hoof", (x - 0.01, 0.15, z), (x + 0.03, 0.02, z), 0.068, dark, f"{tag}_ho")
# Tail chain
tube("Tail1", (-0.60, 1.42, 0), (-0.72, 1.08, 0), 0.05, dark, "tail1")
tube("Tail2", (-0.72, 1.08, 0), (-0.77, 0.76, 0), 0.038, dark, "tail2")

# Join islands into one skinned mesh (groups merge by bone name = rigid skin).
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
_parts = [o for o in bpy.data.objects if o.type == 'MESH']
for _o in _parts:
    _o.select_set(True)
bpy.context.view_layer.objects.active = _parts[0]
bpy.ops.object.join()
_horse = bpy.context.active_object
_horse.name = "HorseMesh"
_mod = _horse.modifiers.new("HorseRig", 'ARMATURE')
_mod.object = arm
bpy.context.view_layer.update()

# ---------- posing ----------
pb = arm.pose.bones
PHASE = {"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75}

def reset():
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
        b.scale = (1, 1, 1)

def pose_walk(p):
    """Lateral-sequence walk: each leg swings fore-aft, knee folds on the carry."""
    reset()
    for tag, ph in PHASE.items():
        s = 2 * math.pi * ((p - ph) % 1.0)
        up, lo, ho = (pb[f"{tag}_up"], pb[f"{tag}_lo"], pb[f"{tag}_ho"])
        up.rotation_euler = (0, 0, -0.34 * math.sin(s))
        lo.rotation_euler = (0, 0, 0.10 + 0.55 * max(0.0, math.sin(s + 1.1)))
        ho.rotation_euler = (0, 0, 0.34 * math.sin(s) - 0.10 - 0.35 * max(0.0, math.sin(s + 1.1)))
    bob = math.sin(4 * math.pi * p)
    pb["spine"].rotation_euler = (0, 0, 0.018 * bob)
    pb["root"].location = (0, 0.018 * math.sin(4 * math.pi * p + 0.8), 0)
    # head counter-bobs twice per stride (two-joint neck: base and poll oppose)
    pb["neck"].rotation_euler = (0, 0, 0.05 * math.sin(4 * math.pi * p + 2.4))
    pb["neck2"].rotation_euler = (0, 0, -0.04 * math.sin(4 * math.pi * p + 2.4))
    pb["head"].rotation_euler = (0, 0, -0.03 * math.sin(4 * math.pi * p + 2.4))
    pb["tail1"].rotation_euler = (0, 0.10 * math.sin(2 * math.pi * p), 0)

def pose_graze(t):
    """Head down cropping: two-joint fold (withers + poll) reaches the grass,
    forelegs soften, tail swishes, flank breathes, weight shifts."""
    reset()
    pb["neck"].rotation_euler = (0, 0, -1.15)
    pb["neck2"].rotation_euler = (0, 0, -0.85)
    pb["head"].rotation_euler = (0, 0, 0.62 + 0.06 * math.sin(2 * math.pi * t * 2))
    pb["FL_up"].rotation_euler = (0, 0, 0.10)
    pb["FL_lo"].rotation_euler = (0, 0, -0.16)
    pb["FR_up"].rotation_euler = (0, 0, -0.06)
    pb["spine"].rotation_euler = (0, 0, -0.10)
    pb["tail1"].rotation_euler = (0, 0.35 * math.sin(2 * math.pi * t * 2 + 1.0), 0)
    pb["tail2"].rotation_euler = (0, 0.30 * math.sin(2 * math.pi * t * 2 + 1.6), 0)
    # ears are skinned to the head; flick reads as a quick head toss at sprite scale.
    flick = max(0.0, math.sin(2 * math.pi * (t - 0.55) * 6)) if 0.55 < t < 0.75 else 0.0
    if flick > 0.5:
        pb["head"].rotation_euler = (0, 0, 0.55 - 0.18)
    pb["root"].location = (0.03 * math.sin(2 * math.pi * t), 0, 0)
    # breathing: flank swells via spine scale (legs hang off root, unaffected)
    br = 1 + 0.012 * math.sin(2 * math.pi * t)
    pb["spine"].scale = (br, 1, 1)

def pose_stand():
    reset()
    pb["neck"].rotation_euler = (0, 0, -0.04)
    pb["head"].rotation_euler = (0, 0, 0.02)

# ---------- scene, camera, render ----------
hdri = "/tmp/train_work/studio_small_09_2k.hdr"
world = bpy.data.worlds["World"]; world.use_nodes = True
nt = world.node_tree; nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputWorld"); bg = nt.nodes.new("ShaderNodeBackground")
env = nt.nodes.new("ShaderNodeTexEnvironment"); env.image = bpy.data.images.load(hdri)
nt.links.new(env.outputs["Color"], bg.inputs["Color"])
nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
bpy.ops.object.light_add(type='SUN', location=(5, -6, 8))
bpy.context.active_object.data.energy = 2.0
bpy.ops.object.camera_add(location=(0.1, 1.35, 7.0), rotation=(0, 0, 0))
cam = bpy.context.active_object
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 3.4
bpy.context.scene.camera = cam
scene = bpy.context.scene
scene.render.engine = 'CYCLES'; scene.cycles.samples = 48
scene.render.film_transparent = True
scene.render.resolution_x = 480; scene.render.resolution_y = 400
outdir = "/tmp/farm_work/horse"
os.makedirs(outdir, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath="/tmp/farm_work/horse_rig.blend")

def shoot(name, pose_fn, arg):
    pose_fn(arg)
    bpy.context.view_layer.update()
    scene.render.filepath = os.path.join(outdir, name)
    bpy.ops.render.render(write_still=True)

for i in range(8):
    shoot(f"horse_walk_{i:02d}.png", pose_walk, i / 8.0)
for i in range(6):
    shoot(f"horse_graze_{i:02d}.png", pose_graze, i / 6.0)
shoot("horse_stand.png", lambda _: pose_stand(), 0)
print("DONE horse frames")
