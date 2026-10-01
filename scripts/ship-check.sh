#!/usr/bin/env bash
# End-of-turn gate (skill always-ship-live). Prints the live itch URL from CI and fails on: uncommitted changes,
# unpushed commits, retired itch slugs still referenced by tracked files. Does NOT replace ship-to-master.sh.
set -u
cd "$(git rev-parse --show-toplevel)"
RETIRED_SLUGS="lil-blunt-adventure"
fail=0
target=$(grep -m1 'ITCH_TARGET:' .github/workflows/export-game.yml | sed 's/.*ITCH_TARGET:[[:space:]]*//; s/:.*//')
slug=${target#*/}; user=${target%/*}
echo "LIVE URL : https://${user}.itch.io/${slug}   (butler target ${target}:html5)"
branch=$(git rev-parse --abbrev-ref HEAD)
if [ -n "$(git status --porcelain --untracked-files=normal | grep -v '^?? .farm/' | grep -v '^?? web_verify/')" ]; then
  echo "✗ uncommitted/untracked files - commit them:"; git status --short | grep -v '\.farm/\|web_verify/' | head -10; fail=1
fi
git fetch -q origin 2>/dev/null
ahead=$(git rev-list --count "origin/${branch}..HEAD" 2>/dev/null || echo 0)
[ "$ahead" != "0" ] && { echo "✗ ${ahead} commit(s) not pushed to origin/${branch}"; fail=1; }
behind=$(git rev-list --count "HEAD..origin/master" 2>/dev/null || echo 0)
[ "$behind" != "0" ] && echo "! ${behind} commit(s) on master not in this branch - ship-to-master.sh will merge them"
notm=$(git rev-list --count "origin/master..HEAD" 2>/dev/null || echo 0)
[ "$notm" != "0" ] && echo "! ${notm} commit(s) not on master yet - run scripts/ship-to-master.sh"
for s in $RETIRED_SLUGS; do
  hits=$(git grep -l "itch.io/${s}|youngstunners88/${s}" -- . ':!docs/founder-prompts' ':!docs/model-responses' ':!CLAUDE.md' ':!scripts/ship-check.sh' ':!.claude/skills/always-ship-live' ':!RELEASE_READY.md' 2>/dev/null)
  if [ -n "$hits" ]; then echo "✗ retired itch slug '${s}' still in:"; echo "$hits" | sed 's/^/    /'; fail=1; fi
done
[ $fail = 0 ] && echo "✓ ship-check clean. Next: scripts/ship-to-master.sh, then PROVE the CI deploy (skill step 5)." || echo "✗ fix the above, then ship."
exit $fail
