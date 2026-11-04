#!/usr/bin/env bash
# gate_pod.sh - run GM-GAME's headless gates and real-renderer captures on a Runpod pod (skill ep2-runpod-gate-pod).
#
# Why: a full `--import` plus the Episode 2 gates and captures swamp a small laptop. The repo is public, so the pod clones it
# directly and holds no secrets; this script only sends the working tree's differences, runs things, and brings logs and shots back.
# Commits and pushes stay on the local machine. It never creates, stops or terminates a pod (that is a Runpod MCP call, priced first).
#
#   POD=gm-pod tools/ep2_runpod/gate_pod.sh setup <git-ref>         clone, packages, pinned Godot 4.3, import, idle guard
#   tools/ep2_runpod/gate_pod.sh sync                               send tracked changes + untracked files; remove local deletions
#   tools/ep2_runpod/gate_pod.sh test ep2_river_cover ep2_ranch     sync, then run tests/<name>_test.tscn in parallel (fresh user://)
#   tools/ep2_runpod/gate_pod.sh ci                                 sync, then CI's whole headless block (scripts/ci-gates-local.sh)
#   tools/ep2_runpod/gate_pod.sh shot <scene.tscn> <local_dir> [k=v] sync, render on xvfb (Compatibility, as the web build), fetch PNGs
#   tools/ep2_runpod/gate_pod.sh import                             re-import after new assets or a new class_name (runs twice)
#   tools/ep2_runpod/gate_pod.sh run "<shell command>"              one command in the pod's repo
set -uo pipefail
POD="${POD:-gm-pod}"
REPO=/workspace/repo
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
JOBS="${JOBS:-6}"
quiet() { grep -v -E 'post-quantum|store now|server may need'; }
remote() { ssh -o BatchMode=yes -o ConnectTimeout=20 "$POD" "$@" 2> >(quiet >&2); }
cd "$(git rev-parse --show-toplevel)"

sync_tree() {
	local base list del
	[ -n "${NOSYNC:-}" ] && { echo "NOSYNC: pod tree left as it is"; return 0; }
	base=$(remote "git -C $REPO rev-parse HEAD") || { echo "pod unreachable"; exit 2; }
	git cat-file -e "$base" 2>/dev/null || { echo "pod base $base is not in this clone: git fetch first"; exit 2; }
	list=$(mktemp)
	{ git diff --name-only --diff-filter=d "$base"; git ls-files -o --exclude-standard; } | sort -u > "$list"
	del=$(git diff --name-only --diff-filter=D "$base")
	rsync -az --files-from="$list" --no-owner --no-group -e "ssh -o BatchMode=yes" ./ "$POD:$REPO/" 2> >(quiet >&2)
	[ -n "$del" ] && printf '%s\n' "$del" | remote "cd $REPO && xargs -r -d '\n' rm -f"
	echo "synced $(wc -l < "$list") files against ${base:0:8}"
	rm -f "$list"
}

case "${1:-}" in
setup)
	ref="${2:?git ref}"
	remote "bash -s" <<EOF
set -e
apt-get update -qq >/dev/null 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb libgl1-mesa-dri libgl1 libglx-mesa0 mesa-vulkan-drivers libvulkan1 vulkan-tools mesa-utils libxcursor1 libxinerama1 libxrandr2 libxi6 libasound2t64 libpulse0 rsync tmux imagemagick jq unzip >/dev/null 2>&1
[ -d $REPO/.git ] || git clone -q --depth 1 --branch "$ref" https://github.com/youngstunners88/GM-GAME.git $REPO
cd $REPO
git config core.fileMode false
GODOT_CACHE_DIR=\$PWD/.godot-cache bash scripts/bootstrap-godot.sh 2>&1 | tail -1
tmux kill-session -t guard 2>/dev/null || true
tmux new-session -d -s guard "bash /workspace/idle_guard.sh"
EOF
	scp -q -o BatchMode=yes tools/ep2_runpod/idle_guard.sh "$POD:/workspace/idle_guard.sh" 2> >(quiet >&2)
	remote "tmux kill-session -t guard 2>/dev/null; tmux new-session -d -s guard 'bash /workspace/idle_guard.sh'; echo guard up"
	"$0" import
	;;
sync) sync_tree ;;
import)
	remote "cd $REPO && touch /workspace/.active && for i in 1 2; do timeout 1500 $G --headless --editor --quit >/dev/null 2>&1; done; timeout 1500 $G --headless --import >/dev/null 2>&1; echo IMPORT_DONE \$(du -sh .godot | cut -f1)"
	;;
test)
	shift
	sync_tree
	remote "bash -s -- $JOBS $*" <<'EOF'
jobs=$1; shift
cd /workspace/repo && touch /workspace/.active
L=/workspace/logs/$(date +%H%M%S); mkdir -p "$L"
one() {
	t=$1; f="$2/$t.log"; x=$(mktemp -d)
	XDG_DATA_HOME=$x/d XDG_CONFIG_HOME=$x/c XDG_CACHE_HOME=$x/k timeout 900 .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --path . "res://tests/${t}_test.tscn" > "$f" 2>&1
	rc=$?; rm -rf "$x"
	printf '%-36s rc=%-3s PASS=%-4s FAIL=%-3s SCRIPT_ERR=%s\n' "$t" "$rc" "$(grep -c '\[PASS\]' "$f")" "$(grep -c '\[FAIL\]' "$f")" "$(grep -cE 'SCRIPT ERROR|Parse Error' "$f")"
}
export -f one
printf '%s\n' "$@" | xargs -P "$jobs" -I{} bash -c "one {} $L"
echo "--- failures ($L)"
grep -HE '\[FAIL\]|SCRIPT ERROR|Parse Error' "$L"/*.log | sed "s#$L/##" | cut -c1-260 | head -40
EOF
	;;
ci)
	sync_tree
	remote "cd $REPO && touch /workspace/.active && git add -AN . >/dev/null 2>&1; GODOT_BIN=$G timeout 3000 bash scripts/ci-gates-local.sh 2>&1 | tail -25"
	;;
shot)
	scene="${2:?scene}"; dest="${3:?local dir}"; shift 3
	sync_tree
	tmp="/workspace/shots/$(basename "$scene" .tscn)-$$"
	remote "cd $REPO && touch /workspace/.active && mkdir -p $tmp && timeout 1500 xvfb-run -a -s '-screen 0 1600x900x24' $G --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --path . res://$scene -- out=$tmp $* > $tmp.log 2>&1; grep -E 'SCRIPT ERROR|Parse Error' $tmp.log | head -10; grep -vE '^(Godot Engine|OpenGL API|ERROR: |   at: |$)' $tmp.log | tail -${SHOT_LINES:-12}; ls $tmp | wc -l"
	mkdir -p "$dest"
	rsync -az -e "ssh -o BatchMode=yes" "$POD:$tmp/" "$dest/" 2> >(quiet >&2)
	echo "fetched to $dest"
	;;
run)
	remote "cd $REPO && touch /workspace/.active && ${2:?command}"
	;;
*)
	sed -n 2,16p "$0"; exit 2 ;;
esac
