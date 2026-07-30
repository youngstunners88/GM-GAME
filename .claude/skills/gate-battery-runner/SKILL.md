---
name: gate-battery-runner
description: Runs the project's full 8-gate verification battery (script compile, real export, v1.0 campaign, v1.2 shooter, save-compat, ICP contract, security sentinel, boss visibility) in one pass and reports a single PASS/FAIL per gate plus an overall verdict. Use before claiming any change "works", before /release-game, and before merging a working branch into master.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# Gate Battery Runner

Every session log for this project ends the same way — a hand-typed line like
`gdparse/can_instantiate (109 scripts + 74 scenes) · export (0 script errors) ·
v1.0 5/5 · shooter 6/6 · save-compat 18/18 · icp-contract 13/13 · security-
sentinel 18/18 · boss-visibility ALL PASS`. That line was always assembled by
re-running eight separate commands from memory. This skill IS that line —
run it instead of retyping it.

**Do not invent new gates here.** This skill wires up checks that already
exist in the repo (`tests/*.tscn`, `scripts/*.mjs`, `scripts/security-sentinel.sh`).
If a gate's underlying script changes, update the command below in the same
commit — a runner that calls a stale path is worse than no runner.

## Before running anything

1. **`git status`** — the security sentinel (gate 7) scans `git ls-files`.
   If you have new/changed files not yet `git add`ed, it silently scans
   nothing and false-passes. Stage first, gate second.
2. Confirm whether a local Godot binary exists: `command -v godot godot4 2>/dev/null`
   and `ls /opt/godot-4.3/Godot 2>/dev/null`. **This remote sandbox typically
   has none** — gates 1, 2, 5, 6, and 8 need `godot --headless`, which only
   runs in CI or on a developer machine. When no local binary exists, mark
   those gates `NOT RUN (no local Godot) — deferred to CI` rather than
   skipping them silently or claiming a pass. Do not report "8/8 green"
   without either a local run or a linked green CI run to point to.
3. Confirm a served build exists for gates 3–4: `ls web/game/index.html`.
   If missing, `node scripts/export-web.sh` (or wait for CI's export
   artifact) before those gates can run against `localhost`.

## The 8 gates

| # | Gate | Command | Pass criteria |
|---|------|---------|----------------|
| 1 | Script compile / can_instantiate | `godot --headless res://tests/script_compile_test.tscn` | Output ends `SCRIPT_COMPILE: ALL PASS`, exit 0. **`gdparse` alone is NOT this gate** — it is syntax-only and passes files a real compile rejects (mixed tabs/spaces, bad `:=` inference). Use `gdparse <file>.gd` only as a fast pre-check on a single changed file, never as proof. |
| 2 | Real web export | `"$GODOT_BIN" --headless --export-release "Web" web/game/index.html` | Log contains zero `SCRIPT ERROR` lines. A scene loading with no script attached does NOT error here — that's the exact failure mode gate 1 exists to catch, so never treat "export succeeded" alone as sufficient. |
| 3 | v1.0 campaign (browser) | `node scripts/serve-web.mjs 8899 web &` then `node scripts/verify-game.mjs "http://localhost:8899/game/index.html"` | `game-verify.json` → `"passed": true`. 5 sub-gates: canvas_attached, engine_booted, no_godot_errors, thread_support, level_1_runs. |
| 4 | v1.2 shooter prototype (browser) | `node scripts/verify-shooter.mjs "http://localhost:8899/game/index.html"` | Reaches PLAYING in the prototype room, fires without new script errors. |
| 5 | Save-format compatibility | `godot --headless res://tests/save_compat_test.tscn` | All `_check()` assertions PASS — covers v1-save-still-loads, self-heals history, round-trip preserves progression, hostile-save clamped, crypto state not persisted. A single FAIL here means an existing player's save could break on load; never wave this one through. |
| 6 | ICP contract (client half) | `godot --headless res://tests/icp_contract_test.tscn -- <base-url>` | All assertions PASS. **Requires a mock HTTP server** at `<base-url>` (default `http://127.0.0.1:8788`) returning the exact JSON `price_feed.mo`'s `http_request` emits — this test does not stand one up itself. If no mock is running, report this gate `NOT RUN (no mock server)`, not a pass and not a battery-wide fail; it does not prove the canister half regardless (no local replica in this sandbox — see `.claude/context-manifests/icp.md`). |
| 7 | Security sentinel | `./scripts/security-sentinel.sh --log` | Exit 0, 0 blockers at the `--fail-on=high` default. Run AFTER staging changes (`git add`) — see "Before running anything" above. `--log` appends the run to `docs/security/audit-log.md` automatically; that's the audit trail, don't duplicate it by hand. |
| 8 | Boss visibility | `godot --headless res://tests/boss_visibility_test.tscn` | All three bosses (Auditor, Distributor, Claim Jumper) resolve a texture, stay visible up the parent chain, non-zero alpha. Exists because Stage 2/3 bosses shipped invisible once and nothing else caught it. |

## Running it

Execute gates in order; **do not stop at the first failure** — collect all
eight results, then report. A developer fixing gate 2 wants to know if gate 7
is also broken before starting a second round-trip.

```bash
# Stage everything first (gate 7 depends on it)
git add -A && git status --short

# Gates 3-4 need a served build + background static server
node scripts/serve-web.mjs 8899 web &
SERVER_PID=$!

# Run gates 1,2,5,6,8 only if a local Godot binary was found in step 2 above.
# Otherwise note them as CI-deferred and check the latest export-game.yml run.

kill $SERVER_PID
```

## Report format

Always end with a single collapsed line matching the project's existing
convention, plus a short table for anything that failed or was not run:

```
Gate battery: 1 [NOT RUN - CI] · 2 [NOT RUN - CI] · 3 [PASS 5/5] · 4 [PASS] ·
5 [NOT RUN - CI] · 6 [NOT RUN - no mock] · 7 [PASS 0 blockers] · 8 [NOT RUN - CI]
```

If ANY gate reports FAIL (not NOT RUN), the verdict is **FAIL** — do not ship,
do not merge to master, do not tell the client anything works. Fix, re-run
the failed gate(s) only (no need to re-run gates that already passed), then
re-report.

If all locally-runnable gates PASS and the rest are legitimately CI-deferred,
state that plainly and point to the CI run that covers the deferred gates —
never claim "all 8 green" on the strength of a partial local run.
