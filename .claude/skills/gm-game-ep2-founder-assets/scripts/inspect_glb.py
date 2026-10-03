#!/usr/bin/env python3
"""Read-only GLB v2 inventory; estimates are not render or deformation proof."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys


def inspect(path):
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError('GLB is truncated')
    magic, version, length = struct.unpack_from('<III', data)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError('invalid GLB v2 header or length')
    offset, doc = 12, None
    while offset < length:
        if offset + 8 > length:
            raise ValueError('truncated chunk header')
        size, kind = struct.unpack_from('<II', data, offset)
        offset += 8
        if size % 4 or offset + size > length:
            raise ValueError('invalid chunk alignment or length')
        if kind == 0x4E4F534A:
            if doc is not None:
                raise ValueError('duplicate JSON chunk')
            doc = json.loads(data[offset:offset+size])
        offset += size
    if not isinstance(doc, dict) or doc.get('asset', {}).get('version') != '2.0':
        raise ValueError('missing glTF 2.0 JSON')
    accessors = doc.get('accessors', [])
    meshes = doc.get('meshes', [])
    triangles, positions = 0, []
    for mesh in meshes:
        for primitive in mesh.get('primitives', []):
            pos = accessors[primitive['attributes']['POSITION']]
            positions.append({'min': pos.get('min'), 'max': pos.get('max')})
            count = accessors[primitive['indices']]['count'] if 'indices' in primitive else pos['count']
            mode = primitive.get('mode', 4)
            if mode == 4:
                triangles += count // 3
            elif mode in (5, 6):
                triangles += max(0, count - 2)
    return {'path': str(path), 'bytes': length, 'sha512': hashlib.sha512(data).hexdigest(),
            'meshes': len(meshes), 'triangles_per_mesh_set_estimate': triangles,
            'nodes': len(doc.get('nodes', [])), 'skins': len(doc.get('skins', [])),
            'animations': [a.get('name', '') for a in doc.get('animations', [])],
            'position_accessor_bounds': positions,
            'materials': [{'name': m.get('name', ''), 'alphaMode': m.get('alphaMode', 'OPAQUE'),
                           'doubleSided': m.get('doubleSided', False),
                           'metallicFactor': m.get('pbrMetallicRoughness', {}).get('metallicFactor', 1),
                           'roughnessFactor': m.get('pbrMetallicRoughness', {}).get('roughnessFactor', 1)}
                          for m in doc.get('materials', [])],
            'limits': 'Bounds are accessor-local, not posed/world bounds; counts do not certify skin or visual quality.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='+', type=Path)
    args = parser.parse_args()
    results, failed = [], False
    for path in args.paths:
        try:
            results.append(inspect(path))
        except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
            failed = True
            results.append({'path': str(path), 'error': str(exc)})
    print(json.dumps(results, indent=2))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
