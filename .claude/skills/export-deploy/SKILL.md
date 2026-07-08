---
name: export-deploy
description: Export the Godot game to web via CI and deploy launcher+game to Vercel. Use when the user says "deploy", "ship it", "update the live game", or after gameplay changes need to reach https://lil-blunt-game.vercel.app.
---

# Export & Deploy — Cloud Pipeline (no desktop needed)

The whole pipeline runs remotely: GitHub Actions exports the Godot game,
Vercel serves it. This encodes the exact procedure that works, including
every trap already hit and fixed. Do not re-derive it.

## Steps

1. **Push game changes** to the working branch. Any change under `src/**` or
   `project.godot` triggers `.github/workflows/export-game.yml` automatically
   (it downloads Godot 4.3 + templates, imports, exports to `web/game/`, and
   commits the build back to the branch).
2. **Watch for the CI auto-commit** — poll `git ls-remote origin <branch>`
   for the head to advance past your pushed SHA (~3-5 min). If it doesn't
   advance in ~10 min, fetch the failed run's logs via the GitHub MCP
   (`actions_list` → `get_job_logs`). NOTE: direct `api.github.com` calls
   through the sandbox proxy sometimes return empty/403 — trust the MCP tools
   or `git ls-remote`, not raw curl.
3. **Pull the export commit**: `git pull origin <branch>`.
4. **Deploy**: `npx -y vercel deploy --prod --yes --token "$VERCEL" --scope youngstunners88s-projects`
   (run from repo root; `vercel.json` sets `web/` as the output dir).
5. **Verify live** (all must pass):
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" https://lil-blunt-game.vercel.app/            # 200
   curl -s -o /dev/null -w "%{http_code} %{content_type}\n" https://lil-blunt-game.vercel.app/game/index.js   # 200 application/javascript
   curl -sI https://lil-blunt-game.vercel.app/ | grep -i cross-origin   # COOP+COEP present
   ```

## Known traps (already encoded in config — do not regress)

- Godot templates dir is `~/.local/share/godot/export_templates/4.3.stable`
  (dot, NOT the `4.3-stable` release-tag spelling).
- `vram_texture_compression/for_mobile=true` without ETC2/ASTC project import
  fails export with a BLANK error (Godot 4.3 bug). It stays `false` until
  real sprite textures land together with `import_etc2_astc=true`.
- Import must run in a separate `--editor --quit` pass before `--export-release`.
- `web/game/*` re-exports overwrite the SAME filenames → cache headers must
  stay `max-age=0, must-revalidate` (never `immutable`), and the service
  worker stays network-first.
- The launcher boots the game via an iframe of `game/index.html` (Godot's own
  shell). Never hand-construct `new Engine(...)` in launcher.js.
- Local git pushes: if the default remote 403s, set
  `origin` to `https://youngstunners88:${GITHUB_API_KEY}@github.com/youngstunners88/GM-GAME.git`.
