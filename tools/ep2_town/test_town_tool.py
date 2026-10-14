"""Executable proposal checks. Does not certify Godot output."""
import copy
import importlib.util
import json
import re
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('town_tool',HERE/'town_tool.py')
tool=importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class TownTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo=HERE.parents[1]
        cls.audit=tool.inspect_repo(cls.repo)

    def setUp(self):
        self.p=tool.plan(self.audit,42)

    def invalid(self,text):
        result=tool.validate(self.p)
        self.assertFalse(result['valid_proposal'])
        self.assertTrue(any(text in e for e in result['errors']),result)

    def test_actual_project_adapter(self):
        self.assertEqual(self.audit['source_observations']['building_count'],10)
        self.assertTrue(self.audit['source_observations']['window_generator'])
        cert=next(b for b in self.audit['buildings'] if b['id']=='Bldg_Certificates')
        self.assertEqual(cert['bounds'],[-18,1408,-9,1416])

    def test_default_passes_without_runtime_claim(self):
        result=tool.validate(self.p,self.repo)
        self.assertTrue(result['valid_proposal'],result)
        self.assertFalse(result['runtime_approved'])
        self.assertEqual(len(result['unresolved_assets']),16)

    def test_seed_determinism(self):
        self.assertEqual(self.p,tool.plan(self.audit,42))
        self.assertNotEqual(self.p['population'],tool.plan(self.audit,43)['population'])

    def test_narrative_bears(self):
        self.p['narrative']['bears_in_town']=True; self.invalid('Narrative')

    def test_cast(self):
        self.p['narrative']['cast']=['JakeX']; self.invalid('Narrative')

    def test_bull_timing(self):
        self.p['narrative']['bull']='OFFICE'; self.invalid('Bull timing')

    def test_removed_keepout(self):
        self.p['keepouts']=[]; self.invalid('clearance')

    def test_road_through_building(self):
        self.p['roads'][1]['points']=[[-30,1412],[32,1412]]; self.invalid('clips')

    def test_disconnected_road(self):
        self.p['roads'].append(dict(id='island',points=[[70,1420],[70,1440]],width=4))
        self.invalid('Disconnected')

    def test_diagonal_road(self):
        self.p['roads'][0]['points'][0]=[1,1401]; self.invalid('axis-aligned')

    def test_narrow_road(self):
        self.p['roads'][0]['width']=1; self.invalid('Invalid road')

    def test_path_through_building(self):
        self.p['population'][0]['path']=[[-24,1441],[0,1441]]; self.invalid('overlaps')

    def test_blocked_door(self):
        self.p['population'][3]['at']=[-8,1412]; self.invalid('blocks doorway')

    def test_actor_in_duel_lane(self):
        self.p['population'][3]['at']=[0,1424]; self.invalid('main_travel_and_duel')

    def test_colliding_placements(self):
        self.p['population'][3]['at']=self.p['population'][4]['at'][:]
        self.invalid('Overlapping placements')

    def test_attachment_exception(self):
        self.assertTrue(tool.validate(self.p)['valid_proposal'])
        self.p['population'][7]['attachment_parent']=None; self.invalid('Overlapping placements')

    def test_facade_coverage(self):
        self.p['facades'].pop(); self.invalid('Facade coverage')

    def test_missing_window_target(self):
        self.p['facades'][0]['min_visible_windows']=0; self.invalid('window target')

    def test_audio_during_draw(self):
        self.p['population'][7]['stop_audio_on']=[]; self.invalid('masks story audio')

    def test_actor_budget(self):
        self.p['budgets']['max_ambient_actors']=2; self.invalid('Actor budget')

    def test_pack_at_limit_fails(self):
        self.p['budgets']['measured_pck_bytes']=190*1024*1024; self.invalid('pack fails')

    def test_nonfinite(self):
        self.p['population'][0]['at'][0]=float('nan')
        with self.assertRaises(ValueError): tool.validate(self.p)

    def test_duplicate_ids(self):
        self.p['population'][0]['id']=self.p['population'][1]['id']; self.invalid('Duplicate')

    def test_unsafe_ids(self):
        self.p['population'][0]['id']='quote"node'
        with self.assertRaises(ValueError): tool.validate(self.p)

    def test_source_drift(self):
        self.p['source_hashes'][tool.SOURCE]='stale'
        self.assertIn('Town source drift: replan from current source',tool.validate(self.p,self.repo)['errors'])

    def test_segment_middle_collision(self):
        self.assertTrue(tool.segment_hits_rect([-10,0],[10,0],[-1,-1,1,1]))
        self.assertFalse(tool.segment_hits_rect([-10,2],[10,2],[-1,-1,1,1]))

    def test_handoff_and_cli_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)
            tool.handoff(self.p,out)
            self.assertEqual(json.loads((out/'town-plan.json').read_text()),self.p)
            self.assertIn('type="Marker3D"',(out/'proposal-markers.tscn').read_text())
            self.assertIn('<svg',(out/'town-board.svg').read_text())
            broken=out/'broken.json'; broken.write_text('{')
            result=subprocess.run(['python3',str(HERE/'town_tool.py'),'validate',str(broken),'--repo',str(self.repo)],capture_output=True)
            self.assertEqual(result.returncode,2)

    def test_skill_structure_and_routes(self):
        names=['ep2-living-town','ep2-town-streets','ep2-town-facades','ep2-town-background-life','ep2-town-proof']
        for name in names:
            text=(self.repo/'.claude/skills'/name/'SKILL.md').read_text()
            front=text.split('---',2)[1]
            for field in ['name','description','argument-hint','user-invocable','allowed-tools']:
                self.assertRegex(front,rf'(?m)^{field}: .+')
            self.assertGreaterEqual(len(re.findall(r'^## ',text,re.M)),2)
            self.assertIn('PASS',text)
            self.assertIn('Before writing',text)
            self.assertRegex(text,r'(?i)next step')
            for path in re.findall(r'`((?:tools|design|src|\.claude)/[^`]+\.(?:md|py|gd))`',text):
                self.assertTrue((self.repo/path).is_file(),path)


if __name__=='__main__': unittest.main()
