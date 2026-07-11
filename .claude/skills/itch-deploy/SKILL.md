---
name: itch-deploy
description: Ship the Godot 4.3 web build to itch.io — export settings, butler CLI, CI automation, page configuration, and verification. Use for any itch.io release, when the game "won't load" in a browser, or when changing web export settings.
---

# itch.io Deploy — Godot 4.3 Web Build → Live Game Page

The proven pipeline. itch.io is the primary distribution platform (game-native
CDN, instant loads, discovery, 90M+ players/month). Vercel/Netlify remain as
secondary mirrors.

## 0. The one rule that prevents "the game doesn't always play"

**Export with `variant/thread_support=false`.** Threaded Godot web builds need
SharedArrayBuffer, which needs COOP/COEP headers — unavailable in itch.io's
default sandbox, many iframes, and some mobile browsers. The non-threaded build
runs everywhere with zero special headers. Cost: slightly higher audio latency.
For a 2D platformer this is invisible; the reliability win is enormous.
Never flip this back to `true` without testing on itch.io itself.

## 1. Export (CI does this automatically)

`.github/workflows/export-game.yml` runs on every push to `master`/`claude/**`
touching `src/**` or `project.godot`:
1. Downloads Godot 4.3-stable + export templates
2. Writes the export preset (thread_support=false, canvas_resize_policy=2)
3. Imports, then exports to `web/game/` and commits it back to the branch
4. Zips `web/game/` → `lil-blunt-itch.zip` artifact (index.html at zip ROOT —
   itch.io rejects nested zips)
5. If the `BUTLER_API_KEY` repo secret is set: pushes `web/game/` to
   `youngstunners88/lil-blunt-adventure:html5` via butler

## 2. Deploy paths (in order of preference)

- **Automatic (CI + butler)**: set repo secret `BUTLER_API_KEY`
  (from https://itch.io/user/settings/api-keys). Every green export deploys.
- **Local script**: `BUTLER_API_KEY=xxx ./scripts/deploy_itch.sh`
  (downloads butler if missing, pushes with git-sha version tag).
- **Manual fallback**: download the `itch-build` artifact from the Actions run,
  upload the zip on the itch.io edit page, tick "This file will be played in
  the browser".

butler diffs uploads (only changed bytes transfer) and keeps version history —
always prefer it over manual zip upload.

## 3. itch.io page configuration (one-time, owner does this)

- Create project at https://itch.io/game/new — **Kind: HTML**
- Slug must match the butler target: `lil-blunt-adventure`
- Embed options: **Click to launch in fullscreen** OR embed at 1280×720
  (game viewport). Enable "Mobile friendly" + fullscreen button.
- **Leave "SharedArrayBuffer support" OFF** — not needed with the
  non-threaded build, and turning it on restricts the page's sandbox.
- Visibility: Draft until verified, then Public.

## 4. Verify (non-negotiable gates before telling the client it's live)

1. Open the itch.io page in a real browser (Playwright: use
   `/opt/pw-browsers/chromium`). Click through the itch launch button.
2. The Godot loading bar must appear immediately (this IS the splash screen —
   Godot's web shell shows progress while the 50MB wasm+pck stream in).
3. Level 1 boots: cowboy Lil Blunt on the first platform, HUD visible.
4. Console (F12): zero errors. Specifically NO "SharedArrayBuffer is not
   defined" — if you see that, thread_support got flipped back to true.
5. Screenshot the running embed and attach it to STATUS.md / the response.

## 5. After every deploy (ALWAYS-SHIP rule applies)

- STATUS.md: note version, itch URL, verification result
- Commit + push; merge to master after the milestone verifies
- The client-facing link is https://youngstunners88.itch.io/lil-blunt-adventure

## Gotchas learned the hard way

- itch.io zip MUST have index.html at the root — `cd web/game && zip -r ...`,
  never zip the parent folder.
- GitHub `secrets.*` can't be used in step `if:` — export to env and test
  `-z "$BUTLER_API_KEY"` in the script body instead.
- butler push target format is `user/game:channel` — the `html5` channel name
  is what makes itch treat it as a browser game.
- The CI commits `web/game/` back to the branch — after any push that triggers
  an export, `git pull` before further local commits or you'll diverge.
- Godot's `canvas_resize_policy=2` (adaptive) is correct for itch's resizable
  embed; don't hardcode canvas size in a custom HTML shell.
