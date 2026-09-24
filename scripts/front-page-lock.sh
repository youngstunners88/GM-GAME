#!/bin/bash
# Front-page lock — the founder-approved title screen must not change unless the
# founder explicitly says so.
#
# WHY THIS EXISTS: the founder builds in several Claude sessions in parallel.
# On 2026-09-23 his new title screen vanished from the live game because another
# session's branch, which did not have it, deployed over it. Master-only deploys
# (export-game.yml) stop branches overwriting the live page; this lock stops the
# title screen itself being changed or reverted by any session or merge.
#
# The locked files and their SHA-512 fingerprints live in
# .claude/locks/front-page.lock (plain `sha512sum` format). Three layers use it:
#   1. .claude/hooks/guard-front-page.sh — every Claude session on this repo must
#      get the founder's approval (a permission prompt) before touching them.
#   2. `check` below, run by CI on every push — any drift fails the build, and on
#      master a failed build means no deploy, so a changed title screen cannot
#      reach players.
#   3. CLAUDE.md — the written rule every session reads at start.
#
# Usage:
#   scripts/front-page-lock.sh check    # exit 1 if any locked file changed
#   scripts/front-page-lock.sh update   # re-fingerprint — ONLY after the founder
#                                       # has explicitly approved a front-page change
#   scripts/front-page-lock.sh list     # print the locked paths

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/.claude/locks/front-page.lock"

# The locked set. Adding or removing a file here is itself a front-page change.
LOCKED_FILES=(
  "src/ui/main_menu.gd"
  "src/ui/main_menu.tscn"
  "src/assets/backgrounds/bg_menu_gm_keyart.jpg"
  "src/assets/music/menu_mist_theme.mp3"
  "src/assets/shaders/title_smoke_flow.gdshader"
)

# SHA-512, deliberately not SHA-256: the security sentinel's SEC-005 flags any
# 64-hex-character literal as a possible leaked private key (the 2026-07-12
# incident). A SHA-256 manifest is exactly that shape and would need a new
# exclusion in the security gate. SHA-512 fingerprints are 128 hex characters,
# which SEC-005 does not match, so the lock needs no loosening of the gate at
# all. Do not "simplify" this back to sha256sum.
HASH=sha512sum

cmd="${1:-check}"
cd "$ROOT" || exit 2

case "$cmd" in
  list)
    printf '%s\n' "${LOCKED_FILES[@]}"
    ;;
  update)
    mkdir -p "$(dirname "$LOCK")"
    for f in "${LOCKED_FILES[@]}"; do
      if [ ! -f "$f" ]; then
        echo "front-page-lock: locked file missing, refusing to write lock: $f" >&2
        exit 1
      fi
    done
    "$HASH" "${LOCKED_FILES[@]}" > "$LOCK"
    echo "front-page-lock: fingerprinted ${#LOCKED_FILES[@]} files -> .claude/locks/front-page.lock"
    ;;
  check)
    if [ ! -f "$LOCK" ]; then
      echo "::error::front-page lock manifest missing (.claude/locks/front-page.lock)"
      exit 1
    fi
    if out=$("$HASH" -c --quiet "$LOCK" 2>&1); then
      echo "FRONT-PAGE LOCK: OK — founder-approved title screen unchanged (${#LOCKED_FILES[@]} files)"
      exit 0
    fi
    echo "::error::FRONT-PAGE LOCK: the founder-approved title screen was changed."
    echo "$out"
    echo
    echo "These files are locked by the founder. They may only change when he"
    echo "explicitly asks for it. If he did, re-fingerprint in the SAME commit:"
    echo "    scripts/front-page-lock.sh update"
    echo "Otherwise restore them from master:"
    echo "    git checkout origin/master -- \$(scripts/front-page-lock.sh list)"
    exit 1
    ;;
  *)
    echo "usage: $0 {check|update|list}" >&2
    exit 2
    ;;
esac
