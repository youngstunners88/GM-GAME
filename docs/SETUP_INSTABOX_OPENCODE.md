# SETUP — Instabox + OpenCode for GM-GAME

Goal: a box that can **build and gate this game**, not just chat about it. When the workstation
is unusable or Claude Code is rate-limited, work continues on an Instabox machine running
OpenCode with the same pinned Godot, the same Blender, and the same 380+ skills.

- Docs: <https://instabox.sh/docs> · Terms: <https://instabox.sh/terms#acceptable-use>
- Only work on software we own or are authorized to change (this repo).

Superseded: the chat-pasted `Setup For Instabox.md` in `~/Downloads`. It would have replaced
`AGENTS.md` with six lines and left the box without Godot or Blender. This file is the
maintained version.

---

## 0. What the box is and is not

| | Box (free plan) | Workstation |
|---|---|---|
| CPU / RAM | 4 vCPU / 8 GiB | 8 vCPU / 7.8 GiB |
| Disk | `/data` 20 GiB, `HOME=/data/home` | 236 GiB |
| OS | Debian 13 | Omarchy (Arch) |
| Godot | **4.3.stable.official** (pinned, checksum-verified) | 4.3 pinned + 4.7.2 |
| Blender | **5.2.1 LTS, CPU only** | 5.2.1 + GUI |
| GPU | **none** | GPU |
| OpenCode | v2, free Zen models | v2 |
| GUI apps (Kdenlive, OBS, Pinta, Godot editor window) | no | yes |

Two consequences that decide what you delegate:

1. **No GPU.** Cycles renders on CPU; the EEVEE/GPU path is unavailable. Character/scene
   *generation and heavy rendering* stay on Runpod (`ep2-cloud-gpu-runpod` skill). The box does
   geometry, rigging, export, tests, captures, gates, and code.
2. **20 GiB is enough, not roomy.** Full clone (4.7 GB) + Godot & export templates (1.2 GB) +
   Blender (0.8 GB) + OpenCode (0.3 GB) ≈ 7 GB, leaving ~13 GB for `~/opt`, logs, and renders.
   Check `df -h /data` before a long render.

---

## 1. Laptop → box (4 commands)

```bash
npx instabox@latest sh            # sign in with the device code, create + SSH in
```

If you are already at the free machine limit (1 machine):

```bash
instabox ls
instabox ssh <existing-name>      # reuse it — this is usually right
instabox suspend <name>           # pause, keeps /data
instabox rm --yes <old-name>      # only if you really mean to wipe the disk
```

Prefer **suspend** over delete: the repo, Godot, Blender, and OpenCode all live on `/data`.

---

## 2. Make the box build-ready (one command)

Inside the box:

```bash
curl -fsSL https://raw.githubusercontent.com/youngstunners88/GM-GAME/master/scripts/bootstrap-box.sh \
  | bash -s -- --gates
```

Or from a clone (preferred once the repo is there, so you can read what you are running):

```bash
git clone https://github.com/youngstunners88/GM-GAME.git ~/GM-GAME
cd ~/GM-GAME && ./scripts/bootstrap-box.sh --gates
```

`scripts/bootstrap-box.sh` is idempotent — re-running reports `already …` and skips. It does:

1. **apt deps** — `git curl unzip python3` (hard fail if missing) + `ffmpeg imagemagick jq rsync
   nodejs npm xvfb libgl1-mesa-dri` (best effort). `xvfb` + `libgl1-mesa-dri` are the exact pair CI
   installs; without them the render-capture gates cannot run.
2. **OpenCode** — `https://opencode.ai/v2/install`, falls back to `/install`.
3. **Clone** — `master`, full history; skills load from `.claude/skills` (346) + `.agents/skills` (42).
4. **Godot 4.3** — delegates to `scripts/bootstrap-godot.sh`, which mirrors the SHA512 gate in
   `.github/workflows/export-game.yml`. Expects `4.3.stable.official.77dcf97d8` and refuses anything
   else. `.godot-cache/` is gitignored, which is why a fresh clone has no Godot.
5. **Blender 5.2.1** — official tarball, size + SHA-256 pinned
   (`a31f524f…b10e9`), resumable download, into `~/opt/blender-5.2.1-linux-x64`, symlinked as
   `blender`.
6. **PATH + verify** — appends a marked block to `~/.bashrc`, then prints every version.

Useful flags: `--no-blender` (saves 0.8 GB), `--shallow` (depth-1 clone, saves ~2 GB, limits
`git log`), `--gates` (run the CI gameplay gates immediately), `REPO_DIR=… BRANCH=…`.

Expected tail of a good run:

```
   opencode opencode v2.0.x
   godot    4.3.stable.official.77dcf97d8
   blender  Blender 5.2.1 LTS
   repo     master @ <sha>
```

