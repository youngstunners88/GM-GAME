#!/usr/bin/env bash
# pack-gate-fresh.sh — measure the web-export .pck the way CI sees it: a FRESH clone of HEAD, no .godot cache, pinned Godot 4.3.
# A warm local cache hides re-extracted/re-imported textures (2026-10-16: local 188 MiB, CI 203 MiB, deploy blocked).
# Fails when index.pck exceeds the CI gate (190 MiB = 199,229,440 bytes). Needs ~4 GB free under $HOME; uses $PACK_GATE_DIR.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
LIMIT=199229440
D="${PACK_GATE_DIR:-$HOME/.cache/gm-pack-gate}"
rm -rf "$D"; mkdir -p "$(dirname "$D")"
git clone -q --no-hardlinks . "$D" && git -C "$D" checkout -q "$(git rev-parse HEAD)" || { echo "✗ clone failed"; exit 2; }
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
[ -x "$G" ] || { echo "✗ pinned Godot missing: scripts/bootstrap-godot.sh"; exit 2; }
mkdir -p "$D/.godot-cache" "$D/.farm"; cp "$G" "$D/.godot-cache/"
( cd "$D" && bash scripts/ep2-local-export.sh > "$D/.farm/pack-gate.log" 2>&1 )
pck="$D/web_verify/game/index.pck"
[ -f "$pck" ] || { echo "✗ fresh export produced no pck (see $D/.farm/pack-gate.log)"; exit 1; }
sz=$(stat -c%s "$pck")
[ "$sz" -gt "$LIMIT" ] && python3 tools/ep2_forge/pck_report.py "$pck" --top 10   # what is big (run from the real repo, not the clone)
rm -rf "$D"
if [ "$sz" -gt "$LIMIT" ]; then echo "✗ fresh-import pck $sz B > gate $LIMIT B (CI would fail: $(( sz / 1048576 )) MiB)"; exit 1; fi
echo "✓ fresh-import pck $sz B (gate $LIMIT, margin $(( LIMIT - sz )) B)"
