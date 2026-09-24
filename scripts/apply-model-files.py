#!/usr/bin/env python3
"""Apply `=== FILE: path === ... === END ===` blocks from a delegated-model reply.
Line-based (a regex mis-pairs an empty block with the next file), skips empty
blocks, strips stray ``` fences. Usage: apply-model-files.py <reply.md>"""
import os, re, sys
path, buf, out = None, [], {}
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    m = re.match(r"^=== FILE: (.+?) ===$", line)
    if m:
        path, buf = m.group(1).strip().replace("res://", ""), []
    elif line.strip() == "=== END ===" and path:
        body = "\n".join(l for l in buf if not re.match(r"^```", l)).strip("\n")
        if body:
            out[path] = body + "\n"
        path = None
    elif path:
        buf.append(line)
for p, b in out.items():
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    open(p, "w", encoding="utf-8").write(b)
    print(p, len(b))
