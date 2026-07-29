# SHOOTER CONTEXT MANIFEST (v1.2 "Blunt Force")

Load `default.md` first, then this. Do not load `src/space/` — that is v1.3 and
crossing the boundary is explicitly forbidden (systems architecture §2.3).

## Always load

| Path | Why |
|---|---|
| `docs/GDD_v1.2_BLUNT_FORCE.md` | The design contract: pillars, tiers, cover, roster, boss |
| `src/shooter/shooter_player.gd` | Aim, cover, peek-fire, weapon host |

## Load on demand

| Task | Load |
|---|---|
| Weapon tiers | `src/shooter/weapon_base.gd`, `src/shooter/weapon_bong_blaster.gd` |
| Cover | `src/shooter/cover_system.gd` |
| Enemies | `src/shooter/enemy_drone.gd` (the reference FSM for the whole roster) |
| Projectiles | `src/shooter/smoke_projectile.gd` |
| Arena / HUD | `src/shooter/prototype_room.gd` |

## Domain rules

- **`shooter/` never imports `space/` or `level/`.** Cross-mode state goes
  through `GameManager`.
- **The player hosts a weapon; it does not implement firing.** Fire rate, ammo,
  recoil and projectiles live on `WeaponBase`. Adding tier 2–4 must not require
  editing `shooter_player.gd`.
- **Every tier is a trade, never a strict upgrade.** Tier 4 has the best DPS and
  the worst uptime. This rule exists because of the v1.0 Big Mode bug, where a
  "power-up" removed double jump and became a downgrade.
- **Enemy attacks need ≥0.8s of readable telegraph** and must never fire at
  something they cannot see (raycast LOS — that is what makes cover real).
- **Unlock is campaign-gated, never wallet-gated** (GDD pillar 4). Token
  holdings may add cosmetics only.

## Collision layers (getting these wrong is silent)

| Layer | Bit | Used by |
|---|---|---|
| World / cover | 1 | Geometry, `cover_system.gd` |
| Player | 2 | `shooter_player.gd` |
| Enemy | 4 | `enemy_drone.gd` |

Projectiles mask `1\|2\|4`. **Omitting bit 4 makes the room unwinnable** — bolts
pass straight through drones. That shipped once and reached review; the
`drone_killable` gate in `scripts/verify-shooter.mjs` exists to catch it.

## Verification

`node scripts/verify-shooter.mjs <url>` — 6 gates. `drone_killable` requires
`ComboSystem`'s score beacon to actually rise, because "fired without errors"
passes happily in a room where nothing can be hit.
