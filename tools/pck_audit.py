#!/usr/bin/env python3
"""WEB PACK BUDGET AUDIT (skill ep2-hyperreal-scene-pipeline lesson 1, docs/pck_budget_doc.md).

  bash scripts/ep2-local-export.sh            # writes .farm/export.log = every file the pck stores (and web_verify/game/index.pck)
  python3 tools/pck_audit.py [--top 30] [--dead]

The CI gate is 190 MiB (199,229,440 bytes) on index.pck. THE LOCAL EXPORT READS ~5 MiB HIGHER THAN CI (stale local imports): the truth for a change is a
branch push - CI prints `index.pck = N MB` in the "Verify export output" step.

What it prints:
  * the packed size by type and by source directory (imported .ctex/.mp3str/.scn sizes, i.e. what the pck really stores, not the source file sizes)
  * --dead: packed assets whose name/stem never appears in any script, scene, json or config, EXCLUDING textures that sit next to a GLB (those are
    referenced from the compressed .scn where a text search cannot see them). It is a CANDIDATE list: names built at run time ("%s_%d") look dead.
    Confirm with a runtime trace or the owner before deleting anything - never delete a founder asset on this list alone.
"""
import argparse
import collections
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(ROOT)
GATE = 190 * 1024 * 1024


def packed_files():
    log = os.path.join(ROOT, ".farm/export.log")
    if not os.path.exists(log):
        sys.exit("no .farm/export.log - run bash scripts/ep2-local-export.sh first")
    out = set()
    for line in open(log, errors="ignore"):
        m = re.search(r"Storing File: res://(.+)$", line.strip())
        if m:
            out.add(m.group(1))
    return out


def imports(packed):
    """(source path, imported bytes) for every packed import sidecar."""
    rows = []
    for imp in glob.glob("src/**/*.import", recursive=True) + glob.glob("assets/**/*.import", recursive=True):
        if imp not in packed:
            continue
        t = open(imp, errors="ignore").read()
        src = re.search(r'source_file="res://(.+?)"', t)
        if not src:
            continue
        dests = set(re.findall(r'"res://(\.godot/imported/[^"]+)"', t))
        sz = sum(os.path.getsize(d) for d in dests if os.path.exists(d))
        rows.append((src.group(1), sz))
    return rows


def text_corpus():
    parts = []
    for pat in ["src/**/*.gd", "src/**/*.tscn", "src/**/*.tres", "src/**/*.json", "src/**/*.cfg", "src/**/*.gdshader", "config.json", "assets/**/*.json",
                "project.godot", "lil-blunt-icp/**/*.gd", "web/*.json", "web/*.js", "tests/**/*.gd"]:
        for f in glob.glob(pat, recursive=True):
            try:
                parts.append(open(f, errors="ignore").read())
            except OSError:
                pass
    return "\n".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--dead", action="store_true", help="list packed assets never referenced by name (candidates only)")
    a = ap.parse_args()
    packed = packed_files()
    rows = imports(packed)
    pck = os.path.join(ROOT, "web_verify/game/index.pck")
    if os.path.exists(pck):
        n = os.path.getsize(pck)
        print("local index.pck %d bytes = %.1f MiB; CI gate %.1f MiB (local reads ~5 MiB above CI)" % (n, n / 1048576, GATE / 1048576))
    tot = sum(s for _, s in rows)
    print("imported sources packed: %d files, %.1f MB\n" % (len(rows), tot / 1e6))
    by_dir, by_ext = collections.Counter(), collections.Counter()
    for p, s in rows:
        by_dir["/".join(p.split("/")[:4])] += s
        by_ext[os.path.splitext(p)[1].lower()] += s
    print("by type:")
    for e, s in by_ext.most_common(10):
        print("  %-7s %7.1f MB" % (e, s / 1e6))
    print("\nby directory:")
    for d, s in by_dir.most_common(a.top):
        print("  %7.2f MB  %s" % (s / 1e6, d))
    print("\nlargest single sources:")
    for p, s in sorted(rows, key=lambda r: -r[1])[:a.top]:
        print("  %7.2f MB  %s" % (s / 1e6, p))
    if not a.dead:
        return
    corpus = text_corpus()
    derived = re.compile(r"(_texture_\d+|_Image_\d+|_normal|_\d+)\.(jpg|png)$")
    dead = []
    for p, s in rows:
        base = os.path.basename(p)
        stem = os.path.splitext(base)[0]
        d = os.path.dirname(p)
        if derived.search(base) and glob.glob(os.path.join(d, "*.glb")):
            continue
        if base.lower().endswith((".jpg", ".png")) and any(base.startswith(os.path.splitext(os.path.basename(g))[0] + "_") for g in glob.glob(os.path.join(d, "*.glb"))):
            continue                                                  # <glb stem>_<image>.jpg: extracted by the GLB importer
        cands = [base, stem]
        s2 = stem
        while len(s2) > 7 and len(cands) < 10:
            s2 = re.sub(r"[_\-]?[0-9]+$", "", s2) if re.search(r"[0-9]$", s2) else s2[:-1]
            cands.append(s2)
        if any(c and c in corpus for c in cands[:2]) or any(len(c) >= 9 and c in corpus for c in cands[2:]):
            continue
        dead.append((s, p))
    dead.sort(reverse=True)
    print("\nCANDIDATES (never referenced by name, GLB-derived textures excluded): %d files, %.2f MB" % (len(dead), sum(s for s, _ in dead) / 1e6))
    bd = collections.Counter()
    for s, p in dead:
        bd["/".join(p.split("/")[:4])] += s
    for d, s in bd.most_common(12):
        print("  %7.2f MB  %s" % (s / 1e6, d))
    print("\ntop candidates (CONFIRM at run time before deleting):")
    for s, p in dead[:a.top]:
        print("  %7.2f MB  %s" % (s / 1e6, p))


if __name__ == "__main__":
    main()
