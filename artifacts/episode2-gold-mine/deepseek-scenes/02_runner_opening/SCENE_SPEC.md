<!-- dispatched: deepseek/deepseek-v4-flash-vision-exp
     prompt: prompts/deepseek-ep2-scene-02-runner.md
     files inlined: 2
     images attached: 3 (artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg, artifacts/founder-art/references/ep2_runner_ref_1_boulder_bandits.jpg, artifacts/founder-art/references/ep2_runner_ref_2_zipline.jpg)
     tokens: 15527 in / 22652 out
     cost: $0.0184
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->

> **UNVALIDATED MODEL OUTPUT until checked.** Authored by DeepSeek via
> OpenRouter from the founder reference images and the shipped Godot
> implementation. Claude's verification notes are in `_VERIFICATION.md` in this
> folder — read that before treating any number here as fact.

**Mood**

A hurtling descent through a working gold mine, not a museum tunnel. The rock is cool, dark, and wet; the timber is old and oiled; the gold is the only thing that glitters. Warm lantern pools slide past at 12 m/s, and every fourth segment the tunnel breathes open into a worked-out bay where the bears are waiting. The player is a green leaf in a brass-bound cart, and the mine is trying to kill them.

**Dimensions (built)**

- Tunnel: 12 m wide (walls at ±5.6 to ±6.3 m), 7–9 m high
- Bays: 16.8 m wide (walls at ±8.4 m), 9 m high, every 4th 20 m segment
- Length: ~240 m (`_chamber_z = 200`, plus 40 m of approach)
- Playable corridor: 5 m wide (lanes at x = −2.5, 0, 2.5)
- Rails: 3, at x = −2.5, 0, 2.5, 0.22 m wide × 0.14 m tall, at y = −0.42
- Sleepers: 6.6 m wide × 0.12 m × 0.5 m, every 3 m

**Zones**

1. **Entry** (z = 0 to 20): Tunnel starts, first timber frames, first lanterns. Player gets oriented. No hazards. Tunnel is 12 m wide, 7 m high.
2. **Runner corridor** (z = 20 to 160): Main stretch. Hazards appear. Segmented walls with pockets every 4th segment. Tunnel varies between 12 m and 16.8 m wide, 7–9 m high.
3. **Zip-line stretch** (z = 160 to 200): Zip segments. Player is off the rails, hanging from cable at y = 2.5. The tunnel is at its most expansive — the zip cable crosses a wide bay.
4. **Chamber gate** (z = 200): Lit gate at y = 2.6, 7.5 m wide. `chamber_reached` signal. The run halts.

**Key props (named and counted)**

- Timber support frames: ~13 (every 18 m), each 2 posts (0.45 × 6.0 × 0.45) + 1 beam (wx × 2 + 0.5 × 0.45 × 0.45)
- Lanterns: ~17 (every 14 m), each OmniLight (energy 3.6, range 17) + GLB/fallback
- Gold vein clusters: ~49 (every 4.5 m), 3 per cluster, each 0.12 × scale × scale × 1.6
- Sleepers: ~80 (every 3 m), 6.6 × 0.12 × 0.5
- Rails: 3, 0.22 × 0.14 × 240
- Wall segments: ~13 segments × 2 sides + ceiling
- Gold piles: 3 GLB props (at z = 70, 124, 176)
- Rock chunks: in pockets, 2.2 scale
- Hazards: data-driven, count varies

**Lighting**

- Ambient: cool `#7C8794`, energy 0.42
- Key: directional `#A8BCD2`, energy 0.7, shadows on, rotation (−55°, 30°, 0°)
- Lanterns: OmniLight `#FFB765`, energy 3.6, range 17, attenuation 1.5, no shadows
- Fog: `#3A2E22`, density 0.012
- Glow: HDR threshold 1.3, intensity 0.35, bloom 0.0

**Camera and player start**

- Camera: behind and above cart, (0, 3.2, −4.5) relative to cart, looking +Z, FOV 78°
- Player start: lane 1 (center), cart at (0, 0, 0), facing +Z
- Camera follows cart x with lerp (speed ~8), y with lerp (speed ~6)

**Movement bounds**

The playable corridor is 5 m wide (lanes at ±2.5 m), but the visual tunnel is 11–17 m wide. The cart is constrained to the three rails by logic, not physics. The walls are scenery, not collision.

The expansiveness comes from:
1. Walls at 5.6–8.4 m from center — the cart never touches them.
2. Pockets opening to 16.8 m — moments of expansiveness every 80 m.
3. Camera FOV 78° — shows the walls in the periphery.
4. Camera position (behind and above) — shows the depth ahead.
5. Layered depth (hanging baskets, distant walkways) — makes the tunnel feel bigger.

The playable corridor is defined by:
1. The rails (the cart is constrained to them).
2. The obstacle hit windows (`OBSTACLE_HIT_X = 0.8`, `OBSTACLE_HIT_Z = 1.0`).
3. The camera (the player's view is centered on the cart).

**Threat anchors**

- Balaclava bears: at pockets (every 4th segment), firing arrows or pushing boulders
- Boulders: roll down the rails, cleared by jump or lane change. Pale granite `#777773`.
- Arrows: fly at head height (y = 1.45), cleared by duck or lane change. Brown shaft `#AD8050`, grey tip `#77797C`.
- Crates: on the rails, cleared by jump. Timber with brass banding.

---
