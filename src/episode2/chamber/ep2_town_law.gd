class_name Ep2TownLaw
extends Node3D
## Consequences for shots fired in GoldMine Town. The chamber supplies the real
## camera ray (and the Gatling's traced round); this module owns capsule hits,
## facade/window damage, restrained blood, the BTC ledger, and the walking arrest.
## It deliberately uses the existing folk walk/step methods: no teleport, fade,
## second health system, physics body, or renderer feature beyond Compatibility.

signal arrest_state_changed(state: String)
signal fine_charged(amount: int, paid: int, debt: int)

const CELL_SECONDS := 120.0
const FINE_QUIET_SECONDS := 3.0
const HORSE_FINE_BTC := 1
const BLOOD_SCRIPT := "res://src/episode2/fx/ep2_blood_fx.gd"
const SOUND_DIR := "res://src/episode2/extras/audio/town/"
const BAM_MODEL := "res://src/episode2/extras/jail/bam_bankman_free.glb"
const ARREST_LINE := "Drop it, Blunt. You just shot a man in my town."
const RELEASE_LINE := "Your irons stay with me while you're in my town. Take your pick and walk soft."
const FINE_LINE := "That damage comes out of your purse, Blunt. BTC, on the barrelhead."

const CELL_LINES: Array = [
	["BAM", "Name's Bam. Bam Bankman Free. The last part is doing a lot of work."],
	["LIL BLUNT", "Easy, Bam. Lil Blunt. You look like you've had a year."],
	["BAM", "Let's just say the books didn't balance. I'd sooner leave it there."],
	["LIL BLUNT", "That's enough for me. No man owes me his worst day."],
	["BAM", "I used to call every dip an opportunity. Then the floor learned my name."],
	["LIL BLUNT", "Floor's an honest teacher. Still, a man can get back up."],
	["BAM", "I told folks I was building a future. Turned out I was renting their patience."],
	["LIL BLUNT", "Well. You can sit quiet with me. That's a fair trade."],
	["BAM", "You're kind, little man. Next coin I earn, I'm counting it twice."],
	["LIL BLUNT", "Count it slow, Bam. And walk softer than you talk."],
]
const CELL_LINE_TIMES: Array = [4.0, 16.0, 28.0, 40.0, 52.0, 64.0, 76.0, 88.0, 100.0, 112.0]
const SHERIFF_COLD_LINES: Array = [
	["SHERIFF", "Walk soft, Blunt. My town remembers."],
	["SHERIFF", "You're still welcome at my office. The easy trust has to be earned back."],
]
const MINISTER_COLD_LINES: Array = [
	["MIKE DEAN", "I'll pray for the man you hurt, and for the temper that did it."],
	["MIKE DEAN", "Kindness costs nothing, son. Try spending a little more of it."],
]
const COLD_PEOPLE_LINES: Dictionary = {
	"clerk": ["CLERK", "Papers are in order. Your manners are another matter."],
	"oldtimer": ["OLDTIMER", "I've seen quicker tempers than yours end in the same cell."],
	"rancher": ["RANCHER", "Keep your barrel off my horses and your distance from me."],
	"grandma": ["GRANDMA", "You sit with your thoughts, dear. I'll keep my welcome for later."],
	"youth": ["YOUTH", "That was your one warning shot with us. Don't ask for another."],
}

const CELL_PLAYER_LOCAL := Vector3(1.65, 0.0, -5.80)
const CELL_BAM_LOCAL := Vector3(2.55, 0.0, -6.10)
const CELL_GATE_LOCAL := Vector3(1.65, 0.0, -4.75)
const CELL_VISIT_LOCAL := Vector3(1.65, 0.0, -4.00)
const CELL_GUARD_LOCAL := Vector3(1.65, 0.0, -3.20)
const CELL_BOUNDS := Rect2(0.75, -6.90, 2.45, 2.00)

var law_state: String = "idle"
var facade_holes: int = 0
var broken_windows: int = 0
var horse_hits: int = 0
var person_hits: int = 0
var damage_marks: int = 0
var fines_charged: int = 0
var last_fine: int = 0
var last_debt: int = 0
var blood_events: int = 0
var release_count: int = 0
var wounded_cast: Array = []
var caption_log: Array = []
var cell_captioned: Array = []
var cell_line_times: Array = []
var last_shot: Dictionary = {}

