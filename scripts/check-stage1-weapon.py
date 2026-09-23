#!/usr/bin/env python3
"""The smoke bomb is Lil Blunt's DEFAULT weapon in every stage. Fail the build
if a plain axe can come back.

Founder, repeatedly (2026-09-14, 2026-09-22, 2026-09-23): smoke bombs, not
axes - "i didnt ever mention the axes and you put them in there". The plain
axe survived for weeks as the router's silent `else:` fallthrough, so any stage
that was not 1 or 3 threw it without anyone choosing that.

Invariants checked in src/player/combat_handler.gd `_spawn_projectile`:
  1. the final fallthrough (`else:`) spawns the SMOKE BOMB;
  2. `_spawn_axe` is reachable only when holding the axe/hammer pickup
     (pickaxe/bigaxe) AND outside Stage 1;
  3. the stage comes from `_stage_index()`, which reads the level scene and
     falls back to 1 (smoke bomb), never to an axe.
"""
import re, sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "src/player/combat_handler.gd"

def fail(m):
    print(f"FAIL: {m}"); sys.exit(1)

s = SRC.read_text()
m = re.search(r"func _spawn_projectile\(.*?\).*?\n((?:\t.*\n|\n)+)", s)
if not m: fail("_spawn_projectile not found")
body = m.group(1)

else_m = re.search(r"\telse:\s*\n\t\t(\w+)\(", body)
if not else_m or else_m.group(1) != "_spawn_smoke_bomb":
    fail("the default (else:) throw is not _spawn_smoke_bomb - a plain axe can come back")

axe_line = re.search(r"\t(?:if|elif)\s+([^\n]*):\s*\n\t\t_spawn_axe\(", body)
if not axe_line: fail("_spawn_axe is reachable without a guarding condition")
cond = axe_line.group(1)
if "holding_tool" not in cond or "stage != 1" not in cond:
    fail(f"_spawn_axe guard must require holding_tool and stage != 1, got: {cond}")

st = re.search(r"func _stage_index\(\).*?\n((?:\t.*\n|\n)+)", s)
if not st or "level_data" not in st.group(1) or not re.search(r"return 1\b", st.group(1)):
    fail("_stage_index() must read the level scene and fall back to 1")

print("OK: smoke bomb is the default in every stage; axe only with the "
      "axe/hammer pickup outside Stage 1; stage read from the level.")
