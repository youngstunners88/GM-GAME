<!-- dispatched: x-ai/grok-4.6
     prompt: prompts/2026-08-19-boss-shared-rootcause.md
     files inlined: 4
     tokens: 40199 in / 10346 out
     cost: $0.1425
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**The shared clamp hypothesis is right for the founder’s Stage 2/3 screenshots and wrong as a single cause of “does not move.”** It does not explain Stage 1 at all, and it does not explain Stage 1’s **negative** tracking.

Seal / level spawn / `GameManager` code was **not** in the provided files. Everything below is from the three boss scripts + `boss_base.gd` plus your session numbers.

---

### 1. Hypothesis — confirm / refute

**Holds for the Stage 2 screenshot, and for “pinned at the lip” on 2/3.**

Distributor and Claim Jumper both hard-clamp the **body centre**, inset by half-body, and **zero the velocity component into the wall**:

```713:732:src/boss/distributor.gd
func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	var half: float = BODY / 2.0
	var lo_x: float = arena_min.x + half
	var hi_x: float = maxf(lo_x, arena_max.x - half)
	# ...
	if not is_equal_approx(clamped_x, centre.x):
		velocity.x = 0.0
```

```256:276:src/boss/claim_jumper.gd
func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	var lo_x: float = arena_min.x + HALF_BODY
	var hi_x: float = maxf(lo_x, arena_max.x - HALF_BODY)
	# ...
	if not is_equal_approx(clamped_x, centre_x):
		global_position.x += clamped_x - centre_x
		velocity.x = 0.0
```

Your photogrammetry matches that math: Stage 2 reachable centre `[3700+120, 4400-120] = [3820, 4280]`; measured x ~3813 is the west pin. Player at ~3109 is **591 px west of `start_x`**. Pursuit still aims at the player (`_hover_pursue` / `_ground_chase`), then `_clamp_to_arena` cancels the closing every frame. That is “frozen against a wall,” not “AI off.”

**Fails as a *shared* root cause:**

| Fact | Why the hypothesis cannot own it |
|---|---|
| **Auditor has no clamp.** | `auditor.gd` has no `arena_min` / `arena_max` / `_clamp_to_arena`. Bounds `(0,0)` are irrelevant; this script cannot pin to an arena. Stage 1 “never left the mouth” is **not** this mechanism. |
| **Inside-arena kite: S2 +0.56, S3 +0.39.** | With the player *in* the box, 2 and 3 **do** chase. Live “does not move” on 2/3 is the **leave-west + seal drop** case (and S2’s 28% wall time even in-box). |
| **Stage 1 tracking −0.20.** | A clamp freeze is `vx = 0` → score near **0**, not **negative**. Negative means he systematically walks/charges **away**. |
| **S1 x_span only 250 px, frozen 33%.** | No walls-as-bounds in this script. Freeze is state-machine / geometry, not `_clamp_to_arena`. |
| **S3 `clamped_at_wall` 0% in-box.** | In-arena “doesn’t move” on Stage 3 is **not** the clamp. See `CHASE_SEPARATION` / ledge hold below. |
| **S2 28% `clamped_at_wall` with player inside.** | Even a *fair* kite hits the 460 px reachable band of a 700 px box. Same function, milder version of the screenshot. |

So: **outside + strict clamp explains the Stage 2 screenshot and the founder’s “stuck at the mouth” read on 2/3.** It does **not** explain Stage 1, and it is not why S3 tracks fine in-box but is also “too easy.”

---

### 2. Stage 1 negative tracking (−0.20)

Treat the in-file “already fixed” comments as the failed-attempt log you said they are. The **live** score is still negative. Two mechanisms in *this* file produce that; a third produces the 33% freeze.

**A. CHARGE aim is origin + 2D normal, and the snapshot is still the state-entry path.**

On PATROL → CHARGE he still writes a one-shot target:

```259:266:src/boss/auditor.gd
			if state_timer <= 0.0:
				state_timer = 1.4
				current_state = State.CHARGE
				var p := get_tree().get_first_node_in_group("player")
				if p:
					charge_target = p.global_position
```

CHARGE then does:

```280:286:src/boss/auditor.gd
			var live := get_tree().get_first_node_in_group("player")
			if live:
				charge_target = (live as Node2D).global_position
			var dir := global_position.direction_to(charge_target)
			velocity.x = dir.x * charge_speed
```

Even with the per-frame overwrite:

