<!-- dispatched: deepseek/deepseek-v4-flash-vision-exp
     prompt: prompts/deepseek-ep2-scene-01-smelting.md
     files inlined: 3
     images attached: 4 (artifacts/episode2-gold-mine/references/inferno_bull_smelting.jpeg, artifacts/episode2-gold-mine/references/inferno_bull_armed.jpeg, artifacts/episode2-gold-mine/references/inferno_bull_whiskey.jpeg, artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg)
     tokens: 16038 in / 11622 out
     cost: $0.0112
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->

> **UNVALIDATED MODEL OUTPUT until checked.** Authored by DeepSeek via
> OpenRouter from the founder reference images and the shipped Godot
> implementation. Claude's verification notes are in `_VERIFICATION.md` in this
> folder — read that before treating any number here as fact.

**Mood.** A breathing chamber. After the dark, claustrophobic runner, the cart brakes into a cavern that is warm, bright, and *safe* — a working smelting facility where molten gold is the dominant light source, the Bull sits among it like a king, and the only sound besides the furnace roar is the quiet clink of a whiskey glass. This is not a combat space; it is the calm before the first real fight, designed to make the player feel that they have arrived somewhere that matters.

**Dimensions.** The built room is **22 m wide × 30 m long × 10 m high** — this is correct for the industrial cavern scale. The floor box is centred at `(0, -0.2, 3.5)` with size `(22, 0.4, 30)`, so its footprint spans **z = -11.5 to z = 18.5**. The playable area is narrower (z = -8 to z = 15), which leaves 3.5 m of dead floor behind the entry and 3.5 m beyond the exit gate — correct: the entry needs space for the runner tunnel to open into, and the exit needs depth so the gate reads as a doorway rather than a wall sticker. The ceiling bottom sits at **y = 9.3**, which gives a 9.3 m clearance — appropriately cavernous for a facility with pour-crucibles and hanging chains.

**Zones (metres, same axis convention as code).**

| Zone | Coordinates | Notes |
|---|---|---|
| Entry | z = -8 to -5 | Player spawns at `(0, 0, -8)`. The cart has just stopped; control is handed over after 1 s. |
| Playable | z = -8 to 15 | The player walks on a linear rail (x = 0). Lateral movement is not implemented. |
| Interaction | Bull at `(1.6, 0, 6)`; mold rack at `(-4.2, 0, 2)` | Talk range is 3.2 m. The Bull is the main interaction anchor; the mold rack is the verb-teach target. |
| Exit | z = 15 | Gate is at `(0, 4.6, 15)`. Resolution fires when the player reaches z ≥ 14 and the Bull's parting line has finished. |

**Key props (named and counted).**

- Cavern shell: 1 floor, 2 side walls, 1 ceiling, 1 back wall (5 boxes)
- Timber framing: 8 posts, 4 cross-beams (spaced every 7.5 m from z = -6 to z = 16.5)
- Crucibles: **3** (positions: `(-6,0,8.5)`, `(6.5,0,11)`, `(-3,0,13.5)`) — each with a forge glow omni
- Ingot racks: **2** (`(8.6,0,4)`, `(-8.6,0,6.5)`)
- Lanterns: **3** (`(9.4,3.6,-4)`, `(9.4,3.6,2)`, `(9.4,3.6,9)`) — each with a lantern omni
- Inferno Bull: 1 (placeholder box, yaw 180)
- Bull key light: 1 (omni, `(-0.2,2.4,3.8)` relative to Bull)
- Whiskey glass: 1 (on a crate table at `(0.5,0.55,5.5)`)
- Crate (table): 1
- Casting molds: **3** (on a bench at `(-4.2,0,2)`)
- Bench: 1
- Lil Blunt (player): 1 (placeholder box)
- Winchester 1886: 1 (starts in Bull's hands, moves to player on hand-off)
- Exit gate: 1

**Lighting.** Three crucible glows (forge omni, `#FF8A3C`, energy 6.0, range 22) are the dominant sources, matching the reference where molten gold lights the Bull and the cavern. Three lanterns (`#FFB765`, energy 3.6, range 17) hang on the timber framing and create warm pools on the floor — the cooler counterpoint to the pours. One dedicated warm key on the Bull (energy 3.2, range 9) ensures he reads as a silhouette-killer, not a black void. The environment uses the forge variant: warm ambient `#C98A4E` at 0.55, warm fog `#6B3D1C` at density 0.020, glow intensity 0.55 with HDR threshold 1.1. This is the warmest, brightest space in Episode 2 — correct.

**Camera and player start.** The implemented camera framing is largely right, with one correction.

- **Player start:** `(0, 0, -8)`, facing +Z.
- **CAM_WIDE** `(0, 4.2, -14), pitch -14°` — used for Arrival, Approach, and Exit. This is a good establishing shot, but **z = -14 is outside the room's floor** (which ends at z = -11.5). The camera would be hanging in the runner tunnel. Recommend moving it to `(0, 4.2, -11.0)` so it stays inside the chamber while still being behind the entry point.
- **CAM_CLOSE** `(1.1, 2.3, 1.4), pitch -8°` — used for Drink, Sizing, Handoff, Terms, Promise. This is correct as a push-in two-shot. With the player at z ≈ 2.8 (inside talk range), the player is 1.4 m in front of the camera and on the left side of the frame (x = 0 vs camera x = 1.1), and the Bull is 4.6 m ahead. The rifle hand-off is visible because the rifle moves to the player's position, which is in front of the camera. This framing is right; keep it.
- **CAM_TEACH** `(-1.0, 3.2, -3.0), pitch -12°` — used for Verb Teach. This is behind the player (who is near z = 2.8) and frames the mold rack ahead. Correct.

The camera lerp at 1.8 units/sec gives a gentle push-in, not a snap — appropriate for a conversation.

**Movement bounds.** The player is constrained to **x = 0** (no lateral movement) and **z ∈ [-8, 15]**. This is a deliberate rail for a story chamber: the player walks forward, talks, shoots, and walks out. The room is wide (22 m), but the playable path is a line. This is acceptable for a cinematic set-piece, but it means the Bull is always approached head-on and the mold rack is shot from a distance. See REVIEW.md.

**Companion anchor.** The Bull sits at `(1.6, 0, 6)` — centre-right of the room's length, slightly off the player's rail. He is flanked by crucibles at z = 8.5, 11, and 13.5, so the reference's "seated among molten gold" staging is preserved. The exit gate at z = 15 is behind him and raised to y = 4.6 so it does not create a green halo around his head in the close-up. This is the correct composition.

---
