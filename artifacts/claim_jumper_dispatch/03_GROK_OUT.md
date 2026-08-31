<!-- dispatched: x-ai/grok-4.6
     prompt: artifacts/claim_jumper_dispatch/03_GROK.md
     files inlined: 1
     tokens: 15777 in / 3508 out
     cost: $0.0526
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Verdict: do not tell the founder this residual is FIXED, even “pending deploy.”** Hedge: height-cap + air-hop are **wired in PATROL** and a **headless real-scene run bounds the wall climb**; that is not the founder’s DoD.

---

### Checklist

**Boss leaves the previously stuck platform and continues pursuit** — **(b)**, and **(c)** if you mark it done from this session.  
`already_high_enough` (`y < player.y - 400`) gates hop arm **and** air-hop fire in PATROL. That stops unbounded wall-pogo; it does **not** prove he leaves a ledge and keeps chasing. The 16s headless run parks the player **outside** the east wall (`x=4500` vs wall `4400`). Result: `min_y=29.3` from spawn `500`, **8 air-hops**, still pinned on X by `_clamp_to_arena()`. That is a **bounded climb at the clamp**, not pursuit past the stuck point. 8 air-hops in 16s is still a lot of hopping in place. Needed: same real `level_03_gold_rush` arena, player on a **reachable** next platform, per-frame **x,y** showing he **clears the old lip and closes on the player**.

**Double jump implemented and used in real chase paths** — **(c)** if sold as done; implement is **(a)**, “real chase paths” is **(b)**.  
Code: `_air_hop_ready`, `AIR_HOP_VELOCITY`, fire when `velocity.y > -120` and not `already_high_enough`, clear on real landing (`is_on_floor() and velocity.y >= 0`), squash/stretch kick. Hops only exist in **PATROL** (cleared on THROW). The 8 air-hop events are the **wall-park pathology**, not a chase across Stage 3 platforms. Needed: a path where he hops a gap / raised ledge and the **second beat fires mid-crossing**.

**Coordinate trace or capture proves both in the real Stage 3 arena** — **(b)**.  
Headless on `level_03_gold_rush.tscn` is better than an empty box, but you only have aggregates (`min_y`, hop count, ceiling frames). No published xy trace of leave-platform + pursuit, **no** browser/itch capture. Founder has already rejected this class of evidence. Needed: frame log or capture of **both** behaviors on the real arena.

**No regression to glued-to-player lock-on** — **(b)** (weakly leaning safe, not certified).  
This diff does not retune standoff/speed as the fix. `CHASE_SEPARATION` / hop aim offset still in the provided script. Named tests (chase_separation, double_jump, difficulty, pressure) are said to pass; **full 59 + sentinel not re-run with this + Auditor together**. Needed: that combined run.

**Gates green** — **(b)**. Partial named greens ≠ gates green. Re-run the full suite + security sentinel on **both** boss fixes.

**Butler ships fresh data** — **(b)**. Explicitly not shipped. No itch/butler push, no fresh build for a hard-refresh.

**STATUS.md updated honestly** — **(b)**. `STATUS.md` was **not in the files provided**. Cannot treat it as updated. If you write it now, it must say **wired / headless-bounded, not founder-confirmed FIXED**.

**Founder hard-refresh confirms movement beyond the stuck point** — **(b)**. Definitionally open. Local/headless/STATUS memory cannot check this. Stays open until the founder hard-refreshes a **shipped** build and sees him **move past the old stuck point**.

---

### Hard-rule check
Not a speed-as-main-fix. Not geometry/art blocked (no `WAITING ON FOUNDER FILE`). Scope is on-target. The failure mode is the one this founder already rejects: **wired + headless numbers, sold as FIXED**.

**Honest language:** residual is **partially mitigated in code** (no infinite Y climb; air-hop exists and fired in a wall-park sim). It is **not FIXED**. Do not check the first three boxes or the last one until a real-arena xy trace (or capture) shows leave-platform + chase, and the founder confirms on a shipped build.