var _host: Node = null
var _visuals: Node3D = null
var _people: Ep2TownPeople = null
var _sheriff: Ep2TownFolk = null
var _minister: Ep2TownFolk = null
var _cast: Array = []
var _horses: Array = []
var _buildings: Array = []
var _effects: Array = []
var _bam: Ep2TownFolk = null
var _gate: Node3D = null
var _cell_t: float = 0.0
var _cell_line_i: int = 0
var _approach_repath: float = 0.0
var _release_stage: int = 0
var _time: float = 0.0
var _fine_pending: bool = false
var _fine_quiet: float = 0.0
var _bill_holes: int = 0
var _bill_windows: int = 0
var _bill_horses: int = 0
var _cold_cd: float = 0.0
var _cold_cast_done: Dictionary = {}
var _blood: Script = null
var _blood_checked: bool = false
static var _hole_tex: ImageTexture = null
static var _crack_tex: ImageTexture = null


## Bind the law to the real chamber and scan its built town. Called once after
## the chamber's people step, and refresh_targets() again after stable restore.
func setup(chamber: Node) -> void:
	_host = chamber
	_visuals = _host.get("_visuals") as Node3D
	_build_building_tests()
	refresh_targets()
	_build_cell_folk()
	_build_cell_gate()


## Refresh roster/cast/horse references without retaining freed actors.
func refresh_targets() -> void:
	_people = _host.get("_people") as Ep2TownPeople
	_cast.clear()
	_horses.clear()
	_sheriff = _host.get("_sheriff") as Ep2TownFolk
	_minister = _host.get("_minister") as Ep2TownFolk
	_add_cast("sheriff", _sheriff, "story", 1.78)
	_add_cast("minister", _minister, "story", 1.65)
	_add_cast("bartender", _host.get("_bartender") as Ep2TownFolk, "story", 1.76)
	_add_cast("rich", _host.get("_rich") as Ep2TownFolk, "story", 1.86)
	_add_cast("utah", _host.get("_utah") as Ep2TownFolk, "story", 1.74)
	_add_cast("opponent", _host.get("_opp") as Ep2TownFolk, "person", 1.84)
	_add_cast("accomplice", _host.get("_accomplice") as Ep2TownFolk, "story", 1.74)
	_add_cast("inferno", _host.get("_bull") as Node3D, "bull", 2.90)
	if _visuals != null:
		var logan: Node3D = _visuals.find_child("Logan", true, false) as Node3D
		_add_cast("logan", logan, "story", 1.80)
	_refresh_stable_cast()
	_refresh_horses()


func _add_cast(id: String, node: Node3D, kind: String, height: float) -> void:
	if node != null:
		_cast.append({"id": id, "node": node, "kind": kind, "height": height})


func _refresh_stable_cast() -> void:
	var yard: Node = _host.get("_stable_yard") as Node
	if yard == null and _visuals != null:
		yard = _visuals.find_child("StableYard", true, false)
	if yard == null:
		return
	var actors: Variant = yard.get("actors")
	if actors is Dictionary:
		for key in actors:
			_add_stable_actor(str(key), actors[key])
	elif actors is Array:
		for i in actors.size():
			_add_stable_actor("stable_%d" % i, actors[i])


func _add_stable_actor(id: String, actor: Variant) -> void:
	if actor is Ep2TownFolk:
		_add_cast(id, actor as Ep2TownFolk, "story", (actor as Ep2TownFolk).height_m)
	elif actor is Node3D:
		_add_cast(id, actor as Node3D, "story", 1.80)
	elif actor is Dictionary and actor.get("folk") is Ep2TownFolk:
		var folk: Ep2TownFolk = actor["folk"]
		_add_cast(id, folk, "story", folk.height_m)


func _refresh_horses() -> void:
	if _visuals == null:
		return
	var seen: Dictionary = {}
	for node in _visuals.find_children("Horse*", "Node3D", true, false):
		var horse: Node3D = node
		var parent_name: String = String(horse.get_parent().name) if horse.get_parent() != null else ""
		if parent_name == "TownLife" or "Stable" in parent_name or "Paddock" in parent_name or "Horses" in parent_name:
			if not seen.has(horse.get_instance_id()):
				seen[horse.get_instance_id()] = true
				_horses.append(horse)


## Resolve one first-person round. In the live draw the opponent is deliberately
## omitted: gold_town.gd handles him through its original win path.
func player_shot(eye: Vector3, direction: Vector3, in_draw: bool = false) -> Dictionary:
	if direction.length_squared() < 1e-8:
		return {"kind": "miss"}
	var hit: Dictionary = trace(eye, direction.normalized(), in_draw)
	last_shot = hit
	_resolve_hit(hit, direction.normalized())
	return hit


