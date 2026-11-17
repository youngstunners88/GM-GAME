---
name: ep2-revisit-route-integrity
description: Episode 2 lets Lil Blunt walk or ride BACK through rooms he has already finished (Ep2WorldRoutes - facility, lift, woods, town, lake trail, lake). This skill owns the integrity of those return routes - every boundary has a way back, a revisited room can never resolve into silence and freeze, what he carries across (saddle, horse, eye height, pace, gaze) is read from the room he is leaving, and nothing he must own is demanded behind a one-way door. TRIGGER on "stuck in town", "can't get back to the lake / trail / Dude's", "froze after mounting", "frozen at the rail", "floating / too tall / too fast on foot", "horse vanished or is somewhere else", "horse followed me but I left it", "went back to town and ...", "turn back to town", "dead end", "the run just ended at the ridge", "needs the Sharps", any edit to world_routes.gd, any new room boundary, any new `_resolve(...)`, any new required item.
argument-hint: "audit | trace <room> | add-boundary | fix"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Revisit routes: every way in has a way back, and nothing freezes

Found by the full audit of 2026-11-17 (`docs/episode2-quality/full-audit-2026-11-17/AUDIT.md`). The forward story chain was covered by
`ep2-state-transition-audit`; the free travel back through finished rooms was covered by nothing, and held two soft-locks:

- back in town after the first ride out, `[E]` at Dude's rail resolved a room nobody was listening to: `_running = false`, frozen for good;
- the revisited town had no boundary back to the lake trail at all, on foot or in the saddle. The rest of the story was unreachable.

Single responsibility: **the return routes between retained rooms**. Not the forward chain (`ep2-state-transition-audit`), not seams and
teleports (`ep2-one-world-no-e-teleport`), not blackouts (`ep2-no-blackouts`).

## Files this skill owns

| File | What |
|---|---|
| `src/episode2/session/world_routes.gd` | `park`, `travel`, `tick`: every boundary and everything carried across it. ONE-SPACE indent. |
| `src/episode2/chamber/gold_town.gd` `can_mount_departure` | the first-departure mount; closed on a revisit |
| `src/episode2/chamber/logans_lake.gd` (the `WALK_ON_Z` hand-over, `_sharps_told`) | the Sharps check before the one-way ridge |
| `tests/ep2_audit_1117_test.gd` / `.tscn` | the gate (`EP2_AUDIT_1117: ALL PASS`, 22 checks), in CI |
| `tests/ep2_world_routes_test.gd` | the older route gate (29 checks); keep both green |

## The four rules

### 1. The boundary table is symmetric
Every row has a return row, on the same physical line, with hysteresis. Keep this table true; a new room adds two rows or says ONE-WAY.

| From -> to | Condition (in `tick`) | Back |
|---|---|---|
| lake trail -> gold town | departure area, trail `z > TOWN_LINE_Z` (118), town parked | town -> trail: revisit, trail parked, town `z < DEPART_HORSE.z + TOWN_LINE_Z - TOWN_LINE_BACK` |
| lake trail -> woods | departure area, trail `z < -78.5` | woods -> trail: revisit, `z > 1152`, trail parked (else -> town) |
| lake trail -> lake | shore run done, lake parked | lake -> trail: `z < SPAWN.z - 0.7` |
| gold town -> woods | `z < 1150` (only before the first ride out; afterwards the trail owns that ground) | woods -> town: revisit, `z > 1152`, trail NOT parked |
| woods <-> mine lift, mine lift <-> facility | the lift pad / the doorway plane | symmetric already |
| lake -> day-88 ridge, ridge -> lake (after day-88), lake -> auction road | story hand-overs | **ONE-WAY** (see rule 4) |

