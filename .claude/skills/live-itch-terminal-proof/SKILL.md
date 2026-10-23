---
name: live-itch-terminal-proof
description: Prove what PLAYERS get on itch.io from the terminal, before anyone says "shipped", "live" or "fixed". Runs scripts/live-itch-probe.mjs (real Chromium on the game iframe, reads the game's own [BUILD] and [EP2] log lines). TRIGGER on any claim about a deploy or a fix being live, "is it shipped", "did it go live", "nothing shipped", "the update isn't there", a browser agent's report about the live build, or before writing any status line that says live/shipped.
---

# Live proof from the terminal (founder rule, 2026-10-20)

The terminal is the strongest tool here. Do not hand a live check to a browser agent or to the founder's browser, and do not
say "live" from a page loading or a green CI run.

## The one command
```
node scripts/live-itch-probe.mjs --expect <tag-prefix> --extras --logan --shot /tmp/live.png
```
`--expect` = the first 7 characters of the merged master commit (the game prints a 7-character tag, e.g. `2026-10-19-6fc7e4d`).
`--extras` = also require the streamed-pack line `[EP2] extras ready`. Exit 0 only when every asked check passes.
The probe loads the game iframe that the public itch page embeds (not the page itself), so it tests what players run.

## What "live" needs (all of them, in this order)
1. `git log origin/master` contains the change (SHA).
2. The master CI run is `success` and its butler step prints `Pushed to ...` (`gh run view <id> --log`, strip ANSI).
3. `scripts/live-itch-probe.mjs --expect <sha7> [--extras]` exits 0.
4. Only then: "live", with the probe output pasted.

If (3) fails, the answer is "pushed, not live" and the probe's own output is the evidence. Never call it fixed on a branch alone.

## Rules that stop the repeat failure
- A browser agent's diagnosis is a HYPOTHESIS until reproduced. Check it like a browser would: on 2026-10-20 a `curl` without
  `Accept-Encoding` "disproved" the (correct) gzip cause; with `-H "Accept-Encoding: gzip"` the CDN gzips and sends the compressed
  Content-Length. See skill `ep2-streamed-extras-web`.
- Reproduce the EXACT failing line in the same environment before writing a fix (the live probe log, not a local server). Local
  "extras ready" with a local server proved nothing about itch.
- `butler` needs `~/.local/bin/butler` (15.28.0, sha256 746de1eb...) and a login (`butler login`, run by the founder in a terminal).
  `butler status youngstunners88/smokerealm:html5` shows processing/ready.
- I cannot run `scripts/ship-to-master.sh` myself (permission classifier). Say so and give the founder the exact command.
- Do not re-ship an unchanged master. Check master first.

For Logan releases, `--logan` also requires the delivered skin (65 bones) and four clips to load. It uses `ep2lakeprobe=1`, a read-only diagnostic behind the access prompt; it does not unlock gameplay or claim a public playthrough.
