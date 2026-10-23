"""Reference-led street cast. Separate background Blender process, never the artist's GUI.

blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/ep2_blender/rebuild_street_people.py -- --only rancher
Inputs, editable sources, image maps and receipts live in design/ep2/town/people-rebuild-20261021.
The original builder remains available, including its separate prisoner. Runtime roster/rig/clips stay unchanged.
"""
import argparse
import importlib.util
import json
import math
import os
from pathlib import Path
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'design/ep2/town/people-rebuild-20261021'
SPEC = importlib.util.spec_from_file_location('street_rig', ROOT/'tools/ep2_blender/build_armory_folk.py')
AF = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AF)
P = argparse.ArgumentParser(description=__doc__)
EXTENDED = json.loads((ROOT/'design/ep2/town/autonomy-20261022/cast-build.json').read_text())
P.add_argument('--only', choices=['clerk', 'oldtimer', 'rancher', 'dressmaker', 'lady'] + list(EXTENDED), required=True)
P.add_argument('--render', action='store_true')
args = P.parse_args(sys.argv[sys.argv.index('--')+1:])
KEY = args.only
CONFIG = {
 'clerk': dict(name='townsman_clerk',height=1.76,girth=.98,ref='1hf_4SEXRphX0utxj8bjTLsjsfqFxiM_K',eye=(.499,.181),chin=.244,morph='male-old',skin=(.49,.31,.23),hair=(.32,.29,.25)),
 'oldtimer': dict(name='townsman_oldtimer',height=1.69,girth=1.06,ref='1XFWvo-NIOQ_k7fzr8c6wvBqetckd4DFv',eye=(.50,.142),chin=.216,morph='male-old',skin=(.50,.32,.23),hair=(.35,.32,.27)),
 'rancher': dict(name='townsman_rancher',height=1.84,girth=1.08,ref=None,eye=(.50,.138),chin=.203,morph='male-young',skin=(.52,.34,.26),hair=(.105,.074,.052)),
 'dressmaker': dict(name='townswoman_dressmaker',height=1.66,girth=.96,ref='1dOSJCq5yxlw5ZpCthbsotOL2UvsDtXWq',eye=(.505,.157),chin=.218,morph='female-young',skin=(.59,.40,.30),hair=(.075,.050,.037)),
 'lady': dict(name='townswoman_lady',height=1.72,girth=.92,ref='1UKoNFW1zvswqQRNdVLvusFkYoNWbMUQm',eye=(.503,.127),chin=.190,morph='female-young',skin=(.63,.44,.34),hair=(.11,.075,.05)),
}
CONFIG.update(EXTENDED)
C = CONFIG[KEY]
STYLE = C.get('style',KEY)
FEMALE = STYLE in ('dressmaker','lady')
OUT = (ROOT/'design/ep2/town/autonomy-20261022' if KEY in EXTENDED else WORK)/'sources'/KEY
OUT.mkdir(parents=True,exist_ok=True)
MAPS = OUT/'textures'
MAPS.mkdir(exist_ok=True)
S = C['height']/1.86


def source_mesh():
    """Read only CC0 body group; discard all helper cages. Preserve the pinned source untouched."""
    verts=[]; faces=[]; groups={}; group=''
    for line in (WORK/'source/mh-base.obj').read_text().splitlines():
        a=line.split()
        if not a: continue
        if a[0]=='v': verts.append(tuple(map(float,a[1:])))
        elif a[0]=='g': group=a[1]; groups[group]=[]
        elif a[0]=='f':
            face=[int(x.split('/')[0])-1 for x in a[1:]]
            groups[group].extend(face)
            if group=='body': faces.append(face)
    vs=np.asarray(verts)
    for line in (WORK/('source/mh-'+C['morph']+'.target')).read_text().splitlines():
        a=line.split()
        if len(a)==4 and not line.startswith('#'):
            vs[int(a[0])]+=np.array(list(map(float,a[1:])))
    return vs,faces,{k:vs[list(set(ids))].mean(axis=0) for k,ids in groups.items() if ids}


def image_save(name, pixels, data=False, jpeg=False):
    h,w,_=pixels.shape
    im=bpy.data.images.new(name,w,h,alpha=False)
    im.colorspace_settings.name='Non-Color' if data else 'sRGB'
    im.pixels.foreach_set(np.asarray(pixels,dtype=np.float32).ravel())
    im.filepath_raw=str(MAPS/(name+('.jpg' if jpeg else '.png')))
    im.file_format='JPEG' if jpeg else 'PNG'
    im.save()
    return im


# One portable material/three image maps per person; no Blender procedural nodes in the exported asset.
TILES={'Skin':2,'Linen':3,'Wool':6,'Leather':7,'Felt':8,'Metal':9,'Hair':10,'Trim':11,'Skirt':12,'Apron':13,'Sole':14,'Eye':15}
PALETTE={
 'Skin':(C['skin'],.68,0), 'Linen':((.48,.43,.34),.91,0),
 'Wool':((.070,.063,.055) if STYLE=='clerk' else (.12,.115,.10),.94,0),
 'Leather':((.095,.060,.038),.59,0), 'Felt':((.065,.059,.050),.96,0),
 'Metal':((.53,.41,.24),.38,1), 'Hair':(C['hair'],.87,0), 'Trim':((.22,.18,.12),.8,0),
 'Skirt':((.10,.125,.13) if STYLE=='dressmaker' else (.23,.19,.135),.94,0),
 'Apron':((.48,.42,.32),.93,0), 'Sole':((.028,.024,.020),.9,0), 'Eye':((.56,.51,.44),.32,0),
}


