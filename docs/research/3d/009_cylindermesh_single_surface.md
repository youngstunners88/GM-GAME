# 009 — CylinderMesh has ONE surface (VERIFIED 2026-09-29)
`CylinderMesh.surface_set_material(1|2, ...)` (caps) errors "Index p_idx = 2 is out of bounds (1 = 1)" in the
Godot 4.3 web build, and the coin rendered as a brown blob. Build multi-material round parts from separate
meshes: a rim CylinderMesh + `_disc_mesh()` (ArrayMesh triangle fan with planar UVs) for each face.
