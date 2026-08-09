"""Key the white studio background out of the founder's two logo lockups,
without disturbing the internal white highlights inside the artwork itself.

A global "make near-white transparent" pass would eat into the diamond's own
bright facets and the letters' metallic highlights. This instead floods
OUTWARD from the four image corners across connected near-white pixels only —
so a white speckle fully enclosed by colored art (a highlight inside a letter,
a bright facet inside the diamond) is never reached and stays opaque.

Used for the two founder assets that arrived on a plain white canvas:
  enter_the_blaze_rush.png  (B2 world-info card)
  blaze_diamond_correct.png (B1 token / badge mark)

now_look_smoke_lounge.png (B6) is a full-bleed banner with its own painted
background (space/planets) and needs no keying — copied through as-is.
"""
import sys
from collections import deque
from PIL import Image

WHITE_THRESHOLD = 232  # a pixel counts as "background white" if every channel >= this

def flood_key(src_path: str, dst_path: str) -> None:
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    px = im.load()

    is_bg = [[False] * w for _ in range(h)]
    seen = [[False] * w for _ in range(h)]
    q = deque()

    def maybe_seed(x, y):
        r, g, b, _ = px[x, y]
        if r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD:
            if not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))

    for x in range(w):
        maybe_seed(x, 0)
        maybe_seed(x, h - 1)
    for y in range(h):
        maybe_seed(0, y)
        maybe_seed(w - 1, y)

    while q:
        x, y = q.popleft()
        is_bg[y][x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                r, g, b, _ = px[nx, ny]
                if r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD:
                    seen[ny][nx] = True
                    q.append((nx, ny))

    out = Image.new("RGBA", (w, h))
    opx = out.load()
    for y in range(h):
        row_bg = is_bg[y]
        for x in range(w):
            r, g, b, _ = px[x, y]
            opx[x, y] = (r, g, b, 0) if row_bg[x] else (r, g, b, 255)

    # Anti-alias the cut edge: a hard binary mask leaves a jagged boundary
    # against the game's dark backgrounds. Blur alpha only, one pass.
    a = out.split()[3]
    from PIL import ImageFilter
    a = a.filter(ImageFilter.GaussianBlur(1.0))
    out.putalpha(a)
    out.save(dst_path)

    corners = [a.getpixel(p) for p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]]
    print(f"{dst_path}: {out.size}  corner alpha={corners}")


if __name__ == "__main__":
    flood_key(sys.argv[1], sys.argv[2])
