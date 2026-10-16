import bpy, bmesh, sys, numpy as np
glb,out,mode=sys.argv[sys.argv.index('--')+1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
o=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='char1')
img=[n.image for n in o.active_material.node_tree.nodes if n.type=='TEX_IMAGE'][0]
W,H=img.size; px=np.array(img.pixels[:]).reshape(H,W,4)
me=o.data; uv=me.uv_layers.active.data
n=len(me.vertices); col=np.zeros((n,3)); cnt=np.zeros(n)
for l in me.loops:
    u,v=uv[l.index].uv; c=px[min(H-1,max(0,int(v*H))),min(W-1,max(0,int(u*W))),:3]
    col[l.vertex_index]+=c; cnt[l.vertex_index]+=1
col/=np.maximum(cnt,1)[:,None]
co=np.array([(o.matrix_world@v.co)[:] for v in me.vertices])  # blender xyz
gz=-co[:,1]; gy=co[:,2]; gx=co[:,0]   # glTF z=-blender y
red=(col[:,0]>0.45)&(col[:,0]>1.6*np.maximum(col[:,1],col[:,2]))
base=red&(gz<0.08)
extra=red&(gy>1.6)&(np.abs(gx)>0.3)   # arrow tips above the shoulders, any depth
m=base|extra if mode=='ext' else base
print("red",red.sum(),"base",base.sum(),"extra-only",(extra&~base).sum(),"used",m.sum())
np.savez(out,red=m)
