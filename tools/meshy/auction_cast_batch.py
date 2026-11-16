#!/usr/bin/env python3
"""The auction's seven new people (founder 2026-11-16) through the townfolk Meshy pipeline: two license checkers and a five-piece band.
Same steps as townfolk_batch.py (image-to-3D T-pose -> rig -> clips -> rename/flatten -> shrink), with this cast, 9k triangles and a
smaller clip set, because the streamed extras pack has almost no room left.

  python3 tools/meshy/auction_cast_batch.py plan                # cast + credit estimate, spends nothing
  python3 tools/meshy/auction_cast_batch.py run [--only id,id]  # resumable: task ids live in the manifest
  python3 tools/meshy/auction_cast_batch.py finish [--only id]  # rebuild the game files from saved tasks

Manifest: design/ep2/auction/cast-references-20261116/manifest.json. Key: MESHY_API_KEY from the environment, never printed.
NOT YET RUN (2026-11-16): the key on the build machine was a placeholder. Check the first result's size before running the rest.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import townfolk_batch as tb  # noqa: E402

tb.REFS = tb.ROOT / "design/ep2/auction/cast-references-20261116"
tb.WORK = tb.REFS
GEN = {"target_polycount": 9000, "texture_resolution": "1k"}
# Library ids already proven on the town cast. The band holds Idle until a suitable playing clip is chosen from the library.
tb.CAST = [
    {"id": "checker_a", "ref": "checker_a.jpg", "file": "auction_checker_a.glb", "h": 1.82, "gen": GEN, "clips": {"Idle": 243, "Talk": 313, "Greet": 42}},
    {"id": "checker_b", "ref": "checker_b.jpg", "file": "auction_checker_b.glb", "h": 1.78, "gen": GEN, "clips": {"Idle": 245, "Talk": 314, "Greet": 290}},
    {"id": "band_lead", "ref": "band_lead.jpg", "file": "auction_band_lead.glb", "h": 1.66, "gen": GEN, "clips": {"Idle": 246, "Talk": 309, "Greet": 28}},
    {"id": "band_fiddle", "ref": "band_fiddle.jpg", "file": "auction_band_fiddle.glb", "h": 1.76, "gen": GEN, "clips": {"Idle": 244, "Talk": 56, "Greet": 290}},
    {"id": "band_guitar", "ref": "band_guitar.jpg", "file": "auction_band_guitar.glb", "h": 1.80, "gen": GEN, "clips": {"Idle": 248, "Talk": 313, "Greet": 42}},
    {"id": "band_bass", "ref": "band_bass.jpg", "file": "auction_band_bass.glb", "h": 1.84, "gen": GEN, "clips": {"Idle": 250, "Talk": 314, "Greet": 28}},
    {"id": "band_harmonica", "ref": "band_harmonica.jpg", "file": "auction_band_harmonica.glb", "h": 1.77, "gen": GEN, "clips": {"Idle": 249, "Talk": 56, "Greet": 42}},
]

if __name__ == "__main__":
    sys.exit(tb.main())
