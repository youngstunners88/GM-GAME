#!/usr/bin/env bash
# bootstrap-box.sh — turn a fresh Debian 13 / Ubuntu cloud box into a working GM-GAME build box.
#
# WHY THIS EXISTS: the workstation is the source of truth (Godot 4.3 pinned, Blender, the
# skill pack, the tool scripts), but the box is disposable. When the workstation is unusable
# or Claude Code is rate-limited, we still need a machine that can run the SAME gates and the
# SAME exports. Rebuilding that by hand from a chat-pasted SETUP.md is how you end up with a
# box that has OpenCode but no Godot, or Godot 4.7 instead of the pinned 4.3 the pack gate
# requires. This script is that rebuild, once, idempotent, and safe to re-run.
#
# It deliberately does NOT invent its own Godot download: it delegates to
# scripts/bootstrap-godot.sh, which mirrors the checksum gate in
# .github/workflows/export-game.yml. A box built here runs a provably identical binary to CI.
#
# WHAT IT SETS UP
#   1. apt build/test deps   — the same set CI installs (xvfb + libgl1-mesa-dri) plus media tools
#   2. opencode              — the agent runtime (free Zen models, no API key)
#   3. GM-GAME clone         — full clone; project skills load from .claude/skills + .agents/skills
#   4. Godot 4.3 + templates — checksum-verified via scripts/bootstrap-godot.sh
#   5. Blender 5.2.1         — checksum-verified tarball into ~/opt (CPU rendering only, see doc)
#   6. PATH + verify         — prints the exact versions so a mismatch is visible, not assumed
#
# USAGE
#   scripts/bootstrap-box.sh                  # everything, into ~/GM-GAME
#   scripts/bootstrap-box.sh --gates          # ...then run the CI gameplay gates (~10-20 min)
#   scripts/bootstrap-box.sh --no-blender     # skip step 5 (saves ~800 MB, breaks 3D work)
#   scripts/bootstrap-box.sh --shallow        # depth-1 clone (saves ~1.5 GB on a 20 GiB box)
#   REPO_DIR=/data/home/GM-GAME BRANCH=master scripts/bootstrap-box.sh
#
# Re-running is cheap: every step reports "already …" and skips. Nothing is deleted, nothing is
# force-reset. On a box that already has the repo, step 3 only fetches and reports.
#
# Disk budget: repo ~4.7 GB (or ~2.7 GB with --shallow) + Godot/templates ~1.2 GB +
# Blender ~0.8 GB + opencode ~0.3 GB. A 20 GiB /data volume is enough, not roomy.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/youngstunners88/GM-GAME.git}"
BRANCH="${BRANCH:-master}"
REPO_DIR="${REPO_DIR:-$HOME/GM-GAME}"
BLENDER_VERSION="${BLENDER_VERSION:-5.2.1}"
BLENDER_SHA256="${BLENDER_SHA256:-a31f524fa99a527d3d52b7f5aaa68c34e1a19d5a1c9473f79c5cc610fd5b10e9}"
BLENDER_BYTES="${BLENDER_BYTES:-383688088}"
MIN_FREE_GIB=10

DO_BLENDER=1
DO_GATES=0
SHALLOW=0
for arg in "$@"; do
  case "$arg" in
    --no-blender) DO_BLENDER=0 ;;
    --gates) DO_GATES=1 ;;
    --shallow) SHALLOW=1 ;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown flag: $arg (try --help)" >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok() { printf '   \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '   \033[33mwarn\033[0m %s\n' "$*"; }
die() { printf '   \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 0. preflight
say "0. preflight"

[ "$(uname -m)" = "x86_64" ] || die "this bootstrap pins x86_64 binaries; got $(uname -m)"
ok "arch x86_64"

if [ -r /etc/os-release ]; then
  . /etc/os-release
  ok "os ${PRETTY_NAME:-unknown}"
  case "${ID:-}:${VERSION_ID:-}" in
    debian:13*|ubuntu:2[2-9]*) : ;;
    *) warn "tuned for Debian 13 / Ubuntu 22.04+; apt package names may differ on ${ID:-?} ${VERSION_ID:-?}" ;;
  esac
fi

mkdir -p "$(dirname "$REPO_DIR")"
FREE_GIB=$(df -Pk "$(dirname "$REPO_DIR")" | awk 'NR==2{print int($4/1048576)}')
if [ "$FREE_GIB" -lt "$MIN_FREE_GIB" ]; then
  die "only ${FREE_GIB} GiB free on $(dirname "$REPO_DIR") — need ~${MIN_FREE_GIB} GiB (repo+Godot+Blender)"
fi
ok "disk ${FREE_GIB} GiB free on $(dirname "$REPO_DIR")"
ok "cpus $(nproc), ram $(free -m | awk '/^Mem:/{print $2}') MiB"

