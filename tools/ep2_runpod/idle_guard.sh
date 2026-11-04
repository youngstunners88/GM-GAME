#!/usr/bin/env bash
# idle_guard.sh - runs inside the pod (tmux session "guard", started by gate_pod.sh setup). A dead agent session must not leave a pod
# billing: after IDLE_MIN minutes with no gate_pod.sh activity and no Godot running, the pod stops itself. Stop keeps /workspace.
IDLE_MIN="${IDLE_MIN:-45}"
touch /workspace/.active
. /etc/rp_environment 2>/dev/null
while sleep 60; do
	pgrep -f Godot_v4 >/dev/null && touch /workspace/.active
	age=$(( ( $(date +%s) - $(stat -c %Y /workspace/.active) ) / 60 ))
	if [ "$age" -ge "$IDLE_MIN" ]; then
		echo "$(date -u) idle ${age} min: stopping pod ${RUNPOD_POD_ID:-?}" >> /workspace/guard.log
		runpodctl stop pod "$RUNPOD_POD_ID" >> /workspace/guard.log 2>&1
		sleep 300
	fi
done
