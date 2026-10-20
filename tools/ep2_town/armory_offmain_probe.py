#!/usr/bin/env python3
"""Measure how far "off Main Street" the Armory really is, from the live layout (stdlib only, no Godot).

Reads LAYOUT / FOOTPRINT / STREET_HALF from src/episode2/chamber/ep2_gold_town.gd, builds each building's
world footprint, then walks eye points down Main Street and casts 2D sight lines at the Armory.

  python3 tools/ep2_town/armory_offmain_probe.py --repo .                      # the layout as committed
  python3 tools/ep2_town/armory_offmain_probe.py --repo . --set Bldg_Armory=-31,1462,1 \
        --add Bldg_A=-31,1440,1 --add Bldg_C=-31,1449,1                          # score a candidate BEFORE editing Godot

--set PIECE=x,z,side replaces a LAYOUT entry; --add PIECE=x,z,side appends a filler (kit pieces repeat, zero new bytes).
Entry meaning matches ep2_gold_town.gd: x = front plane, z = front centre, side 1 faces +x, -1 faces -x, 0 faces -z.

Exit 0 = every check passes, 1 = a check fails, 2 = bad input. The thresholds are PROPOSALS (flags below); the
founder's hard refresh on the live itch page is the only real acceptance. A pass here is necessary, never sufficient.
"""
import argparse
import json
import math
import pathlib
import re
import sys

GD = "src/episode2/chamber/ep2_gold_town.gd"


def const_float(text, name, default):
    m = re.search(r"^const %s\s*:?=\s*(-?[\d.]+)" % name, text, re.M)
    return float(m.group(1)) if m else default


def parse(text):
    half = const_float(text, "STREET_HALF", 9.0)
    town_z = const_float(text, "TOWN_Z", 1400.0)
    lay = re.search(r"const LAYOUT: Array = \[(.*?)^\]", text, re.S | re.M)
    fp = re.search(r"const FOOTPRINT: Dictionary = \{(.*?)^\}", text, re.S | re.M)
    if not lay or not fp:
        raise SystemExit("cannot find LAYOUT / FOOTPRINT in %s" % GD)
    entries = []
    # optional trailing fields (e.g. a "plain" flag) are tolerated, never silently dropping a row
    for m in re.finditer(r'\[\s*"(\w+)"\s*,\s*(-?)\s*([\w.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?\d)\s*(?:,[^\]]*)?\]', lay.group(1)):
        x = half if m.group(3) == "STREET_HALF" else float(m.group(3))
        entries.append([m.group(1), -x if m.group(2) else x, float(m.group(4)), int(m.group(5))])
    foot = {}
    for m in re.finditer(r'"(\w+)"\s*:\s*\[\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\]', fp.group(1)):
        foot[m.group(1)] = [float(m.group(2)), float(m.group(3)), float(m.group(4))]
    return half, town_z, entries, foot


def yaw(side):
    return math.pi * 0.5 if side == 1 else (-math.pi * 0.5 if side == -1 else math.pi)


def to_world(entry, lx, lz):
    """Building-local (x along front, z negative = inside) -> world (x, z). Mirrors Basis(UP, yaw) * p + pos."""
    a = yaw(entry[3])
    c, s = math.cos(a), math.sin(a)
    return (entry[1] + c * lx + s * lz, entry[2] - s * lx + c * lz)


def rect(entry, foot):
    w, d, _ = foot.get(entry[0], [8.0, 9.0, 0.0])
    return [to_world(entry, sx * w * 0.5, sz * -d) for sx, sz in ((-1, 0), (1, 0), (1, 1), (-1, 1))]


def seg_hits_poly(a, b, poly, shrink=0.05):
    cx = sum(p[0] for p in poly) / 4.0
    cz = sum(p[1] for p in poly) / 4.0
    sp = [(cx + (p[0] - cx) * (1 - shrink), cz + (p[1] - cz) * (1 - shrink)) for p in poly]
    for i in range(4):
        if seg_seg(a, b, sp[i], sp[(i + 1) % 4]):
            return True
    return False


