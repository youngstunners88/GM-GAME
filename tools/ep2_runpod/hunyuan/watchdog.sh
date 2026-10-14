# Hard stop: whatever happens, stop this pod after 50 minutes so it cannot bill unattended.
sleep 3000
echo "WATCHDOG fired $(date)" >> /workspace/watchdog.log
runpodctl stop pod "$RUNPOD_POD_ID" >> /workspace/watchdog.log 2>&1 || runpodctl pod stop "$RUNPOD_POD_ID" >> /workspace/watchdog.log 2>&1