If `--gates` is used, the run ends with `gates passed`. That is the difference between "OpenCode is
installed" and "this box can build the game". Note `ci-gates-local.sh` tolerates three known
pause-menu tap-target failures that also fail on unmodified master on some machines — see the
comment in that script before treating them as a regression.

---

## 3. Working on the box

```bash
cd ~/GM-GAME
export GODOT_BIN="$PWD/.godot-cache/Godot_v4.3-stable_linux.x86_64"
opencode
```

Models (free tier, no API key — both verified present):

- **DeepSeek V4.1 Flash Free** — code, gates, multi-file fixes. Default.
- **Nemotron 3.5 Super VL Free** — screenshots, UI/capture review.

Do not leave "max" reasoning on for every prompt; default for small edits, max only for hard
physics/boss/multi-file bugs. `opencode models` lists what the tier currently offers.

Rules that keep the box honest:

- One residual or one scene per session. Narrow prompts.
- Measure coordinates / reproduce on hard-refresh before saying FIXED — a gate PASS is not a live fix.
- Long jobs need logs: `nohup … >job.log 2>&1 &`.

---

## 4. What travels, and what does not

Everything the box needs is on `origin/master` — this was verified, not assumed:

- All seven recent `ep2-*` skills (logans-lake, lake-water-build, side-lane-build, sightline-proof,
  armory-off-main, blender-skills-bridge, logan-character) are committed on `master`.
- The Blender skill pack is vendored in the repo under `.agents/skills` — no external clone needed.
- The 22 `blender-*` skills on the workstation are symlinks into `~/tools/blender-skills`
  (upstream `EL4CTEO/blender-skills`). That tree is a *workstation convenience*, not a dependency:
  the repo copy is what the box reads.

Not on the box, by design: Omarchy system skills (`omarchy`, `diagnose-crash`), the `creative-hub`
manifest, GUI apps, and the GPU.

**Uncommitted work does not travel.** Before switching machines:

```bash
git -C ~/GM-GAME status --porcelain
git -C ~/GM-GAME diff origin/master --stat
```

If there is real local-only work, move it deliberately — push it, or carry a bundle:

```bash
# laptop
git -C ~/GM-GAME bundle create /tmp/wip.bundle origin/master..HEAD
instabox cp /tmp/wip.bundle gm-game:/data/home/
# box
git -C ~/GM-GAME fetch /data/home/wip.bundle 'refs/heads/*:refs/heads/*'
```

One caution: **33 skill names exist in both `.claude/skills` and `.agents/skills`** (the Blender
pack is vendored twice). OpenCode expects skill names to be unique. The repo ships this way and it
has not broken anything, but if a skill loads stale or behaves oddly, that duplication is the first
thing to check.

---

## 5. Don't

- Don't run section-5-style `cat > AGENTS.md << 'EOF'` from the old setup doc. `AGENTS.md` and
  `CLAUDE.md` are real project context and a heredoc **truncates** them. Append only:

  ```bash
  printf '\n- Box note: see docs/SETUP_INSTABOX_OPENCODE.md\n' >> AGENTS.md   # only if it is missing
  ```

- Don't install random reverse-engineering/cracking skill packs on this box.
- Don't assume a gate PASS equals a live fix — plan the hard-refresh check on itch.
- Don't leave paid usage idling (free plan auto-pauses after 30 min; `instabox suspend` is polite).

---

## 6. Verify checklist

```bash
instabox whoami && instabox ls
uname -a && nproc && free -m && df -h /data
which opencode && opencode --version
ls ~/GM-GAME/.claude/skills | wc -l          # expect ~346
cd ~/GM-GAME && git rev-parse --short HEAD
"$PWD/.godot-cache/Godot_v4.3-stable_linux.x86_64" --headless --version   # 4.3.stable.official…
blender --version                                                        # Blender 5.2.1 LTS
```

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `only N GiB free` | small volume | `--shallow`, or `instabox rm` and recreate with a bigger `/data` |
| `fetch failed/timed out` | flaky box network | harmless; re-run, or `git pull` manually. Bootstrap keeps the on-disk checkout |
| `version 4.7.x` from Godot step | wrong binary on PATH | the script checks `.godot-cache` explicitly; never export a 4.7 `GODOT_BIN` for gates |
| Blender download reset | 366 MB pull interrupted | script resumes up to 4×; if it still fails, `curl -C - -o /tmp/b.tar.xz <url>` then re-run |
| `no passwordless sudo` | locked-down template | Godot/Blender/OpenCode still install to `$HOME`; apt step skipped, render-capture gates will not run |
| gates skip render capture | missing `xvfb` / `libgl1-mesa-dri` | `sudo apt-get install -y xvfb libgl1-mesa-dri` |
| EEVEE fails / GPU probe | no GPU on the box | expected — use Cycles CPU or send the render to Runpod |
