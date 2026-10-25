import sys, os, bpy
argv = sys.argv[sys.argv.index("--") + 1:]
src, out_dir = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
img = None
for o in meshes:
    for m in o.data.materials:
        if m and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED" and n.inputs["Base Color"].links:
                    src_node = n.inputs["Base Color"].links[0].from_node
                    while src_node.type != "TEX_IMAGE" and src_node.inputs and any(i.links for i in src_node.inputs):
                        src_node = next(i for i in src_node.inputs if i.links).links[0].from_node
                    if src_node.type == "TEX_IMAGE":
                        img = src_node.image
print("@@meshes", len(meshes), "tris", sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons), "image", img.name if img else None, img.size[:] if img else None)
if img:
    img.filepath_raw = os.path.join(out_dir, "albedo.png"); img.file_format = "PNG"; img.save()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.wm.obj_export(filepath=os.path.join(out_dir, "minister.obj"), export_selected_objects=True, export_uv=True, export_normals=True,
                      export_materials=False, apply_modifiers=True)
print("@@ok")
