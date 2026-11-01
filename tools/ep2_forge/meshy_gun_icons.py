"""Weapon-tab icons from the founder's shrunk Meshy guns: 640x320, transparent, broadside, muzzle LEFT (the card set convention).
blender -b --factory-startup -P tools/ep2_forge/meshy_gun_icons.py -- <meshy_dir> <out_dir> name=icon_name ...
"""
import bpy, sys, os, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src_dir, out_dir, pairs = argv[0], argv[1], [a.split("=") for a in argv[2:]]
for name, icon in pairs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src_dir, name + ".glb"))
    sc = bpy.context.scene
    meshes = [o for o in sc.objects if o.type == 'MESH']
    pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
    mn = mathutils.Vector([min(p[i] for p in pts) for i in range(3)])
    mx = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
    c = (mn + mx) / 2
    sc.render.resolution_x, sc.render.resolution_y = 640, 320
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = 'RGBA'
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.7, 0.72, 0.72, 1); bg.inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); sun.data.energy = 3.8
    sun.rotation_euler = (0.9, 0.3, -0.6); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    # broadside from +X: the muzzle (Blender -Y) is on screen LEFT, up +Z
    cam.location = c + mathutils.Vector((3, 0, 0)); cam.rotation_euler = (1.5708, 0, 1.5708)
    if "thompson" in name:          # colour-only Meshy texture: give the gold its metal (matches Ep2ArmoryGunView._gild)
        for m in bpy.data.materials:
            if m.node_tree:
                b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
                if b:
                    b.inputs['Metallic'].default_value = 0.55
                    b.inputs['Roughness'].default_value = 0.38
    cam.data.ortho_scale = max((mx.y - mn.y) * 1.06, (mx.z - mn.z) * 2.12)
    sc.render.filepath = os.path.join(out_dir, icon + ".png")
    bpy.ops.render.render(write_still=True)
    print("ICON", icon)