- `global_position` is **top-left**, not centre (`collision.position = (BODY/2, BODY/2)` at 140–141). Aim is biased **+110 px east**.
- `direction_to` is **2D-normalized**. Horizontal close is `charge_speed * dx/|d|`. A player above him (he hops at `player.y < origin.y - 90`, 233–236) shrinks `dir.x` and can flip the sign relative to where the **sprite** is.
- Charge **ends on `is_on_wall()`** (288). At the arena mouth that is: commit → hit lip → VULNERABLE. That is “never left the mouth.”

If the live binary still uses the snapshot-only path the comments describe, it is worse: 1.4 s × 240 px/s ≈ **336 px** of stale ground. A reverse during that window is a full charge **away** — exactly a negative tracking score. A re-read that still aims from the origin does not clear that class of error.

**B. VULNERABLE used to be a hard park; the current line is not the one you measured if freeze is still 33%.**

Comments at 301–310 describe the real bug: `move_toward(velocity.x, 0.0, 200.0)` **with no `* delta`**. At 60 fps that is 12 000 px/s² — dead stop in 1–2 frames, then `vx = 0` for the whole `vulnerable_time` (1.1 s). That is a parked x (your 3030 / 3280) and a big chunk of “frozen 33%.”

Current source (316) *does* scale by delta and drifts at `VULNERABLE_DRIFT` (120). If instrumentation still saw a park, **this file’s comment-fix is not what ran**, or PATROL/CHARGE wall-stops dominate. Do not trust the comment; trust the 33% freeze.

**C. Still in source and sufficient for negative correlation — the “reposition” hop inverts chase.**

```257:263:src/boss/auditor.gd
			if hop_timer <= 0.0:
				hop_timer = 6.0 if phase < 3 else 3.5
				velocity.y = -300.0
				velocity.x = lerpf(velocity.x, -patrol_direction * 150.0, 0.45)
```

`patrol_direction` is the stalk sign (211–212). This hop aims **the opposite way**. Over a 9 s / 4 Hz kite that is 1–2 forced anti-chase bursts. PATROL stalk itself also uses **origin** (`dx = player.x - global_position.x`, 209), so a player standing on the visible body (`dx ∈ (0, 110)` and `> TURN_DEAD_ZONE` 34) makes him walk **east, through/away from them**.

**D. Speed does not explain the sign.** P1 `patrol_speed` 140 < 240 loses ground but still moves **with** a kiting player. −0.20 is aim/hop/stale-charge, not “too slow.”

**E. No shared clamp.** Stage 1 frozen time is CHARGE-into-wall, VULNERABLE brake, and hop/leap — not `arena_max`.

---

### 3. Minimal **shared** fix (not three hacks)

**Do not** let the clamp follow the player. Claim Jumper exists specifically because an unbounded ground boss walks off the lip (`claim_jumper.gd` 228–241). Distributor’s hover would leave the set piece. **Do not** suspend the fight when the player leaves — that *is* “the boss does not move.”

**Do this one encounter rule:**

While a living `"boss"` exists, the west seal **does not drop** because the player walked west of `start_x - 40`. Drop it only on **scene reload** (normal death / checkpoint restore / `boss_contact_restart`). Raise it again on re-entry.

That keeps the reason the seal is currently torn down: checkpoints sit west of every arena; a mid-fight death must not respawn you outside an already-up wall. Reload = seal down, walk back in, seal up, fight still live. A *living* kite cannot open a 591 px air gap and pin 2/3.

Seal implementation was **not provided** — that change lives in whatever raises/removes the wall (you named the `start_x - 40` rule; I will not invent the function).

**Shared boss-side contract (small, same for all three):**

1. **Levels always pass real `arena_min` / `arena_max`.** Auditor cannot receive them today — he does not declare the fields. Either give him the same centre-inset clamp as 713–732 / 256–276, or stop pretending Stage 1 has an arena. Prefer giving him the clamp so he cannot wander the pre-boss hallway once the seal is holding the player.
2. **Every horizontal stalk uses body centre**, never origin. Auditor PATROL 209 is the remaining offender; CHARGE must use `global_position + Vector2(BODY/2, BODY/2)` (or a `hit_centre()` like Distributor 560–561). This is a measurement fix, not a speed boost.
3. **Never invert chase as “reposition.”** Delete the `-patrol_direction` hop blend (257–263) or hop *toward* the live centre. That hop is a Stage 1-only anti-tracker; it has no analogue worth keeping.
4. **CHARGE `vx = sign(dx) * charge_speed` (horizontal), not `dir.x` of a 2D unit vector.** Same top speed, actually toward the player. Keep the timed CHARGE → VULNERABLE machine and the `is_on_wall` abort.

