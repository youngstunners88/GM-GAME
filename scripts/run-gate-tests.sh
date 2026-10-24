#!/usr/bin/env bash
# run-gate-tests.sh - run named headless test scenes one by one, each with a FRESH user dir (XDG_DATA_HOME) and a timeout,
# and print one row per test:  name|rc=N|Ns|fail_lines=N|script_err=N|<its "NAME: ALL PASS" result line>
# Use it to confirm a test passes before you list it in scripts/ci-new-gates.txt (the shared user save on a dev machine is
# polluted by other sessions' tests and can hang level tests; a test scene whose script fails to parse hangs, hence timeout).
#   bash scripts/run-gate-tests.sh <outdir> <test name without .tscn> [...]       GATE_TIMEOUT=420 (seconds) by default
# Never run it concurrently with `--import` / `--export` (wrap those in `flock -o /tmp/gm-godot.lock`; -o keeps the lock
# off any server the command starts). Logs: <outdir>/<test>.log
set -u
OUT=${1:?usage: run-gate-tests.sh <outdir> <test> [...]}; shift
mkdir -p "$OUT"
cd "$(git rev-parse --show-toplevel)"
G="${GODOT_BIN:-.godot-cache/Godot_v4.3-stable_linux.x86_64}"
for t in "$@"; do
  f=tests/$t.tscn
  [ -f "$f" ] || { echo "$t|MISSING|-|-|-|-"; continue; }
  s=$(date +%s)
  XDG_DATA_HOME=$(mktemp -d) timeout "${GATE_TIMEOUT:-420}" "$G" --headless --path . "res://$f" > "$OUT/$t.log" 2>&1
  rc=$?
  e=$(( $(date +%s) - s ))
  res=$(grep -E '^[A-Z0-9_]+: (ALL PASS|[0-9]+ FAIL|FAIL)' "$OUT/$t.log" | tail -1)
  nf=$(grep -cE '\[FAIL\]' "$OUT/$t.log")
  ne=$(grep -cE 'SCRIPT ERROR|Parse Error' "$OUT/$t.log")
  echo "$t|rc=$rc|${e}s|fail_lines=$nf|script_err=$ne|${res:-NO RESULT LINE}"
done
