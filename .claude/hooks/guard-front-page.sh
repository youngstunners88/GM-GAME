#!/bin/bash
# Claude Code PreToolUse hook: FOUNDER-LOCKED FRONT PAGE.
#
# The founder builds in several Claude sessions in parallel. His approved title
# screen must stay exactly as it is "no matter what, unless I dictate otherwise".
# This hook runs in EVERY session that works in this repo (it is registered in
# the committed .claude/settings.json), and puts any change to a locked
# front-page file in front of the founder as a permission prompt. Approving the
# prompt IS the founder dictating otherwise; declining it keeps the page as is.
#
# Guards:
#   - Edit / Write / MultiEdit / NotebookEdit whose target is a locked file
#   - Bash commands that name a locked file AND would write to it (redirect,
#     sed -i, cp/mv/rm, git checkout/restore/rm, a script saving to it, ...).
#     Read-only commands (cat, grep, sha256sum, git diff/log/show) pass freely.
#   - The lock machinery itself (manifest, this hook, the check script), so a
#     session cannot quietly unlock by editing the lock.
#
# The locked set comes from scripts/front-page-lock.sh — one list, shared with
# the CI check. This hook is the in-session layer; the CI check is the backstop
# that catches anything a heuristic misses (e.g. a merge that reverts a file).
#
# Input (stdin JSON): {"tool_name": "...", "tool_input": {...}}
# Output: nothing (allow) or a PreToolUse JSON "ask" decision.

INPUT=$(cat)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

GUARDED=$(bash "$ROOT/scripts/front-page-lock.sh" list 2>/dev/null)
GUARDED="$GUARDED
.claude/locks/front-page.lock
.claude/hooks/guard-front-page.sh
scripts/front-page-lock.sh"

if ! command -v python3 >/dev/null 2>&1; then
    # No python: still guard direct file edits with a plain substring match,
    # never break the session over a missing interpreter.
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if echo "$INPUT" | grep -q "\"file_path\"[^,}]*$p"; then
            printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"FOUNDER-LOCKED FRONT PAGE: %s is part of the founder-approved title screen. Only change it if the founder explicitly asked for this change."}}\n' "$p"
            exit 0
        fi
    done <<< "$GUARDED"
    exit 0
fi

GUARD_INPUT="$INPUT" GUARD_LIST="$GUARDED" GUARD_ROOT="$ROOT" python3 - <<'PY'
import json, os, re, sys

try:
    data = json.loads(os.environ.get("GUARD_INPUT", "") or "{}")
except Exception:
    sys.exit(0)  # unparseable input: never block on our own failure

root = os.environ.get("GUARD_ROOT", "").rstrip("/")
guarded = [p.strip() for p in os.environ.get("GUARD_LIST", "").splitlines() if p.strip()]
tool = data.get("tool_name", "")
ti = data.get("tool_input", {}) or {}

def rel(path):
    path = path or ""
    if root and path.startswith(root + "/"):
        path = path[len(root) + 1:]
    if path.startswith("./"):
        path = path[2:]
    return path

hit = None
if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
    target = rel(ti.get("file_path") or ti.get("notebook_path") or "")
    if target in guarded:
        hit = target
elif tool == "Bash":
    cmd = ti.get("command", "") or ""
    mentioned = [p for p in guarded if p in cmd or os.path.basename(p) in cmd]
    if mentioned:
        writes = re.search(
            r"(\bsed\s+(-[a-zA-Z]*\s+)*-[a-zA-Z]*i|\bperl\s+-[a-zA-Z]*i|\bcp\b|\bmv\b|\brm\b|"
            r"\btee\b|\btruncate\b|\bdd\b|\binstall\b|\bln\b|"
            r"\bgit\s+(checkout|restore|rm|mv|apply|am)\b|"
            r"write_text|write_bytes|\.save\(|open\([^)]*['\"][wa]|unlink|shutil\.)",
            cmd)
        # A redirect is only a write to a locked file if it points AT one;
        # `2>&1` / `>/dev/null` next to a read must not trip the guard.
        redirect = any(
            re.search(r">{1,2}\s*['\"]?[^\s;|&'\"]*" + re.escape(os.path.basename(p)), cmd)
            for p in mentioned)
        if writes or redirect:
            hit = mentioned[0]

if hit:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": (
            "FOUNDER-LOCKED FRONT PAGE: '%s' is part of the founder-approved title "
            "screen. It must stay exactly as it is unless the founder explicitly asked "
            "for this change. Approve only if he did; after an approved change, run "
            "`scripts/front-page-lock.sh update` in the same commit or CI will fail "
            "the build." % hit),
    }}))
PY
exit 0
