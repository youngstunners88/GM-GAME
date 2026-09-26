#!/usr/bin/env bash
# Build the SAME web export CI builds, locally, into web_verify/ (gitignored), and serve it.
#   bash scripts/ep2-local-export.sh            # export + serve on :8899
# Reads the preset heredoc straight out of export-game.yml by searching for it, because
# its line number moves whenever CI changes (a hard-coded line once exported garbage).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
[ -x "$G" ] || bash scripts/bootstrap-godot.sh >/dev/null
L=$(grep -n "cat > export_presets.cfg" .github/workflows/export-game.yml | cut -d: -f1)
awk -v L="$L" 'NR>L && /^          EOF$/{exit} NR>L{sub(/^          /,""); print}' .github/workflows/export-game.yml \
  | sed 's#export_path="web/game/index.html"#export_path="web_verify/game/index.html"#' > export_presets.cfg
grep -q 'thread_support=false' export_presets.cfg || { echo "✗ preset lost thread_support=false"; exit 1; }
mkdir -p web_verify/game && rm -f web_verify/game/index.pck
timeout 600 "$G" --headless --editor --quit >/dev/null 2>&1 || true      # fresh class cache
timeout 900 "$G" --headless --export-release "Web" web_verify/game/index.html > .farm/export.log 2>&1
[ -f web_verify/game/index.pck ] || { echo "✗ export produced no pck — see .farm/export.log"; exit 1; }
cp web/web3.js web_verify/game/ 2>/dev/null || true
echo "✓ export ok  pck=$(stat -c%s web_verify/game/index.pck)  script_errors=$(grep -cE 'SCRIPT ERROR|Parse Error' .farm/export.log || true)"
curl -s -o /dev/null http://localhost:8899/game/index.html || (node scripts/serve-web.mjs 8899 web_verify >/dev/null 2>&1 &)
sleep 1; echo "  serving http://localhost:8899/game/index.html?ep2=1&ep2probe=1"
