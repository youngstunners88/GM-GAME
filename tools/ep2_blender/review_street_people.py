"""Measure every required clip, run installed semantic QA and render source multiviews.
ALSOFT_DRIVERS=null blender -b --factory-startup -t 2 -P tools/ep2_blender/review_street_people.py -- --person clerk [--render]
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'design/ep2/town/people-rebuild-20261021'
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--person',required=True)
ap.add_argument('--render',action='store_true')
a=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
EXTENDED_WORK=ROOT/'design/ep2/town/autonomy-20261022'
config=json.loads((EXTENDED_WORK/'cast-build.json').read_text())
if (EXTENDED_WORK/'sources'/a.person/(a.person+'.blend')).exists(): WORK=EXTENDED_WORK
folder=WORK/'sources'/a.person
bpy.ops.wm.open_mainfile(filepath=str(folder/(a.person+'.blend')))
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH')
out=WORK/'qa'/a.person
out.mkdir(parents=True,exist_ok=True)


def installed(skill,file):
    directory=ROOT/'.claude/skills'/skill/'scripts'
    sys.path.insert(0,str(directory))
    spec=importlib.util.spec_from_file_location('street_'+file,directory/(file+'.py'))
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    return mod


rig=installed('blender-character-rigging','rig_check').run(armature=arm.name,meshes=[body.name],profile='game')
overlaps=[]
overlap_vertices=[]
inward=[]
def trace_overlaps(frame,event,arg):
    if event=='call' and frame.f_code.co_name=='_describe':
        parent=frame.f_back.f_locals
        if frame.f_locals['pairs'] is parent.get('zf_pairs'):
            for left,right in list(frame.f_locals['pairs'])[:20]:
                overlaps.append([list(sum((parent['verts'][v] for v in parent['tris'][i]),Vector())/3) for i in (left,right)])
                overlap_vertices.append([list(parent['tris'][i]) for i in (left,right)])
    if event=='call' and frame.f_code.co_name=='_result':
        parent=frame.f_back.f_locals
        for group,volume in parent.get('vol',{}).items():
            if parent['closed'][group] and volume < -1e-9:
                info=parent['island_info'][group]
                ids=set(info['verts']);tiles=set()
                for poly in body.data.polygons:
                    for li in poly.loop_indices:
                        if body.data.loops[li].vertex_index in ids:
                            uv=body.data.uv_layers.active.data[li].uv;tiles.add((int(uv.x*4),int(uv.y*4)))
                inward.append(dict(center=list(info['center']),vertices=len(info['verts']),volume=volume,size=info['size'],uv_tiles=sorted(tiles)))
    return None
sys.settrace(trace_overlaps)
asset=installed('blender-asset-qa','qa_check').run(objects=[body.name],profile='game',eps=.0002)
sys.settrace(None)
asset['overlap_centers']=overlaps
asset['overlap_vertices']=overlap_vertices
asset['inward_islands']=inward
(out/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
(out/'asset.json').write_text(json.dumps(asset,indent=2)+'\n')
# Measured deformation, not a weight-transfer assumption. All vertices and edges at 12 samples/second.
sc=bpy.context.scene
for track in arm.animation_data.nla_tracks:track.mute=True
arm.data.pose_position='REST';bpy.context.view_layer.update()
def positions():
    ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    co=np.empty(len(me.vertices)*3,dtype=np.float64);me.vertices.foreach_get('co',co)
    ev.to_mesh_clear();return co.reshape(-1,3)
rest=positions();edges=np.asarray([tuple(e.vertices) for e in body.data.edges],dtype=np.int32)
lengths=np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1)
valid=lengths>.001
arm.data.pose_position='POSE'
clips=[]
for action in sorted(bpy.data.actions,key=lambda act:act.name):
    if action.name not in ('Idle','Walk','Greet','Point','Carry','Observe','Rest','Talk','Inspect','Alert'):continue
    arm.animation_data.action=action
    if action.slots:arm.animation_data.action_slot=action.slots[0]
    start,end=action.frame_range
    maximum=0;worst=0;minimum=1000;finite=True;maxtravel=0;worst_edge={};max_excess=0
    for frame in np.linspace(start,end,max(2,int((end-start)/2)+1)):
        sc.frame_set(int(frame),subframe=float(frame)%1);bpy.context.view_layer.update()
        co=positions();finite=finite and bool(np.isfinite(co).all())
        ratio=np.linalg.norm(co[edges[:,0]]-co[edges[:,1]],axis=1)[valid]/lengths[valid]
        current_lengths=np.linalg.norm(co[edges[:,0]]-co[edges[:,1]],axis=1)
        max_excess=max(max_excess,float((current_lengths-lengths).max()))
        m=float(ratio.max());minimum=min(minimum,float(ratio.min()))
        if m>maximum:
            maximum=m;worst=float(frame)
            index=np.flatnonzero(valid)[int(ratio.argmax())];indices=edges[index]
            worst_edge=dict(bind_length_m=float(lengths[index]),posed_length_m=float(current_lengths[index]),rest_positions=rest[indices].tolist(),weights=[{body.vertex_groups[g.group].name:round(g.weight,4) for g in body.data.vertices[int(i)].groups if g.weight>.0001}for i in indices])
        maxtravel=max(maxtravel,float(np.linalg.norm(co-rest,axis=1).max()))
    clips.append(dict(clip=action.name,samples=max(2,int((end-start)/2)+1),finite=finite,max_edge_stretch=round(maximum,4),min_edge_ratio=round(minimum,4),worst_frame=worst,max_vertex_travel_m=round(maxtravel,4),max_edge_excess_m=max_excess,worst_edge=worst_edge))
file_prefix='townswoman_' if a.person in ('lady','dressmaker') else 'townsman_'
glb=ROOT/'src/episode2/extras/people'/((config[a.person]['name'] if a.person in config else file_prefix+a.person)+'.glb')
inputs={str(path.relative_to(ROOT)):hashlib.sha512(path.read_bytes()).hexdigest() for path in [glb,folder/(a.person+'.blend'),ROOT/'tools/ep2_blender/rebuild_street_people.py']}
result=dict(rig_pass=rig['pass'],asset_pass=asset['pass'],clips=clips,all_clips_present=len(clips)==10,input_sha512=inputs)
(out/'deformation.json').write_text(json.dumps(result,indent=2)+'\n')
print('@@'+json.dumps(result),flush=True)

if a.render:
    arm.animation_data.action=bpy.data.actions['Idle']
    arm.animation_data.action_slot=arm.animation_data.action.slots[0]
    sc.frame_set(1)
    sc.render.engine='CYCLES';sc.cycles.samples=4;sc.cycles.use_denoising=True
    sc.render.threads_mode='FIXED';sc.render.threads=2
    sc.render.resolution_x=400;sc.render.resolution_y=500;sc.render.resolution_percentage=100
    sc.world=bpy.data.worlds.new('QA_world');sc.world.color=(.2,.2,.2)
    sc.view_settings.view_transform='Standard'
    for name,pos,power,size in [('key',(-3,-4,5),400,4),('fill',(3,-1,3),180,3),('rim',(0,3,4),250,3)]:
        ld=bpy.data.lights.new('QA_'+name,'AREA');ld.energy=power;ld.size=size
        ob=bpy.data.objects.new(ld.name,ld);sc.collection.objects.link(ob);ob.location=pos
        ob.rotation_euler=(Vector((0,0,.9))-ob.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('QA_camera');cam=bpy.data.objects.new(cd.name,cd);sc.collection.objects.link(cam);sc.camera=cam
    cd.type='ORTHO';cd.ortho_scale=2.1
    for name,pos in [('front',(0,-4,1.0)),('three_quarter',(3,-4,1.2)),('side',(4,0,1.0)),('back',(0,4,1.0))]:
        cam.location=pos;cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
if not rig['pass'] or not asset['pass'] or len(clips)!=10 or not all(c['finite'] for c in clips):
    raise RuntimeError('Street person QA did not pass; inspect the JSON and images')
