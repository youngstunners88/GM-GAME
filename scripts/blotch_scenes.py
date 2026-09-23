#!/usr/bin/env python3
"""Resolve scene -> background plate BY READING THE REPO, never from a hardcoded map.

A hardcoded table is how BUILD_TAG rotted for a month: it looked authoritative
while being stale. The plate a scene actually draws lives in two places and
both are parsed here, so a plate swap can never silently desynchronise the
blotch detector from the game:

  * main stages   -> `background_path` in src/resources/level_0N_data.tres
  * Blaze Rush    -> the BLAZE_BACKDROPS dict in src/dashmode/blaze_rush.gd

If either lookup fails this raises rather than guessing. A detector comparing a
frame against the WRONG plate reports overlay residual everywhere and sends the
next session hunting a defect that does not exist.
"""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _res(p: str) -> Path:
    return ROOT / p.replace("res://", "")


def stage_plate(level: int) -> Path:
    tres = ROOT / f"src/resources/level_{level:02d}_data.tres"
    m = re.search(r'^background_path\s*=\s*"([^"]+)"', tres.read_text(), re.M)
    if not m:
        raise SystemExit(f"no background_path in {tres}")
    return _res(m.group(1))


def blaze_plate(level: int) -> Path:
    src = (ROOT / "src/dashmode/blaze_rush.gd").read_text()
    block = re.search(r"const BLAZE_BACKDROPS\s*:?=?\s*\{(.*?)\}", src, re.S)
    if not block:
        raise SystemExit("BLAZE_BACKDROPS not found in blaze_rush.gd")
    m = re.search(rf'^\s*{level}\s*:\s*"([^"]+)"', block.group(1), re.M)
    if not m:
        raise SystemExit(f"no BLAZE_BACKDROPS entry for level {level}")
    return _res(m.group(1))


def plate_for(scene: str) -> Path:
    m = re.fullmatch(r"l(\d)_(stage|blaze)", scene)
    if not m:
        raise SystemExit(f"unrecognised scene name: {scene}")
    lvl, kind = int(m.group(1)), m.group(2)
    p = stage_plate(lvl) if kind == "stage" else blaze_plate(lvl)
    if not p.exists():
        raise SystemExit(f"{scene}: plate missing on disk: {p}")
    return p


def all_versions(plate: Path) -> list[str]:
    """Every committed version of a plate, newest first.

    'It is not in the art' is only true of the art the founder is RUNNING,
    which is not necessarily the art in the working tree.
    """
    import subprocess
    rel = plate.relative_to(ROOT)
    out = subprocess.run(["git", "log", "--format=%H", "--", str(rel)],
                         cwd=ROOT, capture_output=True, text=True)
    return [c for c in out.stdout.split() if c]


if __name__ == "__main__":
    for lvl in (1, 2, 3):
        for kind in ("stage", "blaze"):
            s = f"l{lvl}_{kind}"
            p = plate_for(s)
            print(f"{s:9s} -> {p.relative_to(ROOT)}  ({len(all_versions(p))} committed versions)")
