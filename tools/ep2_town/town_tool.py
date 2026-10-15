#!/usr/bin/env python3
"""Offline Episode 2 town preproduction. No providers or runtime files are changed."""
import argparse
import base64
import hashlib
import html
import json
import math
from pathlib import Path
import random
import re
import subprocess
import sys

SOURCE = 'src/episode2/chamber/ep2_gold_town.gd'
KIT = 'tools/ep2_blender/build_town_kit.py'
BEATS = ['STREET', 'OFFICE', 'TO_BAR', 'BAR', 'SQUARE_UP', 'DRAW', 'WON', 'DONE']
KINDS = {'person', 'horse', 'dog', 'chicken', 'instrument', 'prop'}


def digest(path):
    # Typed base64 checksum; distinguish public source provenance from raw key-shaped hex.
    return 'sha256:' + base64.b64encode(hashlib.sha256(path.read_bytes()).digest()).decode('ascii')


def number(text, half):
    """Only literals and the known street constant; never evaluate GDScript."""
    return {'STREET_HALF': half, '-STREET_HALF': -half}.get(text, None) if 'STREET_HALF' in text else float(text)


def inspect_repo(repo):
    text = (repo / SOURCE).read_text()
    half = float(re.search(r'const STREET_HALF := ([\d.]+)', text)[1])
    layout = text.split('const LAYOUT: Array = [', 1)[1].split('\n]', 1)[0]
    footprints = text.split('const FOOTPRINT: Dictionary = {', 1)[1].split('\n}', 1)[0]
    sizes = {name: [float(n) for n in values.split(',')]
             for name, values in re.findall(r'"([\w]+)": \[([^\]]+)\]', footprints)}
    buildings = []
    for name, x, z, side in re.findall(r'\["(\w+)",\s*([^,]+),\s*([\d.]+),\s*(-?\d+)\]', layout):
        x, z, side = number(x.strip(), half), float(z), int(side)
        w, d, gap = sizes[name]
        if side == 1:
            bounds = [x-d, z-w/2, x, z+w/2]
        elif side == -1:
            bounds = [x, z-w/2, x+d, z+w/2]
        elif side == 0:
            bounds = [x-w/2, z, x+w/2, z+d]
        else:
            raise ValueError(f'Unsupported building side: {side}')
        buildings.append(dict(id=name, front=[x, z], side=side, bounds=bounds,
                              door_half_width=gap, traversable=gap > 0))
    if len(buildings) != len(sizes) or not buildings:
        raise ValueError('Layout/footprint parser mismatch; update the adapter before planning')
    kit = (repo / KIT).read_text()
    head = subprocess.run(['git', '-C', str(repo), 'rev-parse', 'HEAD'],
                          capture_output=True, text=True, check=True).stdout.strip()
    return dict(schema_version=1, source_commit=head,
                source_hashes={SOURCE: digest(repo/SOURCE), KIT: digest(repo/KIT)},
                buildings=buildings,
                source_observations=dict(building_count=len(buildings),
                    door_generator='def shell(' in kit, window_generator='def window(' in kit,
                    note='Definitions only: visibility, mesh openings and animation need engine evidence.'),
                runtime_audit='not_performed')


