#!/usr/bin/env bash
# Release pipeline: push → export (CI) → verify (Playwright) → document
# Usage: ./scripts/release-game.sh
# Outputs: release-{timestamp}.json + game-verify.png

set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TIMESTAMP_FILE=$(date +%s)
RESULT_FILE="release-${TIMESTAMP_FILE}.json"

# Helper to write result JSON
write_result() {
  local status=$1
  local message=$2
  echo "$(cat <<EOF
{
  "status": "${status}",
  "branch": "${BRANCH}",
  "commit": "${COMMIT}",
  "timestamp": "${TIMESTAMP}",
  "message": "${message}",
  "result_file": "${RESULT_FILE}"
}
EOF
)" > "$RESULT_FILE"
  echo "$TIMESTAMP: [$status] $message"
}

echo "=== Lil Blunt Release Pipeline ==="
echo "Branch: $BRANCH"
echo "Commit: $COMMIT"
echo "Timestamp: $TIMESTAMP"
echo ""

# Step 1: Security Sentinel gate (scripts/security-sentinel.sh)
# Single source of truth for the project's automated security checks — this
# used to be 4 inline greps here; they now live in the sentinel script so CI,
# this pipeline, and the game-security-sentinel skill all run identical
# checks instead of three copies that can drift out of sync. Does NOT
# re-litigate docs/security/GAME_SECURITY_CHECKLIST.md's N/A items (no
# backend/DB/auth exists) or the known Vercel-header gap in audit-log.md —
# those need a human/redeploy, not a release block.
echo "[1/6] Security Sentinel..."
if ! ./scripts/security-sentinel.sh --log; then
  write_result "FAIL" "Security Sentinel found blockers. See docs/security/GAME_SECURITY_CHECKLIST.md and fix before releasing."
  exit 5
fi
echo "✓ Security quick-audit passed"

# Step 2: Push with retries
echo "[2/6] Pushing branch..."
for attempt in 1 2 3 4; do
  if git push -u origin "$BRANCH" 2>&1; then
    echo "✓ Push succeeded (attempt $attempt)"
    break
  else
    if [ $attempt -lt 4 ]; then
      delay=$((2 ** (attempt - 1)))
      echo "⚠ Push attempt $attempt failed, retrying in ${delay}s..."
      sleep "$delay"
    else
      write_result "FAIL" "Git push failed after 4 attempts. Check GitHub auth (Settings → GitHub reconnect)."
      exit 1
    fi
  fi
done

# Step 2: Poll CI export
echo "[3/6] Polling GitHub Actions for export workflow..."
max_attempts=30  # 30 * 10s = 5 min timeout
attempt=0
workflow_id=""
export_status=""

while [ $attempt -lt $max_attempts ]; do
  # Query the latest workflow run for export-game.yml on this branch
  runs=$(gh api repos/youngstunners88/gm-game/actions/runs \
    --jq ".workflow_runs[] | select(.head_branch == \"$BRANCH\" and .name == \"Export Godot Game to Web\") | {id, status, conclusion}" \
    2>/dev/null || echo "[]")

  if [ -n "$runs" ] && [ "$runs" != "[]" ]; then
    workflow_id=$(echo "$runs" | jq -r '.id' 2>/dev/null | head -1 || echo "")
    export_status=$(echo "$runs" | jq -r '.status' 2>/dev/null | head -1 || echo "")

    if [ "$export_status" = "completed" ]; then
      conclusion=$(echo "$runs" | jq -r '.conclusion' 2>/dev/null | head -1 || echo "")
      if [ "$conclusion" = "success" ]; then
        echo "✓ Export workflow succeeded (run #$workflow_id)"
        break
      else
        write_result "FAIL" "Export workflow failed (conclusion: $conclusion). Check https://github.com/youngstunners88/gm-game/actions/runs/$workflow_id"
        exit 2
      fi
    fi
  fi

  attempt=$((attempt + 1))
  if [ $attempt -lt $max_attempts ]; then
    echo "  Waiting for export... (attempt $attempt/$max_attempts)"
    sleep 10
  fi
done

if [ $attempt -ge $max_attempts ]; then
  write_result "FAIL" "CI export timed out (5 min). Check https://github.com/youngstunners88/gm-game/actions?query=branch:$BRANCH"
  exit 2
fi

# Step 3: Verify export files exist
echo "[4/6] Verifying export files..."
if [ ! -f "web/game/index.html" ] || [ ! -f "web/game/index.wasm" ] || [ ! -f "web/game/index.pck" ]; then
  write_result "FAIL" "Export files missing. Check web/game/ directory."
  exit 2
fi
echo "✓ Export files present (index.html, index.wasm, index.pck)"

# Step 4: Browser verification (Playwright)
echo "[5/6] Running browser verification..."
if ! npm list @playwright/test > /dev/null 2>&1; then
  echo "  Installing Playwright..."
  npm install -D @playwright/test > /dev/null 2>&1
fi

if ! node scripts/verify-game.mjs "https://lil-blunt-game.vercel.app"; then
  write_result "FAIL" "Browser verification failed. See game-verify-*.json for details."
  exit 3
fi
echo "✓ Browser verification passed (screenshot: game-verify.png)"

# Step 5: Update STATUS.md
echo "[6/6] Updating STATUS.md..."
cat >> STATUS.md <<EOF

### Deployed ($(date -u +%Y-%m-%d))
- Commit: \`$COMMIT\`
- Browser verified: ✅ Level 1 boots, sprites loaded, console clean
- Screenshot: \`game-verify.png\`
- Next: Owner creates itch.io page + adds BUTLER_API_KEY secret for auto-deploy
EOF

git add STATUS.md
git commit -m "docs: release verification complete ($COMMIT)

Browser verified: game boots on Vercel, Level 1 loads, zero console errors.
Screenshot attached. Ready for itch.io deployment (awaiting owner setup).

Co-Authored-By: Claude <noreply@anthropic.com>"

git push -u origin "$BRANCH" || echo "⚠ STATUS.md push failed (non-critical; docs may be ahead of remote)"

# Success
write_result "SUCCESS" "Release complete. Game live at https://lil-blunt-game.vercel.app"
echo ""
echo "✅ RELEASE SUCCESSFUL"
echo "📸 Screenshot: game-verify.png"
echo "📄 Result: $RESULT_FILE"
echo "🎮 Play: https://lil-blunt-game.vercel.app"
echo "🎯 itch.io: https://youngstunners88.itch.io/lil-blunt-adventure (awaiting owner setup)"
echo ""

exit 0