def seg_seg(p, q, r, s):
    def o(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    d1, d2, d3, d4 = o(p, q, r), o(p, q, s), o(r, s, p), o(r, s, q)
    return (d1 > 0) != (d2 > 0) and (d3 > 0) != (d4 > 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".")
    ap.add_argument("--piece", default="Bldg_Armory")
    ap.add_argument("--set", action="append", default=[], metavar="PIECE=x,z,side")
    ap.add_argument("--add", action="append", default=[], metavar="PIECE=x,z,side")
    ap.add_argument("--max-los-pct", type=float, default=25.0, help="door+sign visible from at most this %% of Main Street samples")
    ap.add_argument("--min-off-main", type=float, default=20.0, help="door mouth at least this many m from the nearest Main Street front plane")
    ap.add_argument("--max-row-share", type=float, default=3.0, help="front plane within this many m of a Main Street row = same row (fail)")
    ap.add_argument("--min-street-fronts", type=int, default=3, help="a second street needs this many fronts on one line")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    text = (pathlib.Path(a.repo) / GD).read_text(encoding="utf-8", errors="replace")
    half, town_z, entries, foot = parse(text)

    def parse_spec(spec):
        try:
            name, rest = spec.split("=")
            x, z, side = rest.split(",")
            return [name, float(x), float(z), int(side)]
        except ValueError:
            raise SystemExit("bad spec %r (want PIECE=x,z,side)" % spec)

    for spec in a.set:
        e = parse_spec(spec)
        entries = [e if x[0] == e[0] else x for x in entries]
    entries += [parse_spec(s) for s in a.add]

    arm = next((e for e in entries if e[0] == a.piece), None)
    if arm is None:
        print("no %s in LAYOUT" % a.piece, file=sys.stderr)
        return 2
    others = [(e, rect(e, foot)) for e in entries if e is not arm]

    door = to_world(arm, 0.0, 1.0)            # the door mouth, 1 m out, as door_world(piece, 1.0)
    w = foot.get(a.piece, [8.0, 9.0, 0.7])[0]
    sign = [to_world(arm, dx, 1.0) for dx in (-w * 0.35, 0.0, w * 0.35)] + [door]

    # Main Street walk: the centre line and both boardwalks, from the drop point to the end of the walkable town.
    samples = [(x, z) for x in (-6.0, 0.0, 6.0) for z in [town_z + 3 + i for i in range(0, 93)]]
    clear = 0
    first_seen = None
    for ex, ez in samples:
        seen = any(not any(seg_hits_poly((ex, ez), t, poly) for _, poly in others) for t in sign)
        if seen:
            clear += 1
            if first_seen is None or ez < first_seen[1]:
                first_seen = (ex, ez)
    los_pct = 100.0 * clear / len(samples)

    # distance off the Main Street fronts (x = +-STREET_HALF), measured to the door mouth
    off_main = min(abs(door[0] - half), abs(door[0] + half)) if abs(door[0]) > half else 0.0
    main_rows = [e for e in entries if e[3] in (1, -1) and abs(abs(e[1]) - half) < 0.01]
    same_row = abs(arm[1] + half) <= a.max_row_share or abs(arm[1] - half) <= a.max_row_share
    same_row = same_row and arm[3] in (1, -1)

    # a street = a line of fronts: key (side, front plane) for side +-1, (0, front z) for end-of-street fronts
    fronts = {}
    for e in entries:
        key = (e[3], round(e[1]) if e[3] else round(e[2]))
        fronts.setdefault(key, []).append(e[0])
    streets = {"%s@%s" % (k[0], k[1]): v for k, v in fronts.items() if len(v) >= a.min_street_fronts}
    second = [k for k, v in streets.items() if not (k.split("@")[0] in ("1", "-1") and abs(abs(float(k.split("@")[1])) - half) < 1.0)]
    arm_front_key = "%s@%s" % (arm[3], round(arm[1]) if arm[3] else round(arm[2]))
    on_second = arm_front_key in second

    overlap = [e[0] for e, poly in others if any(seg_hits_poly(p, poly[(i + 1) % 4], rect(arm, foot), 0.0)
                                                 for i, p in enumerate(poly))]
    checks = {
        "not_next_storefront (front plane clear of both Main Street rows)": not same_row,
        "door_off_main_front_plane >= %.0f m" % a.min_off_main: off_main >= a.min_off_main,
        "visible_from_main <= %.0f%% of samples" % a.max_los_pct: los_pct <= a.max_los_pct,
        "armory_fronts_a_second_street (>= %d fronts on its line)" % a.min_street_fronts: on_second,
        "no_footprint_overlap": not overlap,
    }
    out = {
        "armory": {"entry": arm, "door_mouth": [round(door[0], 1), round(door[1], 1)]},
        "off_main_m": round(off_main, 1),
        "visible_from_main_pct": round(los_pct, 1),
        "first_seen_from": first_seen,
        "main_street_rows": len(main_rows),
        "streets_with_%d+_fronts" % a.min_street_fronts: streets,
        "overlaps": overlap,
        "checks": checks,
        "pass": all(checks.values()),
        "note": "proposal thresholds; founder hard refresh on the live itch page is the acceptance",
    }
    if a.json:
        print(json.dumps(out, indent=1))
    else:
        print("armory %s  door mouth %s" % (arm, out["armory"]["door_mouth"]))
        print("off Main front plane: %.1f m   visible from Main: %.1f%% of %d samples   first seen from %s" %
              (off_main, los_pct, len(samples), first_seen))
        print("streets with >=%d fronts: %s" % (a.min_street_fronts, streets))
        for k, v in checks.items():
            print("  [%s] %s" % ("PASS" if v else "FAIL", k))
        print("RESULT:", "PASS" if out["pass"] else "FAIL")
    return 0 if out["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
