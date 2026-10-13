class_name Ep2BearBrain
extends RefCounted
## One bear's mind in the living wood (founder 2026-10-13: "the bears are not active, they have no awareness of their enemies ...
## they should all have personality and individual character"). Three layers, kept apart (design/ep2/LIVING_WOODS_CONTRACT.md):
##   ROUTINE   what he does when nothing is wrong: patrol a beat, roam and sniff, read a magazine on a stump, sleep it off by a
##             log, keep watch on a rock (archers), or wait by the road (road ambushers).
##   AWARENESS unaware -> suspicious (heard / half-saw something: "?") -> investigating (walks to where it came from) -> alert
##             (saw Lil Blunt: "!") -> searching (lost him: looks around the last known spot, then gives up and goes back).
##   COMBAT    brawlers run in and swipe (Leap_and_Punch: telegraphed wind-up, a hit only if still in reach at the strike);
##             archers keep their distance, draw (Archery_Aim), loose a real arrow (warning, flight, miss or hit). Hit
##             reaction, death (Shot_and_Fall_Backward) - the body stays where it fell.
## Sight: range + field of view + dwell (a meter fills while he can see Lil Blunt; walking fills it slower than running, standing
## still slower still) and trunks block the view. Hearing: an event at a position with a loudness radius; how much of it this bear
## catches depends on his ears, his routine (asleep / nose in a magazine) and distance. An unconfirmed sound gives a PLACE to check,
## never Lil Blunt's exact position. A bear who sees Lil Blunt roars, and only bears within earshot of the roar come to look.
## Pure logic over an Ep2Actor; the woods chamber owns the world queries (`world` callbacks) and steps every brain.

enum Aware { UNAWARE, SUSPICIOUS, INVESTIGATE, ALERT, SEARCH, DEAD }

signal roared(bear: Ep2BearBrain, at: Vector3)
signal arrow_loosed(bear: Ep2BearBrain, from: Vector3, to: Vector3)
signal swiped(bear: Ep2BearBrain)
signal died(bear: Ep2BearBrain)
signal spotted(bear: Ep2BearBrain)
signal swing_started(bear: Ep2BearBrain)

var actor: Ep2Actor = null
## Personality (see PERSONALITIES in woods_quad.gd): name, routine, sight, fov, ears, react, role, hp, speeds, voice pitch.
var p: Dictionary = {}
var aware: int = Aware.UNAWARE
var hp: int = 2
var arrows: int = 6
var suspicion: float = 0.0           # 0..1 sight meter: 1 = he has seen Lil Blunt
var target: Vector3 = Vector3.ZERO   # the place he goes to look at / the last position he SAW Lil Blunt
var home: Vector3 = Vector3.ZERO
var route: Array = []                # patrol points (Vector3)
var route_i: int = 0
var _t: float = 0.0                  # time in the current routine / awareness step
var _react: float = -1.0             # >= 0: counting down to react to a sound
var _pause: float = 0.0
var _attack_t: float = -1.0          # >= 0: an attack is winding up / recovering
var _cool: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sense_t: float = 0.0
var _roared: bool = false
var _hit_t: float = 0.0
## Set by the chamber every frame: may this bear start an attack now (a small active-attack budget, contract), does he
## have a clear line to Lil Blunt (no trunk in the way), and how far ahead of Lil Blunt a brawler should run (a moving quad).
var may_attack: bool = true
var has_los: bool = true
var lead: Vector3 = Vector3.ZERO


func _init(a: Ep2Actor, personality: Dictionary, seed_value: int) -> void:
	actor = a
	p = personality
	hp = int(p.get("hp", 2))
	arrows = int(p.get("arrows", 6 if role() == "archer" else 0))
	home = a.position
	_rng.seed = seed_value
	_sense_t = _rng.randf() * 0.2
	var r: Array = p.get("route", [])
	for v in r:
		route.append(Vector3(v.x, 0.0, v.y) if v is Vector2 else v)
	_enter_routine()


func display_name() -> String: return str(p.get("name", "Bear"))
func role() -> String: return str(p.get("role", "brawler"))
func routine() -> String: return str(p.get("routine", "idle"))
func is_dead() -> bool: return aware == Aware.DEAD
func is_alert() -> bool: return aware == Aware.ALERT
func is_unaware() -> bool: return aware == Aware.UNAWARE
func awareness_name() -> String: return Aware.keys()[aware]


# --- routine -------------------------------------------------------------------------------------------------------