## Resolve a Gatling round only if its bore leaves the yard toward the street.
## Ordinary demonstration fire into the plates and bales remains consequence-free.
func gatling_round(origin: Vector3, direction: Vector3, _yard_hit: Dictionary = {}) -> void:
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	var local_dir: Vector3 = (xf.basis.inverse() * direction).normalized()
	var ahead: Vector3 = origin + direction.normalized() * 30.0
	var streetward: bool = local_dir.x < -0.12 or (absf(ahead.x) < 12.0 and ahead.z > 1390.0 and ahead.z < 1495.0)
	if not streetward:
		return
	if _people != null:
		_people.notify_danger(origin, 32.0)
	player_shot(origin, direction, false)


## Return the nearest target along a normalized ray. People/cast/horses are
## capsules, facades are planes, and a window is tested before its front face.
func trace(eye: Vector3, direction: Vector3, in_draw: bool = false) -> Dictionary:
	var best: Dictionary = {"kind": "miss", "t": 160.0, "point": eye + direction * 160.0}
	var best_t: float = 160.0
	var protected_t: float = INF
	if _people != null:
		for person in _people.people:
			var folk: Ep2TownFolk = person.folk
			if folk == null or folk.dead:
				continue
			var t: float = _person_ray(eye, direction, folk, 0.34)
			if t < best_t:
				best_t = t
				best = {"kind": "person", "id": person.id, "folk": folk, "t": t, "point": eye + direction * t}
	for entry in _cast:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node) or not node.visible:
			continue
		var id: String = str(entry["id"])
		if in_draw and id == "opponent":
			continue
		var kind: String = str(entry["kind"])
		if kind == "person" and node is Ep2TownFolk and (node as Ep2TownFolk).dead:
			continue
		var height: float = float(entry["height"])
		var a: Vector3 = node.global_position + Vector3(0.0, 0.25, 0.0)
		var b: Vector3 = node.global_position + Vector3(0.0, height, 0.0)
		var t: float = _ray_capsule(eye, direction, a, b, 0.40 if kind == "bull" else 0.36)
		if kind == "bull":
			protected_t = minf(protected_t, t)
			continue
		if t < best_t:
			best_t = t
			best = {"kind": kind, "id": id, "folk": node, "t": t, "point": eye + direction * t}
	for horse in _horses:
		if not is_instance_valid(horse) or not horse.visible:
			continue
		var centre: Vector3 = horse.global_position + Vector3(0.0, 1.05, 0.0)
		var axis: Vector3 = horse.global_transform.basis.x.normalized()
		var t: float = _ray_capsule(eye, direction, centre - axis * 0.92, centre + axis * 0.92, 0.61)
		if t < best_t:
			best_t = t
			best = {"kind": "horse", "node": horse, "t": t, "point": eye + direction * t}
	var structural: Dictionary = _trace_buildings(eye, direction, best_t)
	if not structural.is_empty():
		best = structural
		best_t = float(structural["t"])
	if protected_t < best_t:
		return {"kind": "miss", "t": protected_t, "point": eye + direction * protected_t, "protected": "inferno"}
	return best


func _person_ray(eye: Vector3, direction: Vector3, folk: Ep2TownFolk, radius: float) -> float:
	var a: Vector3 = folk.global_position + Vector3(0.0, 0.22, 0.0)
	var b: Vector3 = folk.global_position + Vector3(0.0, folk.height_m, 0.0)
	return _ray_capsule(eye, direction, a, b, radius)


