class_name Ep2TownBumps
extends RefCounted
## Contact reactions for Lil Blunt in the walkable town. Detection is deliberately outside the crowd brain:
## a bump is a real interruption, with its own cooldown, while danger/greeting/errand ownership stays in Ep2TownPeople.
## The chamber applies a returned horse-kick displacement through its own collision in small movement steps.

const PERSON_CONTACT := 0.76
const HORSE_CONTACT := 1.38
const PERSON_COOLDOWN := 4.0
const HORSE_COOLDOWN := 6.0
const REAR_COS := 0.819152044             # cos(35 deg): a 70-degree arc centred on the horse's tail

var person_reactions: Dictionary = {}
var horse_kicks: int = 0
var horse_shies: int = 0
var kick_sounds: int = 0
var _people: Ep2TownPeople = null
var _life: Ep2TownLife = null
var _audio: Ep2TownSoundscape = null
var _person_cd: Dictionary = {}
var _horse_cd: Dictionary = {}
var _shy: Dictionary = {}
var _last_player: Vector3 = Vector3.ZERO
var _has_last: bool = false


## Bind the real town crowd, TownLife horses and (when present) the town-only soundscape.
func build(people: Ep2TownPeople, life: Ep2TownLife, audio: Ep2TownSoundscape) -> void:
	_people = people
	_life = life
	_audio = audio
	reset()


## Clear contact history (a chamber build/test scenario). Any shy offset is removed before the nodes are released.
func reset() -> void:
	for id in _shy:
		var entry: Dictionary = _shy[id]
		if is_instance_valid(entry.get("node")):
			(entry["node"] as Node3D).position -= entry.get("offset", Vector3.ZERO) as Vector3
	_shy.clear()
	_person_cd.clear()
	_horse_cd.clear()
	person_reactions.clear()
	horse_kicks = 0
	horse_shies = 0
	kick_sounds = 0
	_has_last = false


## Advance contact detection. `motion` may be the frame's measured world displacement; pass ZERO to let the module
## measure successive player positions. Returns the requested rear-kick knockback (1.5 m), otherwise ZERO.
func step(delta: float, player: Vector3, motion: Vector3 = Vector3.ZERO) -> Vector3:
	if delta <= 0.0:
		return Vector3.ZERO
	_tick_shy(delta)
	for id in _person_cd.keys():
		_person_cd[id] = maxf(0.0, float(_person_cd[id]) - delta)
	for id in _horse_cd.keys():
		_horse_cd[id] = maxf(0.0, float(_horse_cd[id]) - delta)
	var move: Vector3 = motion
	if move.length_squared() < 0.0000001 and _has_last:
		move = player - _last_player
	_last_player = player
	_has_last = true
	move.y = 0.0
	if move.length_squared() < 0.0000001:
		return Vector3.ZERO
	var travel: Vector3 = move.normalized()
	if _people != null:
		for p in _people.people:
			if p.state in Ep2TownPeople.SHOP_STATES or p.state in Ep2TownPeople.CEL_STATES or p.folk.dead:
				continue
			if float(_person_cd.get(p.id, 0.0)) > 0.0 or absf(p.folk.position.y - player.y) > 1.5:
				continue
			var toward: Vector3 = p.folk.position - player
			toward.y = 0.0
			var distance: float = toward.length()
			if distance > PERSON_CONTACT or distance < 0.001:
				continue
			if travel.dot(toward / distance) > 0.20:
				_react_person(p, player)
	var knockback := Vector3.ZERO
	if _life != null:
		for node in _life.get_children():
			if not node is Node3D or not str(node.name).begins_with("Horse"):
				continue
			var horse: Node3D = node
			var id: int = horse.get_instance_id()
			if float(_horse_cd.get(id, 0.0)) > 0.0:
				continue
			var toward: Vector3 = player - horse.position
			toward.y = 0.0
			var distance: float = toward.length()
			if distance > HORSE_CONTACT or distance < 0.001 or absf(horse.position.y - player.y) > 1.5:
				continue
			if travel.dot(-toward / distance) <= 0.20:
				continue                         # he must be walking INTO the horse, not merely passing nearby
			var forward := Vector3(cos(horse.rotation.y), 0.0, -sin(horse.rotation.y))
			var rear: bool = forward.dot(toward / distance) <= -REAR_COS
			_horse_cd[id] = HORSE_COOLDOWN
			if rear:
				horse_kicks += 1
				if _horse_sound(horse, "horse_kick", -4.0):
					kick_sounds += 1
				knockback = toward.normalized() * 1.5
			else:
				horse_shies += 1
				_horse_sound(horse, "horse_blow", -7.0)
				_shy_horse(horse, toward.normalized() * 0.42)
	return knockback


func _react_person(p: Ep2TownPeople.Person, player: Vector3) -> void:
	_person_cd[p.id] = PERSON_COOLDOWN
	person_reactions[p.id] = int(person_reactions.get(p.id, 0)) + 1
	_people._release(p)
	p.partner = ""
	p.folk.stop()
	p.folk.hold_clip("Alert" if _people._has_clip(p, "Alert") else "Observe")
	p.folk.face_point(player)
	p.greet_cd = maxf(p.greet_cd, PERSON_COOLDOWN)
	var away := Vector2(p.folk.position.x - player.x, p.folk.position.z - player.z)
	if away.length() < 0.001:
		away = Vector2.RIGHT
	away = away.normalized()
	var tangent := Vector2(-away.y, away.x) * (1.0 if int(p.id.hash()) % 2 == 0 else -1.0)
	var here := Vector2(p.folk.position.x, p.folk.position.z)
	var target: Vector2 = _people.navigation.closest(here + tangent * 0.95 + away * 0.35)
	var path: Array[Vector2] = _people.navigation.path(here, target)
	p.waypoints = path
	p.threat = Vector2(player.x, player.z)
	p.safety = target
	p.fear = maxf(p.fear, 0.9)
	if path.is_empty():
		p.state = "pause"
		p.timer = 1.0
	else:
		p.state = "flee"                         # a short, alert step aside, not a town-wide danger response
	if _audio != null:
		var clip: String = "bump_grunt_f" if Ep2TownPeople.sex_of(p.id) == "f" else "bump_grunt_m"
		_audio.play_effect(clip, p.folk.position + Vector3(0.0, p.folk.height_m * 0.75, 0.0), -9.0, 15.0)


func _horse_sound(horse: Node3D, clip: String, db: float) -> bool:
	if _life != null and _life.play_horse_effect(horse, clip, db):
		return true
	return _audio != null and _audio.play_effect(clip, horse.position + Vector3(0.0, 1.1, 0.0), db, 38.0)


func _shy_horse(horse: Node3D, away: Vector3) -> void:
	_shy[horse.get_instance_id()] = {"node": horse, "away": away, "t": 0.0, "offset": Vector3.ZERO}


func _tick_shy(delta: float) -> void:
	var done: Array = []
	for id in _shy:
		var entry: Dictionary = _shy[id]
		var horse: Node3D = entry["node"]
		if not is_instance_valid(horse):
			done.append(id)
			continue
		entry["t"] = float(entry["t"]) + delta
		var weight: float = sin(PI * clampf(float(entry["t"]) / 1.15, 0.0, 1.0))
		var offset: Vector3 = (entry["away"] as Vector3) * weight
		horse.position += offset - (entry["offset"] as Vector3)
		entry["offset"] = offset
		if float(entry["t"]) >= 1.15:
			done.append(id)
	for id in done:
		_shy.erase(id)
