# Critical defects: the 49x72 sprite that broke four "fixes" — 2026-08-07

Founder reported, with a screenshot, that several previously-"fixed" defects
are still live. Two of them (torch-at-feet, ladder top-out) had been claimed
fixed in earlier sessions. This log records the actual root cause.

## The shared root cause

Every prior fix computed positions against an **assumed 32px-tall sprite**
whose feet sat on `FEET_LOCAL_Y` (+16, the collision floor).

Measured this session, for the first time:

- `sprite_lil-blunt_cowboy.png` is **49x72**, opaque box y 9..58.
- With `_spr.position.y = FEET_LOCAL_Y - h/2 = -20`, the visible art spans
  local y **-47 (head) .. +2 (feet)**.
- So the art's feet are **14px ABOVE the collision floor line**.

Every calculation anchored to +16 therefore landed ~14px too low, and the
prior "fixes" were re-tuning offsets on top of a wrong premise — which is
exactly why they kept appearing fixed in code review and broken on screen.

The fix is structural: `_measure_art_bounds()` reads the real opaque rect
from the texture once per outfit swap and caches `_art_top_local` /
`_art_feet_local`. Anything that must sit "on the character" derives from
those, so re-generated art can't silently reintroduce this.

## Defects fixed, with evidence produced this session

**1. "Shadow block beneath his feet" — FIXED.**
Two `ColorRect`s (7x11, near-black) created in `_ready()` as procedural
"legs", from when Lil Blunt was a drawn rectangle. Their idle Y was
`feet_y + h/2 - 8` = **+8..+19**, i.e. 6px below the art's feet (+2) — a
solid dark block under him. The shipped art already has legs. Removed
entirely, along with all `_process()` references.
*Evidence: probe reports 0 ColorRect children under `Visual`.*

**2. Torch at the feet — FIXED.**
`_tool_base_y = 2.0 - (tex_h/2 - grip)` — the `2.0` was a hardcoded
hand height valid only for the assumed sprite. With the 36px torch that put
its centre at -7, spanning **-25..+11**: its bottom 9px BELOW the art's feet.
Now `hand_y = _art_top_local + 0.55 * (art_feet - art_top)` (measured), so
the torch spans **-47..-11** — entirely above the feet, flame at head height.
`set_outfit()` re-anchors an already-equipped tool so an outfit swap can't
strand it.
*Evidence: probe prints torch span vs measured feet; bottom < feet == true.*

**3. Ladder top-out unreachable — FIXED.**
`_update_climb()` topped out only when `global_position.y <= top_y() + 6.0`.
Climbing runs through `move_and_slide()`, so the player physically collides
with the underside of the platform sitting at the ladder top: with a 20px
platform and a 32px collision box, he stops ~36px below `top_y` and **can
never satisfy a 6px threshold**. He presses up forever under the platform.
This is why re-tuning `top_exit_offset` in earlier sessions never helped —
the offset was fine, the trigger was unreachable. Margin is now a documented
`LADDER_TOP_OUT_MARGIN = 44.0` (20 platform + 16 half-box + slack). Topping
out slightly early is harmless: `_top_out_ladder()` teleports to the defined
exit and nudges out of overlap regardless.
*Evidence: scripted climb of level-1 ladder1 ends at y=318, `is_on_floor()`
true, i.e. standing on the platform.*

**4. Tax Collector stuck behind a block — FIXED.**
Two compounding bugs in `tax_collector.gd`:
- `detect_x/detect_y` were 200/100 — he barely noticed the player.
- The jump gate was `if (wants_up or blocked) and absf(dx) <= max_jump_gap`
  with `max_jump_gap = 80`. So a **blocked** enemy whose target was more
  than 80px away never jumped. That is the reported "stuck behind the block":
  the gap guard (which exists to stop him leaping into pits) was wrongly
  applied to the obstacle-hop case.
Split the two reasons: `blocked` now hops unconditionally (a wall means he
cannot advance anyway, so jumping is strictly better), while `wants_up`
keeps the pit guard. Detection widened to 520/220, plus a separate
`pursue_keep_x/y` (1600/600) so once engaged he hunts across the stage
instead of disengaging after one screen.
*Evidence: player parked 500px away with a crate in his path — he engages
PURSUE, jumps, and passes the crate. Under the old gate he never jumped.*

## Not fixed / blocked

- **Protocol logos + founder mural.** The founder sent the artwork as chat
  images, not files, so the binaries cannot be written into the repo from
  here. No code change is needed — `_swap_placeholder_texture()` already
  watches `res://src/assets/logos/{smokering,diamonds,goldmine}.png` and
  `res://src/assets/art/founder_portrait.png`. Added a README in each folder
  with exact filenames and format notes.
- **The 9-item defect document** (Distributor damage, death-freeze, Blaze
  Rush complete/ESC resume, Blaze Rush reskin, Auditor facing, L2 boss pit,
  bigger levitating Distributor, Continue-vs-Restart) was NOT started. The
  founder's direct message listed five different, more specific defects with
  a screenshot; those were treated as the priority. Stated plainly rather
  than half-attempted.

## Evidence method note

In-browser screenshots were attempted and **failed to capture gameplay** —
a "Weekly Smoke Realm updates?" email-capture popup covers the main menu on
load and its SKIP button does not respond to synthetic Playwright clicks in
this headless/SwiftShader harness (the same class of limitation seen with the
pause menu). Rather than claim a screenshot I don't have, all four fixes are
evidenced by **behavioural/geometric probes run in the real Godot engine this
session** (built, run, deleted — not committed). That popup blocking first
load is itself worth addressing and is flagged in STATUS.

## Gates

`script_compile` (114 scripts / 77 scenes), `boss_arena_reachable`,
`boss_visibility`, `distributor_behaviour`, `blaze_rush_layout`,
`save_compat` — all PASS. Security sentinel 18/18, 0 blockers. The temporary
screenshot hook in `level_01_smoke_realm.gd` was reverted (verified: zero
diff on that file).
