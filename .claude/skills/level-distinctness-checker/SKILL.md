---
name: level-distinctness-checker
description: Detects levels that are copy-paste reskins of each other — duplicated ground/platform geometry, missing per-level colour/particle/reverb/music identity, and set pieces that are renamed copies. Run after editing level data or LevelBase, and before adding any new stage.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# Level Distinctness Checker

Written because **Gold Rush shipped as a byte-identical copy of Crystal
Caverns' platforming skeleton** and nobody noticed for weeks. The reason it
hid so well is the instructive part:

- The two levels had **genuinely different, expensive backdrop art**
  (sunset canyon vs. cyan crystal cave) — so screenshots looked distinct.
- They had **different music, different reverb profiles, different enemies,
  different collectibles, different set pieces.**
- But `ground_segments` and `platforms` in `level_03_data.tres` were
  **character-for-character identical** to `level_02_data.tres`. The actual
  ledges the player stands on for 90% of play were the same level twice.
- Worse: `level_base.gd` painted every level's ledges with the **same
  hardcoded dark-green** regardless of theme, so even the backdrop's
  distinctness never reached the geometry.

Nothing in the gate battery can catch this. It compiles, boots, and plays.

## Check 1 — Geometry duplication (the one that actually fired)

Compare the geometry arrays of every level data resource pairwise.

```bash
# Extract just the geometry blocks and diff them
for f in src/resources/level_0*_data.tres; do
  echo "=== $f ==="
  sed -n '/^ground_segments/,/^])/p;/^platforms/,/^])/p' "$f"
done
```

Then diff any two levels directly:

```bash
diff <(sed -n '/^ground_segments/,/^])/p;/^platforms/,/^])/p' src/resources/level_02_data.tres) \
     <(sed -n '/^ground_segments/,/^])/p;/^platforms/,/^])/p' src/resources/level_03_data.tres)
```

Verdicts:
- **Identical** → FAIL. This is the shipped bug.
- **>70% of coordinates shared** → FAIL. A few nudged numbers is still a
  reskin.
- **Same count and similar spacing rhythm but different values** → WARN.
  Look at whether the *pacing* differs (gap widths, height variance, run
  lengths), not just the literals.
- **Structurally different** → PASS.

When rewriting a duplicated layout, keep every gap width inside the range
already proven jumpable in the shipped levels — distinctness must not come at
the cost of a level that can't be completed. Measure the existing gaps first.

## Check 2 — Per-level identity fields are actually set

For each level, confirm these differ from the other levels:

| Field | Where | Notes |
|---|---|---|
| `background_path` | `*_data.tres` | must be a distinct file — **verify the file exists and `md5sum` differs**, not just that the path string differs |
| `boss_background_path` | `*_data.tres` | same |
| `platform_body_color` / `platform_lip_color` | `*_data.tres` | added specifically because these used to be hardcoded in `level_base.gd`; a level not setting them silently inherits the default |
| reverb profile | `level_XX_*.gd` → `AudioManager.set_reverb_profile()` | |
| music playlist | `level_XX_*.gd` → `AudioManager.play_playlist()` | verify the `.ogg` files exist on disk |
| ambient particles | `level_XX_*.gd` | atmosphere a static backdrop cannot provide |

```bash
grep -n "platform_body_color\|platform_lip_color\|background_path" src/resources/level_0*_data.tres
grep -n "set_reverb_profile\|play_playlist" src/level/level_0*.gd
```

**Verify assets exist** — a distinct path pointing at a missing file is worse
than a shared one:

```bash
for p in $(grep -ho 'res://src/assets/[^"]*' src/resources/level_0*_data.tres | sort -u); do
  f="${p#res://}"; [ -f "$f" ] && echo "OK   $p" || echo "MISSING $p"
done
```

Also `md5sum` the backdrops against each other — two different filenames
pointing at the same image is the same failure wearing a disguise.

## Check 3 — Set pieces are real, not renamed copies

Each level should have at least one signature interaction that is not just
another level's mechanic with a new label.

Current inventory (keep this updated):

| Level | Signature set piece | Distinct mechanic? |
|---|---|---|
| 1 Smoke Realm | Blaze portal → Blaze Rush | yes |
| 2 Crystal Caverns | full-height ladder escape shafts over deadly pits | yes |
| 3 Gold Rush | pressure-plate **timed gate** race + Fort Knox Vault | yes |

Flag as WARN when two levels' set pieces resolve to the same underlying scene
with only a `room_title` or colour changed. (The Fort Knox Vault reuses
`hall_of_blaze.tscn` — that is acceptable *because* the timed gate carries
Level 3's distinct identity. A level whose ONLY set piece is a reskin fails.)

## Check 4 — Placement sanity after any layout change

This is the follow-on failure: when Gold Rush's geometry was redesigned, the
Fort Knox Vault's hardcoded `x=3550` — fine under the old layout — landed
over the new layout's pre-boss pit.

For every hardcoded world position in `level_XX_*.gd` (vaults, ladders,
secret walls, pressure plates, portals), confirm it sits on a real
`ground_segments` span or platform:

```bash
grep -n "global_position = Vector2(" src/level/level_0*.gd
```

Cross-check each x against the level's `ground_segments` — every entry is
`Vector4(x, y, width, height)`, so the solid spans are `x .. x+width`. A prop
whose x falls in a gap is floating or unreachable.

## Output format

```
LEVEL DISTINCTNESS REPORT

Check 1 Geometry duplication .. PASS / WARN / FAIL   [pairwise matrix]
Check 2 Identity fields ....... PASS / FAIL          [per-level table]
Check 3 Set pieces ............ PASS / WARN          [inventory]
Check 4 Placement sanity ...... PASS / FAIL          [per-prop x vs spans]

VERDICT: DISTINCT / RESKIN RISK / DUPLICATE
Blocking: <specifics>
```

Check 1 FAIL and Check 4 FAIL are blocking — one is the shipped bug, the
other is how fixing it breaks props. Checks 2–3 are advisory.

## When to run

- After ANY edit to `src/resources/level_*_data.tres`
- After ANY edit to `src/level/level_base.gd` (it owns the shared rendering
  path — a hardcoded value there flattens every level at once)
- Before adding a new stage, against all existing stages
- Before a release gate

Pair with `boss-fight-auditor`: that one covers the boss at the end of the
level, this one covers the level leading to it. Neither is covered by
`gate-battery-runner`, which only proves the game compiles and boots.
