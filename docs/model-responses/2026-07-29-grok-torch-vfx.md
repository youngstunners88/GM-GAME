<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-torch-vfx.md
     files inlined: 0
     tokens: 1317 in / 1624 out
     cost: $0.0124
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Flame Projectile VFX Spec (Torch Tap-Attack)

## 1. Flame projectile visual

### Sprite / size approach
**Use CPUParticles2D-driven visuals, not a multi-frame sprite sheet.**

No flame sheet exists, and this matches the codebase’s one-off cosmetic pattern (runtime soft radial dot, no art dependency).

| Element | Node | Role |
|---|---|---|
| Core body | `Sprite2D` + runtime radial texture | Readable 16→24px “ember lump” |
| Flame envelope | `CPUParticles2D` (local) | Grow, flicker, heat shimmer read |
| Optional glow | second soft `Sprite2D` (additive) | Cheap bloom stand-in if light is skipped |

**Size ramp (visual only, not collision):**
- Spawn: ~16×16 px core
- Peak (~40–50% lifetime): ~24×24 px via sprite scale + particle `scale_amount`
- End of flight / pre-despawn: ease back toward ~18×18 or hand off to impact burst

Collision/hitbox should stay stable (match axe’s practical hit size); only the *draw* scales.

### Colors (neon-green / orange 420 palette)

| Layer | Hex | Use |
|---|---|---|
| Core | `#FFF1A8` | Hot center (near-white gold) |
| Mid | `#FF9F1C` | Main flame body |
| Outer | `#FF4D00` | Edge / emissive rim |
| Ember accent | `#B8FF3D` | Sparse neon-green sparks (ties to existing juice) |
| Smoke trail | `#5A6670` @ 40–60% alpha | Cool neutral smoke (not purple-grey lounge) |

Modulation over life: core stays warm; outer shifts `FF9F1C` → `FF4D00` → slight `5A6670` right before despawn so death reads as “burn out,” not pop-off.

### Flicker / frame-cycle
**Yes — cheap, worth it. Do not author a sprite cycle.**

Short life (~0.6–1.0s, axe convention 1.2s) does not justify multi-frame art. Achieve flicker with:
- `CPUParticles2D` randomness on scale / rotation / `hue_variation` (small, ~0.05–0.08)
- A light sine or noise pulse on core `modulate.a` or scale (e.g. 0.9–1.1) in the projectile script’s existing motion tick — if that pulse is unwanted in code, particle randomness alone is enough

Screen time is short; particle noise reads as flame without frame art.

### PointLight2D
**Skip for the flying projectile.**

HTML5 + Android: many simultaneous lights (multi-throw, residual embers) get expensive, and lifetime is &lt;1.2s. Substitute:
- Additive soft sprite under the core (same radial texture, larger scale, low alpha, `FF9F1C`)
- Impact-only: one-shot brightness via particle color peak (no light node)

If a single torch *held* aura already uses a light, keep light on the equipped tool, not on each thrown bolt.

---

## 2. Impact VFX

**Yes — add a short burst.** Axe is SFX-only today; torch should read hotter on contact/despawn.

| Param | Value |
|---|---|
| Node | one-shot `CPUParticles2D` |
| Particle count | **12–16** |
| Lifetime | **0.25–0.35 s** |
| Direction | radial / slight upward bias |
| Colors | mid `#FF9F1C` → outer `#FF4D00` → 1–2 green embers `#B8FF3D` |
| End | fade to smoke `#5A6670` alpha 0 |

Budget split (whole effect &lt;50):
- In-flight flame envelope: ~12–18
- Trail: ~8–12
- Impact burst: ~12–16  
**Total ceiling ~40–46**

On hit *and* on lifetime despawn (weaker burst if no enemy hit — optional 60% count) so whiffs still feel like fire dying.

---

## 3. Trail VFX

**Light smoke + ember trail — flame sprite alone is not enough** at 620px/s (motion blur read is weak in 2D pixel-ish games).

| Trail | Spec |
|---|---|
| Type | `CPUParticles2D`, emitting while alive |
| Count | **8–12** live max |
| Texture | same soft radial dot |
| Color | `#5A6670` smoke + rare `#FF9F1C` / `#B8FF3D` sparks |
| Motion | local velocity drag / slight upward drift; scale down over particle life |
| Draw | behind core sprite |

Keep trail *sparse*: long continuous ribbons cost particles and muddy neon palette. Short puffs every few frames &gt; dense stream.

---

## 4. Sound design notes (keys only)

Fit `AudioManager.play_sfx()` silent-miss pattern — name now, asset later:

| Key | When | Character |
|---|---|---|
| `torch_throw` | attack tap / projectile spawn | Whoosh + soft ignition (short, &lt;0.3s) |
| `torch_flame_loop` | optional, only if flight ≥0.6s and you already have loop infrastructure | Low crackle; **skip** if loops are awkward — one-shot throw is enough |
| `torch_impact` | enemy / hazard hit | Wet sizzle + small pop |
| `torch_fizzle` | lifetime despawn, no hit | Soft extinguish / hiss (drier than impact) |

Priority if only two lands: `torch_throw` + `torch_impact`. `torch_fizzle` is nice separation from axe’s generic hit.

---

## Implementation anchors (for the programmer — not scripts)

- **Branch:** third path in `combat_handler.gd` when `GameManager.has_power_up("torch")` — tap attack spawns this projectile instead of axe.
- **Physics/behavior mirror:** `src/combat/axe.gd` + `.tscn` — `Area2D`, layer 7, mask 36, ~620 px/s, lifetime ≤1.2s (flame can be slightly shorter, ~0.8–1.0s), `take_damage()` on `"enemy"`.
- **Do not** extend `src/shooter/weapon_base.gd`.
- **Stack:** Godot 4.3 `CPUParticles2D` + `Sprite2D` only; runtime radial texture; no `GPUParticles2D`; no new sprite sheet required.

## Open / unsure
- Exact axe impact hook point (where to sibling-spawn burst) needs confirmation from `axe.gd` / its scene — not provided here.
- Whether `AudioManager` expects extensionless keys vs paths: follow whatever axe already passes into `play_sfx()`.