func _ray_capsule(eye: Vector3, direction: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	var best: float = INF
	for i in 7:
		var centre: Vector3 = a.lerp(b, float(i) / 6.0)
		best = minf(best, _ray_sphere(eye, direction, centre, radius))
	return best


func _ray_sphere(eye: Vector3, direction: Vector3, centre: Vector3, radius: float) -> float:
	var oc: Vector3 = eye - centre
	var b: float = oc.dot(direction)
	var c: float = oc.length_squared() - radius * radius
	var disc: float = b * b - c
	if disc < 0.0:
		return INF
	var root: float = sqrt(disc)
	var t: float = -b - root
	if t < 0.02:
		t = -b + root
	return t if t >= 0.02 else INF


func _resolve_hit(hit: Dictionary, direction: Vector3) -> void:
	match str(hit.get("kind", "miss")):
		"person":
			_kill_person(hit, direction)
		"story":
			_wound_story(hit, direction)
		"horse":
			_hit_horse(hit, direction)
		"facade":
			_hit_facade(hit, direction)
		"window":
			_hit_window(hit, direction)


func _kill_person(hit: Dictionary, direction: Vector3) -> void:
	var folk: Ep2TownFolk = hit["folk"]
	if folk == null or folk.dead:
		return
	person_hits += 1
	_blood_spurt(hit["point"], direction, 0.72)
	_blood_stain(folk, hit["point"], -direction, 0.46)
	folk.fall_dead()
	_blood_pool(folk.global_position, 0.62, 5.0)
	_play_sound("body_thud.ogg", folk.global_position, -8.0)
	if _people != null:
		_people.notify_danger(folk.global_position, 32.0)
	GameManager.set_town_standing("cold")
	_begin_arrest()


func _wound_story(hit: Dictionary, direction: Vector3) -> void:
	var folk: Ep2TownFolk = hit["folk"]
	if folk == null or folk.dead:
		return
	person_hits += 1
	if not wounded_cast.has(str(hit["id"])):
		wounded_cast.append(str(hit["id"]))
	folk.set_meta("law_wounded", true)
	folk.kick()
	_blood_spurt(hit["point"], direction, 0.48)
	if _people != null:
		_people.notify_danger(folk.global_position, 32.0)
	GameManager.set_town_standing("cold")
	_begin_arrest()


func _hit_horse(hit: Dictionary, direction: Vector3) -> void:
	var horse: Node3D = hit["node"]
	horse.set_meta("law_wounded", true)
	horse_hits += 1
	_bill_horses += 1
	_blood_spurt(hit["point"], direction, 0.52)
	_blood_stain(horse, hit["point"], -direction, 0.40)
	_note_offence()


func _hit_facade(hit: Dictionary, _direction: Vector3) -> void:
	facade_holes += 1
	_bill_holes += 1
	_add_hole(hit["point"], hit["normal"])
	_spawn_chips(hit["point"], hit["normal"], false)
	_play_sound("wood_splinter.ogg", hit["point"], -4.0)
	_note_offence()


func _hit_window(hit: Dictionary, _direction: Vector3) -> void:
	var window: Dictionary = hit["window"]
	if bool(window.get("broken", false)):
		return
	window["broken"] = true
	broken_windows += 1
	_bill_windows += 1
	var pane: Node3D = _pane_for(window)
	if pane != null:
		pane.set_meta("law_broken", true)
		pane.visible = false
	else:
		window["overlay"] = _add_cracks(window, hit["normal"])
	_spawn_chips(hit["point"], hit["normal"], true)
	_play_sound("window_shatter.ogg", hit["point"], -2.0)
	_note_offence()


func _note_offence() -> void:
	_fine_pending = true
	_fine_quiet = 0.0


## Advance fines, effects, the arrest and the two-minute cell conversation.
func step(delta: float) -> void:
	_time += delta
	_cold_cd = maxf(0.0, _cold_cd - delta)
	for i in range(_effects.size() - 1, -1, -1):
		_effects[i][1] = float(_effects[i][1]) - delta
		if float(_effects[i][1]) <= 0.0:
			var node: Node = _effects[i][0]
			if is_instance_valid(node):
				node.queue_free()
			_effects.remove_at(i)
	if _fine_pending:
		_fine_quiet += delta
		if _fine_quiet >= FINE_QUIET_SECONDS:
			_charge_fine()
	if _bam != null:
		_bam.step(delta)
	match law_state:
		"approach":
			_step_approach(delta)
		"escort":
			_step_escort(delta)
		"enter":
			_step_enter(delta)
		"cell":
			_step_cell(delta)
		"release":
			_step_release(delta)
		"idle":
			_tick_cold_cast()


func _charge_fine() -> void:
	_fine_pending = false
	var amount: int = _bill_windows + int(ceil(float(_bill_holes) / 4.0)) + _bill_horses * HORSE_FINE_BTC
	_bill_holes = 0
	_bill_windows = 0
	_bill_horses = 0
	if amount <= 0:
		return
	var balance: int = GameManager.purse_balance("btc")
	var paid: int = mini(amount, maxi(0, balance))
	if paid > 0:
		GameManager.purse_spend("btc", paid)
	var debt: int = amount - paid
	if debt > 0:
		GameManager.add_town_debt_btc(debt)
	last_fine = amount
	last_debt = debt
	fines_charged += 1
	if _host != null:
		_host.call("_law_fine", amount, debt)
	fine_charged.emit(amount, paid, debt)


## True while the Sheriff, not the player, owns movement and the trigger.
func blocks_control() -> bool:
	return law_state in ["approach", "escort", "enter", "release"]


## The town's story beats wait while an arrest/cell sequence is active.
func suspends_story() -> bool:
	return law_state != "idle"


## True until the full CELL_SECONDS has elapsed and the Sheriff opens the gate.
func cell_locked() -> bool:
	return law_state == "cell"


## Clamp a wished-for position to the occupied cell, with a body-radius margin.
func confine_cell(p: Vector3) -> Vector3:
	var xf: Transform3D = _jail_xf()
	var local: Vector3 = xf.affine_inverse() * p
	local.x = clampf(local.x, CELL_BOUNDS.position.x + 0.22, CELL_BOUNDS.end.x - 0.22)
	local.z = clampf(local.z, CELL_BOUNDS.position.y + 0.22, CELL_BOUNDS.end.y - 0.22)
	var out: Vector3 = xf * local
	out.y = p.y
	return out


## Whether Lil Blunt is currently inside the occupied cell's bounds.
func player_in_cell() -> bool:
	if _host == null:
		return false
	var pos: Vector3 = _host.get("_player_pos")
	var local: Vector3 = _jail_xf().affine_inverse() * pos
	return CELL_BOUNDS.has_point(Vector2(local.x, local.z))


## An arrest is active from the hit until the Sheriff has walked him back out.
func is_arrest_active() -> bool:
	return law_state != "idle"


## True specifically during the locked two-minute stay.
func is_in_cell() -> bool:
	return law_state == "cell"


## Seconds already served (kept after release as test/story evidence).
func cell_elapsed() -> float:
	return _cell_t


## Seconds left before the gate may open.
func cell_seconds_left() -> float:
	return maxf(0.0, CELL_SECONDS - _cell_t)


## The new cellmate; his missing GLB falls back through Ep2TownFolk.setup().
func get_bam() -> Ep2TownFolk:
	return _bam


## Whether a property/animal fine is waiting for three quiet seconds.
func pending_fine() -> bool:
	return _fine_pending


func _set_state(value: String) -> void:
	law_state = value
	arrest_state_changed.emit(law_state)


func _begin_arrest() -> void:
	if law_state != "idle":
		return
	_host.call("_law_arrest_started")
	_line("SHERIFF", ARREST_LINE)
	_approach_repath = 0.0
	_release_stage = 0
	if _bam != null:
		_bam.visible = true
	if _sheriff == null:
		_enter_cell()
		return
	_sheriff.stop()
	_set_state("approach")
	_step_approach(0.0)


func _step_approach(delta: float) -> void:
	if _sheriff == null:
		return
	var player: Vector3 = _host.get("_player_pos")
	_approach_repath -= delta
	if _approach_repath <= 0.0 and _sheriff.position.distance_to(player) > 1.75:
		_approach_repath = 0.65
		_sheriff.walk_to(_stand_off(_sheriff.position, player, 1.45), 2.05)
	if _sheriff.position.distance_to(player) <= 1.9 and not _sheriff.is_walking():
		_sheriff.walk_path([Ep2GoldTown.door_world("Bldg_Jail", 3.0), Ep2GoldTown.door_world("Bldg_Jail", -0.8), _world(CELL_GUARD_LOCAL)], 2.05)
		_set_state("escort")


func _step_escort(delta: float) -> void:
	if _sheriff == null:
		return
	var goal: Vector3 = _world(CELL_GUARD_LOCAL)
	var forward: Vector3 = goal - _sheriff.position
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = Vector3(0.0, 0.0, 1.0)
	var follow: Vector3 = _sheriff.position - forward.normalized() * 1.15
	_move_player(follow, 3.8, delta)
	if not _sheriff.is_walking() and _sheriff.position.distance_to(goal) < 0.45:
		_sheriff.walk_to(_world(CELL_GATE_LOCAL) + (_world(CELL_VISIT_LOCAL) - _world(CELL_GATE_LOCAL)).normalized() * 0.25, 1.4)
		_set_state("enter")


func _step_enter(delta: float) -> void:
	var target: Vector3 = _world(CELL_PLAYER_LOCAL)
	_move_player(target, 2.8, delta)
	var player: Vector3 = _host.get("_player_pos")
	if player.distance_to(target) < 0.14:
		_enter_cell()


func _enter_cell() -> void:
	var state: Ep2ArmoryState = _host.get("armory") as Ep2ArmoryState
	if state != null:
		state.confiscate_firearms()
	_cell_t = 0.0
	_cell_line_i = 0
	cell_captioned.clear()
	cell_line_times.clear()
	if _gate != null:
		_gate.visible = true
	if _bam != null:
		_bam.visible = true
		_bam.hold_clip("Observe")
		_bam.face_point(_host.get("_player_pos"))
	_set_state("cell")


func _step_cell(delta: float) -> void:
	_cell_t += delta
	while _cell_line_i < CELL_LINES.size() and _cell_t >= float(CELL_LINE_TIMES[_cell_line_i]):
		var line: Array = CELL_LINES[_cell_line_i]
		cell_captioned.append([str(line[0]), str(line[1])])
		cell_line_times.append(_cell_t)
		_line(str(line[0]), str(line[1]))
		_cell_line_i += 1
	if _cell_t >= CELL_SECONDS:
		_open_release()


func _open_release() -> void:
	release_count += 1
	if _gate != null:
		_gate.visible = false
	_release_stage = 0
	_line("SHERIFF", RELEASE_LINE)
	if _sheriff != null:
		_sheriff.walk_to(_world(CELL_GUARD_LOCAL), 1.4)
	_set_state("release")


func _step_release(delta: float) -> void:
	if _release_stage == 0:
		var visit: Vector3 = _world(CELL_VISIT_LOCAL)
		_move_player(visit, 2.4, delta)
		var player: Vector3 = _host.get("_player_pos")
		if player.distance_to(visit) < 0.16:
			_release_stage = 1
			if _sheriff != null:
				_sheriff.walk_path([Ep2GoldTown.door_world("Bldg_Jail", -0.8), Ep2GoldTown.door_world("Bldg_Jail", 2.2)], 1.7)
	else:
		var outside: Vector3 = Ep2GoldTown.door_world("Bldg_Jail", 2.2)
		_move_player(outside, 3.0, delta)
		var player: Vector3 = _host.get("_player_pos")
		if player.distance_to(outside) < 0.25:
			_cold_cd = 8.0
			_set_state("idle")


func _move_player(target: Vector3, speed: float, delta: float) -> void:
	var pos: Vector3 = _host.get("_player_pos")
	var flat := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	if flat.length() > 0.001:
		pos += flat.normalized() * minf(flat.length(), speed * delta)
	pos.y = 0.0
	_host.set("_player_pos", pos)


static func _stand_off(from: Vector3, to: Vector3, gap: float) -> Vector3:
	var away := Vector3(from.x - to.x, 0.0, from.z - to.z)
	if away.length() < 0.01:
		away = Vector3.FORWARD
	return Vector3(to.x, 0.0, to.z) + away.normalized() * gap


func _line(who: String, text: String) -> void:
	caption_log.append({"who": who, "text": text, "time": _time})
	if _host != null:
		_host.call("_law_line", who, text)


func _tick_cold_cast() -> void:
	if GameManager.town_standing != "cold" or _cold_cd > 0.0 or _host == null:
		return
	if not bool(_host.call("has_player_control")) or bool(_host.call("is_show_active")):
		return
	var player: Vector3 = _host.get("_player_pos")
	for entry in [["SHERIFF", _sheriff, SHERIFF_COLD_LINES], ["MIKE DEAN", _minister, MINISTER_COLD_LINES]]:
		var who: String = str(entry[0])
		var folk: Ep2TownFolk = entry[1]
		if folk == null or bool(_cold_cast_done.get(who, false)):
			continue
		if folk.global_position.distance_to(player) < 4.2:
			_cold_cast_done[who] = true
			_cold_cd = 12.0
			_host.call("_law_cold_cast", who, entry[2])
			return


## One of the five cold street lines, keyed to its own recorded speaker.
static func cold_line_for(id: String) -> Array:
	return COLD_PEOPLE_LINES.get(id, [])


func _jail_xf() -> Transform3D:
	return Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Jail"))


func _world(local: Vector3) -> Vector3:
	return Ep2GoldTown.local_to_world("Bldg_Jail", local)


func _build_cell_folk() -> void:
	_bam = Ep2TownFolk.new()
	_bam.name = "BamBankmanFree"
	_bam.looping_clips.assign(["Idle", "Observe", "Talk"])
	_bam.clip_blend = 0.18
	add_child(_bam)
	_bam.setup(BAM_MODEL, 1.78, Color(0.30, 0.27, 0.23))
	_bam.position = _world(CELL_BAM_LOCAL)
	_bam.hold_clip("Observe")
	_bam.face_point(_world(CELL_PLAYER_LOCAL))
	_bam.visible = false


func _build_cell_gate() -> void:
	_gate = Node3D.new()
	_gate.name = "LawCellGate"
	add_child(_gate)
	_gate.position = _world(CELL_GATE_LOCAL)
	_gate.rotation.y = _jail_xf().basis.get_euler().y
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.13, 0.12, 0.11)
	iron.metallic = 0.65
	iron.roughness = 0.55
	for i in 6:
		var x: float = -0.50 + float(i) * 0.20
		_gate_box(_gate, Vector3(0.035, 2.10, 0.035), Vector3(x, 1.05, 0.0), iron)
	for y in [0.12, 1.08, 2.04]:
		_gate_box(_gate, Vector3(1.15, 0.045, 0.045), Vector3(0.0, float(y), 0.0), iron)
	_gate.visible = false