SUDO=""
if sudo -n true 2>/dev/null; then
  SUDO="sudo"
  ok "sudo available"
elif [ "$(id -u)" = "0" ]; then
  SUDO=""
  ok "running as root"
else
  warn "no passwordless sudo — skipping apt step; Godot/Blender/opencode still install to \$HOME"
fi

# ---------------------------------------------------------------- 1. apt deps
say "1. system deps"

if [ -z "$SUDO" ] && [ "$(id -u)" != "0" ]; then
  warn "skipped (no sudo). If gates fail on a missing lib, that is why."
else
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -qq
  # Critical: without xvfb + libgl1-mesa-dri the render-capture gates cannot run, and the
  # gameplay gates then silently skip instead of passing. Everything else is quality of life.
  CRITICAL=(git curl ca-certificates unzip xz-utils python3)
  EXTRA=(ffmpeg imagemagick jq rsync file nodejs npm xvfb libgl1-mesa-dri libglu1-mesa libgomp1 build-essential)
  $SUDO apt-get install -y --no-install-recommends "${CRITICAL[@]}" \
    || die "could not install base packages (git/curl/unzip/python3)"
  if ! $SUDO apt-get install -y --no-install-recommends "${EXTRA[@]}" 2>/dev/null; then
    warn "bulk install of optional packages failed — retrying one by one"
    for p in "${EXTRA[@]}"; do
      $SUDO apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 \
        || warn "optional package unavailable: $p"
    done
  fi
  for b in git curl unzip python3 ffmpeg magick Xvfb node; do
    command -v "$b" >/dev/null 2>&1 && ok "$b $(command -v "$b")" || warn "missing: $b"
  done
fi

# ---------------------------------------------------------------- 2. opencode
say "2. opencode"

if command -v opencode >/dev/null 2>&1; then
  ok "already installed: $(opencode --version 2>/dev/null | tail -1)"
else
  # v2 install path first (current), legacy path as fallback if v2 moves.
  if ! curl -fsSL https://opencode.ai/v2/install | bash; then
    warn "v2 installer failed, trying legacy path"
    curl -fsSL https://opencode.ai/install | bash || die "opencode install failed"
  fi
  export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
  command -v opencode >/dev/null 2>&1 \
    || die "opencode installed but not on PATH — expected ~/.opencode/bin or ~/.local/bin"
  ok "installed: $(opencode --version 2>/dev/null | tail -1)"
fi

# ---------------------------------------------------------------- 3. repo
say "3. $REPO_DIR"

if [ -d "$REPO_DIR/.git" ]; then
  ok "already cloned — fetching only (no reset, no clean)"
  # Timeout: a box behind a flaky network must not hang the whole bootstrap on one fetch.
  timeout 180 git -C "$REPO_DIR" fetch --quiet origin 2>/dev/null || warn "fetch failed/timed out (offline? auth?) — continuing with what is on disk"
  ok "HEAD $(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null) on $(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
    warn "working tree is dirty — leaving it alone; review with: git -C $REPO_DIR status"
  fi
else
  if [ "$SHALLOW" = "1" ]; then
    timeout 1800 git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  else
    timeout 1800 git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
  ok "cloned $BRANCH @ $(git -C "$REPO_DIR" rev-parse --short HEAD)"
fi

SKILLS=$( (find "$REPO_DIR/.claude/skills" "$REPO_DIR/.agents/skills" -name SKILL.md 2>/dev/null || true) | wc -l )
[ "$SKILLS" -gt 100 ] || warn "only $SKILLS skills found — expected 300+; is the clone complete?"
ok "$SKILLS skills available to OpenCode (.claude/skills + .agents/skills)"

# ---------------------------------------------------------------- 4. Godot 4.3
say "4. Godot (pinned, checksum-verified)"

GODOT_BIN="$REPO_DIR/.godot-cache/Godot_v4.3-stable_linux.x86_64"
if [ -x "$GODOT_BIN" ]; then
  ok "already cached: $GODOT_BIN"
else
  # bootstrap-godot.sh prints the absolute path as its LAST line on stdout.
  ( cd "$REPO_DIR" && scripts/bootstrap-godot.sh >/dev/null ) || die "Godot bootstrap failed"
  [ -x "$GODOT_BIN" ] || die "Godot bootstrap reported success but $GODOT_BIN is missing"
  ok "installed $GODOT_BIN"
fi
GV=$("$GODOT_BIN" --headless --version 2>/dev/null | tail -1)
case "$GV" in
  4.3*) ok "version $GV" ;;
  *) die "expected 4.3-stable, got '$GV' — the pack gate will not match" ;;
esac
TPL="$HOME/.local/share/godot/export_templates/4.3.stable"
[ -d "$TPL" ] && ok "export templates at $TPL" || warn "export templates missing — web export will fail"

