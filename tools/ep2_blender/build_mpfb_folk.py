"""BACKGROUND FOLK FROM MPFB2 (MakeHuman for Blender) - the Stockpile's workers and the auction hall's five extra people
(founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21; skill ep2-mpfb2-crowd; licence row in ~/Documents/SmokeRealm-mocap/LICENCES.md).

    blender -b --factory-startup -P tools/ep2_blender/build_mpfb_folk.py -- <out_dir> [id ...] [--render <dir>]

Needs the MPFB2 add-on enabled as the Blender extension bl_ext.user_default.mpfb (~/tools/mpfb2/src/mpfb linked into
~/.config/blender/5.2/extensions/user_default/) and the MakeHuman CC0 system assets (makehuman_system_assets_cc0.zip, unpacked to
~/tools/mpfb2-assets/pack and linked into the extension's user data folder). The add-on code is GPLv3 and never ships; every asset
used here (base mesh, proxies, skins, clothes, hats, hair) is CC0.

Every figure gets the SAME skeleton (MPFB's "mixamo" rig: mixamorig:* bones), so one clip library (folk_clips.glb, retargeted once
by tools/ep2_motion/retarget_bvh.py) drives them all. Per figure: the low-poly proxy body, a CC0 skin, clothes + shoes + a hat
and hair; body faces hidden under the clothes are deleted (MPFB's delete groups), each mesh is decimated, every texture is cut to
256 px (128 px for hats and hair) - they are background people at 6-30 m. Exported in metres, facing +Z (glTF), feet on y = 0.
"""
import importlib
import math
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
RENDER = ""
if "--render" in argv:
    i = argv.index("--render")
    RENDER = argv[i + 1]
    argv = argv[:i] + argv[i + 2:]
OUT = argv[0]
ONLY = argv[1:]

# id -> phenotype (MPFB macros 0..1; age 0.5 = 25 y, 1.0 = 90 y), skin, clothes, hat, hair, decimate ratio for clothes
FOLK = {
    # THE STOCKPILE WORKERS (work dress; the game dirties them like the back-lot miners)
    "sp_shovel_a": dict(gender=1.0, age=0.55, muscle=0.72, weight=0.55, height=0.55, race=(0.0, 1.0, 0.0),
                        skin="young_caucasian_male", clothes=["male_worksuit01", "shoes06"], hat="fedora_cocked", hair="short02"),
    "sp_shovel_b": dict(gender=1.0, age=0.68, muscle=0.62, weight=0.62, height=0.48, race=(1.0, 0.0, 0.0),
                        skin="middleage_african_male", clothes=["male_worksuit01", "shoes01"], hat="fedora01", hair="short04"),
    "sp_barrow_a": dict(gender=1.0, age=0.5, muscle=0.6, weight=0.45, height=0.6, race=(0.0, 0.8, 0.2),
                        skin="young_caucasian_male2", clothes=["male_casualsuit03", "shoes06"], hat="fedora01", hair="short01"),
    "sp_barrow_b": dict(gender=1.0, age=0.6, muscle=0.7, weight=0.72, height=0.5, race=(0.2, 0.2, 0.6),
                        skin="middleage_asian_male", clothes=["male_worksuit01", "shoes01"], hat="fedora_cocked", hair="short03"),
    "sp_weigher": dict(gender=1.0, age=0.8, muscle=0.45, weight=0.6, height=0.45, race=(0.0, 1.0, 0.0),
                       skin="old_caucasian_male", clothes=["male_elegantsuit01", "shoes02"], hat="fedora01", hair="short04"),
    "sp_fire": dict(gender=1.0, age=0.88, muscle=0.4, weight=0.4, height=0.42, race=(0.7, 0.3, 0.0),
                    skin="old_african_male", clothes=["male_casualsuit05", "shoes01"], hat="fedora_cocked", hair="short02"),
    # THE AUCTION'S FIVE EXTRA PEOPLE (Sunday-best: suits, vests, hats; varied age and build)
    "au_bidder": dict(gender=1.0, age=0.75, muscle=0.5, weight=0.85, height=0.5, race=(0.0, 1.0, 0.0),
                      skin="middleage_caucasian_male", clothes=["male_elegantsuit01", "shoes02"], hat="fedora01", hair="short04"),
    "au_lady": dict(gender=0.0, age=0.6, muscle=0.4, weight=0.5, height=0.45, race=(0.0, 1.0, 0.0),
                    skin="middleage_caucasian_female", clothes=["female_elegantsuit01", "shoes03"], hat="", hair="bob02"),
    "au_youth": dict(gender=1.0, age=0.47, muscle=0.5, weight=0.3, height=0.65, race=(0.3, 0.7, 0.0),
                     skin="young_caucasian_male", clothes=["male_casualsuit02", "shoes04"], hat="fedora_cocked", hair="short01"),
    "au_matron": dict(gender=0.0, age=0.72, muscle=0.35, weight=0.75, height=0.4, race=(1.0, 0.0, 0.0),
                      skin="old_african_female", clothes=["female_casualsuit01", "shoes03"], hat="", hair="braid01"),
    "au_elder": dict(gender=1.0, age=0.95, muscle=0.3, weight=0.35, height=0.4, race=(0.0, 0.2, 0.8),
                     skin="old_asian_male", clothes=["male_casualsuit05", "shoes02"], hat="fedora01", hair="short02"),
}
PROXY = "proxy741"
TEX = 256
SMALL_TEX = 128
CLOTH_RATIO = float(os.environ.get("FOLK_CLOTH_RATIO", "0.16"))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")
HS = importlib.import_module("bl_ext.user_default.mpfb.services.humanservice").HumanService
AS = importlib.import_module("bl_ext.user_default.mpfb.services.assetservice").AssetService
TS = importlib.import_module("bl_ext.user_default.mpfb.services.targetservice").TargetService


