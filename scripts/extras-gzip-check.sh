#!/usr/bin/env bash
# Prove the streamed Episode 2 extras load under itch's CDN behaviour (gzip + compressed Content-Length), BEFORE shipping.
#   bash scripts/extras-gzip-check.sh            # needs web_verify/game from scripts/ep2-local-export.sh
# Serves web_verify/ through tools/ep2_extras/gzip_server.py and runs scripts/live-itch-probe.mjs --extras against it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[ -f web_verify/game/index.pck ] && [ -f web_verify/game/ep2_extras.pck ] || { echo "✗ run scripts/ep2-local-export.sh first"; exit 1; }
PORT=${PORT:-8941}
python3 tools/ep2_extras/gzip_server.py web_verify "$PORT" & SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
sleep 1
node scripts/live-itch-probe.mjs --url "http://127.0.0.1:$PORT/game/index.html" --extras
