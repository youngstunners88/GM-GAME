import json,struct,numpy as np
from pathlib import Path

def load(path):
 b=Path(path).read_bytes();n=struct.unpack_from('<I',b,12)[0];return json.loads(b[20:20+n]),b[28+n:]
def acc(j,b,k):
 a=j['accessors'][k];v=j['bufferViews'][a['bufferView']];return np.frombuffer(b,dtype={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']],count=a['count']*{'VEC3':3,'VEC4':4,'SCALAR':1,'MAT4':16}[a['type']],offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],-1)
def quat(q):
 x,y,z,w=q;return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def matrices(j):
 parents={c:i for i,n in enumerate(j['nodes']) for c in n.get('children',[])};out={}
 def world(i):
  if i in out:return out[i]
  n=j['nodes'][i];m=np.array(n['matrix']).reshape(4,4).T if 'matrix' in n else np.eye(4)
  if 'matrix' not in n:m[:3,:3]=quat(n.get('rotation',[0,0,0,1]))*n.get('scale',[1,1,1]);m[:3,3]=n.get('translation',[0,0,0])
  out[i]=world(parents[i])@m if i in parents else m;return out[i]
 for i in range(len(j['nodes'])):world(i)
 return out,parents


def repair(source, destination):
 """Fit elbow/wrist pivots and smooth arm weights to the founder mesh's sculpted rest arms.

 The previous nearest-surface transfer had no hand weights and put the wrists 48 cm
 below the paws. Preserve mesh, atlas, joint rotations, hierarchy and all non-arm data.
 """
 j,b=load(source);b=bytearray(b);world,parents=matrices(j)
 skin=j['skins'][0];names=[j['nodes'][k]['name'] for k in skin['joints']]
 ids={j['nodes'][k]['name']:k for k in skin['joints']}
 original={k:v.copy() for k,v in world.items()}
 for side,sign in [('Left',1),('Right',-1)]:
  for bone,point in [('ForeArm',[sign*.58,1.30,.04]),('Hand',[sign*.84,1.31,.10])]:
   idx=ids[side+bone];parent=parents[idx]
   # Recompute after each parent change; preserve this bone's original world rotation.
   world,_=matrices(j);wanted=original[idx].copy();wanted[:3,3]=point
   local=np.linalg.inv(world[parent])@wanted
   j['nodes'][idx]['translation']=local[:3,3].tolist()
 world,_=matrices(j)
 def put(k,array):
  a=j['accessors'][k];v=j['bufferViews'][a['bufferView']];off=v.get('byteOffset',0)+a.get('byteOffset',0)
  raw=array.astype({5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]).tobytes();b[off:off+len(raw)]=raw
 put(skin['inverseBindMatrices'],np.array([np.linalg.inv(world[k]).T.reshape(16) for k in skin['joints']]))
 # Embedded clips also serve the runner, which does not use Ep2Actor's loader.
 # Keep the repaired bone lengths in every consumer, not only the woods.
 for animation in j.get('animations',[]):
  animation['channels']=[c for c in animation['channels'] if c['target']['path']!='translation' or j['nodes'][c['target']['node']].get('name')=='Hips']
 for mesh in j['meshes']:
  for prim in mesh['primitives']:
   attrs=prim['attributes'];P=acc(j,b,attrs['POSITION']);J=acc(j,b,attrs['JOINTS_0']).copy();W=acc(j,b,attrs['WEIGHTS_0']).copy()
   for side,sign in [('Left',1),('Right',-1)]:
    x=P[:,0]*sign
    mask=(x>.36)&(P[:,1]>1.05)&(P[:,1]<1.58)
    # Smooth shoulder/elbow/wrist transitions, identical at duplicated UV seam vertices.
    fore=np.clip((x-.48)/.19,0,1);hand=np.clip((x-.77)/.13,0,1)
    J[mask]=[names.index(side+'Arm'),names.index(side+'ForeArm'),names.index(side+'Hand'),names.index(side+'Arm')]
    W[mask]=np.stack([1-fore,fore*(1-hand),fore*hand,np.zeros(len(P))],1)[mask]
   put(attrs['JOINTS_0'],J);put(attrs['WEIGHTS_0'],W)
 js=json.dumps(j,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
 while len(b)%4:b.append(0)
 Path(destination).write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(b))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(b),0x004e4942)+b)
 for side,sign in [('Left',1),('Right',-1)]:
  local=np.linalg.inv(world[ids[side+'Hand']])@np.array([sign*.90,1.31,.10,1])
  # BoneAttachment holders undo the 0.01 rig scale; local marker values are metres.
  print(side,'palm local metres',local[:3]*np.linalg.norm(world[ids[side+'Hand']][:3,0]))
 print('Repaired',destination,'without changing mesh positions, triangles, UVs or textures.')

if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('source');parser.add_argument('destination');args=parser.parse_args()
 repair(args.source,args.destination)
