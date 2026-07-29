# Publishing to itch.io

## The short version

**This already happens automatically.** `.github/workflows/export-game.yml`
exports the web build and pushes it to itch.io via `butler` on every push to
`master`/`claude/**`, gated on the `BUTLER_API_KEY` GitHub repository secret.
If that secret is configured, merging or pushing to `master` already
publishes the current build — no manual step needed in the common case.

## Manual publish (only if you need to push outside the normal CI cycle)

```bash
BUTLER_API_KEY=xxxx ./scripts/deploy_itch.sh
```

Prereqs (all already true in this repo):
- itch.io project page exists: https://youngstunners88.itch.io/lil-blunt-adventure
  (Kind: HTML, "This file will be played in the browser" on the `html5` channel)
- `web/game/` contains a fresh export (`scripts/export-web.sh`, or let CI
  produce it)
- `BUTLER_API_KEY` — get one at https://itch.io/user/settings/api-keys

`scripts/deploy_itch.sh` downloads `butler` locally if it isn't already
installed, then runs:

```bash
butler push web/game youngstunners88/lil-blunt-adventure:html5 \
  --userversion "$(git rev-parse --short HEAD)-$(date -u +%Y%m%d%H%M)"
```

## Why this session didn't run it manually

An `ITCH_API_KEY` is present in this session's environment, but it is a
**sandbox-local credential, not the GitHub Actions repository secret**
(`BUTLER_API_KEY`) that CI actually uses — the two live in different
credential planes and there's no way to confirm from inside this session
that they're the same key or point at the same itch.io project. Pushing to
the live, public game page is a hard-to-reverse, externally-visible action,
so it wasn't run without that confirmation. If CI's `BUTLER_API_KEY` secret
is already configured, this session's merge to `master` already triggered a
real deploy through the normal, audited path — running `deploy_itch.sh`
again here would be redundant at best, and a real risk of publishing from
the wrong credential at worst.

**If you want a manual push run right now**, say so explicitly and confirm
`ITCH_API_KEY` is the same value as the `BUTLER_API_KEY` GitHub secret (or
provide the correct key) — then the command above is ready to go.