func _gate_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)


# --- buildings, windows and their lightweight damage ---------------------------------------------------------

func _build_building_tests() -> void:
	_buildings.clear()
	for entry in Ep2GoldTown.LAYOUT:
		var piece: String = str(entry[0])
		if piece == "Bldg_Jail" and not Ep2GoldTown.jail_v1:
			continue
		var fp_key: String = "Bldg_Armory2" if piece == "Bldg_Armory" and Ep2GoldTown.armory_v2 else piece
		var fp: Array = Ep2GoldTown.FOOTPRINT.get(fp_key, [8.0, 9.0, 0.0])
		var width: float = float(fp[0])
		var depth: float = float(fp[1])
		var height: float = 3.6
		if piece == "Bldg_Saloon" or fp_key == "Bldg_Armory2":
			height = 7.16
		elif piece == "Church":
			height = 8.5
		var xf: Transform3D = Ep2GoldTown.building_xform(entry)
		var record: Dictionary = {"piece": piece, "xf": xf, "w": width, "d": depth, "h": height, "windows": [],
			"node": _visuals.find_child(piece, true, false) if _visuals != null else null}
		for side in [-1.0, 1.0]:
			var centre := Vector3(side * width * 0.29, 1.65, 0.0)
			var normal: Vector3 = (xf.basis * Vector3.BACK).normalized()
			record["windows"].append({"piece": piece, "centre": centre, "size": Vector2(0.95, 1.25), "broken": false,
				"xf": xf, "normal": normal, "overlay": null})
		_buildings.append(record)


