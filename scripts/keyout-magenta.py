"""Key the solid magenta (#FF00FF) chroma-key background out of gpt-image-2
generations, without eating legitimate bright colors inside the art itself.

Corner-flood-fill convention (see founder-art-intake skill / keyout-founder-art.py):
flood from the four image corners across connected near-magenta pixels only, so a
magenta-adjacent pixel fully enclosed by the artwork is never reached. Also applies
mild spill suppression (desaturates a thin magenta-tinted rim at the cutout edge)
since gpt-image-2 renders often leave a faint magenta halo at the silhouette edge.

Usage: python3 scripts/keyout-magenta.py <src.png> <dst.png> [max_size]
"""
import sys
from collections import deque
from PIL import Image

MAGENTA = (255, 0, 255)
TOLERANCE = 60  # euclidean-ish channel tolerance for "counts as background magenta"


def is_magenta(r: int, g: int, b: int) -> bool:
    return (
        abs(r - MAGENTA[0]) <= TOLERANCE
        and abs(g - MAGENTA[1]) <= TOLERANCE
        and abs(b - MAGENTA[2]) <= TOLERANCE
    )


def keyout(src_path: str, dst_path: str, max_size: int = 0) -> None:
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    px = im.load()

    is_bg = [[False] * w for _ in range(h)]
    seen = [[False] * w for _ in range(h)]
    q = deque()

    def maybe_seed(x, y):
        r, g, b, _ = px[x, y]
        if is_magenta(r, g, b) and not seen[y][x]:
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
                if is_magenta(r, g, b):
                    seen[ny][nx] = True
                    q.append((nx, ny))

    # Second pass, tight global key: gaps fully enclosed by the artwork itself
    # (e.g. the sliver of magenta visible under a cart's chassis between the
    # wheels) never touch a border-seeded pixel, so the flood fill above
    # correctly leaves them alone as "maybe interior art". But real cart art
    # (gold/wood/steel) is nowhere near pure magenta in color space, so a
    # tight global tolerance here only ever catches genuine background bleed,
    # never a legitimate highlight.
    TIGHT_TOLERANCE = 35

    out = Image.new("RGBA", (w, h))
    opx = out.load()
    for y in range(h):
        row_bg = is_bg[y]
        for x in range(w):
            r, g, b, a = px[x, y]
            if row_bg[x]:
                opx[x, y] = (0, 0, 0, 0)
                continue
            if (
                abs(r - MAGENTA[0]) <= TIGHT_TOLERANCE
                and abs(g - MAGENTA[1]) <= TIGHT_TOLERANCE
                and abs(b - MAGENTA[2]) <= TIGHT_TOLERANCE
            ):
                opx[x, y] = (0, 0, 0, 0)
                continue
            # Spill suppression: if a non-background pixel is adjacent to a
            # keyed pixel and still carries a magenta tint, pull it toward
            # neutral so no pink rim survives at the silhouette edge.
            neighbors_bg = False
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and is_bg[ny][nx]:
                    neighbors_bg = True
                    break
            if neighbors_bg and r > g + 25 and r > b - 15 and b > g + 15:
                g2 = min(255, int(g + (r - g) * 0.5))
                opx[x, y] = (r, g2, b, a)
            else:
                opx[x, y] = (r, g, b, a)

    if max_size:
        # Trim to the opaque bounding box, then constrain the longer side.
        bbox = out.getbbox()
        if bbox:
            out = out.crop(bbox)
        scale = max_size / max(out.size)
        if scale < 1.0:
            new_size = (max(1, int(out.size[0] * scale)), max(1, int(out.size[1] * scale)))
            out = out.resize(new_size, Image.LANCZOS)

    out.save(dst_path)
    print(f"{src_path} -> {dst_path}  {out.size}")


if __name__ == "__main__":
    src = sys.argv[1]
    dst = sys.argv[2]
    max_size = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    keyout(src, dst, max_size)