func _enter_routine() -> void:
	_t = 0.0
	match routine():
		"read":
			actor.stop()
			Ep2BearKit.pose(actor, "sit_read")
		"sleep":
			actor.stop()
			Ep2BearKit.pose(actor, "sleep")
		"watch", "road":
			actor.stop()
			Ep2BearKit.pose(actor, "aim" if role() == "archer" else "idle")
		_:
			Ep2BearKit.pose(actor, "idle")
			_pause = 0.5 + _rng.randf() * 1.5
	if p.has("face"):
		actor.face_yaw(float(p["face"]))
	Ep2BearKit.set_mark(actor, "", Color.WHITE)


func _step_routine(delta: float) -> void:
	if bool(p.get("_returning", false)):
		if actor.is_walking():
			return
		p["_returning"] = false                          # home again: back on the stump / down for the nap / on watch
		_enter_routine()
		return
	match routine():
		"patrol":
			if actor.is_walking():
				return
			if _pause > 0.0:
				_pause -= delta
				if _pause <= 0.0 and not route.is_empty():
					route_i = (route_i + 1) % route.size()
					actor.walk_to(route[route_i], float(p.get("walk", 1.1)))
					Ep2BearKit.pose(actor, "walk")
				return
			# arrived: look around (an archer scans with the bow), then go on
			Ep2BearKit.pose(actor, "aim" if role() == "archer" else "idle")
			_pause = float(p.get("pause", 2.5)) + _rng.randf() * 1.5
		"roam":
			if actor.is_walking():
				return
			if _pause > 0.0:
				_pause -= delta
				if _pause <= 0.0:
					var r: float = float(p.get("roam_r", 9.0))
					var a: float = _rng.randf() * TAU
					var to: Vector3 = home + Vector3(cos(a), 0.0, sin(a)) * r * (0.4 + 0.6 * _rng.randf())
					actor.walk_to(to, float(p.get("walk", 0.9)))
					Ep2BearKit.pose(actor, "walk")
				return
			# a sniff about, the odd grumpy stomp
			Ep2BearKit.pose(actor, "stomp" if _rng.randf() < float(p.get("stomp", 0.25)) else "idle")
			_pause = 2.5 + _rng.randf() * 3.0
		"watch", "road":
			# a sentry scans his sector: a slow sweep either side of where he faces
			if p.has("face") and float(p.get("sweep", 0.0)) > 0.0:
				actor.face_yaw(float(p["face"]) + float(p["sweep"]) * sin(_t * 0.32 + float(p.get("phase", 0.0))))
		"read", "sleep":
			pass


# --- senses (called by the woods chamber) ----------------------------------------------------------------------------

## How sharp his eyes and ears are right now (asleep: barely; nose in a magazine: half).
func _attention() -> float:
	if aware != Aware.UNAWARE:
		return 1.0
	match routine():
		"sleep":
			return 0.0
		"read":
			return 0.45
	return 1.0


func _ear() -> float:
	var e: float = float(p.get("ears", 1.0))
	if aware == Aware.UNAWARE:
		match routine():
			"sleep":
				e *= 0.35
			"read":
				e *= 0.6
	return e


## A sound at `at` that carries `radius` metres (footstep, run, shot, engine, a roar). `exact` = a sound that gives away
## the source itself (a gunshot close by) rather than just a direction.
func hear(at: Vector3, radius: float, kind: String) -> void:
	if aware == Aware.DEAD or aware == Aware.ALERT:
		return
	var d: float = Vector2(at.x - actor.position.x, at.z - actor.position.z).length()
	var reach: float = radius * _ear()
	if d > reach:
		return
	# a place to check, not his exact position: the further away, the vaguer
	var blur: float = clampf(d * 0.18, 0.5, 8.0)
	target = at + Vector3((_rng.randf() - 0.5) * blur, 0.0, (_rng.randf() - 0.5) * blur)
	if aware == Aware.UNAWARE or aware == Aware.SEARCH:
		aware = Aware.SUSPICIOUS
		_t = 0.0
		var react: float = float(p.get("react", 1.2))
		if routine() == "sleep":
			react += 1.8                                        # groggy
		if kind == "shot" and d < reach * 0.4:
			react *= 0.5
		if routine() == "sleep" and Ep2BearKit.pose_name(actor) == "sleep":
			Ep2BearKit.pose(actor, "wake")                     # rolls up off the ground (the fall, played backward)
			react = maxf(react, Ep2BearKit.WAKE_TIME)
		_react = react
		Ep2BearKit.set_mark(actor, "?", Color(1.0, 0.8, 0.2))
		if Ep2BearKit.pose_name(actor) != "wake":
			actor.face_point(at)


