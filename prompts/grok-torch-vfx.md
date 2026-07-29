ROLE: VFX designer for a 2D platformer flame projectile.

CONTEXT — read carefully, this corrects a wrong assumption in the brief that
generated this request:

The requesting brief assumed the torch attack should extend
`src/shooter/weapon_base.gd`. That class belongs to a completely different,
standalone game mode (`src/shooter/shooter_player.gd`, a separate playable
prototype room) and is explicitly documented elsewhere as never touching the
main platformer's `player.gd`. The torch attack is a MAIN-CAMPAIGN feature —
it belongs in the main platformer's existing combat system instead:

- `src/player/combat_handler.gd` — a small dedicated Node already handling
  the "attack" input action (tap = throw an axe; holding while the Purple
  Weed power-up is active = a fire-breath cone). Cooldown-gated, one move set
  per power-up.
- `src/combat/axe.gd` (+`.tscn`) — the base thrown projectile: an `Area2D` on
  collision layer 7 (Projectiles), mask 36 (Enemies bit 3 + Hazards bit 6),
  flies flat, 620px/s, 1.2s lifetime, spins in flight, calls `take_damage()`
  on anything in the "enemy" group.
- `src/combat/fire_breath.gd` (+`.tscn`) — the heavier purple-only move: an
  `Area2D` cone parented to the player, ticks damage every 0.15s for ~0.9s.
- The main-game "torch" is a single-slot power-up already in the repo
  (`src/powerups/torch_tool.gd`, 20s duration, `GameManager.has_power_up
  ("torch")`) that currently only does a passive proximity-damage aura and
  shows a torch sprite in Lil Blunt's hand. It has no attack move yet — that
  is what's being added, as a third branch in `combat_handler.gd` alongside
  the existing axe/purple-fan/fire-breath branches (power-ups are a single
  slot, so torch and purple are never both active — no interaction to design
  around).

DELIVERABLE: a flame-projectile visual spec for a NEW thrown attack (tap
"attack" while torch is equipped throws it, replacing the base axe throw for
that power-up's duration):
1. Flame projectile visual spec:
   - Sprite/size: base ~16x16px, growing to ~24x24px at peak — state whether
     this should be achieved via a CPUParticles2D-driven visual (this
     codebase's usual approach for one-off cosmetic effects — a soft radial
     dot texture, generated once at runtime, no art file needed) or a small
     multi-frame sprite, given no dedicated flame sprite sheet exists yet.
   - Colors: core, mid, outer flame tones + a smoke-trail tone (give hex
     values, staying in the game's existing neon-green/orange 420-friendly
     palette, not the purple-grey Smoke Lounge palette — this is main
     campaign, daylight/torch-lit, not the chill secret room).
   - Whether a flicker/frame-cycle read is achievable cheaply given the
     lifetime is short (~0.6-1s of flight before impact/despawn, following
     axe.gd's 1.2s convention) or whether that's more effort than the
     projectile's screen time justifies.
   - Whether a PointLight2D is worth the cost for a projectile this
     short-lived, given the game targets HTML5 + Android.
2. Impact VFX: a short particle burst on hit/despawn, similar scale to what
   `axe.gd`'s impact currently does (just an SFX cue today, no particles) —
   should torch's impact add a burst, and how many particles/how long.
3. Trail VFX: how it should read while flying (a smoke trail, or the flame
   sprite alone is enough).
4. Sound design notes only (no implementation): what SFX keys would fit
   `AudioManager.play_sfx()`'s existing pattern (it already silently no-ops
   on a missing file, so naming them now costs nothing) — e.g. a throw cue,
   an impact sizzle.

CONSTRAINTS:
- Godot 4.3 built-in CPUParticles2D + Sprite2D only (no GPUParticles2D — this
  targets HTML5 export).
- Mobile-friendly: under 50 particles for the whole effect (projectile +
  trail + impact combined).
- Do not write GDScript.
- If you're unsure whether something is feasible in Godot 4.3, say so rather
  than asserting it.
