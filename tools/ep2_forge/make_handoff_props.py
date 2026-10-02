#!/usr/bin/env python3
"""Build the Episode 2 hand-off hero props as real, welded, smooth meshes (no Meshy credits needed):
  src/episode2/assets/winchester_1886.glb   lever-action rifle, 1.2 m, muzzle +Z, stock -Z, centred on the origin
  src/episode2/assets/miner_helmet.glb      brass-lamp hard hat, base at y=0, front +Z, radius ~0.24
Founder 2026-10-02: the old rifle was fifteen loose boxes (the stock floated apart) and the helmet a brass bowl.
Run: python3 tools/ep2_forge/make_handoff_props.py
"""
import numpy as np, trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.transformations import rotation_matrix as rot

def mat(rgb, metal=0.0, rough=0.7, emis=None):
    m = PBRMaterial(baseColorFactor=[*rgb, 1.0], metallicFactor=metal, roughnessFactor=rough)
    if emis is not None:
        m.emissiveFactor = emis
    return m

def colored(mesh, m):
    mesh.visual = trimesh.visual.TextureVisuals(material=m)
    return mesh

def cyl(r, z0, z1, x=0.0, y=0.0, sections=20, rr=None):
    """Cylinder along Z from z0 to z1 (optionally tapered r -> rr)."""
    if rr is None:
        c = trimesh.creation.cylinder(radius=r, height=z1 - z0, sections=sections)
    else:
        prof = np.array([[0, 0], [r, 0], [rr, z1 - z0], [0, z1 - z0]])
        c = trimesh.creation.revolve(prof, sections=sections)
    if rr is None:
        c.apply_translation([x, y, (z0 + z1) / 2])
    else:
        c.apply_translation([x, y, z0])
    return c

def box(sx, sy, sz, x, y, z):
    b = trimesh.creation.box(extents=[sx, sy, sz])
    b.apply_translation([x, y, z])
    return b

def side_extrude(pts, width):
    """Polygon in (z, y) extruded `width` across X, centred."""
    from shapely.geometry import Polygon
    poly = Polygon([(z, y) for z, y in pts])
    m = trimesh.creation.extrude_polygon(poly, height=width)   # x=z_gun, y=y_gun, z=width
    v = m.vertices.copy()
    m.vertices = np.column_stack([v[:, 2] - width / 2, v[:, 1], v[:, 0]])
    m.faces = m.faces[:, ::-1]                                   # axis permutation flips winding
    m.fix_normals()
    return m

def rifle():
    steel = mat([0.13, 0.13, 0.15], 0.35, 0.45)
    blued = mat([0.09, 0.10, 0.13], 0.4, 0.4)
    wood = mat([0.42, 0.22, 0.10], 0.0, 0.55)
    brass = mat([0.78, 0.55, 0.18], 0.3, 0.4, [0.08, 0.05, 0.01])
    parts = []
    # stock: dropped comb, pistol grip wrist, curved butt
    stock = [(-0.13, 0.034), (-0.30, 0.036), (-0.45, 0.044), (-0.60, 0.050), (-0.63, 0.040), (-0.62, -0.075),
             (-0.58, -0.092), (-0.44, -0.040), (-0.30, -0.030), (-0.20, -0.052), (-0.14, -0.046)]
    parts.append(colored(side_extrude(stock, 0.034), wood))
    parts.append(colored(box(0.038, 0.12, 0.012, 0, -0.016, -0.626), brass))          # butt plate
    parts.append(colored(box(0.046, 0.074, 0.22, 0, 0.0, -0.01), steel))                # receiver
    parts.append(colored(box(0.030, 0.012, 0.15, 0, 0.040, -0.02), steel))              # receiver top strap
    parts.append(colored(box(0.010, 0.040, 0.022, 0, 0.056, -0.135), steel))            # hammer spur
    parts.append(colored(box(0.040, 0.030, 0.012, 0, -0.035, 0.105), brass))            # receiver nose band
    parts.append(colored(cyl(0.0155, 0.09, 0.585, 0, 0.026, 16), blued))               # barrel
    parts.append(colored(cyl(0.0105, 0.09, 0.50, 0, -0.012, 16), blued))               # magazine tube
    parts.append(colored(cyl(0.0125, 0.50, 0.52, 0, -0.012, 16), brass))               # mag cap
    parts.append(colored(box(0.014, 0.020, 0.016, 0, 0.045, 0.565), steel))            # front sight
    parts.append(colored(box(0.020, 0.012, 0.030, 0, 0.040, 0.18), steel))             # rear sight
    # forearm (wood) under the barrel
    parts.append(colored(box(0.040, 0.034, 0.30, 0, 0.002, 0.26), wood))
    parts.append(colored(box(0.012, 0.012, 0.012, 0, 0.0, 0.41), brass))
    # lever: a rounded loop under the receiver
    for (sx, sy, sz, y, z) in [(0.008, 0.008, 0.20, -0.088, -0.07), (0.008, 0.060, 0.008, -0.058, 0.03),
                               (0.008, 0.050, 0.008, -0.062, -0.17), (0.008, 0.008, 0.02, -0.036, -0.17)]:
        parts.append(colored(box(sx, sy, sz, 0, y, z), steel))
    parts.append(colored(box(0.006, 0.026, 0.008, 0, -0.050, -0.105), steel))            # trigger
    sc = trimesh.Scene()
    for i, p in enumerate(parts):
        sc.add_geometry(p, node_name=f"p{i}", geom_name=f"p{i}")
    return sc

