#!/usr/bin/env bash
# Kimi K3 pre-merge GDScript review (task #23 / credit-efficiency directive).
# Pipes changed .gd files to moonshotai/kimi-k3 via OpenRouter and prints a
# focused Godot 4.3 best-practices review. Cheap tokens do the first review
# pass; humans (or the main agent) act on real findings only.
#
# Usage:
#   ./scripts/kimi-review.sh file1.gd [file2.gd ...]
#   ./scripts/kimi-review.sh --changed     # review all .gd changed vs master
#
# Requires OPENROUTER_API_KEY in the environment. Read-only: prints findings,
# never edits files. Exit 0 always (advisory, not a gate) unless the API/key
# is unavailable (exit 1) so callers can tell "no review ran" from "clean".
set -euo pipefail

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "kimi-review: OPENROUTER_API_KEY not set" >&2
  exit 1
fi

MODEL="${KIMI_MODEL:-moonshotai/kimi-k3}"

if [ "${1:-}" = "--changed" ]; then
  mapfile -t FILES < <(git diff --name-only master...HEAD -- '*.gd'; git diff --name-only -- '*.gd'; git ls-files --others --exclude-standard -- '*.gd')
  mapfile -t FILES < <(printf '%s\n' "${FILES[@]}" | sort -u | grep -v '^$' || true)
else
  FILES=("$@")
fi
[ "${#FILES[@]}" -eq 0 ] && { echo "kimi-review: no files"; exit 0; }

SYSTEM="You are a strict Godot 4.3 GDScript reviewer for a 2D platformer web export. Report ONLY genuine defects, each as one line 'file:line — issue — fix'. Focus: (1) web-export compiler traps: ':=' inferring Variant from array-index/.get() results (must type explicitly), lambdas capturing freed nodes, (2) 4.3 API misuse (Godot 4 syntax only, no Godot 3 idioms), (3) leaks: signals connected to freed nodes, timers on freed owners, tweens on freed objects, (4) logic bugs. If a file is clean say 'CLEAN'. No style nits, no praise."

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  echo "=== $f ==="
  # Number the lines so findings can cite real locations. Content travels via
  # exported env (a herestring would collide with the python heredoc's stdin;
  # and `VAR=x CMD=$(...)` prefixes don't reach inside command substitution).
  export REVIEW_CONTENT="$(nl -ba "$f" | head -400)"
  export REVIEW_SYSTEM="$SYSTEM"
  export REVIEW_FILE="$f"
  BODY=$(python3 - <<'EOF'
import json, os
print(json.dumps({
  "model": os.environ.get("KIMI_MODEL", "moonshotai/kimi-k3"),
  "max_tokens": 1800,
  "reasoning": {"effort": "low"},
  "messages": [
    {"role": "system", "content": os.environ["REVIEW_SYSTEM"]},
    {"role": "user", "content": "File: %s\n\n%s" % (os.environ["REVIEW_FILE"], os.environ["REVIEW_CONTENT"])},
  ],
}))
EOF
)
  curl -sS --max-time 120 https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    m=d['choices'][0]['message']
    print((m.get('content') or m.get('reasoning') or '(empty)').strip())
except Exception as e:
    print(f'(kimi-review: no response — {e})')"
  echo
done
