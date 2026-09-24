#!/bin/bash
# Claude Code SessionStart hook: Load project context at session start
# Outputs context information that Claude sees when a session begins
#
# Input schema (SessionStart): No stdin input

echo "=== Claude Code Game Studios — Session Context ==="

# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "Branch: $BRANCH"

    # Recent commits
    echo ""
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# Current sprint (find most recent sprint file)
LATEST_SPRINT=$(ls -t production/sprints/sprint-*.md 2>/dev/null | head -1)
if [ -n "$LATEST_SPRINT" ]; then
    echo ""
    echo "Active sprint: $(basename "$LATEST_SPRINT" .md)"
fi

# Current milestone
LATEST_MILESTONE=$(ls -t production/milestones/*.md 2>/dev/null | head -1)
if [ -n "$LATEST_MILESTONE" ]; then
    echo "Active milestone: $(basename "$LATEST_MILESTONE" .md)"
fi

# Open bug count
BUG_COUNT=0
for dir in tests/playtest production; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "BUG-*.md" 2>/dev/null | wc -l)
        BUG_COUNT=$((BUG_COUNT + count))
    fi
done
if [ "$BUG_COUNT" -gt 0 ]; then
    echo "Open bugs: $BUG_COUNT"
fi

# Code health quick check
if [ -d "src" ]; then
    TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l)
    FIXME_COUNT=$(grep -r "FIXME" src/ 2>/dev/null | wc -l)
    if [ "$TODO_COUNT" -gt 0 ] || [ "$FIXME_COUNT" -gt 0 ]; then
        echo ""
        echo "Code health: ${TODO_COUNT} TODOs, ${FIXME_COUNT} FIXMEs in src/"
    fi
fi

# --- Active session state recovery ---
STATE_FILE="production/session-state/active.md"
if [ -f "$STATE_FILE" ]; then
    echo ""
    echo "=== ACTIVE SESSION STATE DETECTED ==="
    echo "A previous session left state at: $STATE_FILE"
    echo "Read this file to recover context and continue where you left off."
    echo ""
    echo "Quick summary (last 20 lines):"
    tail -20 "$STATE_FILE" 2>/dev/null
    TOTAL_LINES=$(wc -l < "$STATE_FILE" 2>/dev/null)
    if [ "$TOTAL_LINES" -gt 20 ]; then
        echo "  ... ($TOTAL_LINES total lines — read the full file to continue)"
    fi
    echo "=== END SESSION STATE PREVIEW ==="
fi


# --- Parallel-session drift check ------------------------------------------------
# Only master deploys. Several sessions work on separate branches, so show how far
# this branch is from master and whether it holds work players can't see yet.
BR_NOW=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BR_NOW" ] && [ "$BR_NOW" != "master" ] && [ "$BR_NOW" != "main" ]; then
    timeout 4 git fetch -q origin master 2>/dev/null
    if git rev-parse -q --verify origin/master >/dev/null 2>&1; then
        BEHIND=$(git rev-list --count HEAD..origin/master 2>/dev/null)
        AHEAD=$(git rev-list --count origin/master..HEAD 2>/dev/null)
        echo ""
        echo "=== LIVE-BUILD CHECK: only master deploys ==="
        echo "  $BR_NOW is $BEHIND behind master, $AHEAD commit(s) not on master."
        [ "${BEHIND:-0}" -gt 0 ] && echo "  → Merge first: git merge origin/master   (other sessions shipped work)"
        [ "${AHEAD:-0}" -gt 0 ] && echo "  → Not live until shipped: scripts/ship-to-master.sh"
    fi
fi

echo "==================================="
exit 0