def helmet():
    shell = mat([0.22, 0.13, 0.07], 0.0, 0.6)       # oiled leather-brown hard hat
    iron = mat([0.16, 0.15, 0.15], 0.3, 0.5)
    brass = mat([0.82, 0.58, 0.18], 0.3, 0.38, [0.1, 0.06, 0.01])
    glass = mat([1.0, 0.93, 0.62], 0.0, 0.2, [1.0, 0.9, 0.55])
    parts = []
    outer = [(0.0, 0.235), (0.07, 0.230), (0.14, 0.208), (0.20, 0.160), (0.232, 0.095), (0.245, 0.03), (0.25, 0.0),
             (0.31, -0.012), (0.325, -0.022)]
    inner = [(0.31, -0.03), (0.23, -0.016), (0.222, 0.03), (0.21, 0.09), (0.18, 0.15), (0.13, 0.195), (0.0, 0.215)]
    prof = np.array(outer + inner)
    h = trimesh.creation.revolve(prof, sections=40)
    h.apply_transform(rot(-np.pi / 2, [1, 0, 0]))  # revolve axis Z -> +Y
    v = h.vertices
    h.vertices = np.column_stack([v[:, 0], v[:, 1], v[:, 2]])
    h = trimesh.Trimesh(vertices=h.vertices, faces=h.faces, process=True)
    h.fix_normals()
    h = trimesh.smoothing.filter_laplacian(h, iterations=0) or h
    parts.append(colored(h, shell))
    # centre comb ridge, front to back
    parts.append(colored(box(0.030, 0.026, 0.28, 0, 0.214, 0.0), iron))
    # lamp bracket + reflector + lens on the brow
    parts.append(colored(box(0.09, 0.020, 0.040, 0, 0.115, 0.238), brass))
    refl = trimesh.creation.revolve(np.array([[0, 0], [0.034, 0], [0.066, 0.07], [0.0, 0.07]]), sections=28)
    refl.apply_translation([0, 0, 0])
    refl.apply_transform(rot(0, [1, 0, 0]))
    refl.apply_translation([0, 0.14, 0.236])
    parts.append(colored(refl, brass))
    lens = trimesh.creation.cylinder(radius=0.042, height=0.012, sections=24)
    lens.apply_translation([0, 0.14, 0.31])
    parts.append(colored(lens, glass))
    # rivets + chin-strap anchors
    for sx in (-1, 1):
        parts.append(colored(trimesh.creation.icosphere(subdivisions=1, radius=0.012).apply_translation([sx * 0.236, 0.05, 0.0]) or trimesh.creation.icosphere(subdivisions=1, radius=0.012), brass))
    sc = trimesh.Scene()
    for i, p in enumerate(parts):
        sc.add_geometry(p, node_name=f"h{i}", geom_name=f"h{i}")
    return sc

if __name__ == "__main__":
    import sys
    out = "src/episode2/assets/"
    rifle().export(out + "winchester_1886.glb")
    helmet().export(out + "miner_helmet.glb")
    print("ok")
