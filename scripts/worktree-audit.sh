#!/usr/bin/env bash
# worktree-audit.sh - read-only report on every git worktree: branch, uncommitted files, commits not on master,
# last commit age and size. Deletes nothing. Skill: worktree-hygiene.
# Usage: scripts/worktree-audit.sh [--no-size]
set -uo pipefail

show_size=1
[ "${1:-}" = "--no-size" ] && show_size=0
git fetch -q origin master 2>/dev/null || echo "(could not fetch: comparing with the last known origin/master)"

printf '%-46s %6s %9s %-14s %7s  %s\n' WORKTREE DIRTY UNMERGED LAST_COMMIT SIZE BRANCH
total=0
candidates=0
while read -r line; do
  case "$line" in
    "worktree "*) path="${line#worktree }" ;;
    "")
      [ -n "${path:-}" ] || continue
      total=$((total + 1))
      if [ ! -d "$path" ]; then
        printf '%-46s %s\n' "$(basename "$path")" "MISSING (git worktree prune would clear this entry)"
        path=""
        continue
      fi
      branch=$(git -C "$path" branch --show-current 2>/dev/null)
      [ -n "$branch" ] || branch="(detached)"
      dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l)
      unmerged=$(git -C "$path" rev-list --count origin/master..HEAD 2>/dev/null || echo "?")
      age=$(git -C "$path" log -1 --format=%cr 2>/dev/null | sed 's/ ago//')
      size="-"
      [ "$show_size" = 1 ] && size=$(du -sh "$path" 2>/dev/null | cut -f1)
      [ "$dirty" = 0 ] && [ "$unmerged" = 0 ] && candidates=$((candidates + 1))
      printf '%-46s %6s %9s %-14s %7s  %s\n' "$(basename "$path" | cut -c1-46)" "$dirty" "$unmerged" "$age" "$size" "$branch"
      path=""
      ;;
  esac
done < <(git worktree list --porcelain; echo)

echo
echo "$total worktree(s); $candidates fully on master with nothing uncommitted (removal candidates: check no session is using them, and ask the founder first)."
echo "This script changes nothing."