Do **not** widen detection, teleport, disable hitboxes, or bypass states.

---

### 4. 290–385 vs 240 + contact wipe — is it survivable?

**Not as a flat footrace.** Contact is `GameManager.boss_contact_restart()` from all three hitboxes (`auditor.gd` 542–556, `distributor.gd` 1146–1160, `claim_jumper.gd` 807–821): instant full-run restart, not a hit. A strictly faster body that is *allowed* to occupy the player’s x **wins the run by existing.**

Intended counter-play, already sketched in 2/3 and missing on 1:

| Boss | How contact is supposed to be *earned* |
|---|---|
| Distributor | Hover + climb lock + `STANDOFF_X` 168 (`distributor.gd` 428–440, 647–676). Touch = jump into him or lose Hoard Gravity, not “he arrived.” |
| Claim Jumper | `CHASE_SEPARATION` 200 / `VULNERABLE_SEPARATION` 96 (`claim_jumper.gd` 63, 92, 467–480). He **retreats** inside that gap. Touch = you walked into a 280 px cart. |
| Auditor | **No standoff.** PATROL walks onto you; CHARGE 430 sets `vx` through you; hitbox `monitoring = true` the whole fight (157). P1 patrol 140 cannot catch a sprint; **CHARGE can, and that is a wipe.** |

**What should change (fair, not easier-by-deletion):**

- Keep boss **closing speed** above 240 so a kite inside the box loses space. That is pressure.
- Keep contact = run-wipe if that is the founder rule — but **every** boss must park at `≥ half-body + player half-width` (CJ’s 200 is the right shape). Auditor needs that same min-separation on PATROL/CHARGE/VULNERABLE. Winning the chase then means **dynamite / clipboards / pull**, not an auto-wipe.
- Counter-play becomes: dodge projectiles, use VULNERABLE windows, jump the charge, win the pull tug-of-war, do not stand in the body. **Outrunning on flat ground is not the counter** and must not be required.
- Do not raise speeds again. 345 / 385 already exceed sprint; more speed only shortens the time-to-wipe if standoffs fail.

Without a shared standoff, Stage 1 CHARGE and a Stage 3 phase-3 385 dash are not a fight.

---

### 5. Stage 3 “too easy” vs “does not move”

**Same geometry, two reads.**

In-box instrumentation: tracking **+0.39**, `clamped_at_wall` **0%**, x_span 396/420. He *moves* when you stay inside. “Does not move” is the **west-exit pin** (hypothesis) **or** the standoff looking like a park: `_ground_chase` with `min_separation` 200 **reverses** `target_vx` when `gap < 200` (467–480). Under a follow-cam that is “he’s just sitting there.”

“Too easy to defeat” is the complementary cheese:

- **Outside the box:** player at ~3109, boss centre locked at 3840 (`3700 + 140`). Body occupies `[3700, 3980]` — he *is* the west wall. Contact cannot happen. Dynamite still targets `p.global_position` (`claim_jumper.gd` 675–677), so the blast is dumped in the hallway the player already cleared; they walk off the telegraph. He is a statue that cannot reach them.
- **On the west lip, inside:** same pin. During `State.VULNERABLE` (`take_damage` gated at 704–705) they poke a non-strafing target. `MAX_VULN_DAMAGE_PER_WINDOW = 3` (98, 724–726) still forces multiple windows — unless they never have to dodge because he cannot step off the wall.
- **VULNERABLE_DRIFT 250 + 96 px floor** (44, 63, 627) still *delivers* him to axe range if they stay in-box and he is not wall-pinned. That is the other “too easy” the comments already named: chase-while-exposed walked him onto the weapon.

So yes: **a wall-pinned (or hallway-kited) Claim Jumper is a safe dummy; a close-in VULNERABLE drift is a free dummy.** Both can be true in one session. Seal-stays-up-while-boss-lives removes the hallway cheese. Keep the per-window damage cap and the 96 px VULNERABLE floor so in-box kills stay multi-window. Do not delete dynamite or the state gate.

---

**Bottom line:** Stage 2/3 live screenshots = player outside a live fight + centre clamp + seal that drops on walk-out. Stage 1 = different bug (origin-aim, anti-chase hop, CHARGE/VULNERABLE freezes); he cannot be “clamped” because that code does not exist. Shared fix = **encounter lock on the seal + centre-based chase + no anti-chase hop + standoff on all three so speed > player does not equal instant wipe.** Missing to implement the seal half: the level scripts and the seal raise/remove function.