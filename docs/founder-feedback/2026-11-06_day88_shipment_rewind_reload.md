# Day-88: Shipment jumps back + reload glitch on the ridge (founder 2026-11-06)

Source: Drive `PROMPT_EPISODE2_DAY88_SHIPMENT_REWIND_RELOAD_2026-11-06.md`.

## Root causes found (src/episode2/chamber/river_cover.gd, ep2_winchester.gd)
1. **Rewind after a won gate.** Downed *after* the gate's wave was down (on the path to the next ledge, the ledge bear) ran the full
   gate retry: the crate went from the eddy back to the gate's start (gate 1 → the launch pool) and the whole wave replayed. Now a
   `_gate_cleared` flag banks the eddy: a fall there puts him on the gate's overlook with full hearts, the crate keeps waiting, no wave.
2. **Silent tip.** Hammer's raft hooks the crate from upstream (behind it) and drains it with no bear visible; at 9 bear-seconds the
   crate tipped and rewound with only an after-the-fact toast. Now a warning at half way: "THE SHIPMENT IS GOING OVER · CLEAR IT!".
3. **Reload: R dropped during the Sharps' 1.1 s breech cycle.** `start_reload()` refused while `_cycle > 0`, so R pressed straight
   after a shot did nothing. It is now queued and starts when the action has cycled (all firearms; the bow is unchanged).
4. **Reload: empty reserve with no top-up.** The gate resupply compared `sniper_rounds` (boxes bought, never decreases) instead of the
   Sharps' real reserve + loaded round, so a long run could leave 0 reserve. It now reads the gun.
5. **Restore left the gun mid-reload.** After any soft-fail restore every gun's reload/queue/breech cycle is cleared (`_ready_guns`).

Gates only advance (`_begin_gate` asserts it). Every intentional rewind prints `[day88] rewind gate=… crate_s=… reason=…` in debug builds.
No second runner, scene reload or checkpoint restore exists on this path (river_cover never emits `chamber_failed`).

## Proof
`tests/ep2_river_cover_test.tscn` RIVER_COVER: ALL PASS with new checks (eddy hold after a down, queued reload, resupply, post-fail
reload). Also ALL PASS: ep2_runner_revolver, ep2_range_lesson, ep2_founder_residuals_1101. **Not founder-verified** — the bar is his
hard-refresh full non-fail run.
