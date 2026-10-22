#!/usr/bin/env python3
"""Verify both project-local skill installations against the reviewed receipt."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
receipt = json.loads((ROOT / 'docs/research/blender-skills/installation.json').read_text())
errors = []
for installation in receipt['installations']:
    for relative, expected in receipt['files'].items():
        path = ROOT / installation / relative
        if not path.is_file() or hashlib.sha512(path.read_bytes()).hexdigest() != expected:
            errors.append(str(path.relative_to(ROOT)))
print(json.dumps({'pass': not errors, 'copies': len(receipt['installations']),
                  'files_per_copy': len(receipt['files']), 'mismatches': errors}, indent=2))
raise SystemExit(1 if errors else 0)