def plan(audit, seed):
    rng = random.Random(seed)
    p = dict(schema_version=1, status='proposal', seed=seed,
             source_commit=audit['source_commit'], source_hashes=audit['source_hashes'],
             coordinate_frame='Godot metres; x east, y up; plan points are [x,z]',
             buildings=audit['buildings'],
             narrative=dict(beats=BEATS, cast=['Sheriff', 'Minister Mike Dean'],
                 bull='absent until WON; existing runtime owns his entrance',
                 bears_in_town=False, diamonds=False, new_protocol_numbers=False),
             budgets=dict(max_ambient_actors=24, max_instrument_emitters=2,
                          pck_limit_bytes=190*1024*1024, measured_pck_bytes=None),
             keepouts=[dict(id='main_travel_and_duel', bounds=[-3.5,1397,3.5,1467])],
             roads=[dict(id='main', points=[[0,1401],[0,1470]], width=7),
                    dict(id='south_cross', points=[[-30,1401],[32,1401]], width=4),
                    dict(id='north_cross', points=[[-30,1458],[32,1458]], width=4),
                    dict(id='west_avenue', points=[[-30,1401],[-30,1458]], width=4),
                    dict(id='east_avenue', points=[[32,1401],[32,1458]], width=4)],
             facades=[dict(building=b['id'], door='open passage' if b['traversable'] else 'closed scenic door',
                           min_visible_windows=2, treatment='recessed sash, sill, frame; weathered timber',
                           proof='first-person frontal and oblique capture; verify window backing/occlusion')
                      for b in audit['buildings']],
             population=[], captures=[],
             evidence=dict(runtime_visual='not_run', performance='not_measured', release='not_attempted'))
    # Intentional activity clusters, not uniform scatter. Keep the street duel unobstructed.
    specs = [
        ('stable_hand','person',[-24,1441],.4,'Stable yard','brush horse; carry feed','stable_loop',[[ -24,1441],[-24,1443]]),
        ('horse_west','horse',[-24,1446],1.0,'Stable yard','weight shift; ear flick; drink','horse_idle',[]),
        ('horse_east','horse',[6.4,1431],.9,'Hitch rail','breath; tail swish; head lower','horse_idle',[]),
        ('storekeeper','person',[-7.1,1422],.4,'General store porch','sweep; pause; watch street','sweep',[]),
        ('miner','person',[-24,1421],.4,'Assay service yard','carry ore sack; rest','carry_loop',[[-24,1421],[-24,1424]]),
        ('laundry_worker','person',[25,1424],.4,'Hotel service yard','peg linen; turn','laundry',[]),
        ('fiddler','person',[7,1409],.4,'Saloon porch','bow fiddle with measured hand contacts','fiddle',[]),
        ('fiddle','instrument',[7,1409],.18,'Saloon porch','attached to fiddler; positional stem','attached',[]),
        ('piano','instrument',[18,1418],.6,'Saloon interior','reuse Bar_Piano; optional quiet stem','piano',[]),
        ('dog_yard','dog',[-23,1428],.4,'Assay yard','sniff; settle; glance up','dog_loop',[[-23,1428],[-24,1430]]),
        ('dog_stable','dog',[-25,1449],.4,'Stable shade','sleep; ear twitch; stand','dog_rest',[]),
        ('chicken_1','chicken',[25,1443],.2,'Feed yard','peck; scratch; short wander','peck',[[25,1443],[26,1444]]),
        ('chicken_2','chicken',[27,1447],.2,'Feed yard','peck; look up','peck',[[27,1447],[26,1448]]),
        ('chicken_3','chicken',[25,1450],.2,'Feed yard','peck; shake feathers','peck',[[25,1450],[26,1451]]),
        ('water_pump','prop',[-23,1452],.65,'Stable yard','bucket, wet patch and worn ground','static',[]),
        ('feed_sacks','prop',[27,1441],.6,'Feed yard','stack by coop, wheelbarrow nearby','static',[])]
    for ident, kind, at, radius, district, action, routine, path in specs:
        p['population'].append(dict(id=ident, kind=kind, at=at, radius=radius, district=district,
            action=action, routine=routine, path=path, phase_seconds=round(rng.uniform(0,8),3),
            asset=None, attachment_parent='fiddler' if ident=='fiddle' else None,
            audio_emitter=kind=='instrument', stop_audio_on=['OFFICE','BAR','SQUARE_UP','DRAW'],
            on_duel='hold in home zone; no street crossing; animals never become targets'))
    for ident, at, target in [('arrival',[-2,1403],[0,1435]), ('cross_street',[0,1458],[-30,1458]),
                             ('stable',[-29,1437],[-24,1446]),('feed_yard',[31,1440],[26,1447]),
                             ('office_door',[-5,1412],[-9,1412]),('saloon_door',[5,1414],[9,1414]),
                             ('duel',[0,1417],[0,1432])]:
        p['captures'].append(dict(id=ident, eye=[at[0],1.55,at[1]], target=[target[0],1.4,target[1]],
            evidence_required=['baseline','candidate','10_second_clip'], status='not_captured'))
    return p


def finite(value):
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError('Non-finite coordinate/value')
    if isinstance(value, dict):
        for v in value.values(): finite(v)
    if isinstance(value, list):
        for v in value: finite(v)


def point(v, size=2):
    if not isinstance(v,list) or len(v)!=size or any(type(n) not in (int,float) for n in v):
        raise ValueError(f'Expected {size} numeric coordinates: {v!r}')


