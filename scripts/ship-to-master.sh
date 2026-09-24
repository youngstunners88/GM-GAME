#!/usr/bin/env bash
# ship-to-master.sh — put THIS branch's work on master, where the live game builds from.
#
# Why this exists: only master deploys to itch (export-game.yml). Several Claude
# sessions work on separate branches at once, so anything that never reaches master
# is invisible to players. It happened twice in one day: the title screen, then the
# smoke bombs and the Episode 2 runner, each "done" on a branch 100+ commits away
# from master. Merging by hand across sessions also silently dropped work.
#
# What it does, in order, stopping at the first problem:
#   1. refuses if the working tree has uncommitted changes
#   2. merges origin/master INTO this branch (never the reverse), so other sessions'
#      shipped work is kept; on a conflict it aborts cleanly and lists the files
#   3. runs the gates (script compile + security sentinel, or --gates "<cmd>")
#   4. pushes this branch, then FAST-FORWARDS master to it. A fast-forward can only
#      add commits; if another session moved master meanwhile, the push is rejected
#      and we merge again (up to 3 tries). It never force-pushes.
#
# Usage: scripts/ship-to-master.sh [--gates "<shell cmd>"] [--dry-run]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

GATES=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --gates) GATES="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

BR=$(git rev-parse --abbrev-ref HEAD)
if [ "$BR" = "master" ] || [ "$BR" = "main" ]; then
  echo "On $BR already — push it directly."; exit 2
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "✗ Uncommitted changes. Commit (or stash) first:"; git status --short | head -20; exit 2
fi

default_gates() {
  local G=".godot-cache/Godot_v4.3-stable_linux.x86_64"
  if [ -x "$G" ]; then
    timeout 400 "$G" --headless res://tests/script_compile_test.tscn >/tmp/ship_compile.log 2>&1 \
      || { echo "✗ script compile failed"; grep -E "FAIL|SCRIPT ERROR|Parse Error" /tmp/ship_compile.log | head -20; return 1; }
    echo "✓ script compile"
  else
    echo "! Godot not bootstrapped (scripts/bootstrap-godot.sh) — skipping compile; CI still gates it"
  fi
  bash scripts/security-sentinel.sh >/tmp/ship_sentinel.log 2>&1 \
    || { echo "✗ security sentinel"; tail -20 /tmp/ship_sentinel.log; return 1; }
  echo "✓ security sentinel"
}

# Merge a ref into HEAD. Conflicts confined to web/game/ (CI's generated export,
# rebuilt on every run) resolve to the incoming side; any other conflict aborts.
merge_ref() {
  local ref="$1"
  git rev-parse -q --verify "$ref" >/dev/null || return 0
  local n; n=$(git rev-list --count "HEAD..$ref")
  [ "$n" -eq 0 ] && return 0
  echo "→ merging $n commit(s) from $ref"
  if git merge --no-edit -q "$ref" 2>/dev/null; then return 0; fi
  local bad; bad=$(git diff --name-only --diff-filter=U | grep -v '^web/game/' || true)
  if [ -z "$bad" ]; then
    git diff --name-only --diff-filter=U | xargs -r git checkout --theirs -- 
    git diff --name-only --diff-filter=U | xargs -r git add --
    git commit -q --no-edit
    echo "  (web/game/ conflicts taken from $ref — CI regenerates them)"
    return 0
  fi
  echo "✗ Merge conflict with $ref. Aborted — nothing was pushed. Conflicting files:"
  echo "$bad"
  git merge --abort
  echo "Resolve with: git merge $ref  (keep BOTH sides' features), commit, re-run this."
  exit 3
}

for attempt in 1 2 3; do
  git fetch -q origin master 2>/dev/null
  git fetch -q origin "$BR" 2>/dev/null || true
  merge_ref "origin/$BR"      # CI's export commits land on the branch too
  merge_ref "origin/master"
  if [ -n "$GATES" ]; then bash -c "$GATES" || { echo "✗ gates failed — not shipping"; exit 4; }
  else default_gates || { echo "✗ gates failed — not shipping"; exit 4; }; fi

  ahead=$(git rev-list --count origin/master..HEAD)
  if [ "$ahead" -eq 0 ]; then echo "✓ master already has everything on $BR"; exit 0; fi
  if [ "$DRY" -eq 1 ]; then echo "(dry run) would push $BR and fast-forward master by $ahead commit(s)"; exit 0; fi

  git push -q -u origin "$BR"
  if git push -q origin "HEAD:master"; then
    echo "✓ master fast-forwarded to $(git rev-parse --short HEAD) (+$ahead commits). CI will export and deploy it."
    echo "  Live build tag to look for: BUILD <date>-$(git rev-parse --short HEAD) (after CI's own export commit)."
    exit 0
  fi
  echo "… master moved while shipping (another session). Retrying ($attempt/3)."
done
echo "✗ master kept moving — gave up after 3 tries. Re-run shortly."; exit 5
