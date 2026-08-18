<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/rejected-kimi.md
     files inlined: 0
     tokens: 677 in / 4000 out
     cost: $0.0620
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Top 3 hypotheses (ranked)

**1. Constant-offset stasis under a player-following camera — most likely.**
Boss holds ~168px beside the player; the camera tracks the player, so the boss's *screen* position is nearly fixed even while its world position moves. A low-amplitude "stalk weave" doesn't break that illusion. The gate measures world-space distance, so it can't see this.
*Instrumentation:* log **screen-space** position per physics frame: `boss.get_global_transform_with_canvas().origin`, dumped to CSV or drawn as a Line2D trail on a CanvasLayer. Rolling 1s screen displacement < ~5px while world velocity > 0 = "moving but imperceptible"; world velocity ≈ 0 = genuinely frozen. Capture a real-input session with Movie Maker (`--write-movie`) and eyeball it — that closes the founder-perception gap directly.

**2. State machine latching a non-chase state under real input.**
The gate drives smooth, monotonic movement. Humans stop, reverse, jump. If chase is entered on a threshold crossing or exited when within standoff (attack/cooldown/idle), oscillating around the boundary can latch a non-chase state, or an attack state may root the boss.
*Instrumentation:* ring buffer of `(state_name, velocity.x, dist_to_player)` every physics frame; dump to `user://` on a hotkey. Add a watchdog: if `dist > STANDOFF_X + 120` for >2s while state ≠ chase, `push_error` with the state history. Repro with a human playtest, not the scripted gate.

**3. Standoff lands off-screen at gameplay zoom.**
168px world units: if camera zoom puts visible half-width under ~170px (common with pixel-art zoom ≥2 on a small base resolution), the boss at standoff is *literally never visible* → "doesn't chase."
*Instrumentation:* per frame, compare the screen-space origin from (1) against `get_viewport_rect()`; log % of chase frames the boss is on-screen. If near 0%, clamp `STANDOFF_X` to ~60% of `get_viewport_rect().size.x * 0.5 / camera.zoom.x`.

Lower likelihood but cheap to check: gravity vs. hover weave causing vertical jitter with near-zero net horizontal motion — count `velocity.x` sign changes per second.

## R1: melt_forge.gd mouth

Replace the ColorRect with a radial-gradient TextureRect + ember particles + pulse, all code-only:

```gdscript
var grad := Gradient.new()
grad.set_color(0, Color(1.0, 0.85, 0.35))   # hot core
grad.add_point(0.6, Color(1