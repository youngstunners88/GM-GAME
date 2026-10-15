"""Fresh gun-only +X landscape source, with no mirrored Bitcoin emblem."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
s=bpy.context.scene
s.camera.location=Vector((-.85,-.09,.035))
s.camera.rotation_euler=(Vector((0,-.09,-.035))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=.57
s.render.resolution_x=896;s.render.resolution_y=496;s.render.resolution_percentage=100
s.render.film_transparent=True;s.cycles.samples=32
s.render.filepath=str(root/'src/assets/models/golden_revolver/sidearm_gun_only.png')
bpy.ops.render.render(write_still=True)
