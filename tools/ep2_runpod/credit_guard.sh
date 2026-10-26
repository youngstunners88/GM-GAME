#!/usr/bin/env bash
# CREDIT GUARD - runs INSIDE a Runpod pod (founder 2026-10-27: "if you know that we are going to die from credits then turn off
# runpod just before that happens"). Skill runpod-credit-guard.
#
#   nohup bash /workspace/credit_guard.sh <max_hours> <min_balance_usd> > /dev/null 2>&1 &
#
# Every 5 minutes: stop this pod when it has run <max_hours>, or when the account balance (GraphQL myself.clientBalance, read with
# the pod's own injected RUNPOD_API_KEY) is below <min_balance_usd> plus 30 minutes of the current spend rate. If the balance cannot
# be read, the runtime cap alone holds. Stopping keeps /workspace (the volume); keep every result there. Logs to
# /workspace/credit_guard.log (no secrets).
set -u
max_hours="${1:-3}"
min_balance="${2:-3}"
log=/workspace/credit_guard.log
start=$(date +%s)
pod="${RUNPOD_POD_ID:-}"

stop_pod() {
	echo "$(date -u +%FT%TZ) STOP: $1" >> "$log"
	runpodctl stop pod "$pod" >> "$log" 2>&1 || runpodctl pod stop "$pod" >> "$log" 2>&1
	exit 0
}

echo "$(date -u +%FT%TZ) guard up: pod=$pod max_hours=$max_hours min_balance=$min_balance" >> "$log"
while true; do
	now=$(date +%s)
	ran=$(( now - start ))
	if [ "$ran" -ge "$(python3 -c "print(int(float('$max_hours') * 3600))")" ]; then
		stop_pod "runtime cap ${max_hours} h reached"
	fi
	if [ -n "${RUNPOD_API_KEY:-}" ]; then
		resp=$(curl -s --max-time 20 https://api.runpod.io/graphql -H "content-type: application/json" \
			-H "Authorization: Bearer $RUNPOD_API_KEY" -d '{"query":"query { myself { clientBalance currentSpendPerHr } }"}' 2>/dev/null)
		read -r bal rate < <(python3 -c "
import json, sys
try:
    m = json.loads(sys.argv[1])['data']['myself']
    print(float(m['clientBalance']), float(m.get('currentSpendPerHr') or 0))
except Exception:
    print('nan', 'nan')
" "$resp")
		if [ "$bal" != "nan" ]; then
			echo "$(date -u +%FT%TZ) balance=\$$bal spend=\$$rate/h ran=$((ran / 60))min" >> "$log"
			if python3 -c "import sys; b, r, m = map(float, sys.argv[1:]); sys.exit(0 if b < m + r * 0.5 else 1)" "$bal" "$rate" "$min_balance"; then
				stop_pod "balance \$$bal under \$$min_balance + 30 min of spend"
			fi
		else
			echo "$(date -u +%FT%TZ) balance unavailable (runtime cap only) ran=$((ran / 60))min" >> "$log"
		fi
	fi
	sleep 300
done
