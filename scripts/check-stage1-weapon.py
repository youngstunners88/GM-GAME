#!/usr/bin/env python3
"""Stage 1 must throw a SMOKE BOMB. Fail the build if that can regress.

Founder lock, twice: 2026-09-14 ("Lil Blunt does NOT throw axes in Stage 1 —
he only finds the pickaxe after beating the Stage 1 Tax Collector") and again
2026-09-22 ("Lil Blunt is throwing axes in the beginning instead of smoke
bombs ... when I told you to go back to the smoke bombs you ignored me").

Nothing ever deleted the smoke bomb — both times the SOURCE looked correct on
review. The weapon hung off `GameManager.current_level`, a mutable global that
level loading, save loading and level progression all write, read at THROW
time. A stale value silently produced an axe with no code change to blame,
which is exactly why reading the diff never caught it.

So this gate does not check "is the smoke bomb still referenced" — it was, the
whole time. It checks the three properties that make Stage 1 structurally
unable to throw an axe:

  1. the base throw tests the smoke bomb FIRST, before any axe branch;
  2. the stage is resolved from the LEVEL SCENE, not only from the global;
  3. the unknown-stage fallback returns 1, so failure lands on the smoke bomb.
"""
from __future__ import annotations
import re, sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "src/player/combat_handler.gd"


def fail(msg: str) -> None:
    print(f"FAIL: {msg}")
    sys.exit(1)


def main() -> int:
    if not SRC.exists():
        fail(f"{SRC} is missing")
    s = SRC.read_text()

    body = re.search(r"func _spawn_projectile\(.*?\).*?\n((?:\t.*\n|\n)+)", s)
    if not body:
        fail("_spawn_projectile not found — the base throw was restructured")
    b = body.group(1)
    if "_uses_smoke_bombs()" not in b:
        fail("_spawn_projectile no longer routes through _uses_smoke_bombs()")
    if b.index("_uses_smoke_bombs()") > b.index("_spawn_axe"):
        fail("the axe branch is tested BEFORE the smoke bomb — Stage 1 would throw an axe")

    st = re.search(r"func _stage_index\(\).*?\n((?:\t.*\n|\n)+)", s)
    if not st:
        fail("_stage_index() is gone — the stage is back on the mutable global alone")
    st_body = st.group(1)
    if "level_data" not in st_body:
        fail("_stage_index() no longer reads the level scene's level_data")
    if not re.search(r"return 1\b", st_body):
        fail("_stage_index() lost its fallback to 1 — an unknown stage could throw an axe")

    us = re.search(r"func _uses_smoke_bombs\(\).*?\n((?:\t.*\n|\n)+)", s)
    if not us or "_stage_index()" not in us.group(1):
        fail("_uses_smoke_bombs() no longer uses _stage_index()")

    print("OK: Stage 1 routes to the smoke bomb, resolved from the level, "
          "and an unknown stage falls back to Stage 1 (never the axe).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