def make_atlas():
    rng=np.random.default_rng(4101+list(CONFIG).index(KEY))
    bc=np.ones((1024,1024,4),dtype=np.float32)
    orm=np.ones_like(bc); normal=np.ones_like(bc); normal[:,:,:3]=(.5,.5,1)
    yy,xx=np.mgrid[0:256,0:256]
    for role,cell in TILES.items():
        x=(cell%4)*256;y=(cell//4)*256
        rgb,rough,metal=PALETTE[role]
        fine=rng.normal(0,.017,(256,256))
        weave=(np.sin(xx*math.pi)*.01+np.cos(yy*math.pi/2)*.012)
        if role in ('Wool','Skirt','Felt'): weave+=.013*np.sin(xx*.35)*np.cos(yy*.28)
        if role=='Hair': weave=.09*np.sin(xx*.6+np.sin(yy*.035))+.015*np.sin(xx*2)
        if role=='Leather': weave=.02*np.sin(xx*.12+np.sin(yy*.11))*np.sin(yy*.14)
        if role=='Skin': weave=.014*np.cos(xx*.17)*np.sin(yy*.11)
        variation=fine+weave
        if role=='Skirt' and FEMALE:
            variation+=.025*(np.cos(xx*.32)**12)*(np.cos(yy*.32)**12)
        tile=np.asarray(rgb)[None,None,:]*(1+variation[:,:,None]*3)
        if role=='Linen' and C.get('striped'):
            bands=np.where(yy[:,:,None]<128,np.asarray((.075,.08,.075)),np.asarray((.67,.64,.54)))
            tile=bands*(1+variation[:,:,None]*2)
        bc[y:y+256,x:x+256,:3]=np.clip(tile,.005,.9)
        orm[y:y+256,x:x+256,0]=1
        orm[y:y+256,x:x+256,1]=np.clip(rough+variation*.7,.18,.99)
        orm[y:y+256,x:x+256,2]=metal
        dy,dx=np.gradient(variation)
        normal[y:y+256,x:x+256,0]=.5-dx*.7
        normal[y:y+256,x:x+256,1]=.5-dy*.7
    # Cylindrical facial atlas. Only the frontal face uses the owner's photo; no street pixels wrap around the head.
    y,x=np.mgrid[0:512,0:512]; u=x/511;v=y/511
    theta=(u-.5)*2*math.pi; z=-.18+.31*v
    name='town-ref-'+C['ref']+'.jpg' if C['ref'] else 'town-reference.jpg'
    im=bpy.data.images.load(str(WORK/'references'/name))
    w,h=im.size
    px=np.empty(w*h*4,dtype=np.float32);im.pixels.foreach_get(px);px=px.reshape(h,w,4)
    sx=C['eye'][0]+np.sin(theta)*(.046 if FEMALE else .050)
    sy=C['eye'][1]-z*((C['chin']-C['eye'][1])/.101)
    sampled=px[np.clip(((1-sy)*h).astype(int),0,h-1),np.clip((sx*w).astype(int),0,w-1),:3]
    # Smooth transition at temples, chin/neck and forehead; preserve identity details without projecting the background.
    mask=np.clip((1.25-np.abs(theta))/.3,0,1)*np.clip((z+.13)/.025,0,1)*np.clip((.048-z)/.020,0,1)
    face=np.asarray(C['skin'])[None,None,:]*(1+ rng.normal(0,.012,(512,512,1)))
    face=face*(1-mask[:,:,None])+sampled*mask[:,:,None]
    bc[0:512,0:512,:3]=np.clip(face,.005,.95)
    orm[0:512,0:512,:3]=(1,.72,0)
    bcim=image_save(KEY+'_basecolor',bc,jpeg=True)
    ormim=image_save(KEY+'_orm',orm,data=True)
    nim=image_save(KEY+'_normal',normal,data=True)
    m=bpy.data.materials.new('M_'+KEY+'_PBR')
    b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    nodes=m.node_tree.nodes;links=m.node_tree.links
    for im,target in [(bcim,'Base Color')]:
        t=nodes.new('ShaderNodeTexImage');t.image=im;links.new(t.outputs['Color'],b.inputs[target])
    t=nodes.new('ShaderNodeTexImage');t.image=ormim
    sep=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],sep.inputs[0]);links.new(sep.outputs[1],b.inputs['Roughness']);links.new(sep.outputs[2],b.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=nim
    n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.35;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs[0],b.inputs['Normal'])
    b.inputs['IOR'].default_value=1.5
    return m


def part(role,bones):
    # Temporary per-part materials identify UV-atlas regions during the mesh join.
    if role not in AF.MATS:
        rgb,rough,metal=PALETTE.get(role,PALETTE['Skin'])
        AF.mat(role,rgb,rough,metal)
    return f.part(role,bones)


def loft(role,bones,sections,sides=32,fold=0,cap=True):
    p=part(role,bones)
    rings=[]
    for row,(x,y,z,rx,ry) in enumerate(sections):
        ring=[]
        for i in range(sides):
            a=2*math.pi*i/sides
            fl=fold*(.6*math.sin(a*12+z*1.5)+.25*math.sin(a*7-z*2))
            ring.append(p.bm.verts.new((x+(rx+fl)*math.cos(a),y+(ry+fl)*math.sin(a),z)))
        rings.append(ring)
    for a,b in zip(rings,rings[1:]):p.bridge(a,b,sides)
    if cap:p._face(list(reversed(rings[0])));p._face(rings[-1])
    return p


def line(role,bones,points,r=.0025):
    p=part(role,bones);p.limb([Vector(v) for v in points],[r]*len(points),8)
    return p


