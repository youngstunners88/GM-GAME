#!/usr/bin/env python3
"""Run the pinned skill runner; make semantic QA failure fail the host command too.
Usage: BLENDER_EXE=/absolute/blender python tools/blender_skills/run_checked.py
       --blend asset.blend .claude/skills/.../script.py -- [script arguments]
This does not sanitize or authorize scripts; execute reviewed local scripts only.
"""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
runner = root / '.claude/skills/blender-core/scripts/run_in_blender.py'
p = subprocess.run([sys.executable, str(runner), *sys.argv[1:]], capture_output=True, text=True)
sys.stdout.write(p.stdout)
sys.stderr.write(p.stderr)
failed = p.returncode != 0
results = 0
for line in p.stdout.splitlines():
    try:
        value = json.loads(line)
    except json.JSONDecodeError:
        continue
    if isinstance(value, dict):
        results += 1
        failed |= value.get('pass') is False or value.get('ok') is False
if not results:
    print('No structured result; readiness is unproven.', file=sys.stderr)
    failed = True
raise SystemExit(1 if failed else 0)
