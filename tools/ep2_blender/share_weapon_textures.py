#!/usr/bin/env python3
"""Use one external image set across the three authored gloves to bound the web pack.
Run after the Blender builders and before Godot import. Texture bytes are unchanged.
"""
import json
import struct
import shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'src/episode2/assets/weapons/armory'
SOURCE=ROOT/'design/ep2/armory/blender/hand-textures'
for name in ['fp_yarn.png','fp_leather.png','olive_glove.png']:
    if name=='olive_glove.png':
        shutil.copy2(SOURCE/name,OUT/('weapon_hand_'+name))
for name in ['remington_grip_hand','bow_left_hand','bow_right_hand']:
    path=OUT/(name+'.glb');raw=path.read_bytes()
    size,=struct.unpack_from('<I',raw,12);doc=json.loads(raw[20:20+size])
    for im in doc.get('images',[]):
        image_name=im.get('name','').lower()
        tex=next((x for x in ['fp_yarn.png','fp_leather.png','olive_glove.png'] if x.split('.')[0] in image_name),None)
        if tex is None:
            raise ValueError('unrecognized image: '+image_name)
        im.pop('bufferView',None)
        im['uri']=('weapon_hand_' if tex=='olive_glove.png' else 'remington_grip_hand_')+tex
    if name=='remington_grip_hand':
        for anim in doc.get('animations',[]):
            anim['channels']=[c for c in anim['channels'] if c['target']['path']=='rotation' and doc['nodes'][c['target']['node']].get('name') in ['index2','index3']]
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    rest=raw[20+size:]
    path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(rest))+struct.pack('<II',len(js),0x4e4f534a)+js+rest)
# Remove only known generated extraction copies for these three updated models.
# Existing original Remington yarn/leather files remain tracked for compatibility.
for prefix in ['bow_left_hand','bow_right_hand','remington_grip_hand']:
    for tex in ['fp_yarn.png','fp_leather.png','olive_glove.png']:
        if prefix=='remington_grip_hand' and tex!='olive_glove.png':continue
        p=OUT/(prefix+'_'+tex)
        p.unlink(missing_ok=True)
        Path(str(p)+'.import').unlink(missing_ok=True)
for tex in ['fp_yarn.png','fp_leather.png']:
    p=OUT/('weapon_hand_'+tex)
    p.unlink(missing_ok=True)
    Path(str(p)+'.import').unlink(missing_ok=True)
print('Shared glove textures linked; redundant neutral finger tracks omitted')