## Called a few times a second by the chamber: can he see Lil Blunt at `eye` (feet `pos`)? `exposure` 0..1 (still / walking /
## running), `blocked` = a trunk is in the way.
func look(pos: Vector3, exposure: float, blocked: bool, delta: float) -> void:
	if aware == Aware.DEAD:
		return
	var to: Vector3 = pos - actor.position
	to.y = 0.0
	var d: float = to.length()
	var sight: float = float(p.get("sight", 24.0)) * _attention()
	var fov: float = deg_to_rad(float(p.get("fov", 110.0))) * 0.5
	var fwd := Vector3(sin(actor.facing), 0.0, cos(actor.facing))
	var in_view: bool = d < sight and d > 0.1 and fwd.angle_to(to / maxf(d, 0.001)) < fov and not blocked
	if aware == Aware.ALERT:
		if in_view or d < 4.0:
			target = pos
			_t = 0.0
		return
	if in_view:
		var near_k: float = 1.0 - d / maxf(sight, 0.1)
		suspicion = minf(1.0, suspicion + delta * (0.35 + 2.2 * near_k) * exposure * float(p.get("eyes", 1.0)))
		if aware == Aware.UNAWARE and suspicion > 0.25:
			aware = Aware.SUSPICIOUS
			target = pos
			_react = float(p.get("react", 1.2))
			actor.face_point(pos)
		if suspicion >= 1.0:
			_go_alert(pos)
	else:
		suspicion = maxf(0.0, suspicion - delta * 0.12)
	if aware == Aware.SUSPICIOUS or aware == Aware.INVESTIGATE:
		var q: float = suspicion
		Ep2BearKit.set_mark(actor, "?" if q < 0.6 else "?!", Color(1.0, 0.8 - 0.4 * q, 0.2))


## Another bear roared at `at` (he saw Lil Blunt there): anyone who hears it comes to look - they do not know where the player is.
func ally_roar(at: Vector3) -> void:
	hear(at, 34.0, "roar")


func _go_alert(pos: Vector3) -> void:
	aware = Aware.ALERT
	target = pos
	suspicion = 1.0
	_t = 0.0
	_cool = 0.6 + _rng.randf() * 0.6
	Ep2BearKit.set_mark(actor, "!", Color(1.0, 0.2, 0.15))
	actor.face_point(pos)
	if not _roared:
		_roared = true
		Ep2BearKit.pose(actor, "stomp")
		roared.emit(self, actor.position)
	spotted.emit(self)


## Something (the quad's engine, a shot right next to him) leaves no doubt: straight to alert.
func alarm(pos: Vector3) -> void:
	if aware != Aware.DEAD and aware != Aware.ALERT:
		_go_alert(pos)


# --- damage ----------------------------------------------------------------------------------------------------------

## A bullet hit him. Returns true if it killed him.
func take_hit(from: Vector3) -> bool:
	if aware == Aware.DEAD:
		return false
	hp -= 1
	if hp <= 0:
		aware = Aware.DEAD
		actor.stop()
		Ep2BearKit.pose(actor, "dead")
		Ep2BearKit.set_mark(actor, "", Color.WHITE)
		died.emit(self)
		return true
	_hit_t = 0.5
	Ep2BearKit.pose(actor, "hit")
	if aware != Aware.ALERT:
		_go_alert(from)
	return false


# --- per frame -------------------------------------------------------------------------------------------------------

