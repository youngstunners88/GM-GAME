# Evidence — F. Mushroom / Big Mode

## Root cause
`player.gd` disabled double jump while `big` (`... and not has_power_up("big")`)
and enlarged the hitbox — Big Mode was a pure downgrade.

## Fix (brief-preferred)
- Restored double jump in Big Mode (removed the `not big` guard); Big keeps a
  slightly heavier arc (×0.9) to sell mass without removing the ability.
- Added the real advantage: a GROUND POUND — press Down in the air while big
  → `_start_ground_pound()` slams down at 900px/s; on landing
  `_resolve_ground_pound()` breaks any `breakable`/`secret_wall` block touched
  and stuns (take_damage 1) enemies within 120px, with screen shake. This is
  the "break designated blocks + ground-impact + defeat enemies" advantage the
  brief lists.
- Scale/collision already consistent via power_up_handler `_update_scale`.

## Verification
Compiles + boots. Big Mode now retains double jump AND gains an offensive/
utility move → net upgrade, not downgrade. Human playtest of the pound
breaking blocks + ceiling/ladder clearance is the final tick (report). PASS
(code + boot).
