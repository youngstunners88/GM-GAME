#!/usr/bin/env bash
# blotch-hunt.sh — one command: find the live build, capture every scene the
# founder grades, measure it, and grade the detector against his matrix.
#
# Exits non-zero when the detector is NOT calibrated against
# scripts/blotch-oracle.json. That is deliberate and it is the point: five
# previous detectors reported this game clean and were believed because nobody
# ever checked them against a frame the founder had already graded.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${OUT:-artifacts/blotch-matrix}"
URL="${1:-}"

if [ -z "$URL" ]; then
  echo "==> resolving the LIVE itch build (never analyse a local export)"
  URL="$(node scripts/capture-itch-blaze.mjs 2>/dev/null \
         | sed -n 's/^LIVE_BUILD_URL=//p' | head -1)"
fi
if [ -z "$URL" ]; then
  echo "could not resolve the live build URL; pass it as \$1" >&2
  exit 3
fi
echo "LIVE BUILD: $URL"

echo "==> capturing the scene matrix at the founder's window size"
OUT="$OUT" node scripts/blotch-matrix.mjs "$URL"

echo
echo "==> measuring, and grading the detector against the founder's matrix"
set +e
python3 scripts/blotch-analyze.py "$OUT"
rc=$?
set -e

echo
if [ "$rc" -ne 0 ]; then
  cat <<'MSG'
The detector did not reproduce the founder's graded matrix.
Fix the metric before reporting anything. Do not change artwork on these
numbers, and do not tell the founder a scene is clean on them.
MSG
fi
echo "captures: $OUT   build: $URL"
exit "$rc"
