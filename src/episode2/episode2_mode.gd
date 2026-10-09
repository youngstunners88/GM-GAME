class_name Episode2Mode
extends RefCounted
## The ONE answer to "what kind of Episode 2 are we in right now?" (founder 2026-10-02: damage, input and camera
## must read the mode, and there is never a second input map). Episode 2 starts as a cart runner, plays out a
## story hideout on foot, and from the Winchester hand-over on becomes a first-person shooter/RPG with Inferno
## Bull as the companion.
##
##   RUNNER  - the minecart ride: chase camera, rail/cart health, mouse AIM, A/D hop rails.
##   HIDEOUT - the Smelting Facility conversation: third-person follow camera, free roam on foot, no damage.
##   FPS     - first person: eye camera, rifle viewmodel, mouse LOOK + LMB fire, the Bull walks beside you.
##
## The WASD / arrows / Space / mouse map is identical on foot (HIDEOUT and FPS) - skill ep2-free-roam-controls.

enum Mode { RUNNER, HIDEOUT, FPS }


static func label(m: int) -> String:
	return Mode.keys()[clampi(m, 0, Mode.size() - 1)]


## Cart health (rail ends, boulders, arrows, pits) only exists in the runner.
static func has_cart_damage(m: int) -> bool:
	return m == Mode.RUNNER


static func is_first_person(m: int) -> bool:
	return m == Mode.FPS


## Mouse look drives the view on foot; in the runner the mouse AIMS the revolver instead.
static func mouse_looks(m: int) -> bool:
	return m != Mode.RUNNER


static func camera_style(m: int) -> String:
	match m:
		Mode.FPS:
			return "first_person"
		Mode.HIDEOUT:
			return "third_person"
		_:
			return "chase"


static func control_hint(m: int) -> String:
	match m:
		Mode.FPS:
			return "WASD / ARROWS move   MOUSE look   LMB fire   RMB aim   R reload   SPACE jump   SHIFT run   ESC menu"
		Mode.HIDEOUT:
			return "WASD / ARROWS move   MOUSE look (click to lock)   SPACE jump   SHIFT run   ESC menu"
		_:
			return "MOUSE aim   LMB fire   R reload   X / RMB axe   A / D hop carts   SPACE jump / grab zipline   S duck"