func _trace_buildings(eye: Vector3, direction: Vector3, limit: float) -> Dictionary:
	var best: Dictionary = {}
	var best_t: float = limit
	for building in _buildings:
		var xf: Transform3D = building["xf"]
		var inv: Transform3D = xf.affine_inverse()
		var origin: Vector3 = inv * eye
		var dir: Vector3 = xf.basis.inverse() * direction
		var w: float = float(building["w"])
		var d: float = float(building["d"])
		var h: float = float(building["h"])
		var faces: Array = [
			{"axis": 2, "value": 0.0, "normal": Vector3.BACK, "front": true},
			{"axis": 2, "value": -d, "normal": Vector3.FORWARD, "front": false},
			{"axis": 0, "value": -w * 0.5, "normal": Vector3.LEFT, "front": false},
			{"axis": 0, "value": w * 0.5, "normal": Vector3.RIGHT, "front": false},
		]
		for face in faces:
			var axis: int = int(face["axis"])
			if absf(dir[axis]) < 1e-6:
				continue
			var t: float = (float(face["value"]) - origin[axis]) / dir[axis]
			if t <= 0.02 or t >= best_t:
				continue
			var point: Vector3 = origin + dir * t
			if point.y < 0.0 or point.y > h:
				continue
			var inside: bool = absf(point.x) <= w * 0.5 and point.z <= 0.001 and point.z >= -d - 0.001 if axis == 2 \
				else absf(point.x - float(face["value"])) < 0.02 and point.z <= 0.001 and point.z >= -d - 0.001
			if not inside:
				continue
			var kind: String = "facade"
			var window: Dictionary = {}
			if bool(face["front"]):
				for candidate in building["windows"]:
					var centre: Vector3 = candidate["centre"]
					var size: Vector2 = candidate["size"]
					if absf(point.x - centre.x) <= size.x * 0.5 and absf(point.y - centre.y) <= size.y * 0.5:
						kind = "window"
						window = candidate
						break
			best_t = t
			best = {"kind": kind, "piece": building["piece"], "t": t, "point": eye + direction * t,
				"normal": (xf.basis * (face["normal"] as Vector3)).normalized(), "window": window}
	return best


