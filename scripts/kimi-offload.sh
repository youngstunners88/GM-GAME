#!/usr/bin/env bash
# Hand a coding packet to Kimi K3.1 Pro (moonshotai/kimi-k3.1-pro, 1M context) through scripts/opus-offload.mjs, which applies
# whole files under --allow paths, runs the --verify command YOU pass, and feeds failures back (skill kimi-k31-offload).
#
#   scripts/kimi-offload.sh <task.md> --allow <path>... [--verify "<cmd>"] [--rounds 3] [--max-tokens 160000] [--dry-run]
#
# The OpenRouter key is read from $OPENROUTER_KEY_FILE (default ~/.config/gm-game/openrouter.key, mode 600) into THIS process
# only - never printed, logged or written. Nothing is committed: the session reviews the diff and owns the commit.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
keyfile="${OPENROUTER_KEY_FILE:-$HOME/.config/gm-game/openrouter.key}"
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
	if [ -r "$keyfile" ]; then
		OPENROUTER_API_KEY="$(cat "$keyfile")"
		export OPENROUTER_API_KEY
	elif ! printf '%s\n' "$@" | grep -qx -- '--dry-run'; then
		echo "kimi-offload: no OpenRouter key (set OPENROUTER_API_KEY or create $keyfile)" >&2
		exit 2
	fi
fi
has_max=0
for a in "$@"; do [ "$a" = "--max-tokens" ] && has_max=1; done
extra=()
[ "$has_max" = 1 ] || extra=(--max-tokens 160000)          # Kimi reasons before it answers: leave room for whole files
exec node "$here/opus-offload.mjs" "$@" "${extra[@]}" --model moonshotai/kimi-k3.1-pro
