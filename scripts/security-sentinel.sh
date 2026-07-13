#!/usr/bin/env bash
# Security Sentinel — autonomous vulnerability scanner for Lil Blunt Adventure.
#
# This is the game-specific, runnable implementation behind the
# `game-security-sentinel` skill (.claude/skills/game-security-sentinel/).
# It is the single source of truth for the project's automated security
# checks — release-game.sh Step 1 and CI both call THIS script instead of
# duplicating grep logic inline.
#
# Adapted from an uploaded generic "secure-build-checklist" (SaaS/Supabase/
# npm-focused: RLS, webhooks, rate limiting, ToS/PP). This game has none of
# that surface (see docs/security/GAME_SECURITY_CHECKLIST.md for the full
# category-by-category adaptation rationale). What's ported here is the
# categories that DO translate to a client-only Godot/GDScript project, plus
# every game-specific control this project has needed so far — including the
# SEC-005 check added directly because of the 2026-07-12 leaked-key incident
# (the OLD wallet-address regex only matched 40-hex-char addresses; the two
# real leaked keys were 64-hex-char private keys, a shape it never checked).
#
# Usage:
#   ./scripts/security-sentinel.sh                 human-readable report
#   ./scripts/security-sentinel.sh --json           machine-readable report
#   ./scripts/security-sentinel.sh --fail-on=medium stricter gate (default: high)
#   ./scripts/security-sentinel.sh --log            append a dated entry to
#                                                    docs/security/audit-log.md
#
# Exit codes: 0 = no blockers at the fail-on threshold. 1 = blockers found.

set -uo pipefail
cd "$(dirname "$0")/.."

JSON=0
LOG=0
FAIL_ON="high"
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --log) LOG=1 ;;
    --fail-on=*) FAIL_ON="${arg#--fail-on=}" ;;
  esac
done

# severity rank: lower = more severe. A check "blocks" if its rank <= threshold rank.
sev_rank() { case "$1" in critical) echo 0;; high) echo 1;; medium) echo 2;; low) echo 3;; esac; }
THRESHOLD_RANK=$(sev_rank "$FAIL_ON")

RESULTS=()   # "id|severity|status|title|evidence"
BLOCKERS=0

record() {
  local id="$1" severity="$2" status="$3" title="$4" evidence="$5"
  RESULTS+=("${id}|${severity}|${status}|${title}|${evidence}")
  if [ "$status" = "FAIL" ]; then
    local rank; rank=$(sev_rank "$severity")
    if [ "$rank" -le "$THRESHOLD_RANK" ]; then
      BLOCKERS=$((BLOCKERS + 1))
    fi
  fi
}

# ---------------------------------------------------------------------------
# CATEGORY: Secrets & Credentials
# ---------------------------------------------------------------------------

# SEC-001: broadened secret-pattern sweep — the release-game.sh quick gate
# only ever checked 4 literal prefixes (sk_live/sk_test/AKIA/pk_live). This
# adds generic key=value secret assignments and PEM private-key headers,
# excluding this script and known compiled-binary paths.
SECRET_PATTERN='sk_live|sk_test|AKIA[0-9A-Z]{16}|pk_live|-----BEGIN [A-Z ]*PRIVATE KEY-----|(api[_-]?key|secret|password|token)["'"'"']?\s*[:=]\s*["'"'"'][A-Za-z0-9+/_-]{20,}["'"'"']'
hits=$(grep -rEn "$SECRET_PATTERN" web/game src scripts .github 2>/dev/null \
  --exclude="security-sentinel.sh" --exclude="release-game.sh" --exclude-dir=".git" \
  --exclude="*.wasm" --exclude="*.pck" | head -10)
if [ -n "$hits" ]; then
  record "SEC-001" "critical" "FAIL" "No secret-looking strings in shipped paths" "$hits"
else
  record "SEC-001" "critical" "PASS" "No secret-looking strings in shipped paths" "clean"
fi

# SEC-002: .env is gitignored
if grep -qE '^\.env($|\*|\.)' .gitignore 2>/dev/null; then
  record "SEC-002" "critical" "PASS" ".env gitignored" "present in .gitignore"
else
  record "SEC-002" "critical" "FAIL" ".env gitignored" ".env pattern missing from .gitignore"
fi

# SEC-003: .env never committed to git history
env_hist=$(git log --all --diff-filter=A --name-only --pretty=format: -- '.env' '.env.local' '.env.production' 2>/dev/null | grep -v '^$' || true)
if [ -z "$env_hist" ]; then
  record "SEC-003" "critical" "PASS" ".env never committed" "clean history"
