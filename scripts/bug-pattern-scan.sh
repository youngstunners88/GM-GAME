#!/usr/bin/env bash
# bug-pattern-scan.sh — repo-wide sweep for the bug CLASSES this project has
# actually shipped and had rejected on a founder hard-refresh.
#
# Every pattern below cost a real round-trip. The point of this script is that a
# class is only allowed to bite ONCE: after it's diagnosed, it becomes a grep
# that runs on every nightly pass, so the same shape can never quietly reappear
# somewhere else in the codebase.
#
# Usage:  bash scripts/bug-pattern-scan.sh [--strict]
#   default : report everything, exit 0 unless a CRITICAL hit is found
#   --strict: exit non-zero on HIGH as well (used by the nightly routine gate)
#
# Output is grouped by class with file:line so a fix can start immediately.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

CRIT=0; HIGH=0; MED=0
SRC="src"

hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }
hit() { # sev, label, results
  local sev="$1" label="$2" res="$3"
  if [ -z "$res" ]; then
    printf '  [ok]   %-8s %s\n' "$sev" "$label"
    return
  fi
  printf '  [HIT]  %-8s %s\n' "$sev" "$label"
  printf '%s\n' "$res" | sed 's/^/           /'
  case "$sev" in
    CRITICAL) CRIT=$((CRIT+1));;
    HIGH)     HIGH=$((HIGH+1));;
    *)        MED=$((MED+1));;
  esac
}

echo "=== GM-GAME bug-pattern scan ==="
echo "scanning $SRC (tracked source only)"

# ---------------------------------------------------------------------------
hdr "1. FREEZE / SOFT-LOCK CLASSES"

# 1a. Zero-scaling a LIVE physics body. THE blue-block freeze (2026-08-26):
# tweening a StaticBody2D/CharacterBody2D 'scale' to ZERO scales its
# CollisionShape2D to zero -> degenerate, non-invertible collider -> whoever
# stands on it is trapped and cannot depenetrate. Animate the SPRITE instead and
# disable the collider first.
res=""; safe=""
for m in $(grep -rln 'tween_property(self, *"scale".*ZERO' $SRC --include=*.gd 2>/dev/null); do
  # "Neutralised" = the body stops colliding around the shrink. A death anim that
  # disables its collider/monitoring is safe; a LIVE prop that keeps colliding
  # while it shrinks to zero is the freeze (breakable_block, timed_door).
  if grep -qE 'set_deferred\("disabled", *true\)|monitoring *= *false|monitorable *= *false|set_physics_process\(false\)' "$m"; then
    safe="${safe}${m} (looks neutralised - spot-check the collider goes off BEFORE the tween)"$'\n'
  else
    res="${res}${m}: shrinks a LIVE body to zero, nothing disables its collider"$'\n'
  fi
done
hit CRITICAL "zero-scaling a LIVE body (degenerate collider / freeze)" "${res}"
if [ -n "$safe" ]; then
  printf '  [note] %-8s %s\n' "TRIAGE" "zero-scale sites that look neutralised:"
  printf '%s' "$safe" | sed 's/^/           /'
fi

# 1b. Overlap probe missing recovery_as_collision. THE ladder-top-out freeze:
# move_and_collide(Vector2.ZERO, true) does NOT report a RESTING overlap, so any
# "am I embedded?" check built on it silently never fires and the depenetration
# it guards never runs. Needs the 4th arg true.
res=$(grep -rn 'move_and_collide(Vector2.ZERO, *true)' $SRC --include=*.gd 2>/dev/null \
  | grep -vE ':[0-9]+:[[:space:]]*#' || true)
hit CRITICAL "embed probe without recovery_as_collision (never detects a wedge)" "$res"

# 1c. Stranded global time_scale: a hitstop that restores on an awaited coroutine
# dies with its node. Restores must ride a TREE-owned timer with
# ignore_time_scale=true (create_timer(t, true, false, true)).
res=$(grep -rn 'Engine.time_scale *= *0' $SRC --include=*.gd 2>/dev/null \
  | grep -v 'time_scale *= *1' || true)
hit HIGH "Engine.time_scale set low — confirm a tree-owned ignore_time_scale restore" "$res"

