"""Shared helpers for the golden revolver passes (headless Blender only; see
blender-headless-render-safety). Import with
    sys.path.insert(0, os.path.dirname(__file__)); import revolver_lib as L
"""
import math
import os

import bpy
from mathutils import Vector

# camera views: name -> (azimuth deg about Z, elevation deg). Muzzle is -X after orient().
VIEWS = {
    "side": (-90.0, 6.0),      # looking at the right flank, muzzle left
    "tq": (-55.0, 22.0),       # three-quarter hero
    "emblem": (-90.0, 0.0),
}


def load_main_mesh(glb):
    """Import the Tripo GLB, drop stray helper objects, return the revolver mesh."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    main = max(meshes, key=lambda o: len(o.data.polygons))
    for o in list(bpy.data.objects):
        if o is not main:
            bpy.data.objects.remove(o, do_unlink=True)
    main.parent = None
    bpy.context.view_layer.objects.active = main
    main.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return main


def bbox(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def studio(world_strength=1.0):
    """Cool-grey gradient world + warm key + cool rim, so polished gold has something to reflect."""
    sc = bpy.context.scene
    w = bpy.data.worlds.new("studio")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs["Color"])
    nt.links.new(bg.outputs[0], out.inputs[0])
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.25, (0.04, 0.045, 0.06, 1)
    e[1].position, e[1].color = 0.75, (0.85, 0.9, 1.0, 1)
    bg.inputs["Strength"].default_value = world_strength

    def area(name, loc, energy, size, color):
        d = bpy.data.lights.new(name, "AREA")
        d.energy, d.size, d.color = energy, size, color
        o = bpy.data.objects.new(name, d)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    area("key", (-1.6, -2.2, 2.4), 260, 2.0, (1.0, 0.93, 0.8))
    area("rim", (2.4, 1.6, 1.4), 150, 1.5, (0.75, 0.85, 1.0))
    area("fill", (0.0, -3.0, -0.4), 50, 3.0, (1.0, 1.0, 1.0))


def render_views(tag, outdir, res=(640, 360), samples=24, views=None, target=None):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 70
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    mesh = target or [o for o in bpy.data.objects if o.type == "MESH"][0]
    lo, hi = bbox(mesh)
    ctr = (lo + hi) / 2
    radius = max((hi - lo).length * 0.95, 0.1)
    os.makedirs(outdir, exist_ok=True)
    for name in views or VIEWS:
        az, el = VIEWS[name]
        a, e = math.radians(az), math.radians(el)
        cam.location = ctr + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * radius * 2.3
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(outdir, "rev_%s_%s.png" % (tag, name))
        bpy.ops.render.render(write_still=True)
        print("render done", sc.render.filepath)