else
  record "SEC-003" "critical" "FAIL" ".env never committed" "$env_hist"
fi

# SEC-004: no hardcoded wallet/contract addresses (40-hex) — CLAUDE.md Global Rule
addr_hits=$(grep -rEn "0x[a-fA-F0-9]{40}" src/ 2>/dev/null | grep -v "DEMO_ADDRESS\|0xDEMO" || true)
if [ -z "$addr_hits" ]; then
  record "SEC-004" "critical" "PASS" "No hardcoded wallet/contract addresses (40-hex)" "clean"
else
  record "SEC-004" "critical" "FAIL" "No hardcoded wallet/contract addresses (40-hex)" "$addr_hits"
fi

# SEC-005: no raw private-key-shaped hex (64-hex) anywhere in TRACKED source.
# This is the exact pattern the 2026-07-12 incident revealed as a blind spot —
# SEC-004's 40-char regex cannot catch a 64-char private key. Scans the
# working tree (not history — that's gitleaks' + CI's job) so a fresh leak
# is caught before the next commit, not after.
# Excludes export-game.yml: it legitimately pins Godot/butler release
# checksums as 64-hex SHA256 strings (audited supply-chain pins, not keys —
# see DEP-004). A genuinely new 64-hex literal anywhere else still fails.
key_hits=$(git ls-files | xargs grep -lEn "\b(0x)?[a-fA-F0-9]{64}\b" 2>/dev/null \
  | grep -vE "\.(wasm|pck|png|jpg|jpeg|ogg|import)$" \
  | grep -v "\.github/workflows/export-game\.yml" || true)
if [ -z "$key_hits" ]; then
  record "SEC-005" "critical" "PASS" "No 64-hex private-key-shaped literals in tracked source" "clean"
else
  record "SEC-005" "critical" "FAIL" "No 64-hex private-key-shaped literals in tracked source" "$key_hits"
fi

# ---------------------------------------------------------------------------
# CATEGORY: Dynamic Execution / Injection (GDScript RCE-equivalents)
# ---------------------------------------------------------------------------

# INJ-001: no OS.execute() — the GDScript equivalent of shell/command injection
exec_hits=$(grep -rn "OS\.execute" src/ 2>/dev/null || true)
if [ -z "$exec_hits" ]; then
  record "INJ-001" "critical" "PASS" "No OS.execute() in game code" "clean"
else
  record "INJ-001" "critical" "FAIL" "No OS.execute() in game code" "$exec_hits"
fi

# INJ-002: no dynamic GDScript code execution (Expression class = GDScript's eval)
expr_hits=$(grep -rn "Expression\.new\|class Expression" src/ 2>/dev/null || true)
if [ -z "$expr_hits" ]; then
  record "INJ-002" "critical" "PASS" "No Expression (dynamic code exec) in game code" "clean"
else
  record "INJ-002" "critical" "FAIL" "No Expression (dynamic code exec) in game code" "$expr_hits"
fi

# INJ-003: every JavaScriptBridge.eval call site uses a fixed template, not
# raw interpolation of untrusted data. Heuristic: flag any call where the
# eval'd string isn't one of the two known-safe postMessage templates.
# Heuristic: every JavaScriptBridge.eval() call in this codebase is followed
# within 2 lines by the fixed "window.parent.postMessage" template (the
# eval'd string is built across lines, so the call site itself never shows
# it). If the eval-call count ever exceeds the nearby-postMessage count, a
# new call site was added without that safe template — flag it.
js_eval_sites=$(grep -rn "JavaScriptBridge\.eval" src/ 2>/dev/null || true)
eval_count=$(echo "$js_eval_sites" | grep -c . || echo 0)
safe_count=$(grep -rzoP "JavaScriptBridge\.eval\([^)]{0,200}" src/ 2>/dev/null \
  | tr '\0' '\n' | grep -c "window.parent.postMessage" || echo 0)
if [ "$eval_count" -eq 0 ] || [ "$safe_count" -ge "$eval_count" ]; then
  record "INJ-003" "high" "PASS" "JavaScriptBridge.eval sites use fixed postMessage templates only" "$eval_count site(s), $safe_count fixed-template"
else
  record "INJ-003" "high" "FAIL" "JavaScriptBridge.eval sites use fixed postMessage templates only" "$js_eval_sites"
fi

