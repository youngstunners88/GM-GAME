#!/usr/bin/env python3
"""Stage 1 throws SMOKE BOMBS; Stage 2 the axe; Stage 3 the revolver.
Founder 2026-09-23: "The smoke bombs are only for the fucking stage 1!!!"
Checks combat_handler.gd: _spawn_projectile tests _uses_smoke_bombs() FIRST;
_uses_smoke_bombs() is exactly `_stage_index() == 1`; _stage_index() reads the
level scene and falls back to 1."""
import re, sys
from pathlib import Path
s = (Path(__file__).resolve().parent.parent / "src/player/combat_handler.gd").read_text()
def fail(m): print("FAIL:", m); sys.exit(1)
b = re.search(r"func _spawn_projectile\(.*?\).*?\n((?:\t.*\n|\n)+)", s)
if not b: fail("_spawn_projectile missing")
b = b.group(1)
first = re.search(r"\tif\s+([^\n]*):\s*\n\t\t(\w+)\(", b)
if not first or "_uses_smoke_bombs()" not in first.group(1) or first.group(2) != "_spawn_smoke_bomb":
    fail("first branch must be `if _uses_smoke_bombs(): _spawn_smoke_bomb`")
u = re.search(r"func _uses_smoke_bombs\(\).*?\n\treturn (.*)\n", s)
if not u or u.group(1).strip() != "_stage_index() == 1":
    fail("_uses_smoke_bombs() must be exactly `_stage_index() == 1` (Stage 1 ONLY)")
st = re.search(r"func _stage_index\(\).*?\n((?:\t.*\n|\n)+)", s)
if not st or "level_data" not in st.group(1) or not re.search(r"return 1\b", st.group(1)):
    fail("_stage_index() must read the level scene and fall back to 1")
print("OK: smoke bombs Stage 1 only; axe Stage 2; revolver Stage 3; stage read from the level.")
