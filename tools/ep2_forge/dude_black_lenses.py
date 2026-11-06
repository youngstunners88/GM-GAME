"""Darken only Dude's existing lens UVs; preserve every mesh/skin/animation byte.

Usage: python3 tools/ep2_forge/dude_black_lenses.py original.glb output.glb
The mask is measured in the supplied model's bind-space, inside its black frames.
"""
import io
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

source, target = map(Path, sys.argv[1:3])
raw = source.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20 + length])
binary = bytearray(raw[28 + length:])


def accessor(index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    count = {'VEC3': 3, 'VEC2': 2, 'SCALAR': 1}[a['type']]
    dtype = {5126: '<f4', 5123: '<u2', 5125: '<u4'}[a['componentType']]
    return np.frombuffer(binary, dtype=dtype, count=a['count'] * count,
                         offset=view.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(-1, count).copy()


primitive = doc['meshes'][0]['primitives'][0]
vertices = accessor(primitive['attributes']['POSITION'])
uv = accessor(primitive['attributes']['TEXCOORD_0'])
triangles = accessor(primitive['indices']).reshape(-1, 3)
material = doc['materials'][primitive['material']]
image_index = doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
view = doc['bufferViews'][doc['images'][image_index]['bufferView']]
im = Image.open(io.BytesIO(binary[view['byteOffset']:view['byteOffset'] + view['byteLength']])).convert('RGB')
mask = Image.new('L', im.size)
draw = ImageDraw.Draw(mask)
selected = 0
for tri in triangles:
    center = vertices[tri].mean(axis=0)
    x, y, z = center
    if (0.008 + max(0.0, 0.930 - y) * 0.35 < abs(x) < 0.041
            and 0.911 + max(0.0, abs(x) - 0.030) * 0.65 < y < 0.934
            and z > 0.025):
        draw.polygon([tuple(p * (np.array(im.size) - 1)) for p in uv[tri]], fill=255)
        selected += 1
assert selected > 5, 'Source model no longer matches the measured lens bounds'
# Retain slight texture variation and highlights; remove visible skin/eye colour.
pixels = np.array(im)
region = np.array(mask) > 0
pixels[region] = (pixels[region].astype(float) * 0.035 + 3).astype('uint8')
buffer = io.BytesIO()
Image.fromarray(pixels).save(buffer, format='PNG')
payload = buffer.getvalue()
while len(binary) % 4: binary.append(0)
view['byteOffset'] = len(binary)
view['byteLength'] = len(payload)
binary.extend(payload)
while len(binary) % 4: binary.append(0)
doc['images'][image_index]['mimeType'] = 'image/png'
material['alphaMode'] = 'OPAQUE'
doc['buffers'][0]['byteLength'] = len(binary)
encoded = json.dumps(doc, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
result = struct.pack('<III', 0x46546c67, 2, 28 + len(encoded) + len(binary))
result += struct.pack('<I4s', len(encoded), b'JSON') + encoded
result += struct.pack('<I4s', len(binary), b'BIN\0') + binary
target.write_bytes(result)
print(json.dumps({'triangles': selected, 'pixels': int(region.sum()), 'bytes': len(result)}))
