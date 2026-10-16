import bpy, bmesh, sys, json
glb=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
o=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='char1')
mat=o.active_material; img=None
for n in mat.node_tree.nodes:
    if n.type=='TEX_IMAGE': img=n.image
W,H=img.size; px=list(img.pixels)
def tex(u,v):
    x=min(W-1,max(0,int(u*W))); y=min(H-1,max(0,int(v*H))); i=(y*W+x)*4
    return px[i:i+3]
me=o.data; bm=bmesh.new(); bm.from_mesh(me); uv=bm.loops.layers.uv.active
# islands by POSITION-welded connectivity: build key per vertex
key={}
for v in bm.verts: key[v.index]=(round(v.co.x*1e4),round(v.co.y*1e4),round(v.co.z*1e4))
parent={}
def find(a):
    while parent.setdefault(a,a)!=a:
        parent[a]=parent[parent[a]]; a=parent[a]
    return a
for f in bm.faces:
    ks=[key[v.index] for v in f.verts]
    for k in ks[1:]: parent[find(ks[0])]=find(k)
groups={}
for f in bm.faces:
    r=find(key[f.verts[0].index]); groups.setdefault(r,[]).append(f)
mw=o.matrix_world; rows=[]
for r,fs in groups.items():
    if len(fs)>=120: continue
    cols=[];cs=[]
    for f in fs:
        u=sum(l[uv].uv.x for l in f.loops)/len(f.loops); v=sum(l[uv].uv.y for l in f.loops)/len(f.loops)
        cols.append(tex(u,v)); 
        cs.append(sum((mw@vv.co for vv in f.verts),__import__('mathutils').Vector())/len(f.verts))
    m=[sum(c[i] for c in cols)/len(cols) for i in range(3)]
    c=sum(cs,__import__('mathutils').Vector())/len(cs)
    red = m[0]>0.45 and m[0]>1.6*max(m[1],m[2])
    if red: rows.append((len(fs),[round(x,2) for x in m],[round(x,2) for x in c]))
rows.sort(key=lambda r:-r[2][2])
print("RED small shells:",len(rows),"of",len(groups))
for r in rows[:25]: print(r)
