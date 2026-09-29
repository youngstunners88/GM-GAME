#!/usr/bin/env python3
"""Reference-match board + rubric grade (skill: ep2-reference-match-loop).

  python3 scripts/ref_compare.py <founder_reference.jpg> <game_capture.png> <out_board.jpg>
        [--grade [MODEL]] [--rubric-file rubric.md] [--label-ref "TARGET"] [--label-cap "GAME"]

Builds ONE labelled board: reference on the left, the in-game capture on the right, both
scaled to the same height. With --grade, sends the board to a vision model through
scripts/or-call.mjs (default deepseek/deepseek-v4.1-flash, ~$0.001) with the founder's
checklist and writes <out_board>.grade.md. The grade is a LEAD, never a verdict: Claude
still looks at the board itself (CLAUDE.md MODEL ROLE SPLIT), and every 'fail' becomes a fix
or a test.

Why this exists: on 2026-09-29 the founder said "Lil Blunt looks like a deformed creature ...
he doesn't even have his golden revolver nor his pick axe" after a build where every test was
green and the assets 'loaded'. The gates checked that files existed, not that the picture
matched the picture he had handed over.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]

DEFAULT_RUBRIC = """You are grading a GAME SCREENSHOT (right half) against the FOUNDER'S TARGET (left half) for
'Lil Blunt Adventure — Episode 2, a 3D gold-mine mine-cart runner'. Judge the RIGHT half only,
using the left as the standard. Answer ONLY as a markdown table, one row per item, columns:
item | verdict (PASS / PARTIAL / FAIL) | one-line evidence. Then '## Top 3 fixes' (most important first).

Items:
1. Lil Blunt is clearly visible and reads as the target character (leafy green body, cowboy hat, leather vest) - NOT deformed, not a blob, not hidden in the cart.
2. His golden revolver is visible in one hand.
3. His pickaxe is visible in the other hand.
4. The cart under him is the leaf-emblem wooden ore cart on shiny bolted rails.
5. Coins (if any are visible) are solid gold Bitcoin discs - no translucent halo, no filter, no flat cut-out look.
6. Bear archers (if visible) are furry bears with helmets, bows and arrows - readable at a glance.
7. The tunnel matches the target: dark faceted rock with GLOWING AMBER gold crystals, thick timber posts with iron brackets, hanging lanterns.
8. Overall lighting is warm amber and bright enough to read the scene (not muddy or dark brown).
9. HUD / call-outs do not hide the hero or the action.
"""


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def board(ref: Path, cap: Path, out: Path, lref: str, lcap: str, h: int = 720) -> None:
    a = Image.open(ref).convert("RGB")
    b = Image.open(cap).convert("RGB")
    a = a.resize((int(a.width * h / a.height), h), Image.LANCZOS)
    b = b.resize((int(b.width * h / b.height), h), Image.LANCZOS)
    pad = 36
    g = Image.new("RGB", (a.width + b.width + 12, h + pad), (20, 18, 16))
    g.paste(a, (0, pad))
    g.paste(b, (a.width + 12, pad))
    d = ImageDraw.Draw(g)
    d.text((10, 6), lref, fill=(255, 215, 120), font=font(22))
    d.text((a.width + 22, 6), lcap, fill=(140, 220, 255), font=font(22))
    out.parent.mkdir(parents=True, exist_ok=True)
    g.save(out, quality=90)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("reference")
    ap.add_argument("capture")
    ap.add_argument("out")
    ap.add_argument("--grade", nargs="?", const="deepseek/deepseek-v4.1-flash", default=None)
    ap.add_argument("--rubric-file", default="")
    ap.add_argument("--label-ref", default="FOUNDER TARGET")
    ap.add_argument("--label-cap", default="GAME (real web build)")
    a = ap.parse_args()
    out = Path(a.out)
    board(Path(a.reference), Path(a.capture), out, a.label_ref, a.label_cap)
    print(f"board -> {out}")
    if a.grade:
        rubric = Path(a.rubric_file).read_text() if a.rubric_file else DEFAULT_RUBRIC
        prompt = out.with_suffix(".rubric.md")
        prompt.write_text(rubric)
        grade = out.with_suffix(".grade.md")
        r = subprocess.run(["node", "scripts/or-call.mjs", a.grade, str(prompt), str(grade), "--image", str(out)],
                           cwd=ROOT, capture_output=True, text=True)
        if r.returncode != 0:
            print("grade failed:", (r.stdout + r.stderr)[-300:])
            return 1
        print(f"grade -> {grade}")
        print(grade.read_text()[:1800])
    return 0


if __name__ == "__main__":
    sys.exit(main())