def head_and_hands(vs,faces,markers):
    eye=markers['joint-l-eye'].copy(); eye[0]=0
    srcscale=.105*S
    def hp(v):return Vector((v[0]*srcscale,-(v[2]-.20)*srcscale,j['foramen'].z+(v[1]-eye[1])*srcscale))
    p=part('Face',['Head'])
    neck_y=markers['joint-neck'][1]
    selected=[face for face in faces if all(vs[i][1]>max(neck_y+.05,eye[1]-.99) and (vs[i][1]>neck_y+.85 or abs(vs[i][0])<.65) for i in face)]
    def hair_face(face):
        center=sum((hp(vs[i]) for i in face),Vector())/len(face)
        back=max(0,min(1,(center.y/S+.06)/.10))
        hairline=j['foramen'].z+(.043*(1-back)-.065*back)*S
        return False if C.get('bald') else center.z>hairline
    ids=set(sum([face for face in selected if not hair_face(face)],[])); cache={i:p.bm.verts.new(hp(vs[i])) for i in ids}
    for face in selected:
        if not hair_face(face):p._face([cache[i] for i in face])
    loft('Skin',['Chest','Neck','Head'],[(0,.004*S,j['neck'].z-.038*S,.059*S,.055*S),(0,.002*S,j['neck'].z+.018*S,.051*S,.050*S),(0,-.003*S,j['foramen'].z-.075*S,.044*S,.047*S)],32)
    for side in ('l','r'):
        center=hp(markers['joint-'+side+'-eye'])
        p=part('Eye',['Head'])
        p.lathe([(0,-.011*S),(.008*S,-.008*S),(.012*S,0),(.008*S,.008*S),(0,.011*S)],24,xform=Matrix.Translation(center))
        disk('Hair',['Head'],center+Vector((0,-.012*S,0)),.0045*S)
    # Anatomical scalp shell follows the base skull, rather than a stack of separate hair balls.
    scalp=part('Hair',['Head'])
    sf=[face for face in selected if hair_face(face)]
    ids=set(sum(sf,[])); cache={}
    for i in ids:
        v=hp(vs[i]);cache[i]=scalp.bm.verts.new(v)
    for face in sf:scalp._face([cache[i] for i in face])
    for side,sx in [('L',1),('R',-1)]:
        # Each realistic five-digit hand is kept rigid to its Hand bone: no nearest-torso weights on fingertips.
        wrist=Vector(markers['joint-'+side.lower()+'-hand'])
        middle=Vector(markers['joint-'+side.lower()+'-finger-3-1'])
        ix=Vector(markers['joint-'+side.lower()+'-finger-2-1'])
        pk=Vector(markers['joint-'+side.lower()+'-finger-5-1'])
        longitudinal=(middle-wrist).normalized();across=(ix-pk).normalized();across=(across-longitudinal*across.dot(longitudinal)).normalized();normal=across.cross(longitudinal).normalized()
        target_long=(j['hand.'+side]-j['wrist.'+side]).normalized();target_across=Vector((0,-sx,0));target_normal=target_across.cross(target_long).normalized()
        def hand_coord(v):
            delta=Vector(v)-wrist
            return j['wrist.'+side]+(target_long*delta.dot(longitudinal)+target_across*delta.dot(across)+target_normal*delta.dot(normal))*(.104*S)
        hf=[fa for fa in faces if all(vs[i][0]*sx>3.65 and (Vector(vs[i])-wrist).dot(longitudinal)>-.13 for i in fa)]
        p=part('Skin',['Hand.'+side]);ids=set(sum(hf,[]));cache={i:p.bm.verts.new(hand_coord(vs[i])) for i in ids}
        for face in hf:p._face([cache[i] for i in face])
        # Extend the anatomical wrist boundary into the cuff, including a contact ring at the sleeve's end plane.
        boundary=[edge for edge in p.bm.edges if len(edge.link_faces)==1]
        for distance in (.012,.024):
            extruded=bmesh.ops.extrude_edge_only(p.bm,edges=boundary)
            vertices=[item for item in extruded['geom'] if isinstance(item,bmesh.types.BMVert)]
            center=j['wrist.'+side]-target_long*(distance*S)
            for vertex in vertices:
                delta=vertex.co-j['wrist.'+side]
                angle=math.atan2(delta.dot(target_normal),delta.dot(target_across))
                vertex.co=center+(target_across*math.cos(angle)+target_normal*math.sin(angle))*(.032*S)
            boundary=[edge for edge in extruded['geom'] if isinstance(edge,bmesh.types.BMEdge) and len(edge.link_faces)==1]


