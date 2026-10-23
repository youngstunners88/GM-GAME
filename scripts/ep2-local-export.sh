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
# OPT-IN test-harness build: `GM_HARNESS=1 bash scripts/ep2-local-export.sh` adds the custom feature tag gm_harness, which
# switches on the two probe hooks in src/debug/harness_hooks.gd (?ep2gate=skip, ?bosskill=1). Off by default, so the default
# build stays CI-identical (pack-gate-fresh.sh and ship-to-master call this script). This is the ONLY place the tag is ever
# written; scripts/check-harness-hooks.py fails CI if the CI preset heredoc or export-web.sh ever carries it.
if [ "${GM_HARNESS:-0}" = "1" ]; then
  sed -i 's#custom_features=""#custom_features="gm_harness"#' export_presets.cfg
  grep -q 'custom_features="gm_harness"' export_presets.cfg || { echo "✗ gm_harness tag did not land in the preset"; exit 1; }
  echo "⚠ HARNESS BUILD (custom_features=gm_harness): probe hooks are live. NOT CI-identical - never ship it, never size-gate it."
fi
mkdir -p web_verify/game && rm -f web_verify/game/index.pck
# import with --import, twice: "--editor --quit" can quit before its scan thread finishes ("Scan thread aborted"), leaving
# images unimported -> "No loader found" + an export segfault (fresh-clone gate, 2026-10-19); the 2nd pass imports the textures
# GLB imports extract
timeout 1500 "$G" --headless --path . --import >/dev/null 2>&1 || true
timeout 1200 "$G" --headless --path . --import >/dev/null 2>&1 || true
timeout 900 "$G" --headless --export-release "Web" web_verify/game/index.html > .farm/export.log 2>&1
[ -f web_verify/game/index.pck ] || { echo "✗ export produced no pck — see .farm/export.log"; exit 1; }
cp web/web3.js web_verify/game/ 2>/dev/null || true
timeout 300 "$G" --headless --path . --script tools/ep2_extras/pack_extras.gd -- web_verify/game/ep2_extras.pck > .farm/extras-pack.log 2>&1 || echo "✗ extras pack failed - see .farm/extras-pack.log"
echo "✓ export ok  pck=$(stat -c%s web_verify/game/index.pck)  script_errors=$(grep -cE 'SCRIPT ERROR|Parse Error' .farm/export.log || true)"
curl -s -o /dev/null http://localhost:8899/game/index.html || (node scripts/serve-web.mjs 8899 web_verify >/dev/null 2>&1 &)
sleep 1; echo "  serving http://localhost:8899/game/index.html?ep2=1&ep2probe=1"
