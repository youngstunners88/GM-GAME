<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-blaze-rush-visual.md
     files inlined: 0
     tokens: 1240 in / 2213 out
     cost: $0.0158
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Blaze Rush — Art Direction

## 1. Visual Direction

### Palette — “Electric Haze”
Distinct from Smoke Realm green, Crystal cyan, Lounge purple-grey. Fast = hot + acid contrast on deep void.

| Role | Color | Hex-ish |
|---|---|---|
| Void / deep BG | Near-black magenta | `Color(0.04, 0.0, 0.08)` |
| Mid haze | Hot violet | `Color(0.35, 0.05, 0.55)` |
| Accent electric | Acid lime | `Color(0.55, 1.0, 0.25)` |
| Hazard hot | Ember / candle red-orange | `Color(1.0, 0.25, 0.08)` |
| Safe ground | Cool lavender-steel | `Color(0.45, 0.35, 0.75)` |
| Safe top-edge | Bright cyan-mint | `Color(0.3, 1.0, 0.85)` |
| Collectible | Soft cream-white + pale gold rim | `Color(1.0, 0.95, 0.75)` |
| Player body | Saturated neon green (keep) | bump saturation vs. current |
| Player eyes | Black with tiny white speck (alive) | — |

**Rule:** hazards = warm (red/orange). Safe = cool (lavender + cyan edge). Collectibles = light/desaturated cream. Never put warm fill on a landable surface.

### Background layers (3 + particles)

All primitives / CPUParticles2D. No sprite sheets.

| Layer | Content | Scroll (vs run 320px/s) | Notes |
|---|---|---|---|
| L0 Void | Full-screen `ColorRect` near-black magenta | 0 | Static base |
| L1 Far haze | 2–3 large soft radial-gradient blobs (procedural texture on `Sprite2D`/`TextureRect`), violet→transparent | ~0.15× | Slow drift; optional very slow vertical bob via code tween |
| L2 Streak field | CPUParticles2D: thin horizontal line-streaks (lime/violet, low alpha), emitted screen-left, velocity matches run feel | ~0.55× visual | Motion-linked (see §2) |
| L3 Near dust | CPUParticles2D: small soft dots, cream/violet | ~0.85× | Sparse; depth cue only |

**Feasibility:** radial-gradient textures are in-engine pattern you already use — fine. Horizontal streak particles = elongated `scale`, short lifetime, `direction = Vector2(-1,0)`, no gravity. Stay on CPUParticles2D.

**Do not** add a 4th full-screen rect layer or heavy per-frame blur — HTML5 will feel it at 320px/s scroll.

### Obstacle / pickup read at speed

Silhouette + color locked. Labels secondary (FUD text can stay but must not be the only signal).

| Type | Silhouette | Fill | Edge / top | Never |
|---|---|---|---|---|
| **candle** (kill) | Tall thin vertical + 1px wick above | Ember red-orange body | Hotter yellow-orange top cap on body; wick = thin pale | Same purple family as floor/walls |
| **fud_wall** (safe top / kill side) | Wide block, heavier than floor segment height | Cool lavender-steel (same family as floor) | **Thick cyan-mint top lip only** (2–3px visual); sides = darker violet, no mint | Red/orange anywhere; mint on sides |
| **smoke** ($SMOKE) | Small square/diamond, smaller than player | Cream-white | Soft gold/pale pulse halo (particle or scaled rect) | Hazard red; large enough to read as wall |
| **gap** | Absence of floor + optional dark pit wash below | Void shows through | Floor ends with mint edge stopping cleanly | Decorative particles that bridge the gap visually |

**Glance test:** at speed, player only needs:
- **Red vertical** → jump or die  
- **Mint horizontal lip** → landable  
- **Small cream** → grab  
- **Missing mint line** → gap  

Keep candle width clearly < fud_wall width. Keep smoke token ≤ ~½ player size.

---

## 2. Motion-Linked Effects (run speed / proximity, not beat)

