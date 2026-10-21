# The Hunyuan paint pipeline imports bpy (Blender as a Python module) only to turn its textured OBJ into a GLB. bpy has no wheel for this pod's
# Python, so: make the import optional and override convert_obj_to_glb with a trimesh export. The OBJ + the PBR PNGs it wrote next to it are what we
# actually keep (rebuilt into a proper material locally in Blender 5.2).
p = "/workspace/Hunyuan3D-2.1/hy3dpaint/DifferentiableRenderer/mesh_utils.py"
s = open(p).read()
if "BPY_STUB" not in s:
    s = s.replace("import bpy\n", "try:\n    import bpy  # noqa\nexcept Exception:\n    bpy = None  # BPY_STUB\n", 1)
    s += '''

def convert_obj_to_glb(obj_path, glb_path, *args, **kwargs):  # BPY_STUB override
    import trimesh
    m = trimesh.load(obj_path, process=False)
    m.export(glb_path)
    return True
'''
    open(p, "w").write(s)
print("patched", "BPY_STUB" in open(p).read())
