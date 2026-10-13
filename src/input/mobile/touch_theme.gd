class_name TouchTheme
extends Resource
## Look of the on-screen touch controls: tints, opacities, stroke widths.
##
## A plain Resource (not a Godot `Theme`) because the controls draw themselves
## with vector primitives and only need a handful of named numbers and colours.
## Swap the resource to re-skin all controls per biome without touching layouts
## or input logic (`MobileLayoutManager.apply_theme`). The default instance is
## `themes/smoke_realm_touch_theme.tres`.

## Resting opacity: quiet enough to read the platforming through it.
@export_range(0.05, 0.6, 0.01) var idle_alpha: float = 0.30
## Opacity while a finger is on the control.
@export_range(0.3, 1.0, 0.01) var pressed_alpha: float = 0.78
## Opacity while the first-time hint is showing.
@export_range(0.3, 1.0, 0.01) var hint_alpha: float = 0.88
## Share of the disc that is filled (the rest of the look is the ring + glyph).
@export_range(0.0, 1.0, 0.01) var fill_strength: float = 0.40
@export var ring_width_dp: float = 2.5
@export var glyph_width_dp: float = 3.6
@export var label_color: Color = Color(1, 1, 1, 0.96)
@export var label_outline: Color = Color(0, 0, 0, 0.85)
@export var label_size_dp: float = 11.0

@export_group("Role tints")
## Smoke Realm green for movement, cyan for jump, coral for attack, violet dash,
## amber run, gold grab: the same accents the old overlay used.
@export var tint_stick: Color = Color(0.55, 0.95, 0.66)
@export var tint_jump: Color = Color(0.42, 0.85, 1.0)
@export var tint_attack: Color = Color(1.0, 0.48, 0.44)
@export var tint_dash: Color = Color(0.78, 0.54, 1.0)
@export var tint_run: Color = Color(1.0, 0.72, 0.38)
@export var tint_grab: Color = Color(1.0, 0.85, 0.38)
@export var tint_hint: Color = Color(0.82, 0.92, 0.88)

## Tint for a control `role` (the layout scenes name roles, not colours).
func tint_for(role: StringName) -> Color:
	match role:
		&"stick": return tint_stick
		&"jump": return tint_jump
		&"attack": return tint_attack
		&"dash": return tint_dash
		&"run": return tint_run
		&"grab": return tint_grab
		_: return tint_hint
