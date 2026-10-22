import bpy, math, os

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name, color, metallic=0.0, roughness=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    try:
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    except: pass
    return m

wood  = mat("St_Wood", (0.42, 0.28, 0.15), 0.0, 0.85)
def _pbrify(m, albedo_path, tint=(1.0, 1.0, 1.0)):
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(albedo_path)
    try:
        tex.image.colorspace_settings.name = 'sRGB'
    except: pass
    if tint[:3] == (1.0, 1.0, 1.0):
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = 'MULTIPLY'
        mul.inputs["Fac"].default_value = 1.0
        mul.inputs["Color1"].default_value = (*tint[:3], 1.0)
        nt.links.new(tex.outputs["Color"], mul.inputs["Color2"])
        nt.links.new(mul.outputs["Color"], bsdf.inputs["Base Color"])

_pbrify(wood, "/tmp/farm_work/tex/wood_albedo.jpg", tint=(0.85, 0.75, 0.65))
dark  = mat("St_Dark", (0.16, 0.10, 0.07), 0.0, 0.9)
roofm = mat("St_Roof", (0.30, 0.18, 0.12), 0.0, 0.9)
hole  = mat("St_Hole", (0.03, 0.02, 0.02), 0.0, 1.0)
haym  = mat("St_Hay", (0.75, 0.60, 0.25), 0.0, 0.95)
steelm = mat("St_Steel", (0.4, 0.4, 0.42), 0.8, 0.5)

def box(name, loc, size, material, rot=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = name
    o.dimensions = size
    if rot: o.rotation_euler = rot
    o.data.materials.append(material)
    return o

# Barn long side faces camera: 7m wide, walls 3m, stalls open
box("WallL", (-2.6, 0, 1.5), (1.6, 0.25, 3.0), wood)
box("WallR", (2.6, 0, 1.5), (1.6, 0.25, 3.0), wood)
box("WallTop", (0, 0, 2.85), (7.0, 0.25, 0.5), wood)
for x in (-1.05, 0.35, 1.75):
    box(f"Post_{x}", (x, 0, 1.5), (0.28, 0.3, 3.0), dark)
# Stall darkness behind openings
for cx in (-1.75, 0.0, 1.75):
    box(f"Stall_{cx}", (cx, -0.35, 1.4), (1.2, 0.1, 2.6), hole)
# Hayloft door + hay bale hint
box("Loft", (0, 0.02, 3.6), (0.9, 0.28, 0.9), dark)
box("Hay", (-0.1, -0.1, 3.55), (0.5, 0.3, 0.4), haym)
# Gable roof: two slabs + triangle ends
box("RoofL", (-1.85, 0, 4.15), (4.1, 2.6, 0.12), roofm, rot=(0, 0, math.radians(28)))
box("RoofR", (1.85, 0, 4.15), (4.1, 2.6, 0.12), roofm, rot=(0, 0, math.radians(-28)))
box("GableL", (-3.45, 0, 3.35), (0.25, 0.2, 1.3), wood)
box("GableR", (3.45, 0, 3.35), (0.25, 0.2, 1.3), wood)
# Hitch rail + trough to the right
box("Trough", (5.6, 0.6, 0.45), (1.6, 0.7, 0.6), wood)
box("Water", (5.6, 0.6, 0.72), (1.4, 0.5, 0.06), mat("St_Water", (0.25, 0.4, 0.5), 0.0, 0.2))
# Corral fence spanning wide, in front plane
for i in range(-8, 9):
    x = i * 1.5
    if abs(x) < 4.2: continue  # barn frontage
    box(f"FPost_{i}", (x, 1.1, 0.75), (0.16, 0.16, 1.5), wood)
box("FRail1", (0, 1.1, 1.25), (25.0, 0.1, 0.1), wood)
box("FRail2", (0, 1.1, 0.75), (25.0, 0.1, 0.1), wood)

# HDRI + side camera
hdri = "/tmp/train_work/studio_small_09_2k.hdr"
world = bpy.data.worlds["World"]; world.use_nodes = True
nt = world.node_tree; nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputWorld"); bg = nt.nodes.new("ShaderNodeBackground")
env = nt.nodes.new("ShaderNodeTexEnvironment"); env.image = bpy.data.images.load(hdri)
nt.links.new(env.outputs["Color"], bg.inputs["Color"])
nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
bpy.ops.object.light_add(type='SUN', location=(5, -6, 8))
bpy.context.active_object.data.energy = 2.0
bpy.ops.object.camera_add(location=(0, -16, 2.4), rotation=(math.radians(90), 0, 0))
cam = bpy.context.active_object
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 26.0
bpy.context.scene.camera = cam
scene = bpy.context.scene
scene.render.engine = 'CYCLES'; scene.cycles.samples = 48
scene.render.film_transparent = True
scene.render.resolution_x = 1400; scene.render.resolution_y = 600
outdir = "/tmp/farm_work"; os.makedirs(outdir, exist_ok=True)
scene.render.filepath = os.path.join(outdir, "sprite_prop_stable.png")
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(outdir, "stable.blend"))
print("DONE stable")
