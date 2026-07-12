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

# Step 1: Quick security gate (docs/security/GAME_SECURITY_CHECKLIST.md)
# Blocks the release on real findings (leaked secrets, real wallet/contract
# addresses, threaded-export regression). Does NOT re-litigate the doc's N/A
# items (no backend/DB/auth exists) or the known Vercel-header gap tracked in
# docs/security/audit-log.md — those need a human/redeploy, not a release block.
echo "[1/6] Security quick-audit..."
SECURITY_FAIL=0
SECRET_PATTERN="sk_live|sk_test|AKIA|pk_live"
if grep -rE "$SECRET_PATTERN" web/game src scripts --exclude="release-game.sh" 2>/dev/null; then
  echo "✗ Secret-looking string found in shipped paths"
  SECURITY_FAIL=1
fi
if grep -rEq "0x[a-fA-F0-9]{40}" src/ 2>/dev/null; then
  echo "✗ Hardcoded-looking wallet/contract address found in src/ (CLAUDE.md Global Rules forbid this)"
  SECURITY_FAIL=1
fi
if ! grep -q "thread_support=false" .github/workflows/export-game.yml 2>/dev/null; then
  echo "✗ Web export is not non-threaded — this regresses the itch.io/iframe/mobile boot fix"
  SECURITY_FAIL=1
fi
# Wallet-connect demo was REMOVED entirely 2026-07-12 (owner request). If any
# wallet UI ever returns, it must carry explicit DEMO labeling — so: file
# absent = pass; file present without DEMO labeling = block.
if [ -f src/autoload/web3_manager.gd ] && ! grep -q "DEMO" src/autoload/web3_manager.gd; then
  echo "✗ web3_manager.gd exists without DEMO-mode labeling — wallet UI would imply real functionality"
  SECURITY_FAIL=1
fi
if [ "$SECURITY_FAIL" -ne 0 ]; then
  write_result "FAIL" "Security quick-audit failed. See docs/security/GAME_SECURITY_CHECKLIST.md and fix before releasing."
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
