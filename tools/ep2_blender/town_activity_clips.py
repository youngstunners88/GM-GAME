"""Conservative standing activity clips on the retained 20-joint rig. No unproven hand/prop contacts."""
import argparse
import importlib.util
from pathlib import Path
import sys


def add(AF,arm):
    clips={
        'Observe':[(1,{'Head':(0,0,-12),'Chest':(0,0,-2)}),(30,{'Head':(-3,0,0),'Chest':(0,0,1)}),(60,{'Head':(0,0,12),'Chest':(0,0,2)}),(90,{'Head':(0,0,-12),'Chest':(0,0,-2)})],
        'Rest':[(1,{'Spine':(3,0,0),'Chest':(-2,0,1),'Head':(3,0,0)}),(36,{'Spine':(4,0,0),'Chest':(-1,0,-1),'Head':(4,0,2)}),(72,{'Spine':(3,0,0),'Chest':(-2,0,1),'Head':(3,0,0)})],
        'Talk':[(1,{'Head':(0,0,-3),'Forearm.R':(-20,0,0)}),(18,{'Head':(4,0,2),'Forearm.R':(-28,0,2),'Chest':(0,0,-2)}),(36,{'Head':(-2,0,4),'Forearm.R':(-23,0,-2)}),(54,{'Head':(0,0,-3),'Forearm.R':(-20,0,0)})],
        'Inspect':[(1,{'Head':(12,0,-3),'Neck':(3,0,0),'Chest':(3,0,0)}),(24,{'Head':(17,0,2),'Neck':(4,0,0),'Chest':(4,0,1)}),(48,{'Head':(12,0,-3),'Neck':(3,0,0),'Chest':(3,0,0)})],
        'Alert':[(1,{'Head':(-4,0,-8),'Chest':(-2,0,0),'Forearm.L':(-22,0,0),'Forearm.R':(-22,0,0)}),(18,{'Head':(-5,0,8),'Chest':(-3,0,1),'Forearm.L':(-26,0,0),'Forearm.R':(-24,0,0)}),(36,{'Head':(-4,0,-8),'Chest':(-2,0,0),'Forearm.L':(-22,0,0),'Forearm.R':(-22,0,0)})],
    }
    for name,frames in clips.items():AF.apply_clip(arm,AF.clip(name,frames))


if __name__=='__main__':
    import bpy
    root=Path(__file__).resolve().parents[2]
    parser=argparse.ArgumentParser();parser.add_argument('--person',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    spec=importlib.util.spec_from_file_location('af',root/'tools/ep2_blender/build_armory_folk.py');AF=importlib.util.module_from_spec(spec);spec.loader.exec_module(AF)
    role=args.person
    work=root/'design/ep2/town/people-rebuild-20261021/sources'/role
    bpy.ops.wm.open_mainfile(filepath=str(work/(role+'.blend')))
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    geo=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.find_armature()==arm)
    add(AF,arm)
    # Preserve the original editable source; the activity version is a separate file.
    out=root/'design/ep2/town/autonomy-20261022/sources'/role;out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(role+'.blend')))
    filename={'clerk':'townsman_clerk','oldtimer':'townsman_oldtimer','rancher':'townsman_rancher','dressmaker':'townswoman_dressmaker','lady':'townswoman_lady'}[role]
    AF.export(str(root/'src/episode2/extras/people'/(filename+'.glb')),arm,geo)
    print('TOWN_ACTIVITY_CLIPS: PASS '+role,flush=True)
