class_name Ep2WorldFacts
extends RefCounted
## WHAT THE PEOPLE IN THE WORLD KNOW (founder 2026-11-04: "give characters in the game intelligence to understand what changes may occur in their
## reality and can act accordingly so that they are not simply bots that dont know if it's day or night"; skill ep2-npc-reality-awareness).
## One read-only picture of the moment, built from the state the game already keeps, and one table saying which lines only make sense in which
## reality. A character chooses from what is true right now; a line that contradicts it is never played, whichever room or save it came from.

## line id -> what must be true for it to be said. Every key is a fact from now(). A line not listed here is safe in any reality.
const LINE_NEEDS: Dictionary = {
	"jh_bandit_1": {"on_horse": true},                                # "That is the rider! Get him off that horse!"
	"jh_bandit_3": {"on_horse": true, "horse_sound": true},           # "Shoot the horse if you cannot hit the man!" - not once they have shot it
	"trail_lb_unhorse": {"horse_down": true},                         # "The horse is down. I will finish it on foot."
}


## The moment as a character could see it. `on_horse`: is Lil Blunt in the saddle. `sun`: the room's sun, for day or night.
static func now(armory: Ep2ArmoryState, on_horse: bool = false, sun: DirectionalLight3D = null, player_hostile: bool = false) -> Dictionary:
	var wounds: int = armory.horse_wounds if armory != null else 0
	return {
		"horse_sound": wounds == 0,
		"horse_wounded": wounds > 0 and wounds < Ep2ArmoryState.HORSE_WOUNDS_MAX,
		"horse_down": wounds >= Ep2ArmoryState.HORSE_WOUNDS_MAX,
		"on_horse": on_horse,
		"night": is_night(sun),
		"player_hostile": player_hostile,
	}


## Night by the room's own sun: below the horizon or too faint to see by. No sun known = day.
static func is_night(sun: DirectionalLight3D) -> bool:
	if sun == null:
		return false
	return sun.light_energy < 0.25 or sun.global_transform.basis.z.y <= 0.0


## Does this line fit the moment?
static func allows(line_id: String, facts: Dictionary) -> bool:
	var needs: Dictionary = LINE_NEEDS.get(line_id, {})
	for k in needs:
		if facts.get(k) != needs[k]:
			return false
	return true


## The lines that fit, keeping their order.
static func fitting(line_ids: Array, facts: Dictionary) -> Array:
	return line_ids.filter(func(id: Variant) -> bool: return allows(str(id), facts))