Once he has ridden out of town, the ground between town `z` 1150 and 1348 (Dude's ranch, the lake road) belongs to the **trail**, which
carries the town's own streets (`adopt_departure`). Never route a revisit into the town room on that ground.

### 2. A revisited room cannot resolve into silence
`park()` disconnects `chamber_cleared`; `travel()` reconnects it only for a `continuing_story` room. So on a revisit, any path that reaches
`_resolve(...)` sets `_running = false` with no listener: a frozen player and no error. For every `_resolve` in a room that can be
revisited, either the path is closed on `_world_revisit` (the town's mount), or `tick` takes the player away first (the trail's shore run),
or the room is `continuing_story`. Check with:

```bash
grep -n "_resolve(" src/episode2/chamber/*.gd          # each hit: can it run while _world_revisit is true?
```

### 3. What crosses a boundary is read from the room he is leaving
`mounted` / `horse` are set from `LakeTrailChamber.is_mounted()` when the trail is parked, and cleared when he is back on the trail. They are
never remembered from an earlier leg (a horse left drinking at the lake used to "carry" him through town: saddle height, riding pace, no
horse). The horse node is reparented back under the trail's `_visuals` on return. On foot in the woods or town his eye height is
`FPS_EYE_HEIGHT` and his pace is the room's own (`_foot_pace`). Gaze: the town and the woods share the trail's axes (translation only);
only the lake is rotated (`lake_transform()`), so only lake <-> trail converts the yaw.
A retry snapshot is a carried thing too: the trail's `_armory_snapshot` is retaken on every arrival, so a retry of the ride restores what
he carries on THIS leg (the snapshot of its first minute used to wipe gear bought since, with the BTC already spent).

### 4. No required item behind a one-way door
If a room needs something (the day-88 ridge needs the Sharps; the lake ride needs the Shipment) the check happens in the LAST room that
still has a way back to where it is sold, and it says what and where. The ridge's own `BLOCKED` beat stays as a backstop for old saves only.
A new "needs X" is a finding until you can name the room that turns him round.

## Method (audit / add-boundary)
1. Read `world_routes.gd` whole (it is short). Rebuild the table above from `tick`; diff it against this file.
2. For each row, find the return row. None = P0. Different line or no hysteresis = P1 (ping-pong).
3. Run rule 2's grep; classify every hit.
4. List every field `travel()` copies or sets on the arriving room; for each, say which room it is read from.
5. Add the case to `tests/ep2_audit_1117_test.gd` through the production `tick`/`travel` (never set `_active` by hand to "arrive"), prove it
   fails without the fix, then fix.

## Definition of Done
- [ ] `tests/ep2_audit_1117_test.tscn` prints `EP2_AUDIT_1117: ALL PASS` (pinned check count updated) and `tests/ep2_world_routes_test.tscn` prints `29 checks, 0 failed`.
- [ ] The new or changed check was seen to FAIL on the unfixed code (paste both lines).
- [ ] The gates of every room touched are green (`ep2_gold_town`, `ep2_lake_trail`, `ep2_logans_lake`, `ep2_horse_and_logan`, `ep2_river_cover`, `ep2_fix_document`, `ep2_playtest_dude`).
- [ ] **Hard-refresh proof on the live build** (Ctrl+Shift+R on the itch page, BUILD tag read from the title screen): `?playtest=dude`, buy
      the horse, mount, ride north up the street into town, turn round, ride back out past Dude's and on toward the lake; then once more
      on foot. Record what happened at each line of the table you touched.
- [ ] The residual evidence table below is filled in and copied into the report.

## Residual evidence table (mandatory in every report)

| Boundary / rule | Headless gate (check name, PASS line) | Failed before the fix? | Local web export seen? | Live hard-refresh seen? (build tag, who) | Status |
|---|---|---|---|---|---|

Status is one of `IN CODE`, `GATED` (headless), `SEEN LOCAL` (real renderer, local export), `SEEN LIVE` (hard refresh on itch),
`FOUNDER-VERIFIED`. Leave a cell empty rather than guess.

## Never claim FIXED without live evidence
A headless gate proves the logic, not the play. Until the live column holds a build tag and what was seen, the words are
"pushed / deploying" or "gated, not seen live" - never "fixed", never "works", never "verified". No founder report is closed on a
headless run.