## A safe authored aim point on a building's front, away from door and windows.
func facade_target(piece: String) -> Vector3:
	for building in _buildings:
		if str(building["piece"]) == piece:
			return (building["xf"] as Transform3D) * Vector3(-float(building["w"]) * 0.44, 1.30, 0.0)
	return Vector3.ZERO


## Outward normal of a building's street-facing facade.
func front_normal(piece: String) -> Vector3:
	for building in _buildings:
		if str(building["piece"]) == piece:
			return ((building["xf"] as Transform3D).basis * Vector3.BACK).normalized()
	return Vector3.BACK


## Number of testable window openings on a building front.
func window_count(piece: String) -> int:
	for building in _buildings:
		if str(building["piece"]) == piece:
			return (building["windows"] as Array).size()
	return 0


## Centre of one window opening in world space.
func window_target(piece: String, index: int = 0) -> Vector3:
	for building in _buildings:
		if str(building["piece"]) == piece:
			var windows: Array = building["windows"]
			if index >= 0 and index < windows.size():
				return (building["xf"] as Transform3D) * (windows[index]["centre"] as Vector3)
	return Vector3.ZERO


func _pane_for(window: Dictionary) -> Node3D:
	var piece: String = str(window["piece"])
	for building in _buildings:
		if str(building["piece"]) != piece:
			continue
		var root: Node = building["node"]
		if root == null:
			return null
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node
			var name: String = String(mesh.name).to_lower()
			if ("pane" in name or "glass" in name) and not bool(mesh.get_meta("law_broken", false)):
				return mesh
	return null


