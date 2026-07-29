<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-polish-audit.md
     files inlined: 3
     tokens: 15178 in / 23751 out
     cost: $0.4018
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Telegraph bar correctness

The scan itself is safe. Empty-match is handled: `next_x` stays at the `-1.0` sentinel, hits `if next_x < 0.0`, and alpha is forced to `0.0`. There is no stuck-alpha path: `_update_telegraph()` recomputes alpha from scratch every physics frame on all three branches (no hazard ahead → 0; hazard beyond `TELEGRAPH_LEAD` → 0; in range → computed). Passing a hazard without hitting it just means that `hx > px` fails for it on the next frame, so the scan either finds the next hazard or zeroes the bar. `_crash()` → `_reset_player()` returns the player to x=0 and the next frame's scan re-evaluates cleanly. No state accumulates between frames.

- **med — blaze_rush.gd:~156 (`_build_speed_atmosphere`) — the telegraph bar's vertical extent is hardcoded to world y∈[-260, 0] (`position = Vector2(-3, -260)`, `size = Vector2(6, 260)`), while every other world element (floors, candles, walls, tokens, finish, player spawn) is anchored to `GROUND_Y`. The camera is pinned at y=360 and `CRASH_Y` is 700, which strongly implies `GROUND_Y` is far below y=0 — in which case the warning bar renders hundreds of pixels above the hazards it marks, likely off-screen. Why it matters: the session's headline fairness feature may be invisible/misplaced. Missing: the `BlazeRushLayouts` definition was not provided, so the actual `GROUND_Y` value can't be confirmed from the inlined code — but nothing in the file compensates for a non-zero `GROUND_Y`.
- **low — blaze_rush.gd:~525 (`_update_telegraph`) — `_telegraph.position.x = next_x` overwrites the authored `-3` half-width offset, so the 6px bar's left edge sits on the hazard x instead of being centered on it. Why: 3px cosmetic drift from the obvious intent; no functional impact.

## 2. Camera-/player-attached particle lifetime

Confirmed from the inlined code: `_reset_player()` (blaze_rush.gd:~552) only writes `_player.position`, `_player.velocity`, and `_player_visual.rotation`. It does **not** free or re-instance the player node, so the trail emitter added as a child of `_player` in `_build_player()` survives crashes intact — no rebuild needed, no per-crash accumulation. `_crash()` likewise frees nothing. The streak/dust emitters parented to `_camera` live exactly as long as the scene and are freed with it on `_exit_to_level()` → `SceneRouter.load_scene`. Pickup bursts are `one_shot` and self-free via a 0.5s timer guarded by `is_instance_valid(burst)`, which also covers scene exit mid-timer. No findings.

## 3. Performance

- **med — blaze_rush.gd:~118-145, ~270, ~410, ~350 — steady-state live-particle cap is 85 (streaks 40 + dust 20 + trail 25), plus 3 per candle ember, plus 10 per transient pickup burst (≤0.5s life). Headroom to the stated ~120 budget is ~35 particles — i.e. roughly 11 candles before a single concurrent pickup burst crosses the budget. Candle counts per level live in `BlazeRushLayouts`, which was not provided, so the actual peak cannot be verified from the inlined code. Additionally, the per-candle embers have no distance or visibility gating anywhere in the file — every candle in the course simulates continuously from scene start. Why it matters: CPUParticles2D is CPU-simulated and the targets are non-threaded HTML5 and Android; the budget is a stated constraint and whether it's kept is currently data-dependent on a file this audit can't see.

Individually every emitter is small and the one-shot bursts self-free, so nothing reads as a frame-rate tank on its own — the risk is purely the unverified aggregate.

## 4. `tax_collector.gd` — `play_sfx_at` edge behavior

No new risk. The call sits inside the `State.PATROL` arm of the `match`, after `state = State.ALERT` is assigned. Because dispatch is on `state`, the very next frame executes the `ALERT` arm, not `PATROL` — so the sound fires exactly once per PATROL→ALERT edge, never per-frame. It can re-fire only after a genuine disengage (PURSUE→PATROL via `lose_interest_time` or player-freed) followed by re-entry into range, which is a new telegraph and correctly gets a new sound. Per the stated convention, a missing `tax_alert` file no-ops silently. No findings.

## 5. `secret_realm.gd` — `_swap_placeholder_texture()`

- **low — secret_realm.gd:~255-280 — if the helper were ever called twice on the same container instance, the second call would hide the first `TextureRect` along with the placeholder children and stack a second one — visually harmless (the duplicate is hidden) but a small node leak with no re-entry guard. Why it matters: only theoretically — it cannot happen via the four known call sites, because all of them run in `_ready()` on freshly constructed containers (`sign` Panels, `inner` ColorRect), and a scene reload re-instantiates the entire tree, so no container instance ever sees the function twice.

Null-safety: no gap. `container` is a non-null, just-constructed `Control` at all four call sites; `get_children()` returns an array (possibly empty) and cannot null; `load(path)` is null-checked after `ResourceLoader.exists(path)`. The hide-then-add ordering is correct — the new `TextureRect` is added after the hide loop, so the real art stays visible.

## 6. Gate compatibility (gdparse / `can_instantiate()`)

No blockers found in the new code. Specifically checked:

- `child.visible = false` on the `Node`-typed loop variable (`get_children()` returns `Array[Node]`): member access on native Object types resolves dynamically, so this compiles; at runtime every child is a `Control` (labels, bolt Panels), which owns `visible` — safe.
- Mid-class member declaration (`var _glow_tex: ImageTexture` between functions in both files): legal at class scope.
- Sub-property assignment on value-type properties (`_telegraph.color.a = ...`, `label.modulate.a = 0.0`): legal.
- Lambdas match signal signatures (`body_entered` → `func(b: Node2D)`); `tw.finished.connect(layer.queue_free)` is a valid Callable; `sort_custom` lambda is well-formed; `tax_collector.gd`'s 4-space indentation is internally consistent.
- `const GROUND_Y: float = BlazeRushLayouts.GROUND_Y` requires `BlazeRushLayouts` to resolve at parse time — its definition was not provided, so this can't be verified from the inlined files, but it's pre-existing, not this session's change.

## 7. Verdict

Functionally sound but not ship-as-is: two bugs in the blaze_rush.gd visual pass mean parts of it don't render as intended — (a) the L1 haze `ParallaxBackground` is on CanvasLayer `-2` while the opaque full-screen void rect is on CanvasLayer `-1`, and lower layer indices draw behind, so the haze is fully occluded by the void (the "3-layer background" renders as two); (b) the hazard telegraph bar is anchored to world y∈[-260,0] instead of `GROUND_Y`, so it's very likely drawn far above the course it warns about. Both are one-line-class fixes (swap the layer indices; anchor the telegraph to `GROUND_Y`). The telegraph scan logic, crash/reset emitter lifetimes, the `tax_alert` edge trigger, and the placeholder-swap helper are all clean, and nothing fails gdparse. Before shipping, also confirm candle counts in `BlazeRushLayouts` (not provided) against the ~120-particle budget — steady state is already 85 before embers and bursts.