"""Inspect the exported street GLBs independently of Blender and compare the recoverable baseline.
python tools/ep2_blender/audit_street_people.py
"""
import hashlib
import argparse
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'design/ep2/town/people-rebuild-20261021'
baseline=json.loads((WORK/'baseline.json').read_text())
parser=argparse.ArgumentParser();parser.add_argument('--full-cast',action='store_true');args=parser.parse_args()
cast=baseline['assets'].copy()
if args.full_cast:
    config=json.loads((ROOT/'design/ep2/town/autonomy-20261022/cast-build.json').read_text())
    cast.extend(dict(file=c['name']+'.glb',triangles=None,animations=['Idle','Walk','Greet','Point','Carry']) for c in config.values())
results=[]
for previous in cast:
    path=ROOT/'src/episode2/extras/people'/previous['file']
    raw=path.read_bytes()
    magic,version,length=struct.unpack_from('<III',raw)
    assert magic==0x46546C67 and version==2 and length==len(raw),path
    size,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4E4F534A,path
    gltf=json.loads(raw[20:20+size])
    primitives=[p for mesh in gltf['meshes'] for p in mesh['primitives']]
    assert len(primitives)==1,'Expected one draw surface per street character'
    for primitive in primitives:
        assert {'POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'} <= primitive['attributes'].keys(),path
        vertices=gltf['accessors'][primitive['attributes']['POSITION']]['count']
        for attribute in ['NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0']:
            assert gltf['accessors'][primitive['attributes'][attribute]]['count']==vertices,(path,attribute)
    assert len(gltf['skins'])==1 and len(gltf['skins'][0]['joints'])==20,path
    required=set(previous['animations']) | ({'Observe','Rest','Talk','Inspect','Alert'} if args.full_cast else set())
    assert required.issubset(a['name'] for a in gltf['animations']),path
    assert len(gltf.get('images',[]))>=3,path
    for image in gltf['images']:
        assert image.get('mimeType') in ['image/jpeg','image/png'],(path,image)
        assert 'bufferView' in image and 'uri' not in image,(path,'unembedded image')
    unsupported={'KHR_draco_mesh_compression','EXT_meshopt_compression','KHR_mesh_quantization','KHR_texture_basisu','EXT_texture_webp'}
    assert not unsupported.intersection(gltf.get('extensionsUsed',[])),path
    assert len(gltf['materials'])==1,path
    material=gltf['materials'][0];pbr=material['pbrMetallicRoughness']
    assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in material,path
    triangles=sum(gltf['accessors'][p['indices']]['count']//3 for p in primitives)
    assert 10000<=triangles<=40000,(path,triangles)
    results.append(dict(file=path.name,triangles=triangles,previous_triangles=previous['triangles'],vertices=vertices,materials=1,images=len(gltf['images']),joints=20,clips=sorted(a['name'] for a in gltf['animations']),bytes=len(raw),sha512=hashlib.sha512(raw).hexdigest()))
report=dict(pass_checks=True,source_baseline_sha=baseline['source_sha'],assets=results)
if args.full_cast: WORK=ROOT/'design/ep2/town/autonomy-20261022'
(WORK/'export-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