## `player` = Lil Blunt's feet. Returns nothing; attacks are signalled (the chamber resolves damage).
func step(delta: float, player: Vector3) -> void:
	_t += delta
	Ep2BearKit.tick_pose(actor, delta)
	if aware == Aware.DEAD:
		actor.step(delta)
		return
	if _hit_t > 0.0:
		_hit_t -= delta
		actor.step(delta)
		return
	match aware:
		Aware.UNAWARE:
			_step_routine(delta)
		Aware.SUSPICIOUS:
			if _react >= 0.0:
				_react -= delta
				if _react < 0.0:
					# up from the stump / the nap; then walk over to have a look
					aware = Aware.INVESTIGATE
					_t = 0.0
					actor.walk_to(target, float(p.get("walk", 1.1)) * 1.1)
					Ep2BearKit.pose(actor, "walk")
			elif _t > 6.0:
				_calm_down()
		Aware.INVESTIGATE:
			if not actor.is_walking():
				if _t < 30.0 and Ep2BearKit.pose_name(actor) == "walk":
					Ep2BearKit.pose(actor, "aim" if role() == "archer" else "idle")       # looks around where the noise was
					_pause = 3.5
				_pause -= delta
				if _pause <= 0.0:
					_calm_down()
		Aware.ALERT:
			_step_combat(delta, player)
		Aware.SEARCH:
			if not actor.is_walking():
				_pause -= delta
				if _pause <= 0.0:
					if _t > 14.0:
						_calm_down()
					else:
						var a: float = _rng.randf() * TAU
						actor.walk_to(target + Vector3(cos(a), 0.0, sin(a)) * 5.0, float(p.get("walk", 1.1)))
						Ep2BearKit.pose(actor, "walk")
						_pause = 2.0
	actor.step(delta)


func _calm_down() -> void:
	aware = Aware.UNAWARE
	suspicion = 0.0
	_t = 0.0
	Ep2BearKit.set_mark(actor, "", Color.WHITE)
	# back home first for the stay-put routines, then the routine again
	if routine() in ["read", "sleep", "watch", "road"] and actor.position.distance_to(home) > 0.6:
		actor.walk_to(home, float(p.get("walk", 1.1)))
		Ep2BearKit.pose(actor, "walk")
		_pause = 0.0
		p["_returning"] = true
		return
	_enter_routine()


func _step_combat(delta: float, player: Vector3) -> void:
	var to: Vector3 = player - actor.position
	to.y = 0.0
	var d: float = to.length()
	# lost him: he has not seen Lil Blunt for a while -> search the last place he saw him
	if _t > float(p.get("forget", 9.0)) and d > 6.0:
		aware = Aware.SEARCH
		_t = 0.0
		_pause = 0.0
		Ep2BearKit.set_mark(actor, "?", Color(1.0, 0.6, 0.2))
		actor.walk_to(target, float(p.get("run", 3.6)))
		Ep2BearKit.pose(actor, "run")
		return
	_cool -= delta
	if role() == "archer":
		actor.stop()
		actor.face_point(player)
		if _attack_t >= 0.0:
			_attack_t += delta
			if _attack_t >= 1.15 and Ep2BearKit.pose_name(actor) == "aim":
				Ep2BearKit.pose(actor, "shot")
				arrows -= 1
				var lead: Vector3 = player + Vector3(0.0, 1.0, 0.0)
				arrow_loosed.emit(self, actor.position + Vector3(0.0, actor.height_m * 0.62, 0.0), lead)
			if _attack_t >= 1.9:
				_attack_t = -1.0
				_cool = float(p.get("reload", 2.2)) + _rng.randf() * 0.8
				Ep2BearKit.pose(actor, "aim")
		elif _cool <= 0.0 and arrows > 0 and d < float(p.get("range", 45.0)) and may_attack and has_los:
			_attack_t = 0.0
			Ep2BearKit.pose(actor, "aim")                                     # the draw: the visible warning
		elif arrows <= 0 and d > 2.4:
			actor.walk_to(player, float(p.get("run", 3.6)))                   # out of arrows: comes at you
			Ep2BearKit.pose(actor, "run")
		return
	# brawler: run in, wind up, swipe; a swipe only lands if he is still in reach when it strikes
	if _attack_t >= 0.0:
		_attack_t += delta
		actor.stop()
		actor.face_point(player)
		if _attack_t >= 0.55 and not bool(p.get("_struck", false)):
			p["_struck"] = true
			if d < 2.6:
				swiped.emit(self)
		if _attack_t >= 1.5:
			_attack_t = -1.0
			p["_struck"] = false
			_cool = 1.0 + _rng.randf() * 0.6
		return
	var strike_r: float = 2.2 if lead.length() < 0.5 else 4.2          # a quad coming at him: he jumps early
	if d < strike_r and _cool <= 0.0 and may_attack:
		_attack_t = 0.0
		Ep2BearKit.pose(actor, "leap")
		swing_started.emit(self)
		return
	if d > 1.8:
		actor.walk_to(player + lead, float(p.get("run", 3.6)))
		if Ep2BearKit.pose_name(actor) != "run":
			Ep2BearKit.pose(actor, "run")
	else:
		actor.stop()
		actor.face_point(player)
