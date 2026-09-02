# Nightly Hardening Routine — spec, scripts, skills, prompt

**Goal:** wake up to *proven* bug and vulnerability fixes on a reviewable draft
PR — never to an unreviewed change on the live game.

---

## 1. The one hazard that shapes the whole design

`.github/workflows/export-game.yml` exports **and auto-deploys to itch.io via
butler** on every push to `master` **or `claude/**`**. So an unattended run that
pushes to a `claude/**` branch **publishes to the live public game while you
sleep**, with nobody having played it.

**Therefore the routine works on `nightly/hardening-<date>`** — a branch prefix
CI does not build or deploy — and it **opens a draft PR and stops**. You merge in
the morning; merging is what triggers the deploy, with you awake.

> Want the opposite (ship straight to itch overnight)? That's a one-line change
> to the branch prefix, but it's your call to make explicitly — see §6.

---

## 2. What runs, in order

| # | Step | Tool | Blocking? |
|---|------|------|-----------|
| 1 | Sync `master`, cut `nightly/hardening-<date>` | git | — |
| 2 | **Pattern sweep** — the bug classes that have actually shipped | `scripts/bug-pattern-scan.sh` | CRITICAL blocks the PR |
| 3 | **Security sentinel** — 18 checks | `scripts/security-sentinel.sh` | must be 18/18 |
| 4 | **Secret scan** (full history) | gitleaks (also in CI) | any hit = stop + report |
| 5 | **Gate battery** — the headless real-physics suite | `tests/*.tscn` | red gate = finding |
| 6 | **Triage** findings against the skill's catalogue | `gm-nightly-hardening` | — |
| 7 | **Fix 1–3 highest-confidence items**, one commit + one gate each | — | gate must fail pre-fix |
| 8 | Re-run 2–5, write `docs/ops/nightly-reports/<date>.md`, draft PR | — | — |

---

## 3. Scripts

- **`scripts/bug-pattern-scan.sh`** *(new — the engine of this routine)*
  Greps the repo for every bug **class** this project has shipped and had
  rejected: zero-scale live colliders, embed probes missing
  `recovery_as_collision`, stranded `time_scale`/`paused`, physics writes during
  a flush, coroutine-after-free, stranding state flags, hardcoded addresses.
  Discriminates a *live prop* (real bug) from a *dying entity* (triage note).
  `--strict` also fails on HIGH. Exit 2 = CRITICAL.
  *Already earning its keep: on its first run it found the `timed_door` freeze —
  the same zero-scale-collider class as the blue block, with a 0.5s window.*
- **`scripts/security-sentinel.sh`** *(existing)* — 18 security checks, `--log`
  appends to `docs/security/audit-log.md`.
- **`.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/<t>.tscn`**
  — the gate battery. Budget ~1–3 min per gate; run the freeze/boss/player set
  every night, the full 70+ only on a weekly pass.

---

## 4. Skills

**Author/installed for this routine**
- **`gm-nightly-hardening`** *(new — read it first every run)*: the safety rails
  for unattended work plus the bug-class catalogue and triage rules.

**Existing, used by the routine**
- `game-security-sentinel` — autonomous security scanning (self-activating).
- `secure-build-checklist` — the deeper 47-check pass, weekly.
- `gate-battery-runner` — runs the verification battery in one pass.
- `gm-game-boss-fsm-trace` — freeze taxonomy + measure-first chase rules.
- `live-build-proof` — what "FIXED" is allowed to mean.
- `test-standards` (rule) — naming, arrange/act/assert, regression test per bug.

---

## 5. THE ROUTINE PROMPT (this is what the Routine fires)

```
Autonomous nightly hardening pass on GM-GAME. No founder is awake — follow the
rails exactly.

FIRST: read .claude/skills/gm-nightly-hardening/SKILL.md and obey it. The rails
that matter most: never push to master or claude/** (CI auto-deploys those to the
LIVE itch.io game), never merge, one fix per commit with its own gate, and every
gate must be proven to FAIL before the fix and PASS after.

1. git fetch; branch nightly/hardening-$(date +%Y-%m-%d) from origin/master.
2. Run: bash scripts/bug-pattern-scan.sh
         bash scripts/security-sentinel.sh
   Then the freeze/boss/player gate set:
     player_freeze_recovery, breakable_block_no_freeze, big_mode_no_grow_wedge,
     player_solid_platform_land, level1_return_path, auditor_damage_kill_path,
     auditor_solid_wall_traverse, boss_visible_lunge
   (.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/<name>.tscn)
3. Triage every finding against the skill's catalogue. Separate:
   (a) mechanical + certain  (b) needs a judgement call  (c) false positive.
4. Fix ONLY the (a) items, at most 3, highest severity first. For each:
   - write/extend a gate that reproduces it, prove it FAILS on current code
   - fix it
   - prove the gate PASSES, and that the gate set in step 2 is still green
   - commit alone, with the root cause in the message
5. Do NOT touch tuning/feel constants (boss speeds, separations, multipliers,
   level geometry) — those need a founder hard-refresh.
6. Re-run step 2. Security sentinel must be 18/18.
7. Write docs/ops/nightly-reports/<date>.md:
   - what the scanner found, by class
   - what you fixed + the gate that proves each (name the pre-fail evidence)
   - what you deliberately did NOT touch and why (the (b) list — this is the
     most useful section for the morning)
   - anything still red
8. Push the nightly/ branch and open a DRAFT PR to master. Do not merge.
9. If anything is ambiguous, unreproducible, or would need a design decision:
   STOP, leave it in the report, and finish the run. Two proven fixes beat six
   guesses.
```

---

## 6. Knobs (your call, one line each)

| Knob | Default | Change to |
|---|---|---|
| Ship policy | draft PR on `nightly/**`, no deploy | push to `claude/nightly-*` to auto-deploy to itch overnight |
| Fix budget | max 3 per night | raise once you trust a few reports |
| Gate set | freeze/boss/player subset nightly | full 70+ battery on a weekly run |
| Depth | sentinel (18) nightly | `secure-build-checklist` (47) weekly |

---

## 7. Morning checklist (60 seconds)

1. Open `docs/ops/nightly-reports/<date>.md` — read the "deliberately did NOT
   touch" section first; that's where the judgement calls are.
2. Open the draft PR; scan one commit per fix, each with its gate.
3. Merge what you agree with → that's what deploys, with you awake to test it.
4. Hard-refresh and confirm the `BUILD` tag moved.