def asset(name, sub):
    ext = {"skins": ".mhmat", "proxymeshes": ".proxy"}.get(sub, ".mhclo")
    p = AS.find_asset_absolute_path(name + "/" + name + ext, asset_subdir=sub)
    if p is None:
        p = AS.find_asset_absolute_path(name + ext, asset_subdir=sub)
    if p is None:
        raise RuntimeError("MPFB asset not found: %s/%s" % (sub, name))
    return p


def build(fid, spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")
    info = HS._create_default_human_info_dict()
    ph = info["phenotype"]
    for k in ("gender", "age", "muscle", "weight", "height"):
        ph[k] = spec[k]
    ph["race"] = {"african": spec["race"][0], "caucasian": spec["race"][1], "asian": spec["race"][2]}
    ph["proportions"] = 0.6
    info["name"] = fid
    info["skin_mhmat"] = asset(spec["skin"], "skins")
    info["skin_material_type"] = "MAKESKIN"
    info["proxy"] = asset(PROXY, "proxymeshes")
    # under a hat the hair is a few strands at the temples: not worth 1.8k vertices on a background man
    info["hair"] = asset(spec["hair"], "hair") if spec["hair"] and not spec["hat"] else ""
    info["eyebrows"] = ""
    info["eyelashes"] = ""
    info["clothes"] = [asset(c, "clothes") for c in spec["clothes"]] + ([asset(spec["hat"], "clothes")] if spec["hat"] else [])
    info["clothes_material_type"] = "MAKESKIN"
    info["rig"] = "mixamo"
    settings = HS.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    settings["override_rig"] = "mixamo"
    settings["override_skin_model"] = "MAKESKIN"
    basemesh = HS.deserialize_from_dict(info, settings)
    rig = basemesh.parent if basemesh.parent and basemesh.parent.type == "ARMATURE" else next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig.name = "Armature"
    rig.data.name = "Armature"
    # the base mesh is drawn by the proxy: remove it (its helpers and the hidden parts with it)
    bpy.data.objects.remove(basemesh, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    # apply every modifier but the armature (the proxy's delete-group masks under the clothes), then decimate the clothes
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                continue
            if m.type == "MASK" and PROXY in o.name.lower():
                # the clothes' delete groups are too coarse on a 741-vertex proxy: applied, they cut the arm away past a short
                # sleeve (a gap at the elbow, render 2026-11-21). The covered body is kept and pulled 12 mm in under the cloth.
                vg = o.vertex_groups.get(m.vertex_group) if m.vertex_group else None
                if vg is not None:
                    gi = vg.index
                    for v in o.data.vertices:
                        if any(g.group == gi and g.weight > 0.5 for g in v.groups) != m.invert_vertex_group:
                            continue
                        v.co -= v.normal * 0.012
                o.modifiers.remove(m)
                continue
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception as e:
                print("WARN modifier", o.name, m.name, e)
                o.modifiers.remove(m)
        low = o.name.lower()
        is_body = PROXY in low
        if not is_body:
            d = o.modifiers.new("dec", "DECIMATE")
            d.ratio = 0.15 if "shoes" in low else (0.25 if any(h in low for h in ("bob0", "braid", "short0", "ponytail", "long0", "afro")) else CLOTH_RATIO)
            # the armature modifier must stay last
            while o.modifiers[-1].name != "dec" and False:
                pass
            bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)
            bpy.ops.object.modifier_apply(modifier="dec")
        print("MESH", fid, o.name, len(o.data.vertices), [m.type for m in o.modifiers])
    for img in bpy.data.images:
        try:
            _ = img.pixels[0]                  # MPFB images load lazily: size reads 0 until the pixels are touched
        except Exception:
            pass
        if img.size[0] == 0:
            continue
        nm = img.name.lower()
        side = SMALL_TEX if ("fedora" in nm or "hair" in nm or any(h in nm for h in ("short0", "bob0", "braid", "afro", "ponytail", "long0"))) else TEX
        if "normal" in nm or "_ao" in nm or "bump" in nm or "rough" in nm:
            side = 64                     # dropped below: background people carry colour only
        if "shoe" in nm:
            side = SMALL_TEX
        if img.size[0] > side:
            img.scale(side, side)
            img.pack()                         # export the scaled pixels, not the full-size file on disk
    # colour only: unlink normal / ao / roughness images from every material (Godot keeps the albedo)
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in list(m.node_tree.nodes):
            if n.type == "TEX_IMAGE" and n.image is not None:
                nm = n.image.name.lower()
                if "diffuse" not in nm and "color" not in nm and "albedo" not in nm and not nm.endswith("_d.png"):
                    m.node_tree.nodes.remove(n)
                    continue
                hairy = any(h in nm for h in ("bob0", "braid", "short0", "ponytail", "long0", "afro", "hair"))
                if not hairy:
                    # opaque cloth and skin: no alpha link, so the exporter writes a JPEG (hair keeps its PNG cut-out)
                    for l in list(n.outputs["Alpha"].links):
                        m.node_tree.links.remove(l)
                    n.image.alpha_mode = "NONE"
                    m.blend_method = "OPAQUE" if hasattr(m, "blend_method") else None
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, fid + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=78,
                              export_apply=False, export_animations=False, export_yup=True, use_selection=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("FOLK", fid, os.path.getsize(path), "tris", tris, "bones", len(rig.data.bones))
    if RENDER:
        render(fid)
    return path


def render(fid):
    from mathutils import Vector
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = 320, 480
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.8, 0.0, 0.5)
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = Vector((1.2, -4.2, 1.3))
    cam.rotation_euler = (Vector((0, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(RENDER, fid + ".png")
    bpy.ops.render.render(write_still=True)


for fid, spec in FOLK.items():
    if ONLY and fid not in ONLY:
        continue
    build(fid, spec)