# INJ-004: FileAccess.open only targets compile-time consts, never a
# runtime-built path — the GDScript path-traversal surface. Heuristic: flag
# any FileAccess.open call whose first arg isn't a bare CONST identifier or
# a string literal.
fa_hits=$(grep -rn "FileAccess\.open(" src/ --include="*.gd" 2>/dev/null || true)
fa_dynamic=$(echo "$fa_hits" | grep -vE 'FileAccess\.open\((SAVE_PATH|"[^"]*"|user://)' || true)
if [ -z "$fa_dynamic" ]; then
  record "INJ-004" "medium" "PASS" "FileAccess.open never takes a runtime-built path" "$(echo "$fa_hits" | grep -c . || echo 0) site(s), all const/literal"
else
  record "INJ-004" "medium" "FAIL" "FileAccess.open never takes a runtime-built path" "$fa_dynamic"
fi

# ---------------------------------------------------------------------------
# CATEGORY: Web Export & Deploy Integrity
# ---------------------------------------------------------------------------

# DEP-001 (carries GAME_SECURITY_CHECKLIST D-C3): web export stays non-threaded
if grep -q "thread_support=false" .github/workflows/export-game.yml 2>/dev/null; then
  record "DEP-001" "critical" "PASS" "Web export stays non-threaded" "thread_support=false present"
else
  record "DEP-001" "critical" "FAIL" "Web export stays non-threaded" "thread_support=false missing — regresses itch.io/iframe/mobile boot fix"
fi

# DEP-002 (carries D-C4): postMessage handlers enforce same-origin
origin_hits=$(grep -n "postMessage\|e\.origin\|event\.origin" web/launcher.js src/autoload/combo_system.gd 2>/dev/null || true)
if echo "$origin_hits" | grep -q "origin"; then
  record "DEP-002" "high" "PASS" "postMessage handlers enforce same-origin" "$(echo "$origin_hits" | wc -l) origin-check reference(s) found"
else
  record "DEP-002" "high" "FAIL" "postMessage handlers enforce same-origin" "no origin check found in launcher.js / combo_system.gd"
fi

# DEP-003: no source maps in the shipped web bundle
maps=$(find web/game -name "*.map" 2>/dev/null || true)
if [ -z "$maps" ]; then
  record "DEP-003" "high" "PASS" "No source maps in shipped bundle" "clean"
else
  record "DEP-003" "high" "FAIL" "No source maps in shipped bundle" "$maps"
fi

# DEP-004: Godot editor + butler downloads in CI are checksum-pinned, not "latest"
if grep -q "SHA512-SUMS\|BUTLER_SHA256" .github/workflows/export-game.yml 2>/dev/null; then
  record "DEP-004" "medium" "PASS" "Supply-chain downloads (Godot/butler) are checksum-pinned" "SHA verification present in CI"
else
  record "DEP-004" "medium" "FAIL" "Supply-chain downloads (Godot/butler) are checksum-pinned" "no checksum verification found"
fi

# ---------------------------------------------------------------------------
# CATEGORY: Wallet/Crypto UI Trust (game-specific)
# ---------------------------------------------------------------------------

# TRUST-001 (carries D-C1): no wallet UI without explicit DEMO labeling.
# Wallet-connect was removed entirely 2026-07-12 — inverted check: absence
# passes; presence without "DEMO" in the same file fails.
if [ ! -f src/autoload/web3_manager.gd ]; then
  record "TRUST-001" "critical" "PASS" "No wallet UI without explicit DEMO labeling" "wallet-connect feature removed"
elif grep -q "DEMO" src/autoload/web3_manager.gd; then
  record "TRUST-001" "critical" "PASS" "No wallet UI without explicit DEMO labeling" "web3_manager.gd present and DEMO-labeled"
else
  record "TRUST-001" "critical" "FAIL" "No wallet UI without explicit DEMO labeling" "web3_manager.gd exists WITHOUT DEMO label"
fi

# ---------------------------------------------------------------------------
# CATEGORY: CI/Pipeline Hygiene
# ---------------------------------------------------------------------------

# CI-001: gitleaks step present in CI
if grep -q "gitleaks" .github/workflows/export-game.yml 2>/dev/null; then
  record "CI-001" "high" "PASS" "Secret-scan (gitleaks) step present in CI" "present"
else
  record "CI-001" "high" "FAIL" "Secret-scan (gitleaks) step present in CI" "missing"
fi

# CI-002: this sentinel itself is wired into CI (self-check)
if grep -q "security-sentinel" .github/workflows/export-game.yml 2>/dev/null; then
  record "CI-002" "medium" "PASS" "Security Sentinel wired into CI" "present"
