---
name: itch-butler-deploy
description: Diagnose and (with explicit founder OK) execute a manual itch.io HTML5 deploy via butler — for when CI's auto-deploy is unset/broken and the founder is testing fixes against a stale live build. Never pushes to the public itch page without explicit confirmation. Run when a founder reports "still broken live" after a fix was committed, or asks about itch/butler/deploy status.
user-invocable: true
allowed-tools: Read, Bash
---

# itch.io / butler Deploy

## When to use this

- Founder reports a fix is "still broken live" — before re-diagnosing game
  code, check whether the live build actually contains the fix at all (see
  `live-build-proof` for the full diagnostic order).
- Founder asks "is butler working / can we deploy / what's on itch right
  now."
- CI's export workflow shows the butler step skipped or failed.

## Step 1 — is auto-deploy even wired up?

`.github/workflows/export-game.yml` pushes to itch on every push to
`master` and `claude/**`, but the deploy step is gated:

```
if [ -z "$BUTLER_API_KEY" ]; then
  echo "::notice::BUTLER_API_KEY secret not set — skipping itch.io deploy."
  exit 0
fi
```

If the `BUTLER_API_KEY` **repo secret** (Settings → Secrets → Actions) is
unset, **every push exports but never deploys** — the live itch page stays
on whatever was last uploaded manually, silently, with no error. This is
indistinguishable from "the fix didn't work" unless you check for it
explicitly. Check the workflow file and/or ask whether that secret exists;
you cannot read repo secrets directly, only confirm the workflow expects
one under that exact name (see `env-secrets-and-apis` for the session-key
vs. repo-secret distinction — a session `ITCH_API_KEY`/`BUTLER_API_KEY`
does NOT make this CI step fire; only the repo secret does).

## Step 2 — can THIS session deploy manually?

Run the `env-secrets-and-apis` presence scan for `ITCH_API_KEY` and
`BUTLER_API_KEY`. Either name being present means this session holds a
working butler credential (they're the same credential family) and can
push a build right now.

## Step 3 — manual deploy, ONLY with explicit founder confirmation

**Pushing to the live public itch.io page is an outward-facing, visible
action. Always get explicit confirmation before doing it** — "deploy this
fixed build to itch now" or equivalent. Do not infer consent from "please
fix this" alone.

Once confirmed:

```bash
# 1. Fresh export (must stay non-threaded — see export_presets.cfg
#    variant/thread_support=false; threaded web builds silently fail to
#    boot on itch.io).
mkdir -p /tmp/itch-deploy
./.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
  --export-release Web /tmp/itch-deploy/index.html

# 2. Fetch the CI-pinned butler binary to a SEPARATE directory (not the
#    game dir — butler must not end up inside the pushed build).
mkdir -p /tmp/butler-bin && cd /tmp/butler-bin
BUTLER_SHA256="746de1eb9e0b8aba2b8aa766d3cfeacd92d69bcf06acf571a5b9a0faf28e3733"
curl -fsL --retry 3 -o butler.zip \
  "https://broth.itch.zone/butler/linux-amd64/15.28.0/archive/default"
echo "${BUTLER_SHA256}  butler.zip" | sha256sum -c -   # never skip this
unzip -oq butler.zip; chmod +x butler

# 3. Push. Use whichever key name env-secrets-and-apis found present.
LD_LIBRARY_PATH=/tmp/butler-bin BUTLER_API_KEY="$ITCH_API_KEY" \
  ./butler push /tmp/itch-deploy youngstunners88/lil-blunt-adventure:html5

# 4. Confirm it actually landed (don't just trust "push" exiting 0).
LD_LIBRARY_PATH=/tmp/butler-bin BUTLER_API_KEY="$ITCH_API_KEY" \
  ./butler status youngstunners88/lil-blunt-adventure:html5
```

`butler status` showing a NEW build number that differs from before the
push (and ideally a nonzero patch/delta size vs. the prior build) is the
proof the push changed something — a 0-byte patch against an identical
build means you deployed the same thing that was already live.

If the SHA256 checksum ever needs to change (butler version bump), pull
the new pinned version + hash from `.github/workflows/export-game.yml` —
never fetch an unpinned "latest" butler binary; this step holds a real API
key.

## What this skill does NOT do

- It does not touch the `BUTLER_API_KEY` repo secret — that requires
  founder action in GitHub settings, not something callable from here.
- It does not merge branches or touch `master`. Deploying a build to itch
  and merging PR #12 are two independent actions; do not conflate "the fix
  is live on itch" with "the fix is merged."
- It never proceeds past Step 3 without the explicit confirmation
  described there.
