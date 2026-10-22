"""Geometry details for the additional owner-supplied town references; called by the cast builder."""
import math
from mathutils import Matrix
from mathutils import Vector


def build(env):
    C=env['C'];S=env['S'];j=env['j'];f=env['f'];loft=env['loft'];line=env['line'];part=env['part']
    if C.get('suspenders'):
        for side in (-1,1):
            line('Leather',['Hips','Spine','Chest'],[(side*.08*S,-.126*S,j['hips'].z),(side*.10*S,-.13*S,j['chest'].z),(side*.11*S,.01*S,j['neck'].z-.06*S),(side*.10*S,.13*S,j['chest'].z),(side*.08*S,.12*S,j['hips'].z)],.012*S)
    if C.get('shawl'):
        z=j['neck'].z
        loft('Wool',['Chest','Neck'],[(0,.01*S,z-.26*S,.215*S,.14*S),(0,0,z-.17*S,.225*S,.145*S),(0,0,z-.08*S,.20*S,.115*S),(0,0,z-.025*S,.064*S,.065*S)],40,fold=.008*S,cap=False)
        for side in (-1,1):
            for k in range(9):
                x=side*(.025+k*.02)*S
                line('Trim',['Chest'],[(x,-.13*S,z-.22*S),(x,-.135*S,z-.28*S)],.002*S)
    if C.get('scarf'):
        z=j['neck'].z
        loft('Trim',['Chest','Neck'],[(0,-.004*S,z-.055*S,.074*S,.07*S),(0,0,z+.012*S,.066*S,.064*S)],28,fold=.003*S,cap=False)
        line('Trim',['Chest'],[(.02*S,-.11*S,z-.02*S),(.025*S,-.15*S,z-.16*S),(.04*S,-.135*S,z-.22*S)],.027*S)
    if C.get('curly'):
        # Rounded poles instead of planar caps: adjacent clumps previously
        # shared overlapping horizontal triangles at each row's cap height.
        for row in range(4):
            for k in range(13):
                a=(k+row*.5)*math.tau/13;z=j['foramen'].z+(.03+row*.023)*S
                r=(.088-row*.008)*S
                p=part('Hair',['Head'])
                profile=[(0,-.018*S),(.014*S,-.014*S),(.021*S,0),(.017*S,.015*S),(0,.024*S)]
                p.lathe(profile,10,xform=Matrix.Translation(Vector((math.cos(a)*r,math.sin(a)*r,z+.017*S))),ry_scale=.91)
    if C.get('bob'):
        z=j['foramen'].z
        # Open front, thick hair at sides/back down to the jaw; no adult braid or bun.
        p=part('Hair',['Head']);rows=[]
        for row in range(5):
            ring=[]
            for k in range(25):
                a=-.45+k*(math.pi+.90)/24
                ring.append(p.bm.verts.new((math.cos(a)*.106*S,math.sin(a)*.103*S,z+(.06-row*.034)*S)))
            rows.append(ring)
        for a,b in zip(rows,rows[1:]):
            for k in range(24):p._face((a[k],a[k+1],b[k+1],b[k]))
    if C.get('child'):
        # Re-proportion mesh AND bind landmarks. Shorter legs, narrower shoulders and a larger head/body ratio;
        # unlike runtime scaling this changes the anatomy relative to height.
        hip=j['hips'].z;neck=j['neck'].z
        def transform(v,head=False):
            z=v.z
            if z<=hip:v.z=z*.89
            elif z<=neck:v.z=hip*.89+(z-hip)*.96
            else:v.z=hip*.89+(neck-hip)*.96+(z-neck)*1.24
            v.x*=.90 if not head else 1.13
            v.y*=.94 if not head else 1.15
        for p in f.parts:
            head=p.bones==['Head']
            for v in p.bm.verts:transform(v.co,head)
        for name,v in j.items():transform(v,name in ('head','head_top','chin','foramen'))
    if C.get('elder'):
        # Mild age posture lives in the bind shape, with the clothing and neck following it.
        hip=j['hips'].z
        for p in f.parts:
            for v in p.bm.verts:v.co.y-=max(0,v.co.z-hip)*.035
        for v in j.values():v.y-=max(0,v.z-hip)*.035
