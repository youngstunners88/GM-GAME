<!-- dispatched: x-ai/grok-4.5
     prompt: /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/prompts/grok-skateboard-boss-presence.md
     files inlined: 3
     tokens: 25504 in / 1005 out
     cost: $0.0570
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Part 1 — Magic board (implementable)

**Host:** Blaze Rush corridor only. It already auto-runs and places `$SMOKE` on a fixed path; a rideable pickup in normal levels fights jump/walk and the chill platformer contract.

**Mode flag:** `board_segment` stretch inside a Blaze Rush layout (same auto-X as rush; swap jump cube → board rig for that X range).

| Param | Value |
|---|---|
| Auto scroll (inherit rush) | `speed_start`→`speed_end` (layout; ~320–460 px/s) |
| Steer max `|vx_offset|` | **140 px/s** |
| Steer accel / decel | **900 / 1100 px/s²** |
| Steer input | left/right only (or drag); adds to auto `velocity.x` |
| Hover band | **fixed path height** `path_y` ± **28 px** bob; **no** up/down steer |
| Bob | amp **10 px**, period **1.8 s** (`sin`) |
| Y spring to band center | **velocity.y = (target_y - y) * 8.0** (mirrors Distributor float feel, snappier) |
| Floor clearance | board deck **≥ 18 px** above `GROUND_Y` collision top; clamp `y` so deck never intersects floor |
| Optional jump | same `JUMP_VELOCITY (-700)` / `GRAVITY (2200)`; on land re-enter band spring; **main token line at band center ± 12 px** so jump is optional only |
| Magnet radius | **48 px** |
| Magnet pull | **220 px/s** toward token, only while `distance < 48` and token on board layer; cap lateral so it can’t yank off steer deadzone |
| Drop-off | end of segment: 0.4 s ease, restore cube controller |

**Token line rule:** place smoke at `GROUND_Y - height` with `height` in **[band_center_offset − 8, band_center_offset + 8]** so steer-only clears the main line.

**Visual (ColorRect / Polygon2D, no new art):**
- Deck: flat rounded plank `ColorRect` ~**56×10**, fill `Color(0.25, 0.55, 0.22)` with lime edge `Color(0.55, 1.0, 0.25)` 2 px top lip (same read language as FUD top lip / safe edge).
- Trucks/wheels: two small dark `ColorRect` under deck; soft under-glow `Polygon2D` diamond/haze `Color(0.45, 1.0, 0.4, 0.3)` bobbing opposite the deck (lift source, like Distributor disc).
- Lil Blunt: existing cube/nugget seated **12 px** above deck; short lime streak particles behind (reuse rush trail settings, half amount).

---

## Part 2 — Auditor scale

**1.3×**

Reason: first boss stays readable/fair below Distributor’s **1.7×**, so size steps **1.3 → 1.7 → Claim Jumper (~2.0–2.2)** escalate instead of flat or inverted.