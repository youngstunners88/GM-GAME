"""Contact-fit Lil Blunt's right hand to the Remington; independent reusable hand mesh.
Reuses the project's Blender hand/skin tools, not the old runtime capsule fingers.
"""
import bpy, math, os, sys, bmesh
from mathutils import Vector, Matrix
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
OUT=os.path.join(ROOT,'src/episode2/assets/weapons/armory/remington_grip_hand.glb')
TEXDIR=os.path.join(ROOT,'design/ep2/armory/blender/hand-textures');os.makedirs(TEXDIR,exist_ok=True)
# Import only the existing author's modelling functions; do not run the rifle-hand build.
source=open(os.path.join(ROOT,'tools/blender/build_fp_hands.py')).read()
helpers=source[source.index('def B(p)'):source.index('# ------------------------------------------------------------------------------------------------------------------ main')]
helpers=helpers.replace('tris=1800','tris=600').replace('segments=10, ring_count=6','segments=8, ring_count=4')
helpers=helpers.replace('location=pos)', 'location=B(pos))').replace('location=cpos)', 'location=B(cpos))').replace('rotation_difference(up)', 'rotation_difference(B(up))')
exec(helpers)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
make_textures()
leaf=material('Lil Blunt textured green hand','fp_yarn.png',rough=.87)
leather=material('Worn sewn leather','fp_leather.png',rough=.65)
brass=material('Antique brass cuff',color=(.58,.34,.09,1),rough=.32,metal=.7)
parts=[sphere((-.033,-.101,-.113),.03,(.55,1.25,1.1))]
# Three fingers wrap the actual walnut face, with distinct knuckles/contact arcs.
for j in range(3):
 y=-.083-.019*j
 points=[(-.041,y,-.097),(-.035,y,-.074),(-.015,y,-.065),(.013,y,-.069),(.026,y,-.084)]
 for a,b in zip(points[:-1],points[1:]):parts.append(tube(a,b,.0077,.0072,seg=12))
 for p in points:parts.append(sphere(p,.0078))
# Index fingertip rests inside the trigger guard; the thumb crosses the backstrap.
for pts,r in [([(-.039,-.073,-.098),(-.032,-.058,-.068),(-.018,-.057,-.039),(0,-.055,-.028)],.0075),([(-.037,-.073,-.118),(-.027,-.06,-.104),(-.008,-.055,-.099),(.01,-.056,-.094)],.009)]:
 for a,b in zip(pts[:-1],pts[1:]):parts.append(tube(a,b,r,r*.9,seg=12))
 for p in pts:parts.append(sphere(p,r))
hand=skin(join(parts,'ContactFittedHand'),voxel=.0028,smooth=3,tris=2000);hand.data.materials.append(leaf)
wrist=Vector((-.038,-.126,-.127)); back=Vector((-.38,-.44,-.82)).normalized()
fa=forearm('Forearm',wrist,back,length=.65,r_wrist=.024,r_elbow=.038);fa.data.materials.append(leaf)
# Small bracer relative to pistol, with stitches/concho; avoids the giant old cuff.
cuff,band=bracer('Sewn bracer',wrist,back,c0=.027,length=.095,r=.033)
cuff.data.materials.append(leather);band.data.materials.append(brass)
for ob in [cuff]:
 bpy.context.view_layer.objects.active=ob;bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cylinder_project();bpy.ops.object.mode_set(mode='OBJECT')
# Seal textures into GLB and keep source separate from the production gun.
for img in bpy.data.images:
 if img.source=='FILE':img.pack()
for ob in [fa,cuff,band]:
 for p in ob.data.polygons:p.use_smooth=True
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'design/ep2/armory/blender/remington_grip_hand.blend'))
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',export_apply=True)
print('REMINGTON_HAND_DONE',os.path.getsize(OUT))
