"""Build the additional supplied figures serially, preserving editable sources and every reference ID."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--only');p.add_argument('--blender',default=str(Path.home()/'creative-hub/apps/blender'));a=p.parse_args()
    config=json.loads((ROOT/'design/ep2/town/autonomy-20261022/cast-build.json').read_text())
    people=[a.only] if a.only else list(config)
    logs=ROOT/'design/ep2/town/autonomy-20261022/logs';logs.mkdir(exist_ok=True)
    for person in people:
        if person not in config:raise SystemExit('Unknown cast ID: '+person)
        print('BUILD '+person,flush=True)
        with (logs/(person+'.log')).open('w') as stream:
            subprocess.run([a.blender,'-b','--factory-startup','-t','2','--python-exit-code','1','-P',str(ROOT/'tools/ep2_blender/rebuild_street_people.py'),'--','--only',person],env=dict(os.environ,ALSOFT_DRIVERS='null'),cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,check=True,timeout=600)
        receipt=ROOT/'design/ep2/town/autonomy-20261022/sources'/person/'receipt.json'
        assert receipt.exists() and json.loads(receipt.read_text())['joints']==20
        print('PASS '+person,flush=True)
