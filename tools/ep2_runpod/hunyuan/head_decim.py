import trimesh, pymeshlab
m = trimesh.load("/workspace/head_hy_shape.glb", force="mesh")
ms = pymeshlab.MeshSet(); ms.add_mesh(pymeshlab.Mesh(m.vertices, m.faces))
ms.meshing_decimation_quadric_edge_collapse(targetfacenum=60000, preservenormal=True, preserveboundary=True, qualitythr=0.5)
d = ms.current_mesh()
out = trimesh.Trimesh(d.vertex_matrix(), d.face_matrix())
out.export("/workspace/head_60k.glb"); print("DECIM", len(out.faces), "faces")
