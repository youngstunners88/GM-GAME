"""Inspect the exported street GLBs independently of Blender and compare the recoverable baseline.
python tools/ep2_blender/audit_street_people.py
"""
import hashlib
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'design/ep2/town/people-rebuild-20261021'
baseline=json.loads((WORK/'baseline.json').read_text())
results=[]
for previous in baseline['assets']:
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
    assert sorted(a['name'] for a in gltf['animations'])==previous['animations'],path
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
    results.append(dict(file=path.name,triangles=triangles,previous_triangles=previous['triangles'],vertices=vertices,materials=1,images=len(gltf['images']),joints=20,clips=previous['animations'],bytes=len(raw),sha512=hashlib.sha512(raw).hexdigest()))
report=dict(pass_checks=True,source_baseline_sha=baseline['source_sha'],assets=results)
(WORK/'export-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