### Pulse / streak with forward motion
- **L2 streak field:** emission strength and streak length scale lightly with run speed (faster = longer, slightly denser). Caps below.
- **Floor mint edge:** optional short afterimage segments (2–3 faint `ColorRect`s or particle puffs) sliding backward from floor tops — very low alpha, sells speed without noise.
- **Player trail:** CPUParticles2D behind player — small green squares fading out, emit rate tied to speed. 1 trail emitter only.
- **Smoke token idle:** gentle scale pulse (1.0 → 1.12) + tiny radial cream particles on proximity pickup (burst, not continuous).
- **Candle:** wick tip 1-dot ember particle upward (sparse). Reads “hot/danger,” not decoration spam.

### Hazard / gap telegraph (critical for auto-run)
Auto-run at 320px/s ≈ ~0.4s to cross ~128px. Telegraph must lead by ~0.35–0.5s.

**Practical primitive approach (no new art):**
1. **Edge warning flash on upcoming floor end / candle / wall side** — a thin vertical acid-lime or ember bar at the *next* hazard’s x, parented in world space, opacity ramps as it approaches screen (starts ~400–500px ahead of player, fades once on-screen).
2. **Top-of-screen or horizon “pip” row** (optional, minimal): 3–4px tall markers scrolling in a HUD strip, color-coded (ember = candle, cool = fud, void notch = gap). Only if it doesn’t fight main-game HUD; otherwise skip and rely on (1).
3. **Screen-edge vignette warmth:** when a candle is within ~350px ahead, subtle shift of a full-screen radial vignette toward ember at the right edge (procedural gradient, low alpha). Proximity-driven, not music.

Prefer (1) + player trail. Skip beat-sync language until audio exists; hook the same emitters to a future music clock later.

---

## 3. Consistency vs. main identity

**Recommendation: allowed to look different — with one tether.**

This is a hidden secret compress-into-smoke-cube mode. Full Lounge chill or Realm forest would undercut “you broke into something faster.”

**Keep one thread back to Smoke Realm:**
- Player stays the green cube language (eyes, body) — same character, different energy.
- $SMOKE cream token = same collectible identity as main-game smoke currency if that read already exists.
- Name/portal framing (Blaze Portal) can carry Realm vibe; the corridor itself goes electric.

**Drop:** forest greens, chill purple-grey Lounge grading, slow particle drift aesthetics.

---

## 4. Asset list

### Achievable now (CPUParticles2D + ColorRect/Panel + procedural radial gradients)

- L0 void rect  
- L1 2–3 radial-gradient haze sprites (runtime texture)  
- L2 horizontal streak particles (lime/violet)  
- L3 sparse dust particles  
- Player body + eyes (existing rects, retinted)  
- Player speed trail (one CPUParticles2D)  
- Floor segments + mint top edge rects (retint)  
- Candle = stacked rects (body + wick) + optional 1-point ember particle  
- Fud wall = rect + thick mint top lip + darker side value (text optional)  
- Smoke token = small rect/diamond + proximity cream burst  
- Gap = no floor + optional darker pit rect below corridor  
- Proximity warning bar (thin world-space ColorRect, fade by distance)  
- Optional right-edge warm vignette (radial gradient, low alpha)

**Particle budget (HTML5/Android ceiling):**  
- Total live particles across all emitters ≈ **80–120** peak.  
  Suggested split: trail 25, streaks 40, dust 20, candle embers 5–8, pickup bursts 15 short-lived.  
- Max **4–5** concurrent CPUParticles2D nodes. No per-obstacle permanent emitters; candles share one ember system or use scripted 1-dot flashes if counts climb.

### Needs a real sprite sheet (out of scope this pass — do not block on these)

| Sheet | Why |
|---|---|
| `blaze_candle_sheet` | Legible wick/flame animation, market-candle bevel |
| `blaze_fud_wall_sheet` | Styled brick/FUD graffiti without relying on `Label` |
| `blaze_smoke_token_sheet` | Soft billow / currency icon matching main HUD |
| `blaze_portal_sheet` | Entry portal fantasy (if portal is still a flat rect) |
| `blaze_player_cube_sheet` | Squash/stretch run frames, eye blink |

Design this pass so rects + particles already read correctly; sheets only upgrade fidelity later.

---

## Direction summary

**Trip without mud:** void magenta base, acid lime motion streaks, warm = death, cool mint lip = safe, cream = grab. Three BG layers + one player trail. Telegraph hazards ~400px ahead with a thin color bar. Secret mode may go electric; keep green cube + $SMOKE as the only hard tethers to Realm identity.