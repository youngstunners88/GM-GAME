"""Measured repairs for the supplied Logan mesh, retaining UVs and skin weights.
Subtract overlapping coplanar triangle areas rather than deleting whole clothes.
The original source is always retained separately. No global weld/remesh.
"""
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def inside(p, a, b, c, n):
    return all((v-u).cross(p-u).dot(n) >= -1e-10 for u,v in ((a,b),(b,c),(c,a)))

def half(poly, a, b, normal, keep_inside):
    out = []
    for p, q in zip(poly, poly[1:] + poly[:1]):
        dp = (b-a).cross(p-a).dot(normal)
        dq = (b-a).cross(q-a).dot(normal)
        pin = dp >= -1e-12 if keep_inside else dp <= 1e-12
        qin = dq >= -1e-12 if keep_inside else dq <= 1e-12
        if pin: out.append(p)
        if pin != qin and abs(dp-dq) > 1e-16:
            out.append(p + (q-p) * (dp/(dp-dq)))
    return out

def bary(p, a, b, c):
    u,v,w = b-a,c-a,p-a
    den=u.dot(u)*v.dot(v)-u.dot(v)**2
    y=(v.dot(v)*w.dot(u)-u.dot(v)*w.dot(v))/den
    z=(u.dot(u)*w.dot(v)-u.dot(v)*w.dot(u))/den
    return [1-y-z,y,z]

def subtract(bm, target, cover):
    n = target.normal.copy()
    points=[v.co.copy() for v in target.verts]
    cut=[v.co - n*n.dot(v.co-points[0]) for v in cover.verts]
    if (cut[1]-cut[0]).cross(cut[2]-cut[0]).dot(n) < 0: cut.reverse()
    remaining=points[:]
    pieces=[]
    for a,b in zip(cut,cut[1:]+cut[:1]):
        outside=half(remaining,a,b,n,False)
        if len(outside)>=3: pieces.append(outside)
        remaining=half(remaining,a,b,n,True)
        if len(remaining)<3: return False
    area=sum((remaining[i]-remaining[0]).cross(remaining[i+1]-remaining[0]).length/2
             for i in range(1,len(remaining)-1))
    if area < 1e-10: return False
    uv=bm.loops.layers.uv.active
    deform=bm.verts.layers.deform.active
    uvs=[loop[uv].uv.copy() for loop in target.loops]
    weights=[dict(v[deform]) for v in target.verts]
    for poly in pieces:
        for i in range(1,len(poly)-1):
            tri=[poly[0],poly[i],poly[i+1]]
            # Clipping nearly coincident source edges can leave sub-0.1 mm
            # numerical slivers. Discard these new fragments, not source faces.
            if (tri[1]-tri[0]).cross(tri[2]-tri[0]).length/2 < 1e-8: continue
            vs=[]; tex=[]
            for p in tri:
                coeff=bary(p,*points)
                v=bm.verts.new(p)
                ws={k:sum(coeff[j]*weights[j].get(k,0) for j in range(3)) for k in set().union(*weights)}
                ws=sorted(((k,max(0,w)) for k,w in ws.items()),key=lambda kv:kv[1],reverse=True)[:4]
                total=sum(w for k,w in ws)
                for k,w in ws: v[deform][k]=w/total
                tex.append(sum((uvs[j]*coeff[j] for j in range(3)),Vector((0,0))))
                vs.append(v)
            f=bm.faces.new(vs)
            f.material_index=target.material_index
            f.smooth=target.smooth
            for loop,t in zip(f.loops,tex): loop[uv].uv=t
    bm.faces.remove(target)
    return True

def repair_overlaps(bm):
    changes=0
    for iteration in range(12):
        bm.normal_update()
        bm.verts.ensure_lookup_table(); bm.verts.index_update()
        faces=list(bm.faces)
        coords=[v.co.copy() for v in bm.verts]
        tris=[[v.index for v in f.verts] for f in faces]
        bvh=BVHTree.FromPolygons(coords,tris,all_triangles=True)
        touched=set(); changed=0
        for i,f in enumerate(faces):
            if f in touched or not f.is_valid: continue
            a,b,c=[v.co for v in f.verts]
            center=(a+b+c)/3
            found=False
            for p in [center,center.lerp(a,.6),center.lerp(b,.6),center.lerp(c,.6)]:
                for _,_,j,_ in bvh.find_nearest_range(p,.001):
                    if j==i or j is None: continue
                    other=faces[j]
                    if other in touched or not other.is_valid: continue
                    if set(f.verts)&set(other.verts): continue
                    if f.normal.dot(other.normal)<.999: continue
                    aa,bb,cc=[v.co for v in other.verts]
                    q=p-other.normal*other.normal.dot(p-aa)
                    if not inside(q,aa,bb,cc,other.normal): continue
                    # Keep the larger continuous patch and trim only the overlap.
                    target,cover=(f,other) if f.calc_area()<other.calc_area() else (other,f)
                    if subtract(bm,target,cover):
                        touched.update((f,other));changed+=1;found=True;break
                if found: break
        changes+=changed
        print('Logan overlap repair', iteration + 1, 'trimmed', changed, flush=True)
        if not changed: break
    # Edges/verts formerly belonging to trimmed faces are now harmless orphans.
    for e in list(bm.edges):
        if not e.link_faces: bm.edges.remove(e)
    for v in list(bm.verts):
        if not v.link_edges: bm.verts.remove(v)
    return changes

def attach_measured_fragments(bm):
    """Source QA identified two tiny gear fragments; snap to nearest own surface."""
    targets=[Vector((.199,.039,.399)), Vector((.397,.027,.734))]
    seen=set(); moves=[]
    for first in list(bm.verts):
        if first in seen: continue
        todo=[first]; seen.add(first); vs=[]
        while todo:
            v=todo.pop();vs.append(v)
            for e in v.link_edges:
                other=e.other_vert(v)
                if other not in seen: seen.add(other);todo.append(other)
        if len(vs)>40: continue
        lo=Vector(tuple(min(v.co[i] for v in vs) for i in range(3)))
        hi=Vector(tuple(max(v.co[i] for v in vs) for i in range(3)))
        center=(lo+hi)/2
        if min((center-t).length for t in targets)>.003: continue
        own=set(vs)
        bm.verts.ensure_lookup_table();bm.verts.index_update()
        faces=[f for f in bm.faces if not any(v in own for v in f.verts)]
        bvh=BVHTree.FromPolygons([v.co for v in bm.verts],[[v.index for v in f.verts] for f in faces])
        best=None
        for v in vs:
            hit,_,_,distance=bvh.find_nearest(v.co)
            if best is None or distance<best[0]: best=(distance,hit-v.co)
        # Measured source fragment gap: 0.015043 m at (.199,.039,.399).
        assert best[0]<.016, f'Unexpected fragment gap {best[0]:.6f} at {tuple(center)}'
        for v in vs: v.co+=best[1]
        moves.append({'center':list(center),'vertices':len(vs),'distance':best[0]})
    return moves
