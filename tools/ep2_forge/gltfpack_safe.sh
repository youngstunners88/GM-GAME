#!/usr/bin/env bash
# gltfpack_safe.sh — shrink a rigged character GLB with meshoptimizer's gltfpack in the ONLY mode Godot 4.3 imports.
#
#   tools/ep2_forge/gltfpack_safe.sh in.glb out.glb [ratio]      (ratio 0..1 = triangle target, default 1 = no simplify)
#
# Verified 2026-10-17 (Godot 4.3.0 import test, Bull 63,565 tris):
#   * gltfpack DEFAULT output uses KHR_mesh_quantization and Godot 4.3 REFUSES it ("required extension ... not supported").
#     So -noq is mandatory. -kn -km keep node/material names.
#   * -noq alone: imported .scn 2.41 -> 2.25 MB (-7%). With -si 0.5: 1.39 MB (-42%), face/bandana/cigar/aviators unchanged in the engine.
#   * gltfpack drops the mesh NAME ("InfernoBull"); this script puts it back.
#   * Without -slb gltfpack PRUNES small disconnected shells (meshopt_SimplifyPrune). The bear is ~870 detached shells
#     (quiver arrows, fur cards): pass BORDERS=lock for the bear so they are kept.
# Needs: gltfpack on PATH (~/.local/bin, built from zeux/meshoptimizer master), pinned Godot 4.3 for the import check.
set -euo pipefail
in="$1"; out="$2"; ratio="${3:-1}"
command -v gltfpack >/dev/null || { echo "gltfpack not on PATH (see docs/episode2-quality/3d-tools-survey-2026-10-17/README.md)"; exit 2; }
args=(-i "$in" -o "$out" -noq -kn -km)
if [ "$ratio" != "1" ]; then
  args+=(-si "$ratio" -sv)
  [ "${BORDERS:-}" = "lock" ] && args+=(-slb)
  # Optional, measured budgets for new founder rigs; existing callers keep their defaults.
  if [ -n "${GLTFPACK_SIMPLIFY_ERROR:-}" ]; then
    python3 - "$GLTFPACK_SIMPLIFY_ERROR" <<'PY'
import sys
assert 0 < float(sys.argv[1]) <= 0.05, "simplification error must be in (0, 0.05]"
PY
    args+=(-se "$GLTFPACK_SIMPLIFY_ERROR")
  fi
  [ "${GLTFPACK_PERMISSIVE:-}" = "1" ] && args+=(-sp)
fi
gltfpack "${args[@]}" 2>&1 | tail -2
python3 - "$in" "$out" <<'PY'
import json, struct, sys
def load(p):
    d = open(p, "rb").read(); n, = struct.unpack_from("<I", d, 12); return d, n, json.loads(d[20:20 + n])
src, _, sj = load(sys.argv[1]); dst, n, dj = load(sys.argv[2])
for sm, dm in zip(sj["meshes"], dj["meshes"]):
    if sm.get("name"): dm["name"] = sm["name"]
js = json.dumps(dj, separators=(",", ":")).encode(); js += b" " * ((-len(js)) % 4)
rest = dst[20 + n:]
out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
open(sys.argv[2], "wb").write(out)
sj_j = [sj["nodes"][i]["name"] for i in sj["skins"][0]["joints"]]; dj_j = [dj["nodes"][i]["name"] for i in dj["skins"][0]["joints"]]
assert sj_j == dj_j, "joint list changed"
assert [a.get("name") for a in sj["animations"]] == [a.get("name") for a in dj["animations"]], "clips changed"
assert not dj.get("extensionsUsed"), f"output needs extensions Godot 4.3 lacks: {dj.get('extensionsUsed')}"
print(f"ok: {len(sj_j)} joints, {len(sj['animations'])} clips, mesh names {[m.get('name') for m in dj['meshes']]}, {len(dst)} B (was {len(src)} B)")
PY
G="${GODOT43:-$(git rev-parse --show-toplevel 2>/dev/null)/.godot-cache/Godot_v4.3-stable_linux.x86_64}"
if [ -x "$G" ]; then
  t=$(mktemp -d); cp "$in" "$t/a.glb"; cp "$out" "$t/b.glb"; printf 'config_version=5\n[application]\nconfig/name="gltfpack-check"\n' > "$t/project.godot"
  timeout 300 "$G" --headless --import --path "$t" 2>&1 | grep -E "^ERROR: GLTF" && { echo "✗ Godot 4.3 cannot import the output"; rm -rf "$t"; exit 1; }
  echo "imported .scn sizes: $(ls -l "$t"/.godot/imported/a.glb-*.scn | awk '{print $5}') B -> $(ls -l "$t"/.godot/imported/b.glb-*.scn | awk '{print $5}') B"
  rm -rf "$t"
fi
echo "NEXT: swap in a COPY, re-shoot the poses (skinned meshes change), run scripts/ci-gates-local.sh, then ship."