else
  record "CI-002" "medium" "FAIL" "Security Sentinel wired into CI" "missing — add a step calling this script"
fi

# CI-003: .gitleaks.toml allowlist stays narrow — regression guard against
# quietly widening it to hide a real finding (the exact failure mode this
# project already had to think through once).
if [ -f .gitleaks.toml ]; then
  path_count=$(grep -cE "^\s*'''.*'''\s*,?\s*$" .gitleaks.toml 2>/dev/null || echo 0)
  if [ "$path_count" -le 4 ]; then
    record "CI-003" "medium" "PASS" ".gitleaks.toml allowlist stays narrow" "$path_count allowlisted path(s)"
  else
    record "CI-003" "medium" "FAIL" ".gitleaks.toml allowlist stays narrow" "$path_count allowlisted paths — review for scope creep"
  fi
else
  record "CI-003" "medium" "PASS" ".gitleaks.toml allowlist stays narrow" "no allowlist file"
fi

# CI-004: .gitleaksignore fingerprint count stays reasonable (same guard, for
# the per-commit fingerprint ignore list rather than the path allowlist)
if [ -f .gitleaksignore ]; then
  fp_count=$(grep -cE '^[0-9a-f]{40}:' .gitleaksignore 2>/dev/null || echo 0)
  if [ "$fp_count" -le 20 ]; then
    record "CI-004" "low" "PASS" ".gitleaksignore fingerprint count reasonable" "$fp_count fingerprint(s)"
  else
    record "CI-004" "low" "FAIL" ".gitleaksignore fingerprint count reasonable" "$fp_count fingerprints — review for scope creep"
  fi
else
  record "CI-004" "low" "PASS" ".gitleaksignore fingerprint count reasonable" "no ignore file"
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

TOTAL=${#RESULTS[@]}
PASS_COUNT=0
FAIL_COUNT=0
for r in "${RESULTS[@]}"; do
  status=$(echo "$r" | cut -d'|' -f3)
  [ "$status" = "PASS" ] && PASS_COUNT=$((PASS_COUNT + 1))
  [ "$status" = "FAIL" ] && FAIL_COUNT=$((FAIL_COUNT + 1))
done

if [ "$JSON" -eq 1 ]; then
  echo "{"
  echo "  \"total\": $TOTAL, \"pass\": $PASS_COUNT, \"fail\": $FAIL_COUNT, \"blockers\": $BLOCKERS, \"fail_on\": \"$FAIL_ON\","
  echo "  \"results\": ["
  first=1
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r id severity status title evidence <<< "$r"
    [ "$first" -eq 0 ] && echo ","
    first=0
    evidence_escaped=$(echo "$evidence" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '    {"id": "%s", "severity": "%s", "status": "%s", "title": "%s", "evidence": "%s"}' \
      "$id" "$severity" "$status" "$title" "$evidence_escaped"
  done
  echo ""
  echo "  ]"
  echo "}"
else
  echo "=== Security Sentinel — Lil Blunt Adventure ==="
  echo "fail-on: $FAIL_ON | total: $TOTAL | pass: $PASS_COUNT | fail: $FAIL_COUNT | blockers: $BLOCKERS"
  echo ""
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r id severity status title evidence <<< "$r"
    mark="✓"
    [ "$status" = "FAIL" ] && mark="✗"
    echo "[$mark] $id ($severity) $title"
    [ "$status" = "FAIL" ] && echo "      $evidence" | head -c 300 && echo ""
  done
  echo ""
  if [ "$BLOCKERS" -gt 0 ]; then
    echo "BLOCKED: $BLOCKERS finding(s) at or above '$FAIL_ON' severity."
  else
    echo "No blockers at fail-on=$FAIL_ON."
  fi
fi

if [ "$LOG" -eq 1 ]; then
  {
    echo ""
    echo "## $(date -u +%Y-%m-%d) — Security Sentinel automated run"
    echo ""
    echo "fail-on=$FAIL_ON | total=$TOTAL pass=$PASS_COUNT fail=$FAIL_COUNT blockers=$BLOCKERS"
    echo ""
    echo "| ID | Severity | Status | Title |"
    echo "|----|----------|--------|-------|"
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r id severity status title evidence <<< "$r"
      echo "| $id | $severity | $status | $title |"
    done
  } >> docs/security/audit-log.md
fi

[ "$BLOCKERS" -gt 0 ] && exit 1
exit 0