# ---------------------------------------------------------------- 5. Blender
say "5. Blender ${BLENDER_VERSION}"

if [ "$DO_BLENDER" = "0" ]; then
  warn "skipped (--no-blender)"
else
  BL_ROOT="$HOME/opt/blender-${BLENDER_VERSION}-linux-x64"
  if [ -x "$BL_ROOT/blender" ]; then
    ok "already installed: $("$BL_ROOT/blender" --version 2>/dev/null | head -1)"
  else
    TARBALL="blender-${BLENDER_VERSION}-linux-x64.tar.xz"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    URL="https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/${TARBALL}"
    # Resumable + retried: a 366 MB pull on a cloud box gets reset mid-transfer often enough
    # that a plain `curl --retry` (which does not resume) fails the whole bootstrap.
    attempt=1
    while :; do
      if curl -fL -sS --retry 5 --retry-all-errors --retry-delay 2 -C - \
           -o "$TMP/$TARBALL" "$URL"; then
        break
      fi
      if [ "$attempt" -ge 4 ]; then
        die "Blender download failed after $attempt attempts: $URL"
      fi
      warn "download interrupted, resuming (attempt $((attempt + 1))/4)"
      attempt=$((attempt + 1))
      sleep 3
    done
    SIZE=$(stat -c%s "$TMP/$TARBALL")
    [ "$SIZE" = "$BLENDER_BYTES" ] || die "Blender size mismatch ($SIZE != $BLENDER_BYTES) — refusing partial tarball"
    echo "${BLENDER_SHA256}  $TMP/$TARBALL" | sha256sum -c --quiet - || die "Blender checksum mismatch"
    ok "downloaded + checksum OK (${SIZE} bytes)"
    mkdir -p "$HOME/opt"
    tar -xJf "$TMP/$TARBALL" -C "$HOME/opt" || die "Blender extract failed"
    [ -x "$BL_ROOT/blender" ] || die "expected $BL_ROOT/blender after extract"
    ok "extracted $BL_ROOT"
  fi
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$BL_ROOT/blender" "$HOME/.local/bin/blender"
  export PATH="$HOME/.local/bin:$PATH"
  BVER=$(blender --version 2>/dev/null | head -1)
  ok "$BVER"
  warn "no GPU on this box: Cycles renders on CPU and the EEVEE/GPU path is unavailable —"
  warn "heavy Blender rendering belongs on Runpod (skill: ep2-cloud-gpu-runpod)"
fi

# ---------------------------------------------------------------- 6. shell env
say "6. shell env"

BASHRC="$HOME/.bashrc"
MARK="# >>> gm-game box bootstrap >>>"
if grep -qF "$MARK" "$BASHRC" 2>/dev/null; then
  ok "PATH block already in $BASHRC"
else
  cat >> "$BASHRC" <<'EOF'

# >>> gm-game box bootstrap >>>
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
export GODOT_BIN="${GODOT_BIN:-$HOME/GM-GAME/.godot-cache/Godot_v4.3-stable_linux.x86_64}"
# Blender on this box is CPU-only; keep it from stalling on GPU probing.
export LIBGL_ALWAYS_SOFTWARE=1
# <<< gm-game box bootstrap <<<
EOF
  ok "appended PATH block to $BASHRC"
fi

# ---------------------------------------------------------------- 7. verify
say "7. verify"

printf '   opencode %s\n' "$(command -v opencode >/dev/null && opencode --version 2>/dev/null | tail -1 || echo MISSING)"
printf '   godot    %s\n' "$GV"
if [ "$DO_BLENDER" = "1" ]; then
  printf '   blender  %s\n' "$(blender --version 2>/dev/null | head -1)"
fi
printf '   git      %s\n' "$(git --version 2>/dev/null)"
printf '   repo     %s @ %s\n' "$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)" "$(git -C "$REPO_DIR" rev-parse --short HEAD)"
printf '   disk     %s free on %s\n' "$(df -h "$(dirname "$REPO_DIR")" | awk 'NR==2{print $4}')" "$(dirname "$REPO_DIR")"

say "done"
cat <<EOF
   Next:
     cd $REPO_DIR
     export GODOT_BIN=$GODOT_BIN
     opencode                      # pick a free model; DeepSeek V4.1 Flash Free for code

   Prove the box can actually build (10-20 min, same gates CI runs):
     cd $REPO_DIR && ./scripts/ci-gates-local.sh
EOF

if [ "$DO_GATES" = "1" ]; then
  say "8. CI gameplay gates"
  ( cd "$REPO_DIR" && GODOT_BIN="$GODOT_BIN" ./scripts/ci-gates-local.sh ) \
    || die "gates failed — this box is NOT build-ready; see the log dir above"
  ok "gates passed"
fi
