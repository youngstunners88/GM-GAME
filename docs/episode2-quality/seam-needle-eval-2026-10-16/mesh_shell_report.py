import bpy, bmesh, sys, json, collections
glb, out = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
res={}
for o in bpy.data.objects:
    if o.type!='MESH': continue
    me=o.data; bm=bmesh.new(); bm.from_mesh(me)
    n0=len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.edges.ensure_lookup_table()
    bnd=[e for e in bm.edges if e.is_boundary]
    nonm=[e for e in bm.edges if not e.is_manifold and not e.is_boundary]
    # islands by connectivity
    seen=set(); isl=[]
    for f in bm.faces:
        if f.index in seen: continue
        st=[f]; seen.add(f.index); fs=[]
        while st:
            c=st.pop(); fs.append(c)
            for e in c.edges:
                for g in e.link_faces:
                    if g.index not in seen: seen.add(g.index); st.append(g)
        isl.append(fs)
    sizes=sorted((len(i) for i in isl), reverse=True)
    # boundary edge clusters (by 5cm grid), world space
    mw=o.matrix_world
    cl=collections.Counter()
    for e in bnd:
        p=mw@((e.verts[0].co+e.verts[1].co)/2)
        cl[(round(p.x*20)/20,round(p.y*20)/20,round(p.z*20)/20)]+=1
    bb=[mw@__import__('mathutils').Vector(c) for c in o.bound_box]
    res[o.name]=dict(verts=n0,welded=len(bm.verts),faces=len(bm.faces),boundary=len(bnd),nonmanifold=len(nonm),
        islands=len(isl),island_top=sizes[:8],small_islands_lt50=sum(1 for s in sizes if s<50),
        bbox=[[min(v[i] for v in bb) for i in range(3)],[max(v[i] for v in bb) for i in range(3)]],
        bnd_clusters=cl.most_common(12), vgroups=len(o.vertex_groups))
    bm.free()
json.dump(res,open(out,'w'),indent=1,default=str)