def segment_hits_rect(a, b, rect, padding=0):
    """Inclusive slab intersection; padding gives conservative disc/corridor clearance."""
    lo, hi = 0.0, 1.0
    for axis in (0,1):
        lower, upper = rect[axis]-padding, rect[axis+2]+padding
        delta = b[axis]-a[axis]
        if abs(delta)<1e-12:
            if a[axis]<lower or a[axis]>upper: return False
        else:
            t0, t1 = sorted(((lower-a[axis])/delta,(upper-a[axis])/delta))
            lo, hi = max(lo,t0), min(hi,t1)
            if lo>hi: return False
    return True


def segments(road):
    return list(zip(road['points'],road['points'][1:]))


def touching(a,b,c,d):
    # Axis-aligned roads only; crossing junctions count as graph connections.
    return segment_hits_rect(a,b,[min(c[0],d[0]),min(c[1],d[1]),max(c[0],d[0]),max(c[1],d[1])])


def validate(p, repo=None):
    finite(p)
    errors=[]
    if p['schema_version']!=1 or p['status']!='proposal': errors.append('Only schema 1 proposals are supported')
    n=p['narrative']
    if n['beats']!=BEATS or n['cast']!=['Sheriff','Minister Mike Dean'] or any(n[k] for k in ('bears_in_town','diamonds','new_protocol_numbers')):
        errors.append('Narrative locks changed')
    if n['bull']!='absent until WON; existing runtime owns his entrance': errors.append('Bull timing changed')
    groups=('buildings','roads','population','keepouts','captures')
    for group in groups:
        ids=[obj['id'] for obj in p[group]]
        if any(not isinstance(v,str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*',v) for v in ids):
            raise ValueError('IDs must be simple node-safe names')
        if len(ids)!=len(set(ids)): errors.append(f'Duplicate IDs in {group}')
    protected=next((k for k in p['keepouts'] if k['id']=='main_travel_and_duel'),None)
    if not protected or protected['bounds']!=[-3.5,1397,3.5,1467]: errors.append('Required travel/duel clearance removed or changed')
    if not p['captures'] or 'duel' not in {c['id'] for c in p['captures']}: errors.append('Missing capture coverage')
    for b in p['buildings']+p['keepouts']:
        point(b['bounds'],4)
        if b['bounds'][0]>=b['bounds'][2] or b['bounds'][1]>=b['bounds'][3]: errors.append(f'Invalid bounds: {b["id"]}')
    roads=p['roads']
    if not roads: errors.append('No roads')
    for r in roads:
        if len(r['points'])<2 or type(r['width']) not in (int,float) or r['width']<2.5: errors.append(f'Invalid road: {r["id"]}')
        for pt in r['points']: point(pt)
        for a,b in segments(r):
            if a==b or (a[0]!=b[0] and a[1]!=b[1]): errors.append(f'Road must have nonzero axis-aligned segments: {r["id"]}')
            for building in p['buildings']:
                if segment_hits_rect(a,b,building['bounds'],r['width']/2): errors.append(f'Road {r["id"]} clips {building["id"]}')
    reached={0} if roads else set()
    while True:
        linked={j for j,r in enumerate(roads) if any(touching(a,b,c,d) for i in reached
                for a,b in segments(roads[i]) for c,d in segments(r))}
        new=reached|linked
        if new==reached: break
        reached=new
    if len(reached)!=len(roads): errors.append('Disconnected avenue network')
    for actor in p['population']:
        point(actor['at'])
        radius=actor['radius']
        if type(radius) not in (int,float) or radius<=0: raise ValueError('Actor radius must be positive')
        if actor['kind'] not in KINDS: errors.append(f'Unknown kind: {actor["kind"]}')
        if actor['kind']=='instrument' and not set(['OFFICE','BAR','SQUARE_UP','DRAW'])<=set(actor['stop_audio_on']): errors.append('Instrument masks story audio')
        path=actor['path']
        for pt in path: point(pt)
        if path and path[0]!=actor['at']: errors.append(f'Path must start at placement: {actor["id"]}')
        route=[actor['at']]+path
        for a,b in zip(route,route[1:]+[route[-1]]):
            for rect in p['buildings']+p['keepouts']:
                if actor['id']=='piano' and rect['id']=='Bldg_Saloon': continue  # explicit interior furnishing
                if segment_hits_rect(a,b,rect['bounds'],radius): errors.append(f'{actor["id"]} overlaps {rect["id"]}')
            for building in p['buildings']:
                if building['traversable']:
                    x,z=building['front']
                    # Protect entry approach as well as the existing opening.
                    if segment_hits_rect(a,b,[x-1.2,z-1.2,x+1.2,z+1.2],radius): errors.append(f'{actor["id"]} blocks doorway {building["id"]}')
    # Deliberate attached instrument/body overlap only; other placements must not intersect.
    actors=p['population']
    for i,a in enumerate(actors):
        for b in actors[i+1:]:
            if a.get('attachment_parent')==b['id'] or b.get('attachment_parent')==a['id']: continue
            if math.dist(a['at'],b['at'])<a['radius']+b['radius']: errors.append(f'Overlapping placements: {a["id"]}, {b["id"]}')
    for a in actors:
        parent=a.get('attachment_parent')
        if parent and parent not in {v['id'] for v in actors}: errors.append('Missing attachment parent')
    facades=p['facades']
    if {v['building'] for v in facades}!={b['id'] for b in p['buildings']} or len(facades)!=len(p['buildings']): errors.append('Facade coverage incomplete')
    for f in facades:
        if f['min_visible_windows']<2: errors.append('Facade window target missing')
    for c in p['captures']: point(c['eye'],3); point(c['target'],3)
    budget=p['budgets']
    if sum(a['kind'] in {'person','horse','dog','chicken'} for a in actors)>budget['max_ambient_actors']: errors.append('Actor budget exceeded')
    if sum(bool(a['audio_emitter']) for a in actors)>budget['max_instrument_emitters']: errors.append('Audio budget exceeded')
    if budget['pck_limit_bytes']!=190*1024*1024: errors.append('Pack limit changed')
    size=budget['measured_pck_bytes']
    if size is not None and (type(size)!=int or size<0 or size>=budget['pck_limit_bytes']): errors.append('Measured pack fails size gate')
    if repo:
        audit=inspect_repo(repo)
        if p['source_hashes']!=audit['source_hashes'] or p['buildings']!=audit['buildings']: errors.append('Town source drift: replan from current source')
    return dict(valid_proposal=not errors, errors=sorted(set(errors)),
        unresolved_assets=[a['id'] for a in actors if not a['asset']],
        runtime_approved=False, note='Checks cover proposal geometry and declared locks only; engine navigation, full moving-body collisions, visibility, sound and performance remain unverified.')


def write_json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')


def board(p):
    # Schematic only: coordinates remain traceable to the Godot world.
    def xy(pt): return ((pt[0]+40)*8+30,(1500-pt[1])*8+35)
    def rect(bounds,colour,label):
        x,y=xy([bounds[0],bounds[3]])
        w,h=(bounds[2]-bounds[0])*8,(bounds[3]-bounds[1])*8
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{colour}" stroke="#453a2b"/><text x="{x+3}" y="{y+13}" font-size="10">{html.escape(label)}</text>'
    out=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 900"><rect width="720" height="900" fill="#eddfbd"/><g font-family="sans-serif" fill="#241d15"><text x="20" y="22" font-size="17">EPISODE 2 — PROPOSED LIVING TOWN</text>']
    for r in p['roads']:
        pts=' '.join(f'{x},{y}' for x,y in map(xy,r['points']))
        out.append(f'<polyline points="{pts}" fill="none" stroke="#c8aa76" stroke-width="{r["width"]*8}"/>')
    names=dict(Bldg_A='General Store',Bldg_B='Hotel',Bldg_C='Assay',Bldg_D='Auctions',Bldg_E='Stats',Bldg_F='Reserve')
    for b in p['buildings']: out.append(rect(b['bounds'],'#ad8056',names.get(b['id'],b['id'].replace('Bldg_',''))))
    for b in p['keepouts']:
        x,y=xy([b['bounds'][0],b['bounds'][3]])
        out.append(f'<rect x="{x}" y="{y}" width="{(b["bounds"][2]-b["bounds"][0])*8}" height="{(b["bounds"][3]-b["bounds"][1])*8}" fill="none" stroke="#b35337" stroke-dasharray="6 4"/>')
    colors=dict(person='#285e60',horse='#664336',dog='#805c9a',chicken='#986b1e',instrument='#ba422b',prop='#54633e')
    for a in p['population']:
        x,y=xy(a['at'])
        out.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{colors[a["kind"]]}"/><text x="{x+6}" y="{y-4}" font-size="8">{html.escape(a["id"])}</text>')
    out.append('<text x="20" y="850" font-size="12">Dashed red: travel / duel clearance. Brown: existing buildings.</text><text x="20" y="872" font-size="12">Proposal only. Player-camera, animation and performance review required.</text></g></svg>')
    return ''.join(out)


def handoff(p,out):
    result=validate(p)
    if not result['valid_proposal']: raise ValueError('; '.join(result['errors']))
    out.mkdir(parents=True,exist_ok=True)
    write_json(out/'town-plan.json',p)
    write_json(out/'validation.json',result)
    (out/'town-board.svg').write_text(board(p))
    jobs=[]
    for a in p['population']:
        jobs.append(dict(id=a['id'],kind=a['kind'],purpose=a['action'],
            status='reuse_search_required' if a['id']=='piano' else 'asset_unresolved',
            existing_candidate='town_kit.glb:Bar_Piano' if a['id']=='piano' else None,
            required_clips=[a['routine']], model=a['asset'], license_proof=None,
            pipeline='approved library/local Blender first; existing Tripo/Meshy workflow only if needed',
            prompt=f'Golden-hour GoldMine western town. {a["district"]}: {a["action"]}. Weathered period materials, grounded scale; no modern equipment, no bears, no new story dialogue.',
            acceptance=['metres; feet/pivot at ground','licensed source recorded','whole animation loop checked','real first-person camera review']))
    write_json(out/'asset-jobs.json',jobs)
    write_json(out/'capture-jobs.json',p['captures'])
    # Explicit marker scene, not meshes, navigation, collisions or playable runtime integration.
    lines=['[gd_scene format=3]','', '[node name="TownProposalMarkers" type="Node3D"]',
           'metadata/proposal_only = true','metadata/runtime_approved = false']
    for a in p['population']:
        lines.extend(['',f'[node name="{a["id"]}" type="Marker3D" parent="."]',
            f'position = Vector3({a["at"][0]}, 0, {a["at"][1]})',
            f'metadata/kind = "{a["kind"]}"'])
    (out/'proposal-markers.tscn').write_text('\n'.join(lines)+'\n')
    (out/'README.md').write_text('# Episode 2 living-town handoff\n\nProposal only; no runtime scene changed.\n\n'
        'Start with `.claude/skills/ep2-living-town/SKILL.md`. The SVG is a schematic, not a gameplay render. '
        'JSON uses Godot [x,z] metres and preserves existing building coordinates. '
        '`proposal-markers.tscn` contains placement markers only; never wire it as finished art.\n\n'
        'Implement avenues in the shared town builder used by both arrival and town scenes. '
        'Resolve asset jobs, facade openings/visibility, clip contacts, navigation/collision and story audio; '
        'then capture all jobs and run the existing town/interlude/arc gates, real Godot export and browser checks. '
        'Measure final PCK (<190 MiB), frame timing and active actor counts. A valid proposal is not visual/runtime approval.\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    for name in ('audit','plan'):
        s=sub.add_parser(name); s.add_argument('--repo',type=Path,required=True); s.add_argument('--out',type=Path,required=True)
        if name=='plan': s.add_argument('--seed',type=int,default=22015)
    for name in ('validate','handoff'):
        s=sub.add_parser(name); s.add_argument('plan',type=Path); s.add_argument('--repo',type=Path,required=True)
        if name=='handoff': s.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    try:
        if args.command=='audit': write_json(args.out,inspect_repo(args.repo))
        elif args.command=='plan':
            p=plan(inspect_repo(args.repo),args.seed)
            result=validate(p,args.repo)
            if not result['valid_proposal']: raise ValueError('; '.join(result['errors']))
            write_json(args.out,p)
        else:
            p=json.loads(args.plan.read_text())
            result=validate(p,args.repo)
            if args.command=='validate': print(json.dumps(result,indent=2))
            elif result['valid_proposal']: handoff(p,args.out)
            if not result['valid_proposal']: return 1
        return 0
    except (ValueError,KeyError,TypeError,IndexError,OSError,subprocess.CalledProcessError) as exc:
        print(f'town-tool: {exc}',file=sys.stderr); return 2


if __name__=='__main__':
    sys.exit(main())