def torso_and_sleeves():
    first=len(f.parts)
    body=['Hips','Spine','Chest']
    waist=j['hips'].z;ch=j['chest'].z;neck=j['neck'].z
    width=.162 if FEMALE else .18
    shell=loft('Wool' if STYLE=='clerk' else 'Linen',body,[(0,0,waist-.06,.17*S,.112*S),(0,0,waist+.05,.156*S,.110*S),(0,0,j['spine'].z,.158*S,.109*S),(0,-.004,ch-.04,width*S,.119*S),(0,-.006,ch+.04,(width+.013)*S,.115*S),(0,0,neck-.055,.174*S,.09*S),(0,0,neck-.015,.075*S,.063*S)],fold=.0025*S)
    if FEMALE:
        for vertex in shell.bm.verts:
            amount=max(0,min(1,(ch-vertex.co.z)/(.18*S)))
            vertex.co.x*=1-.12*amount;vertex.co.y*=1-.12*amount
    if STYLE=='clerk':
        bib=part('Linen',body);rows=[]
        for z,y,w in [(waist+.02,-.116*S,.055*S),(j['spine'].z,-.119*S,.055*S),(ch,-.128*S,.058*S),(neck-.045,-.104*S,.045*S)]:
            rows.append([bib.bm.verts.new((x,y,z)) for x in (-w,0,w)])
        for left,right in zip(rows,rows[1:]):
            for i in range(2):bib._face((left[i],left[i+1],right[i+1],right[i]))
    # Stand collar and placket, cut to follow the chest.
    loft('Linen',['Neck','Chest'],[(0,0,neck-.02,.064*S,.06*S),(0,0,neck+.015,.059*S,.058*S)],24,cap=False)
    line('Trim',body,[(0,-.119*S,waist+.03),(0,-.123*S,ch-.05),(0,-.095*S,neck-.045)],.002*S)
    for k in range(5):
        z=waist+.07+k*.075*S
        disk('Metal',body,(0,-.125*S,z),.0038*S)
    for side,sx in [('L',1),('R',-1)]:
        a=j['arm.'+side];e=j['elbow.'+side];w=j['wrist.'+side]
        allowed=['Shoulder.'+side,'UpperArm.'+side,'Forearm.'+side,'Chest']
        # A continuous shoulder-to-cuff tube, with loops supporting both sides of the elbow.
        pts=[a+Vector((-sx*.065,0,-.04)),a,a.lerp(e,.23),a.lerp(e,.6),a.lerp(e,.88),e,e.lerp(w,.12),e.lerp(w,.35),e.lerp(w,.64),e.lerp(w,.78 if STYLE in ('rancher','dressmaker') else .96)]
        radii=[.045,.060,.064,.061,.055,.052,.052,.054,.048,.040]
        role='Wool' if STYLE=='clerk' else 'Linen'
        p=part(role,allowed)
        p.limb(pts,[(r*S,(r+.004)*S) for r in radii],24,cap0=True,cap1=True)
        # Tailored fold ridges grow from the same surface; do not add disconnected shoulder spheres.
        for idx in (3,5,7):
            at=pts[idx]
            q=part(role,allowed)
            direction=(pts[min(idx+1,len(pts)-1)]-pts[max(0,idx-1)]).normalized()
            q.limb([at-direction*.008*S,at,at+direction*.009*S],[(radii[idx]*S,radii[idx]*S),((radii[idx]+.004)*S,(radii[idx]+.004)*S),(radii[idx]*S,radii[idx]*S)],24,False,False)
        end=pts[-1];d=(w-e).normalized()
        p=part('Linen',['Forearm.'+side])
        p.lathe([(.043*S,-.015*S),(.043*S,.014*S),(.034*S,.014*S),(.034*S,-.015*S),(.043*S,-.015*S)],24,xform=Matrix.Translation(end)@d.to_track_quat('Z','Y').to_matrix().to_4x4(),cap_ends=False)
        p.seat=True
        if STYLE in ('rancher','dressmaker'):
            p=part('Skin',['Forearm.'+side,'Hand.'+side]);p.limb([end-d*.006*S,end.lerp(w,.5),w],[(.036*S,.037*S),(.032*S,.033*S),(.025*S,.028*S)],24,False,False)
    # Union the shirt's overlapping volumes BEFORE UVs and skinning. Shoulder topology is continuous.
    role='Wool' if STYLE=='clerk' else 'Linen'
    chosen=[p for p in f.parts[first:] if p.name==role]
    def sleeve_side(p):
        for side in ('L','R'):
            if any(bone in p.bones for bone in ('UpperArm.'+side,'Forearm.'+side)):return side
        return 'torso'
    def spread_at(z):return .30*S*max(0,min(1.1,(j['arm.L'].z-z)/(j['arm.L'].z-j['wrist.L'].z)))
    # Weld in an open A-pose. Welding hanging sleeves to the shirt hem would fuse wrist to waist.
    for p in chosen:
        side=1 if sleeve_side(p)=='L' else -1 if sleeve_side(p)=='R' else 0
        if side:
            for vertex in p.bm.verts:vertex.co.x+=side*spread_at(vertex.co.z)
    regions={}
    for p in chosen:
        region=sleeve_side(p)
        if region not in regions:regions[region]=[[],[]]
        verts,polys=regions[region];offset=len(verts)
        p.bm.verts.ensure_lookup_table();p.bm.verts.index_update()
        verts.extend(v.co.copy() for v in p.bm.verts)
        polys.extend(tuple(offset+v.index for v in face.verts) for face in p.bm.faces)
    region_bvhs={region:BVHTree.FromPolygons(verts,polys) for region,(verts,polys) in regions.items()}
    bm=bmesh.new()
    for p in chosen:
        me=bpy.data.meshes.new('shirt_part');p.bm.to_mesh(me);bm.from_mesh(me);bpy.data.meshes.remove(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    me=bpy.data.meshes.new('shirt_union');bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new('shirt_union',me);bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    mod=ob.modifiers.new('Weld_shoulders','REMESH');mod.mode='VOXEL';mod.voxel_size=.006*S;mod.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=ob.modifiers.new('Relax_garment','SMOOTH');mod.factor=.5;mod.iterations=4;bpy.ops.object.modifier_apply(modifier=mod.name)
    count=sum(len(poly.vertices)-2 for poly in ob.data.polygons)
    mod=ob.modifiers.new('Garment_budget','DECIMATE');mod.ratio=min(1.0,6500/max(1,count));bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=ob.modifiers.new('Soften_tailored_shoulders','SMOOTH');mod.factor=.7;mod.iterations=8;bpy.ops.object.modifier_apply(modifier=mod.name)
    merged=AF.Part(role,['Hips','Spine','Chest','Shoulder.L','UpperArm.L','Forearm.L','Shoulder.R','UpperArm.R','Forearm.R'])
    merged.bm.from_mesh(ob.data)
    merged.bm.verts.ensure_lookup_table()
    region_weights={}
    for vertex in merged.bm.verts:
        distances={key:region_bvhs[key].find_nearest(vertex.co)[3] for key in region_bvhs}
        weights={key:1/max(.016*S,d)**4 for key,d in distances.items()}
        total=sum(weights.values());weights={key:value/total for key,value in weights.items()}
        region_weights[vertex]=weights
        # Continuous inverse warp: the torso stays put; the lower sleeves return to the original bind pose.
        side=weights.get('L',0)-weights.get('R',0)
        vertex.co.x-=spread_at(vertex.co.z)*side
    bmesh.ops.dissolve_degenerate(merged.bm,dist=.0001,edges=list(merged.bm.edges))
    visited=set();remove=[];components=[]
    for vertex in list(merged.bm.verts):
        if vertex in visited:continue
        stack=[vertex];component=[];visited.add(vertex)
        while stack:
            current=stack.pop();component.append(current)
            for edge in current.link_edges:
                other=edge.other_vert(current)
                if other not in visited:visited.add(other);stack.append(other)
        components.append(component)
        if len(component)<8:remove.extend(component)
    # Voxel unions can retain a closed cavity behind the fitted bodice. Remove hidden inner shells.
    outer=max(components,key=len);outer_set=set(outer);indices={vertex:i for i,vertex in enumerate(outer)}
    outer_faces={face for vertex in outer for face in vertex.link_faces}
    outer_bvh=BVHTree.FromPolygons([vertex.co.copy() for vertex in outer],[tuple(indices[v] for v in face.verts) for face in outer_faces])
    direction=Vector((1,.371,.193)).normalized()
    for component in components:
        if component is outer or len(component)<8:continue
        if not all(len(edge.link_faces)==2 for vertex in component for edge in vertex.link_edges):continue
        if FEMALE and max(abs(vertex.co.x) for vertex in component)<.20*S and max(vertex.co.z for vertex in component)<j['hips'].z+.15*S:
            # A detached blouse-tail remnant inside the skirt has no visible surface and can invert when skinned.
            remove.extend(component)
            continue
        origin=sum((vertex.co for vertex in component),Vector())/len(component);hits=0
        for attempt in range(50):
            location,normal,index,distance=outer_bvh.ray_cast(origin,direction)
            if location is None:break
            hits+=1;origin=location+direction*.00001
        if hits%2:remove.extend(component)
    if remove:bmesh.ops.delete(merged.bm,geom=remove,context='VERTS')
    merged.bm.verts.ensure_lookup_table()
    merged.vertex_regions=[region_weights.get(vertex,{'torso':1.0}) for vertex in merged.bm.verts]
    for face in merged.bm.faces:face.smooth=True
    for p in chosen:p.bm.free();f.parts.remove(p)
    f.parts.append(merged)
    me=ob.data;bpy.data.objects.remove(ob,do_unlink=True);bpy.data.meshes.remove(me)


def disk(role,bones,center,r):
    p=part(role,bones);p.lathe([(0,-.001),(r,-.001),(r,.001),(0,.002)],12,xform=Matrix.Translation(Vector(center))@Matrix.Rotation(math.pi/2,4,'X'))


def vest_and_coat():
    body=['Hips','Spine','Chest'];z0=j['hips'].z
    # Open front panels with shaped hems, broad lapels, real thickness and separate lining.
    for sx in [-1,1]:
        for iscoat in ([False,True] if STYLE=='clerk' else [False]):
            role='Wool' if STYLE=='clerk' else 'Leather' if STYLE=='rancher' else 'Wool'
            p=part(role,body)
            rows=[]
            low=z0-(.35*S if iscoat else .055*S)
            for k in range(12):
                t=k/11;z=low+(j['neck'].z-.035-low)*t
                width=(.18-.028*math.sin(t*math.pi))*S
                if iscoat:width+=.015*S
                row=[]
                for n in range(12):
                    a=-math.pi/2+(n/11)*math.pi
                    x=sx*(.025*S+width*math.cos(a))
                    y=(.135+(.018 if iscoat else 0))*S*math.sin(a)
                    if n==0:x=sx*(.025+.065*max(0,(t-.65)/.35))*S;y=-.139*S-(.011*S if iscoat else 0)
                    row.append(p.bm.verts.new((x,y,z+.012*S*math.cos(n*math.pi/11))))
                rows.append(row)
            for a,b in zip(rows,rows[1:]):
                for n in range(11):p._face((a[n],a[n+1],b[n+1],b[n]))
            # Lapel seam deliberately catches grazing desert light.
            if STYLE!='clerk' or iscoat:
                line('Trim',body,[(sx*.036*S,-.145*S,z0+.08*S),(sx*.085*S,-.15*S,j['chest'].z+.04*S),(sx*.066*S,-.10*S,j['neck'].z-.028*S)],.004*S)
                # Welt pocket with a folded top edge; do not duplicate the same trim on both formal layers.
                line('Trim',body,[(sx*.09*S,-.143*S,z0+.09*S),(sx*.16*S,-.115*S,z0+.10*S)],.006*S)
    for z in [z0+.06*S,z0+.13*S,z0+.20*S]:disk('Metal',body,(.034*S,-.148*S,z),.006*S)


def legs_and_boots():
    for side,sx in [('L',1),('R',-1)]:
        allowed=['Hips','Thigh.'+side,'Shin.'+side,'Foot.'+side]
        h=j['thigh.'+side];k=j['knee.'+side];a=j['ankle.'+side]
        if not FEMALE:
            p=part('Wool',allowed)
            # The two thigh tops meet inside the hip. Leave those concealed rings
            # open rather than placing overlapping horizontal caps across the crotch.
            p.limb([h+Vector((0,0,.04*S)),h,h.lerp(k,.30),h.lerp(k,.75),h.lerp(k,.94),k,k.lerp(a,.10),k.lerp(a,.35),k.lerp(a,.73),a+Vector((0,0,.065*S))],[(r*S,r*S) for r in [.085,.085,.083,.068,.064,.061,.063,.069,.062,.049]],28,cap0=False)
        x=a.x
        loft('Leather',['Foot.'+side,'Shin.'+side],[(x,.01*S,.07*S,.060*S,.074*S),(x,.012*S,.20*S,.050*S,.051*S),(x,.014*S,.28*S,.056*S,.051*S)],24)
        loft('Leather',['Foot.'+side],[(x,-.052*S,.035*S,.060*S,.13*S),(x,-.06*S,.07*S,.061*S,.133*S),(x,-.037*S,.108*S,.052*S,.098*S),(x,.012*S,.15*S,.041*S,.043*S)],28)
        loft('Sole',['Foot.'+side],[(x,-.053*S,.015*S,.063*S,.135*S),(x,-.053*S,.033*S,.063*S,.135*S)],28)
        for l in range(5):
            z=(.12+l*.023)*S
            line('Trim',['Foot.'+side,'Shin.'+side],[(x-.024*S,-.055*S,z),(x+.024*S,-.057*S,z+.01*S)],.0015*S)


def skirt_and_apron():
    allowed=['Hips','Spine','Thigh.L','Thigh.R']
    waist=j['hips'].z+.08*S; hem=.18*S
    sections=[]
    for k in range(20):
        t=k/19;z=hem+(waist-hem)*t
        rx=(.32-.16*t+.025*math.sin(math.pi*t))*S
        ry=(.255-.135*t)*S
        sections.append((0,.014*S,z,rx,ry))
    loft('Skirt',allowed,sections,64,fold=.011*S,cap=False)
    # Under-skirt and hem, both anchored to pelvis. No shin weights pulling a full skirt apart.
    loft('Linen',allowed,[(0,.015*S,hem-.015*S,.307*S,.242*S),(0,.015*S,hem+.036*S,.30*S,.24*S)],64,fold=.006*S,cap=False)
    loft('Trim',allowed,[(0,.014*S,hem+.01*S,.323*S,.258*S),(0,.014*S,hem+.035*S,.32*S,.255*S)],64,fold=.011*S,cap=False)
    # Fitted bodice, with neck opening and stitched lacing.
    loft('Wool',['Hips','Spine','Chest'],[(0,-.002,j['hips'].z+.015*S,.16*S,.116*S),(0,-.004,j['spine'].z-.03*S,.147*S,.117*S),(0,-.006,j['chest'].z-.01*S,.181*S,.132*S),(0,-.004,j['chest'].z+.065*S,.173*S,.119*S)],32,fold=.001*S,cap=False)
    for k in range(7):
        z=j['hips'].z+.065*S+k*.033*S
        line('Trim',['Hips','Spine','Chest'],[(-.014*S,-.137*S,z),(.014*S,-.137*S,z+.025*S)],.0018*S)
    # Curved draped apron with gathers and a free hem; never a solid box.
    p=part('Apron',allowed);rows=[]
    for r in range(16):
        t=r/15;z=waist-.06*S-(waist-hem-.12*S)*t
        width=(.165+.07*t)*S
        row=[]
        for k in range(25):
            a=-1+2*k/24;x=a*width
            depth=(.137+.10*t)*S*math.sqrt(max(.12,1-(a*.72)**2))
            y=-depth-.01*S-.007*S*math.cos(a*math.pi*7)*(0.2+.8*t)
            row.append(p.bm.verts.new((x,y,z+.01*S*a*a)))
        rows.append(row)
    for a,b in zip(rows,rows[1:]):
        for k in range(24):p._face((a[k],a[k+1],b[k+1],b[k]))
    # Pockets lie on the drape, with rounded sewn edges and no box thickness.
    for sx in [-1,1]:
        line('Trim',allowed,[(sx*.08*S,-.208*S,waist-.25*S),(sx*.075*S,-.228*S,waist-.38*S),(sx*.16*S,-.208*S,waist-.38*S),(sx*.166*S,-.189*S,waist-.25*S)],.002*S)
    loft('Apron',['Hips','Spine'],[(0,0,waist-.06*S,.17*S,.135*S),(0,0,waist-.035*S,.169*S,.135*S)],32,cap=False)


def hats_hair_beard():
    z=j['foramen'].z;head=['Head']
    if STYLE in ('clerk','oldtimer','rancher') and not C.get('no_hat') and not C.get('bald'):
        # Shaped felt brim with upturned sides, pinched crown and an independent leather band.
        brim=.145 if STYLE=='clerk' else .17 if STYLE=='oldtimer' else .194
        loft('Felt',head,[(0,0,z+.072*S,brim*S,brim*.85*S),(0,0,z+.084*S,(brim+.002)*S,brim*.85*S),(0,0,z+.089*S,.089*S,.108*S)],48,cap=False)
        if STYLE=='clerk':sections=[(0,0,z+.081*S,.09*S,.108*S),(0,0,z+.22*S,.084*S,.093*S),(0,0,z+.228*S,.075*S,.087*S)]
        else:sections=[(0,0,z+.082*S,.091*S,.110*S),(0,0,z+.15*S,.080*S,.095*S),(0,0,z+.183*S,.064*S,.079*S),(0,0,z+.191*S,.053*S,.07*S)]
        loft('Felt',head,sections,40)
        loft('Leather',head,[(0,0,z+.089*S,.092*S,.111*S),(0,0,z+.11*S,.091*S,.109*S)],40,cap=False)
    if STYLE=='oldtimer':
        loft('Hair',head,[(0,-.105*S,z-.25*S,.012*S,.015*S),(0,-.105*S,z-.19*S,.042*S,.028*S),(0,-.092*S,z-.12*S,.063*S,.042*S),(0,-.084*S,z-.055*S,.074*S,.047*S)],40,fold=.003*S)
    if STYLE=='clerk':
        # Fine round spectacles, attached to the head throughout all clips.
        for sx in [-1,1]:
            q=part('Metal',head);q.torus(Vector((sx*.034*S,-.157*S,z)),.022*S,.0015*S,28,6,Matrix.Rotation(math.pi/2,4,'X'))
        line('Metal',head,[(-.012*S,-.157*S,z),(.012*S,-.157*S,z)],.0013*S)
    if FEMALE:
        if STYLE=='dressmaker' and not C.get('bob'):
            loft('Hair',head,[(0,.065*S,z+.035*S,.045*S,.044*S),(0,.088*S,z+.065*S,.054*S,.045*S),(0,.092*S,z+.10*S,.035*S,.03*S)],24)
        elif not C.get('bob'):
            for strand in range(3):
                points=[]
                for k in range(40):
                    t=k/39;a=t*math.pi*12+strand*math.tau/3
                    points.append((.073*S+math.cos(a)*.008*S,-(.06+.08*t)*S+math.sin(a)*.008*S,z-(.025+.30*t)*S))
                line('Hair',['Head','Neck','Chest'],points,.006*S)


def uv_atlas(geo):
    bpy.context.view_layer.objects.active=geo;geo.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.025)
    bpy.ops.object.mode_set(mode='OBJECT')
    uv=geo.data.uv_layers.active.data
    for poly in geo.data.polygons:
        role=geo.data.materials[poly.material_index].name
        if role=='Face':
            us=[]
            for li in poly.loop_indices:
                co=geo.data.vertices[geo.data.loops[li].vertex_index].co
                angle=math.atan2(co.x,-(co.y-.005*S))
                u=angle/math.tau+.5;v=(co.z-j['foramen'].z+.18*S)/(.31*S)
                us.append((li,u,v))
            if max(u for _,u,_ in us)-min(u for _,u,_ in us)>.5:us=[(li,u+1 if u<.5 else u,v)for li,u,v in us]
            for li,u,v in us:uv[li].uv=(u*.5,max(.002,min(.998,v))*.5)
        elif role=='Linen' and C.get('striped'):
            # World-height UVs keep the prisoner's shirt and rolled sleeves in
            # broad horizontal bands rather than turning stripes with each UV island.
            for li in poly.loop_indices:
                co=geo.data.vertices[geo.data.loops[li].vertex_index].co
                uv[li].uv=((3.025+(co.x/S+.5)%1*.95)/4,(.025+((co.z/S)/.14)%1*.95)/4)
        else:
            cell=TILES[role];x=cell%4;y=cell//4
            for li in poly.loop_indices:
                old=uv[li].uv.copy();uv[li].uv=((x+.025+old.x*.95)/4,(y+.025+old.y*.95)/4)
        poly.material_index=0
    geo.data.materials.clear();geo.data.materials.append(atlas)


