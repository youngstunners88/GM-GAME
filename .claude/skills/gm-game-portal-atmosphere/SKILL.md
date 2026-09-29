---
name: gm-game-portal-atmosphere
description: Add life to a Protocol Portal room without touching the founder-approved painting - drifting haze, smoke wisps, breathing glows on painted features, coin glints, rising embers. Config-driven via RoomLayout.ATMOSPHERE. TRIGGER when the founder asks for haze/smoke blowing in, "accentuate what's already there", a redundant gate/door, or the room feeling static.
---

# Portal atmosphere & accents

All of it lives in `RoomLayout.ATMOSPHERE[protocol]` and is built by `StudyRoom._build_atmosphere()`.
No per-room code: add data, not branches.

| key | what | notes |
|---|---|---|
| `haze` / `far` / `near` | two drifting fog layers (`portal_haze.gdshader`): far behind the props (z -90), near in front (z 3000) | keep `near` <= 0.10 or it veils the props |
| `sources[]` `door/rise/drift` | CPUParticles2D smoke wisps | `door` = smoke breathing out of a doorway (Smoke lounge) |
| `accents[]` `glow` | additive radial bloom that breathes, above the painting and under every prop (z -80) | pulse = half-cycle seconds; use it to accentuate a painted arch, crystal, lantern |
| `accents[]` `rise` | additive embers lifting off a point | for doors/braziers |
| `accents[]` `glints` | additive twinkles in place | sun on coin heaps |

## Rules that cost time
- **Blotch rule:** haze/glow colours must NOT be green-dominant (`scripts/check-green-vfx.py` flags translucent
  G>R,G>B literals in .gd/.tscn). Cyan needs B >= G (e.g. 0.40, 0.90, 0.95); warm glows keep R >= G >= B.
- **CPUParticles2D gravity defaults to 98 px/s^2.** Set `gravity` explicitly on every emitter or motes fall
  out of the map (seen as dots in the letterbox). `local_coords = true` for static emitters.
- Additive glow needs a `CanvasItemMaterial` with `BLEND_MODE_ADD`; alpha is tweened, not scale.
- Accent, don't duplicate: when the painting already shows a gate/door/crystal, glow it instead of placing
  another prop on it (founder on Diamonds: "the gate seems redundant ... just accentuate what's already there").
- Verify with the capture tool at overview zoom AND a close-up; subtle in the overview is correct.
