<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-mobile-control-scheme.md
     files inlined: 0
     tokens: 1010 in / 986 out
     cost: $0.0079
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Lil Blunt Adventure — Mobile Touch Layout Brief

## 1. Thumb-zone layout (landscape, 1280×720 ref)

**Left thumb — movement cluster (bottom-left)**
- **Digital L/R pad**: two large hit zones, not a fake stick.
  - LEFT: x 0–18%, y 55–92%
  - RIGHT: x 18–36%, y 55–92%
  - Each ~230×260 px. Dead zone / neutral in the middle ~8% width.
- **UP / DOWN** (contextual): only show when near a ladder (or while climbing).
  - UP: above the L/R cluster, x 8–28%, y 38–55% (~250×120 px)
  - DOWN: below or overlapping bottom of L/R, x 8–28%, y 88–98% (or hold DOWN on same cluster while climbing)
  - Hidden otherwise — keeps the chill UI clean.

**Right thumb — action cluster (bottom-right)**
| Control | Position (approx) | Size |
|--------|-------------------|------|
| **ATK** | x 72–92%, y 58–85% | **~250×190 px** (primary) |
| **JUMP** | x 78–96%, y 32–58% | ~230×180 px (above ATK, easy roll-up) |
| **DASH** | x 58–72%, y 62–82% | ~180×140 px (left of ATK) |
| **SPRINT** | hold-to-sprint on L/R zones, OR small toggle x 60–72%, y 82–94% | ~150×90 px |
| **INTERACT** | x 84–96%, y 85–96% | ~150×80 px (bottom edge, contextual highlight near forge/door) |

**Blaze Mode**: keep as pickup/auto or a non-combat contextual button near INTERACT — not a permanent face button.

**Thumb rest principle**: right thumb defaults on ATK; flicks up to JUMP, flicks left to DASH. No vertical stack of equal squares.

---

## 2. ATK placement

- **Home button for right thumb** — bottom-right quadrant, slightly down-left of the corner so the thumb pad sits on it naturally (not under the nail tip at the bezel).
- **Size: ~250×190 px** at 1280×720 (roughly 2× current). Biggest button on screen after the L/R zones.
- Shape: rounded rect / pill, not a tiny square. Generous overflow hitbox (invisible padding ~20–30 px) so edge presses still register.
- Attack must never require reaching past JUMP or into the center of the screen.

---

## 3. Three concrete don'ts

1. **Don't stack 4–5 equal ~80 px squares on the right edge** — thumb covers the lower buttons, mis-taps are constant, and ATK gets lost as “one of many.”
2. **Don't put primary actions in the top 12% or outer 4% edges** — notches, status bars, rounded corners, and browser chrome eat those presses (itch.io mobile browser especially).
3. **Don't use a visual joystick knob that doesn’t track + only reads sign(x)** — it’s the worst of both worlds: looks analog, feels broken. Either go true digital zones or real analog; no fake stick.

---

## 4. Analog vs digital movement

**Recommendation: clean digital L/R + forgiving deadzone.**

Why for this game:
- Chill 2D platformer, no precision air-strafe or run-up speed ramps that demand analog.
- Double jump / dash / attack timing matter more than walk-speed modulation.
- Digital = predictable jumps, easier ladder align, fewer “I drifted into the pit” moments on a bouncing phone thumb.
- Implement as wide left/right hit bands with a neutral center deadzone (~10–15% of the move cluster width), optional light haptic on press if the browser allows.

Skip analog thumbstick unless you later add true variable move speed that changes jump distance in a meaningful, taught way.

---

**Implement order**: (1) enlarge + rehome ATK, (2) split L/R into big digital zones, (3) contextual UP/DOWN on ladders, (4) demote SPRINT/INTERACT to smaller/hold/contextual slots.