def configure_render(geo):
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.use_denoising=True
    sc.render.resolution_x=640;sc.render.resolution_y=800;sc.render.resolution_percentage=100
    if not sc.world:sc.world=bpy.data.worlds.new('Review_world')
    sc.world.color=(.18,.18,.18);sc.view_settings.view_transform='Standard'
    for name,pos,power,size in [('Key',(-3,-4,5),450,4),('Fill',(3,-1,3),220,3),('Rim',(0,3,4),350,3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
        ob=bpy.data.objects.new(name,d);sc.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,.9))-ob.location).to_track_quat('-Z','Y').to_euler()
    camd=bpy.data.cameras.new('Review_camera');cam=bpy.data.objects.new('Review_camera',camd);sc.collection.objects.link(cam);sc.camera=cam;camd.type='ORTHO';camd.ortho_scale=C['height']*1.15
    for name,xyz in [('front',(0,-4,1.0)),('three_quarter',(3,-4,1.2)),('side',(4,0,1.0)),('back',(0,4,1.0))]:
        cam.location=xyz;cam.rotation_euler=(Vector((0,0,C['height']/2))-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=24
bpy.context.scene.render.threads_mode='FIXED';bpy.context.scene.render.threads=2
AF.MATS.clear()
j=AF.S(C['height'],C['girth'])
# The legacy puppet's eye joint sits too far above the shoulders for anatomical heads.
# Adjust the anatomical head landmark and bind together, retaining every joint name and clip.
for landmark in ('foramen','head','head_top','chin'):j[landmark].z-=.055*S
f=AF.Figure(C['name'],C['height'])
atlas=make_atlas()
vs,faces,markers=source_mesh()
head_and_hands(vs,faces,markers)
torso_and_sleeves();legs_and_boots()
if FEMALE:skirt_and_apron()
elif not C.get('suspenders') and not C.get('no_vest'):vest_and_coat()
hats_hair_beard()
if KEY in EXTENDED:
    spec = importlib.util.spec_from_file_location('extended_details', ROOT/'tools/ep2_blender/town_cast_details.py')
    details = importlib.util.module_from_spec(spec);spec.loader.exec_module(details)
    details.build(globals())
# Figure.build historically rescales only the mesh, which can move its joints away from the rig.
# Cancel that implicit transform; runtime Ep2TownFolk scales the complete rig to the roster height.
raw_z=[v.co.z for p in f.parts for v in p.bm.verts]
zmin,zmax=min(raw_z),max(raw_z)
f.height=zmax-zmin
geo,groups=f.build();geo.name=C['name']+'_body'
for v in geo.data.vertices:v.co.z+=zmin
# Seat sewn trim, buttons and soles on their actual support surface rather than hovering at guessed coordinates.
seat_vertices=set()
for detail,(_,lo,hi) in zip(f.parts,groups):
    if detail.name in ('Trim','Metal','Sole') or getattr(detail,'seat',False):seat_vertices.update(range(lo,hi+1))
support_faces=[tuple(p.vertices) for p in geo.data.polygons if not any(i in seat_vertices for i in p.vertices)]
support=BVHTree.FromPolygons([v.co.copy() for v in geo.data.vertices],support_faces)
for detail,(_,lo,hi) in zip(f.parts,groups):
    if detail.name not in ('Trim','Metal','Sole') and not getattr(detail,'seat',False):continue
    best=None
    for vi in range(lo,hi+1):
        co=geo.data.vertices[vi].co;hit= support.find_nearest(co)
        if hit[0] is not None and (best is None or hit[3]<best[0]):best=(hit[3],hit[0]+hit[1]*.0005-co)
    if best and best[0]>.0008:
        for vi in range(lo,hi+1):geo.data.vertices[vi].co+=best[1]
floor=min(v.co.z for v in geo.data.vertices)
for v in geo.data.vertices:v.co.z-=floor
arm=AF.make_armature(C['name'],j)
# Move bind joints with the foot normalization; root remains at the world origin.
bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
for bone in arm.data.edit_bones:
    if bone.name!='Root':bone.head.z-=floor;bone.tail.z-=floor
bpy.ops.object.mode_set(mode='OBJECT')
for point in j.values():point.z-=floor
AF.skin(geo,arm,groups,j)
ends=AF.bone_ends(j)
for detail,(_,lo,hi) in zip(f.parts,groups):
    if not hasattr(detail,'vertex_regions'):continue
    for i,regions in enumerate(detail.vertex_regions):
        vi=lo+i;co=geo.data.vertices[vi].co;combined={}
        for region,region_weight in regions.items():
            allowed=['Hips','Spine','Chest'] if region=='torso' else ['Chest','Shoulder.'+region,'UpperArm.'+region,'Forearm.'+region]
            local=[]
            for name in allowed:
                start,end=ends[name];delta=end-start;t=max(0,min(1,(co-start).dot(delta)/delta.length_squared))
                distance=(co-start-delta*t).length;local.append((1/max(distance,.012)**4,name))
            total=sum(weight for weight,_ in local)
            for weight,name in local:combined[name]=combined.get(name,0)+region_weight*weight/total
        kept=sorted(combined.items(),key=lambda pair:-pair[1])[:4];total=sum(weight for _,weight in kept)
        for group in geo.vertex_groups:group.remove([vi])
        for name,weight in kept:geo.vertex_groups[name].add([vi],weight/total,'REPLACE')
    # Geodesic weight smoothing removes abrupt nearest-surface transitions at the welded armpit.
    names=[group.name for group in geo.vertex_groups]
    matrix=np.zeros((hi-lo+1,len(names)),dtype=np.float64)
    for vi in range(lo,hi+1):
        for group in geo.data.vertices[vi].groups:matrix[vi-lo,group.group]=group.weight
    edges=np.array([(edge.vertices[0]-lo,edge.vertices[1]-lo) for edge in geo.data.edges if lo<=edge.vertices[0]<=hi and lo<=edge.vertices[1]<=hi],dtype=np.int32)
    degree=np.bincount(edges.ravel(),minlength=len(matrix))[:,None]
    for iteration in range(10):
        neighbors=np.zeros_like(matrix)
        np.add.at(neighbors,edges[:,0],matrix[edges[:,1]]);np.add.at(neighbors,edges[:,1],matrix[edges[:,0]])
        matrix=matrix*.4+neighbors/np.maximum(1,degree)*.6
    for index,row in enumerate(matrix):
        vi=lo+index;keep=np.argsort(row)[-4:];total=float(row[keep].sum())
        for group in geo.vertex_groups:group.remove([vi])
        for gi in keep:
            if row[gi]>.000001:geo.vertex_groups[int(gi)].add([vi],float(row[gi]/total),'REPLACE')
uv_atlas(geo)
# Coherent weights at garment joints; keep head, hats and fingers rigid, skirt driven by pelvis rather than ankles.
AF.build_clips(arm,'utah')
if KEY in EXTENDED:
    activity_spec=importlib.util.spec_from_file_location('town_activity',ROOT/'tools/ep2_blender/town_activity_clips.py')
    activity=importlib.util.module_from_spec(activity_spec);activity_spec.loader.exec_module(activity)
    activity.add(AF,arm)
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(KEY+'.blend')))
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_mainfile()
dest=ROOT/'src/episode2/extras/people'/(C['name']+'.glb')
AF.export(str(dest),arm,geo)
receipt=dict(person=KEY,height=C['height'],triangles=sum(len(p.vertices)-2 for p in geo.data.polygons),vertices=len(geo.data.vertices),joints=len(arm.data.bones),clips=sorted(a.name for a in bpy.data.actions),textures=[p.name for p in MAPS.iterdir()],bytes=dest.stat().st_size,source='MakeHuman CC0 a8bc2d54ff0ac92e78ff71431b1023eda42bf482',reference=C['ref'] or '1xtNAz0raq7nbV3vqaIITeEyrQJpVtPh1')
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('@@'+json.dumps(receipt),flush=True)
if args.render:configure_render(geo)