# 1d. Direct tree pause without a guaranteed release in the same file.
res=""
for f in $(grep -rl 'get_tree().paused *= *true' $SRC --include=*.gd 2>/dev/null); do
  if ! grep -q 'get_tree().paused *= *false' "$f"; then
    res="${res:-}$f: pauses the tree, no 'paused = false' in this file"$'\n'
  fi
done
hit HIGH "tree paused with no release in the same file" "${res:-}"
res=""

# 1e. Physics disabled with no re-enable in the same file (a dead entity is fine;
# a gameplay node that never resumes is a soft-lock).
for f in $(grep -rl 'set_physics_process(false)' $SRC --include=*.gd 2>/dev/null); do
  if ! grep -q 'set_physics_process(true)' "$f"; then
    res="${res:-}$f: disables physics, never re-enables"$'\n'
  fi
done
hit MEDIUM "set_physics_process(false) with no re-enable (review: dead vs stuck)" "${res:-}"
res=""

# ---------------------------------------------------------------------------
hdr "2. COROUTINE / LIFETIME CLASSES"

# 2a. await followed by node use with no validity re-check. After an await the
# node can be freed and the scene can have changed.
res=$(grep -rn -A3 '^[[:space:]]*await ' $SRC --include=*.gd 2>/dev/null \
  | grep -E 'global_position|queue_free|add_child|\.text *=|\.visible' \
  | grep -v 'is_instance_valid' | head -25 || true)
hit HIGH "node touched after 'await' without is_instance_valid re-check" "$res"

# 2b. Physics-state writes that must be deferred (throws "Can't change this
# state while flushing queries" when hit from a physics callback).
res=$(grep -rnE '^[[:space:]]*[A-Za-z_.]*(collision|shape)[A-Za-z_.]*\.disabled *= *(true|false)' $SRC --include=*.gd 2>/dev/null \
  | grep -v set_deferred || true)
hit HIGH "collision .disabled written directly (use set_deferred)" "$res"

# ---------------------------------------------------------------------------
hdr "3. GDSCRIPT TRAPS THAT gdparse DOES NOT CATCH"

# Deliberately NO ':=' type-inference grep. `:=` on a typed member var, or on
# get_first_node_in_group() (which returns Node), is perfectly legal — that grep
# was a pure false-positive generator, and a noisy scanner sends an autonomous
# nightly run chasing ghosts. The genuine Godot 4.3 load-killer surfaces for real
# when the gate battery loads every script in a live engine, which the nightly
# routine already does.
echo "  [ok]   INFO     type-inference traps are covered by the real engine load in the gate battery"

# ---------------------------------------------------------------------------
hdr "4. STATE FLAGS THAT CAN STRAND"

# Flags whose ONLY exit is a condition that may never become true. Each of these
# has frozen the player at least once. Reported for review, not auto-fixed.
for flag in _ground_pounding _climbing _dying _boss_restart_pending _vault_timer _surge_active; do
  n=$(grep -rn "$flag" $SRC --include=*.gd 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && printf '  [info] %-22s %s references — confirm every path clears it\n' "$flag" "$n"
done
echo "         (player.gd _force_unstick() is the safety net; new flags must be added there)"

# ---------------------------------------------------------------------------
hdr "5. SECRETS / CHAIN SAFETY (mirrors the sentinel, cheap double-check)"
res=$(grep -rnE '0x[a-fA-F0-9]{40}' $SRC --include=*.gd 2>/dev/null || true)
hit CRITICAL "hardcoded 40-hex wallet/contract address in game code (use config.json)" "$res"

# ---------------------------------------------------------------------------
hdr "SUMMARY"
printf '  critical: %s   high: %s   medium: %s\n' "$CRIT" "$HIGH" "$MED"

if [ "$CRIT" -gt 0 ]; then
  echo "  VERDICT: CRITICAL findings — fix before shipping."
  exit 2
fi
if [ "$STRICT" -eq 1 ] && [ "$HIGH" -gt 0 ]; then
  echo "  VERDICT: HIGH findings under --strict."
  exit 1
fi
echo "  VERDICT: no blocking findings."
exit 0
