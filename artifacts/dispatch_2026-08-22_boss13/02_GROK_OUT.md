<!-- dispatched: x-ai/grok-4.6
     prompt: artifacts/dispatch_2026-08-22_boss13/02_GROK.md
     files inlined: 0
     tokens: 1167 in / 4565 out
     cost: $0.0297
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**REJECT. Not shippable.** Founder-acceptance is centre-X past the circled spot on a hard-refresh. This patch still permits frozen X (and Y-only motion).

---

**Failure modes**

1. **Trigger:** Boss mashed into the east World wall / clamp band with the player anywhere east or close.  
   **Why:** Boundary guard kills hop; `_clamp_to_arena` zeros `velocity.x`; vault X is same-signed into the wall or never arms. Centre X never leaves the clamp. Freeze, not a fix.

2. **Trigger:** Vault (or any hop) while centre is still inside the clamp window.  
   **Why:** Hop is mostly Y. Clamp still fires every airborne frame and zeros `vx`. Result is a 1.27s pogo on a frozen X — the exact metric he already rejected.

3. **Trigger:** Stuck under a platform (Boss 1).  
   **Why:** Vault sets `vy = LEAP` and `air_jump_ready = true`. Ceiling sidestep immediately does `vy = max(vy, 0)` and `air_jump_ready = false`, then locks facing 1.2s. He bonks, drops in the same X pocket, 3s vault cooldown. X unmoved.

4. **Trigger:** Boss 1 CHARGE (`state_timer` ~2.5s) while the 2.0s stuck accumulator is running.  
   **Why:** Vault lives in PATROL only. CHARGE preempts it, slams the same wall, may jiggle X one frame (timer reset) or leave PATROL entirely. Periodic animation, frozen centre. He will call it still stuck.

5. **Trigger:** Player stands within `player_dx <= 120` (i.e. actually fighting, or standing on the circled spot to watch).  
   **Why:** Timer hard-resets every frame. Vault never fires. The acceptance test itself disables the escape.

6. **Trigger:** Corner clip / wall mash / ceiling press so `is_on_floor()` is false.  
   **Why:** Entire anti-stuck block is gated on floor. Timer never increments. Permanent freeze with no vault.

7. **Trigger:** One frame of collision correction or sub-pixel slide (`dx/delta >= 10`).  
   **Why:** Instantaneous speed resets `_stuck_timer`. Oscillating 1–2px against a wall is “progress.” He watches X sit on the circle for minutes.

8. **Trigger:** Vault fires, lands in the same X, `_vault_cooldown = 3`.  
   **Why:** `_last_progress_x` tracked him through the air, so landing looks like a fresh baseline. 3s of guaranteed no retry. Net X = 0. He refreshes, still looking at the same pixel.

9. **Trigger:** `sign(player.x - centre)` points into the obstacle (player on the far side of the ledge/wall, or east of an east-clamped Boss 3).  
   **Why:** Vault aims at the player, i.e. into the wall. Y impulse + clamped/cancelled X = pogo. Centre does not pass the circle.

10. **Trigger:** Founder hard-refreshes and stares for 2s.  
    **Why:** The patch *requires* 2.0s of visible do-nothing before it even tries, then may hop in Y only. That is the bug, staged.

---

**A.** While airborne or during the 3s cooldown, `_last_progress_x` is slaved to current `x` every frame and `progress_speed` is not computed. On the first eligible ground frame you measure **one frame** of displacement from the immediately previous frame — not 2s of failed progress, not net X across the hop. Airborne return-to-same-X is invisible. The timer measures “am I on the floor, cooldown ready, and crawling this instant,” not “have I failed to advance.” It does not measure what it claims.

**B.** Unreliable. It aliases. At 60 fps, 10 px/s is ~0.17 px/frame — below collision slop. One jitter frame resets the 2s accumulator; one hitch with `dx=0` false-increments it. Use **net displacement vs a sample taken N ms ago** (e.g. `|x - x_stamp| < threshold` over 0.4–0.6s), never `abs(dx)/delta` on a single frame.

**C.** No. Trace: PATROL vault → `vy = LEAP`, `air_jump_ready = true`, `vx` toward player → rises into the underside → CEILING SIDESTEP sets `vy = max(vy, 0)` (upward killed) and `air_jump_ready = false`, locks facing 1.2s → falls into the same pocket → 3s cooldown. Under a platform the vault is a ceiling bonk. Centre X does not clear.

**D.** Nothing reliable. `is_on_wall()` is true (body past the real wall); `at_arena_boundary` is true so hop is suppressed; clamp zeros `vx` every frame he stays at the rail. The only remaining X impulse is the vault, which (a) may not arm, (b) is eaten by the same clamp if centre hasn’t left `[arena_min+24, arena_max-24]`, (c) points into the wall if the player is east. **Yes: the guard trades the pogo for a permanent freeze.** That is a downgrade against his acceptance test.

**E.** Yes. 2.0s of motionless boss on the circled pixel **is** the stuck he is hunting. Then a Y hop makes it worse. Use ~0.35–0.5s of **net X**, or no wait: if `is_on_wall()` and clamp/ceiling geometry say you cannot advance, change X immediately. Do not demo the bug for 2s.

**F.** **Reject as-is.** Instantaneous floor-only speed + 120px player gate + PATROL-only + 3s cooldown cannot guarantee centre-X motion. Boss 1 vault is cancelled by ceiling sidestep. Boss 3 boundary guard + `_clamp_to_arena` (`vx = 0`) removes the hop that was the only wall escape and does not replace it with an X impulse that survives the clamp. The founder will hard-refresh, see 2s of frozen X (or a Y pogo at the same X), and reject this like the last 50. Do not ship. Fix is: measure net X, act off geometry not a 2s sit, and apply an X impulse that is not zeroed by clamp/ceiling — then prove centre X past his mark.