func _add_hole(at: Vector3, normal: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.085, 0.085)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _hole_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	var mark := MeshInstance3D.new()
	mark.name = "BulletHole"
	mark.mesh = quad
	add_child(mark)
	mark.global_position = at + normal * 0.004
	mark.look_at(mark.global_position + normal, Vector3.UP)
	damage_marks += 1


func _add_cracks(window: Dictionary, normal: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = window["size"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _crack_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	var overlay := MeshInstance3D.new()
	overlay.name = "BrokenWindow"
	overlay.mesh = quad
	add_child(overlay)
	overlay.global_position = (window["xf"] as Transform3D) * (window["centre"] as Vector3) + normal * 0.006
	overlay.look_at(overlay.global_position + normal, Vector3.UP)
	return overlay


static func _hole_texture() -> ImageTexture:
	if _hole_tex != null:
		return _hole_tex
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var p := Vector2(float(x) - 15.5, float(y) - 15.5) / 15.5
			var angle: float = atan2(p.y, p.x)
			var edge: float = 0.56 + 0.13 * sin(angle * 7.0) + 0.07 * sin(angle * 13.0 + 0.8)
			var alpha: float = clampf((edge - p.length()) * 9.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.055, 0.035, 0.020, alpha * 0.94))
	_hole_tex = ImageTexture.create_from_image(image)
	return _hole_tex


static func _crack_texture() -> ImageTexture:
	if _crack_tex != null:
		return _crack_tex
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for branch in 9:
		var p := Vector2(32.0, 32.0)
		var angle: float = float(branch) * TAU / 9.0 + 0.12 * sin(float(branch) * 4.0)
		for step in 22:
			angle += 0.20 * sin(float(step * branch + step))
			p += Vector2(cos(angle), sin(angle)) * 1.45
			for ox in [-1, 0, 1]:
				for oy in [-1, 0, 1]:
					var x: int = int(p.x) + ox
					var y: int = int(p.y) + oy
					if x >= 0 and x < 64 and y >= 0 and y < 64:
						image.set_pixel(x, y, Color(0.72, 0.82, 0.86, 0.72))
	_crack_tex = ImageTexture.create_from_image(image)
	return _crack_tex


func _spawn_chips(at: Vector3, normal: Vector3, glass: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 18 if glass else 9
	particles.lifetime = 0.75 if glass else 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.direction = normal
	particles.spread = 52.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.8
	particles.gravity = Vector3(0.0, -7.0, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.006, 0.035) if glass else Vector3(0.012, 0.008, 0.055)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.78, 0.84, 0.72) if glass else Color(0.42, 0.25, 0.11)
	mat.roughness = 0.8
	if glass:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.mesh = mesh
	add_child(particles)
	particles.global_position = at + normal * 0.025
	particles.restart()
	particles.emitting = true
	_effects.append([particles, 1.4])


func _play_sound(file: String, at: Vector3, volume: float) -> void:
	var path: String = SOUND_DIR + file
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume
	player.unit_size = 8.0
	player.max_distance = 90.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


# --- optional blood (the parallel FX packet may not be mounted) ----------------------------------------------

func _load_blood() -> void:
	if _blood_checked:
		return
	_blood_checked = true
	if ResourceLoader.exists(BLOOD_SCRIPT):
		_blood = load(BLOOD_SCRIPT) as Script


func _blood_spurt(at: Vector3, direction: Vector3, size: float) -> void:
	_load_blood()
	if _blood != null:
		_blood.call("spurt", self, at, direction, size)
		blood_events += 1


func _blood_stain(body: Node3D, at: Vector3, normal: Vector3, size: float) -> void:
	_load_blood()
	if _blood != null:
		_blood.call("stain", body, at, normal, size)
		blood_events += 1


func _blood_pool(at: Vector3, radius: float, grow_s: float) -> void:
	_load_blood()
	if _blood != null:
		_blood.call("pool", self, Vector3(at.x, 0.0, at.z), radius, grow_s)
		blood_events += 1
