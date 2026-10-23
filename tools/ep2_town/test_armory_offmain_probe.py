"""Regression tests for armory_offmain_probe.py (stdlib unittest, no Godot).

  python3 -m unittest discover -s tools/ep2_town -p 'test_*.py'
"""
import pathlib
import subprocess
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
PROBE = HERE / "armory_offmain_probe.py"
sys.path.insert(0, str(HERE))
import armory_offmain_probe as probe  # noqa: E402

CANDIDATE = ["--set", "Bldg_Armory=-30,1428,1", "--add", "Bldg_A=-30,1419,1",
             "--add", "Bldg_C=-30,1448,1", "--add", "Bldg_F=-30,1407,1"]


def run(*args):
    return subprocess.run([sys.executable, str(PROBE), "--repo", str(REPO), *args], capture_output=True, text=True)


class ProbeTests(unittest.TestCase):
    def test_layout_parses_every_row(self):
        text = (REPO / probe.GD).read_text(encoding="utf-8")
        half, _, entries, foot = probe.parse(text)
        names = [e[0] for e in entries]
        self.assertEqual(half, 9.0)
        self.assertIn("Bldg_Armory", names)
        self.assertIn("Bldg_Certificates", names)
        self.assertIn("Bldg_Armory", foot)

    def test_extra_layout_fields_do_not_drop_rows(self):
        text = 'const STREET_HALF := 9.0\nconst LAYOUT: Array = [\n\t["Bldg_A", -STREET_HALF, 1421.5, 1, "plain"],\n]\n' \
               'const FOOTPRINT: Dictionary = {\n\t"Bldg_A": [7.0, 8.0, 0.0],\n}\n'
        _, _, entries, _ = probe.parse(text)
        self.assertEqual(entries, [["Bldg_A", -9.0, 1421.5, 1]])

    def test_door_mouth_follows_the_front(self):
        # side 1 faces +x: one metre out of the door is +1 in x
        self.assertEqual(tuple(round(v, 3) for v in probe.to_world(["P", -30.0, 1428.0, 1], 0.0, 1.0)), (-29.0, 1428.0))
        # side 0 faces -z: one metre out is -1 in z
        self.assertEqual(tuple(round(v, 3) for v in probe.to_world(["P", -20.0, 1468.0, 0], 0.0, 1.0)), (-20.0, 1467.0))

    def test_committed_layout_fails_the_founders_complaint(self):
        # If this starts passing without a placement change, the probe stopped measuring.
        r = run()
        if "Bldg_Armory=-30" in (REPO / probe.GD).read_text(encoding="utf-8"):
            self.skipTest("armory already moved on this checkout")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("FAIL", r.stdout)

    def test_back_lane_candidate_passes(self):
        r = run(*CANDIDATE)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_overlap_is_caught(self):
        r = run("--set", "Bldg_Armory=-9,1421,1")  # on top of the left row
        self.assertEqual(r.returncode, 1)
        self.assertIn("no_footprint_overlap", r.stdout)

    def test_bad_input_exits_2(self):
        self.assertEqual(run("--piece", "Bldg_Nope").returncode, 2)


if __name__ == "__main__":
    unittest.main()
