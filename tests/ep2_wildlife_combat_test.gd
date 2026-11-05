extends Node
## Wildlife and creature combat (founder 2026-11-05). Real rooms, real shot rays. Every animal can be hit, wounded and killed; the
## stampede stays one-time and gives NO on-screen warning; a dead mount leaves him on foot and a dead horse leaves no barrier.
## Run: XDG_DATA_HOME=$(mktemp -d) timeout 400 <godot> --headless --path . res://tests/ep2_wildlife_combat_test.tscn
## The check count is pinned: a coroutine that dies silently cannot print ALL PASS (see the context manifest).

const TRAIL := preload("res://src/episode2/chamber/lake_trail.tscn")
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const CHECKS_PINNED := 113

var _fail: int = 0
var _count: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_count += 1
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fail += 1


func _ready() -> void:
	print("-- EP2 WILDLIFE COMBAT")
	_flock_flies_as_one()
	_flock_can_die()
	_flock_audio()
	_carrion_can_die()
	_audio_assets()
	await get_tree().process_frame
	await _stampede_gives_no_warning()
	await get_tree().process_frame
	_stampede_hits_and_stagger()
	await get_tree().process_frame
	_stampede_cannot_stall_the_ride()
	await get_tree().process_frame
	await _music_comes_back_when_a_herd_is_torn_down()
	await get_tree().process_frame
	await _mount_dies_on_the_trail()
	await get_tree().process_frame
	_one_round_one_target()
	await get_tree().process_frame
	await _lake_horse()
	await get_tree().process_frame
	await _town_horses()
	await get_tree().process_frame
	var complete: bool = _count == CHECKS_PINNED
	if not complete:
		print("  [FAIL] pinned check count: expected %d, ran %d" % [CHECKS_PINNED, _count])
	if _fail == 0 and complete:
		print("EP2_WILDLIFE_COMBAT: ALL PASS (%d checks)" % _count)
		get_tree().quit(0)
	else:
		print("EP2_WILDLIFE_COMBAT: %d FAILURE(S) of %d" % [_fail + (0 if complete else 1), _count])
		get_tree().quit(1)


func _flock() -> Ep2TrailVultures:
	var flock := Ep2TrailVultures.new()
	add_child(flock)
	return flock


## A ray from just below a bird, straight up through it.
func _ray_to(target: Vector3) -> Array:
	var eye: Vector3 = target + Vector3(3.0, -14.0, 2.0)
	return [eye, (target - eye).normalized()]


func _shoot_bird(flock: Ep2TrailVultures, index: int, damage: int = 1) -> float:
	var r: Array = _ray_to(flock.birds[index].global_position)
	return flock.shoot(r[0], r[1], damage)


func _flock_flies_as_one() -> void:
	print("-- THE FLOCK IS ONE THERMAL")
	var flock := _flock()
	_check("five birds, built from the real silhouette (fingered wings, a head, a tail)", flock.birds.size() == 5
		and flock.birds[0].get_node_or_null("WingL/Primaries") != null and flock.birds[0].get_node_or_null("Neck/Head") != null
		and flock.birds[0].get_node_or_null("Tail") != null)
	var gaps: Array = _flock_gaps(flock)
	var worst_step: float = 0.0
	var last_y: float = flock.birds[2].position.y
	for i in 60 * 60:
		flock._process(1.0 / 60.0)
		worst_step = maxf(worst_step, absf(flock.birds[2].position.y - last_y))
		last_y = flock.birds[2].position.y
	var after: Array = _flock_gaps(flock)
	var drift: float = 0.0
	for i in gaps.size():
		drift = maxf(drift, absf(angle_difference(float(gaps[i]), float(after[i]))))
	_check("after a minute each bird still holds its slot in the turn (no bird laps another)", drift < 0.3, "drift %.2f rad" % drift)
	_check("the height changes smoothly, no per-frame jitter", worst_step < 0.03, "worst %.3f m/frame" % worst_step)
	Ep2VultureMesh.flap(flock.birds[0], 0.0, 0.0)
	var left: Node3D = flock.birds[0].get_node("WingL")
	var right: Node3D = flock.birds[0].get_node("WingR")
	_check("gliding wings are held in a V: both tips above the shoulders",
		(left.transform.basis * Vector3(-1.0, 0.0, 0.0)).y > 0.1 and (right.transform.basis * Vector3(1.0, 0.0, 0.0)).y > 0.1)
	flock.free()


## Each bird's bearing from the thermal's centre, relative to the first bird.
func _flock_gaps(flock: Ep2TrailVultures) -> Array:
	var column := Vector3(cos(flock.phase * 0.17) * 7.0, 0.0, sin(flock.phase * 0.13) * 7.0)
	var out: Array = []
	var ref: Vector3 = flock.birds[0].position - column
	for b in flock.birds:
		var p: Vector3 = b.position - column
		out.append(angle_difference(atan2(ref.z, ref.x), atan2(p.z, p.x)))
	return out


func _flock_can_die() -> void:
	print("-- VULTURES ARE HIT, WOUNDED AND KILLED")
	var flock := _flock()
	var hits: Array = []
	flock.bird_hit.connect(func(_at: Vector3, killed: bool) -> void: hits.append(killed))
	var r: Array = _ray_to(flock.birds[1].global_position)
	_check("the sight turns red on a bird in the sky", flock.under_sight(r[0], r[1]))
	_check("a ray at empty sky misses", flock.shoot(Vector3(0, 500, 0), Vector3.UP) < 0.0)
	var y0: float = flock.birds[1].position.y
	var hit: float = _shoot_bird(flock, 1)
	var st: Dictionary = flock._states[1]
	_check("one round wounds: it stays in the air", hit > 0.0 and bool(st["wounded"]) and not bool(st["dead"]) and flock.alive_count() == 5, str(hit))
	var worst: float = 0.0
	var last: float = flock.birds[1].position.y
	for i in 60 * 4:
		flock._process(1.0 / 60.0)
		worst = maxf(worst, absf(flock.birds[1].position.y - last))
		last = flock.birds[1].position.y
	_check("...and it sags out of the thermal gradually, no teleport", flock.birds[1].position.y < y0 - 3.0 and worst < 0.1, "y %.1f -> %.1f, worst %.3f" % [y0, flock.birds[1].position.y, worst])
	var x_when_shot: Vector3 = flock.birds[1].position
	_shoot_bird(flock, 1)
	_check("the second round kills it", bool(st["dead"]) and flock.alive_count() == 4 and hits == [false, true], str(hits))
	var fell_at: float = -1.0
	for i in 60 * 6:
		flock._process(1.0 / 60.0)
		if fell_at < 0.0 and bool(st["settled"]):
			fell_at = float(i) / 60.0
	_check("it falls to the ground and stays there", fell_at > 0.5 and flock.birds[1].position.y < 0.5 and flock.birds[1].visible, "fell %.1f s" % fell_at)
	var drifted: Vector2 = Vector2(flock.birds[1].position.x - x_when_shot.x, flock.birds[1].position.z - x_when_shot.z)
	_check("...carrying the way it was flying, not dropping like a stone off a shelf", drifted.length() > 1.0, "%.1f m" % drifted.length())
	_check("a corpse takes no more rounds", _shoot_bird(flock, 1) < 0.0)
	_check("the rest keep flying", flock.birds[0].position.y > 20.0 and flock.birds[4].position.y > 20.0)
	_check("one buffalo-gun round is enough", _shoot_bird(flock, 3, 2) > 0.0 and bool(flock._states[3]["dead"]))
	for i in int(Ep2TrailVultures.CORPSE_SECONDS) + 8:
		flock._process(1.0)
	_check("a body is retired after a while", not flock.birds[1].visible)
	flock.reset_flock()
	var wing: Node3D = flock.birds[1].get_node("WingL")
	_check("a retry puts all five back, whole and in the air", flock.alive_count() == 5 and flock.birds[1].visible and flock.birds[1].position.y > 20.0
		and is_equal_approx(wing.scale.x, 1.0) and absf(wing.rotation.y) < 0.01 and (flock._states[1]["health"] as Ep2CreatureHealth).hp == Ep2TrailVultures.HP)
	flock.free()


func _flock_audio() -> void:
	print("-- THE FLOCK'S AUDIO")
	var flock := _flock()
	flock._process(0.1)
	_check("a room still being prebuilt is silent", not flock._wings.playing)
	flock.listener = flock.global_position + Vector3(10.0, 0.0, 0.0)
	flock._process(0.1)
	_check("wings are heard under the flock", flock._wings.playing)
	flock._process(1.0)
	_check("...and stop when the room stops telling it where he is", not flock._wings.playing)
	flock.listener = flock.global_position + Vector3(400.0, 0.0, 0.0)
	flock._process(0.1)
	_check("...and when he has ridden away", not flock._wings.playing)
	flock.free()


func _carrion_can_die() -> void:
	print("-- BIRDS AT THE CARCASS")
	var birds := Ep2CarrionVultures.new()
	add_child(birds)
	var far := Vector3(200.0, 0.0, 0.0)
	birds.add_body(Vector3(0.0, 3.0, 0.0))                  # a body on higher ground: nothing may assume the ground is y = 0
	birds._send_bird(0)
	birds._send_bird(0)
	for i in int((Ep2CarrionVultures.DESCEND_S + 0.5) * 10.0):
		birds.step(0.1, far)
	_check("two birds feed", birds.feeding() == 2, str(birds.feeding()))
	var a: Dictionary = birds.birds[0]
	var b: Dictionary = birds.birds[1]
	_check("they are the same vulture as the flock", (a["node"] as Node3D).get_node_or_null("Model/WingL/Primaries") != null)
	var spot_y: float = (a["spot"] as Vector3).y
	# straight down onto it: the other bird, a step away, is not on this line
	var eye: Vector3 = (b["node"] as Node3D).global_position + Vector3(0.0, 8.0, 0.0)
	var aim: Vector3 = Vector3.DOWN
	_check("the sight turns red on a feeding bird", birds.under_sight(eye, aim))
	birds.shoot(eye, aim, 2)
	_check("a heavy round kills it where it stands", str(b["state"]) == "down" and (b["health"] as Ep2CreatureHealth).dead)
	_check("...and the other lifts off", str(a["state"]) == "flee")
	_check("...and the body is free for later birds", int(birds.bodies[0]["birds"]) == 0, str(birds.bodies[0]["birds"]))
	for i in 30:
		birds.step(0.1, far)
	_check("the dead bird lies on the ground of the body it came for", absf((b["node"] as Node3D).position.y - spot_y) < 0.01 and bool(b.get("settled", false)), str((b["node"] as Node3D).position.y))
	birds.clear()
	birds.add_body(Vector3.ZERO)
	birds._send_bird(0)
	var c: Dictionary = birds.birds[0]
	for i in int((Ep2CarrionVultures.DESCEND_S + 0.5) * 10.0):
		birds.step(0.1, far)
	var eye2: Vector3 = (c["node"] as Node3D).global_position + Vector3(0.0, 0.3, 6.0)
	var aim2: Vector3 = ((c["node"] as Node3D).global_position + Vector3(0.0, 0.3, 0.0) - eye2).normalized()
	birds.shoot(eye2, aim2)
	_check("one light round wounds: it labours away", bool(c["wounded"]) and str(c["state"]) == "flee")
	for i in 10:
		birds.step(0.1, far)
	var eye3: Vector3 = (c["node"] as Node3D).global_position + Vector3(0.0, 0.3, 6.0)
	var aim3: Vector3 = ((c["node"] as Node3D).global_position + Vector3(0.0, 0.3, 0.0) - eye3).normalized()
	birds.shoot(eye3, aim3)
	_check("the second brings it down out of the air", str(c["state"]) == "down")
	var high: float = (c["node"] as Node3D).position.y
	for i in 60:
		birds.step(0.1, far)
	_check("...and it comes down", (c["node"] as Node3D).position.y < high or high < 0.1, "%.2f" % (c["node"] as Node3D).position.y)
	birds.free()


func _audio_assets() -> void:
	print("-- AUDIO LAYERS EXIST")
	for name in ["vulture_wings", "vulture_cry", "stampede_rumble", "stampede_hooves", "stampede_pass", "bison_hit"]:
		var path: String = "res://src/episode2/extras/audio/trail/%s.ogg" % name
		var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
		_check("%s.ogg imports as a playable stream" % name, stream is AudioStreamOggVorbis and stream.get_length() > 0.5, path)


func _trail(armory_state: Ep2ArmoryState = null) -> LakeTrailChamber:
	var t: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(t)
	t.set_physics_process(false)
	if armory_state != null:
		t.bind_armory(armory_state)
	t.setup(0, [], 0)
	return t


## Ride him to the herd's stretch and start it through the room's own trigger.
func _start_herd(t: LakeTrailChamber) -> Ep2Stampede:
	t._route_s = LakeTrailChamber.STAMPEDE_S + 1.0
	t._place_at_distance(t._route_s)
	t._speed = 0.0
	t._tick_stampede(1.0 / 60.0)
	return t._stampede


func _stampede_gives_no_warning() -> void:
	print("-- THE STAMPEDE: NO WARNING ON SCREEN, ONCE PER RUN")
	var keep: bool = GameManager.ep2_stampede_done
	GameManager.ep2_stampede_done = false
	var t: LakeTrailChamber = _trail()
	var hud: Ep2FpsHud = t._hud
	_check("the room has a real HUD to watch", hud != null)
	hud.toast_text = ""
	var objective: String = hud.objective
	var speech: int = hud.speech_log.size()
	var destination: Variant = GameManager.map_active_destination
	var st: Ep2Stampede = _start_herd(t)
	_check("the herd forms", st != null and st.active and st.herd.size() == Ep2Stampede.COUNT)
	_check("the music steps back under it", AudioManager.is_speech_ducking())
	var shown: Array = []
	var loudest_hooves: float = -80.0
	var quietest_hooves: float = 80.0
	var away: Vector3 = st._target + Vector3(0.0, 0.0, -9999.0)
	for i in 60 * 40:
		st.step(1.0 / 60.0, away)
		if hud.toast_text != "" and not (hud.toast_text in shown):
			shown.append(hud.toast_text)
		if hud.objective != objective and not (hud.objective in shown):
			shown.append(hud.objective)
		if st._hooves != null and st._t > 0.5 and st.active:
			loudest_hooves = maxf(loudest_hooves, st._hooves.volume_db)
			quietest_hooves = minf(quietest_hooves, st._hooves.volume_db)
		if st.done:
			break
	_check("start to finish: no toast, no banner, no objective", shown.is_empty(), str(shown))
	_check("...no line of text in the log, no map change", hud.speech_log.size() == speech and GameManager.map_active_destination == destination)
	_check("the hooves rise as it comes", loudest_hooves - quietest_hooves > 8.0, "%.1f..%.1f dB" % [quietest_hooves, loudest_hooves])
	_check("the herd passes, the flag is written", st.done and GameManager.ep2_stampede_done)
	var waited: float = 0.0
	while AudioManager.is_speech_ducking() and waited < 15.0:     # a line being spoken holds the duck a little longer, by design
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_check("the music comes back on its own", not AudioManager.is_speech_ducking(), "%.2f s, voice playing %s" % [waited, AudioManager.is_voice_playing()])
	# once per run: the same stretch again, a retry, a fresh ride
	var keep_st: Ep2Stampede = t._stampede
	t._stampede = null
	t._tick_stampede(0.1)
	_check("riding the stretch again: no second herd", t._stampede == null)
	t._stampede = keep_st
	t._retry_trail()
	_check("a retry after the herd has passed does not bring it back", t._stampede == keep_st and GameManager.ep2_stampede_done)
	t.free()
	# TRAMPLED! is damage feedback: it stays, and it is the only text the event can ever raise
	GameManager.ep2_stampede_done = false
	var t2: LakeTrailChamber = _trail()
	t2._hud.toast_text = ""
	var st2: Ep2Stampede = _start_herd(t2)
	t2._invuln = 0.0
	st2.trampled.emit()
	_check("caught in it, TRAMPLED! still lands as damage feedback", t2.get_health() < t2.HEALTH_MAX and (t2._hud.toast_text == "" or "TRAMPLED" in t2._hud.toast_text or "HORSE WOUNDED" in t2._hud.toast_text), t2._hud.toast_text)
	t2.free()
	GameManager.ep2_stampede_done = keep


func _stampede_hits_and_stagger() -> void:
	print("-- BISON: HIT, STAGGER, FALL, AND THE REAL AUDIO")
	var keep: bool = GameManager.ep2_stampede_done
	GameManager.ep2_stampede_done = false
	var t: LakeTrailChamber = _trail()
	var st: Ep2Stampede = _start_herd(t)
	_check("real recordings, not the horse-loop fallback", st._rumble.stream.resource_path.ends_with("stampede_rumble.ogg") and st._hooves.stream.resource_path.ends_with("stampede_hooves.ogg")
		and st._hit_voice.stream.resource_path.ends_with("bison_hit.ogg") and st._pass.stream.resource_path.ends_with("stampede_pass.ogg"))
	_check("the rumble and the hooves loop for the whole charge", (st._rumble.stream as AudioStreamOggVorbis).loop and (st._hooves.stream as AudioStreamOggVorbis).loop)
	var away: Vector3 = st._target + Vector3(0.0, 0.0, -9999.0)
	for i in int((Ep2Stampede.TELEGRAPH + 2.0) * 60.0):
		st.step(1.0 / 60.0, away)
	var positions: Dictionary = {}
	for b in st.herd:
		var anim: AnimationPlayer = b["anim"]
		if anim != null:
			positions[snappedf(anim.current_animation_position, 0.02)] = true
	_check("the herd is not in lock-step", positions.size() >= 7, str(positions.size()))
	# the body hangs off the stride: a real bounce and a real rock over one gallop
	var lead: Dictionary = st.herd[0]
	var node: Node3D = lead["node"]
	var y_range := Vector2(99.0, -99.0)
	var pitch_range := Vector2(99.0, -99.0)
	for i in int(Ep2Stampede.STRIDE_S * 60.0) + 2:
		st.step(1.0 / 60.0, away)
		(lead["anim"] as AnimationPlayer).advance(1.0 / 60.0)     # no frames run inside this loop
		y_range = Vector2(minf(y_range.x, node.position.y), maxf(y_range.y, node.position.y))
		pitch_range = Vector2(minf(pitch_range.x, node.rotation.z), maxf(pitch_range.y, node.rotation.z))
	_check("each stride lifts and drops the body", y_range.y - y_range.x > 0.1, "%.2f m" % (y_range.y - y_range.x))
	_check("...and rocks it from shoulder to rump", pitch_range.y - pitch_range.x > 0.1, "%.2f rad" % (pitch_range.y - pitch_range.x))
	var target: Dictionary = st.herd[1]
	var peer: Dictionary = st.herd[2]
	var eye: Vector3 = (target["pos"] as Vector3) + Vector3(0, 1.4, 0) + st.heading * 25.0
	var aim: Vector3 = ((target["pos"] as Vector3) + Vector3(0, 1.15, 0) - eye).normalized()
	var at0: Vector3 = target["pos"]
	var peer0: Vector3 = peer["pos"]
	var speed_ratio: float = float(peer["speed"]) / float(target["speed"])
	var thuds: Array = []
	st.bison_hit.connect(func(_at: Vector3, killed: bool) -> void: thuds.append(killed))
	st.shoot(eye, aim, false)
	_check("a light round wounds: it stays on its feet", not bool(target["dead"]) and bool(target["wounded"]) and (target["health"] as Ep2CreatureHealth).hp == 1 and float(target["stagger"]) > 0.0)
	_check("the meaty hit plays", st._hit_voice.playing)
	st.step(0.2, away)
	var moved: float = (target["pos"] as Vector3).distance_to(at0)
	var peer_moved: float = (peer["pos"] as Vector3).distance_to(peer0)
	_check("it breaks stride and loses ground", moved < peer_moved / speed_ratio * 0.7, "%.2f vs %.2f m" % [moved, peer_moved])
	_check("its nose goes down", (target["node"] as Node3D).rotation.z < -0.03, str((target["node"] as Node3D).rotation.z))
	st.step(0.5, away)
	eye = (target["pos"] as Vector3) + Vector3(0, 1.4, 0) + st.heading * 25.0
	aim = ((target["pos"] as Vector3) + Vector3(0, 1.15, 0) - eye).normalized()
	st.shoot(eye, aim, false)
	_check("the second round drops it", bool(target["dead"]) and st.killed == 1 and thuds == [false, true], str(thuds))
	# kill everything left: the event ends on the last body, and that body must still go over
	for b in st.herd:
		if not bool(b["dead"]):
			var e: Vector3 = (b["pos"] as Vector3) + Vector3(0, 1.4, 0) + st.heading * 8.0
			st.shoot(e, ((b["pos"] as Vector3) + Vector3(0, 1.15, 0) - e).normalized(), true)
	var last: Dictionary = st.herd[st.herd.size() - 1]
	_check("every bison can be shot down", st.killed == Ep2Stampede.COUNT, str(st.killed))
	st.step(1.0 / 60.0, away)
	_check("the last body ends the event at once", st.done and not st.active)
	for i in 60:
		t._tick_stampede(1.0 / 60.0)
	_check("...and it still falls: nothing is left standing frozen", absf((last["node"] as Node3D).rotation.x - PI * 0.5) < 0.05, str((last["node"] as Node3D).rotation.x))
	_check("the fallen lie at ground level", (last["node"] as Node3D).position.y < 0.6)
	t.free()
	GameManager.ep2_stampede_done = keep


func _stampede_cannot_stall_the_ride() -> void:
	print("-- STANDING STILL MUST NOT SOFT-LOCK")
	var keep: bool = GameManager.ep2_stampede_done
	GameManager.ep2_stampede_done = false
	var t: LakeTrailChamber = _trail()
	var st: Ep2Stampede = _start_herd(t)
	var route0: float = t._route_s
	var limit: float = Ep2Stampede.expected_seconds() + 6.0
	var waited: float = 0.0
	while not st.done and waited < limit:
		t._tick_stampede(1.0 / 60.0)
		waited += 1.0 / 60.0
	_check("he does nothing at all: the herd crosses and the event ends", st.done and GameManager.ep2_stampede_done, "%.1f s" % waited)
	_check("the ride is still his: on the horse, in the same place, in control", t._mounted and t._route_s == route0 and not t._failing and t.has_player_control())
	var survivor: Dictionary = st.herd[0]
	var seen_at_end: Vector3 = survivor["pos"]
	for i in 60 * 12:
		t._tick_stampede(1.0 / 60.0)
	_check("the survivors run on instead of galloping on the spot", (survivor["pos"] as Vector3).distance_to(seen_at_end) > 20.0)
	_check("...until the distance has them", not (survivor["node"] as Node3D).visible)
	t.free()
	# the herd never waits for the room's beats: he can be unhorsed in the middle of it
	GameManager.ep2_stampede_done = false
	var t2: LakeTrailChamber = _trail()
	var st2: Ep2Stampede = _start_herd(t2)
	for i in int((Ep2Stampede.TELEGRAPH + 1.0) * 60.0):
		t2._tick_stampede(1.0 / 60.0)
	t2._unhorse()
	var before: Vector3 = st2.herd[0]["pos"]
	for i in 30:
		t2._tick(1.0 / 60.0)
	_check("unhorsed mid-charge: the herd keeps coming", t2._unhorse_active and (st2.herd[0]["pos"] as Vector3).distance_to(before) > 3.0)
	t2.free()
	# no herd forms while he is already on the ground or at the shore
	GameManager.ep2_stampede_done = false
	var t3: LakeTrailChamber = _trail()
	t3._unhorse()
	t3._route_s = LakeTrailChamber.STAMPEDE_S + 1.0
	t3._tick_stampede(0.1)
	_check("no herd forms for a man on foot", t3._stampede == null)
	t3.free()
	GameManager.ep2_stampede_done = keep


func _music_comes_back_when_a_herd_is_torn_down() -> void:
	print("-- THE MUSIC IS NEVER LEFT MUTED")
	var keep: bool = GameManager.ep2_stampede_done
	GameManager.ep2_stampede_done = false
	var t: LakeTrailChamber = _trail()
	var st: Ep2Stampede = _start_herd(t)
	_check("ducked for the herd", AudioManager.is_speech_ducking() and st != null)
	t.free()                                              # the room dies mid-charge: nobody will ever call finished
	await get_tree().create_timer(Ep2Stampede.expected_seconds() + 3.2).timeout
	_check("the room dies mid-charge: the music still comes back", not AudioManager.is_speech_ducking())
	GameManager.ep2_stampede_done = keep


## Aim the room's own camera at a world point.
func _aim_trail(t: LakeTrailChamber, at: Vector3) -> void:
	var eye: Vector3 = t._camera.global_position
	t._look_yaw = atan2(at.x - eye.x, at.z - eye.z)
	t._look_pitch = atan2(at.y - eye.y, Vector2(at.x - eye.x, at.z - eye.z).length())
	t._update_camera(0.0)
	# the camera's yaw/pitch may carry the room's look offset: read the real ray back and correct it once
	var eye2: Vector3 = t._camera.global_position
	t._look_yaw = atan2(at.x - eye2.x, at.z - eye2.z)
	t._look_pitch = atan2(at.y - eye2.y, Vector2(at.x - eye2.x, at.z - eye2.z).length())
	t._update_camera(0.0)


func _mount_dies_on_the_trail() -> void:
	print("-- A DEAD MOUNT LEAVES HIM ON FOOT")
	var keep: bool = GameManager.ep2_stampede_done
	GameManager.ep2_stampede_done = true
	var st := Ep2ArmoryState.post_hideout()
	var t: LakeTrailChamber = _trail(st)
	t._route_s = 30.0
	t._place_at_distance(30.0)
	t._invuln = 0.0
	t._update_horse(0.0)
	await get_tree().process_frame
	var props_before: int = t._town_props.size()
	_aim_trail(t, t._horse.global_position + Vector3(0.0, 1.05, 0.0) + t._horse.global_transform.basis.z * 0.6)
	var eye: Vector3 = t._camera.global_position
	var dir: Vector3 = -t._camera.global_transform.basis.z
	_check("his own horse is on the ray when he looks down at it", str(t._creature_on_ray(eye, dir, true).get("kind", "")) == "mount", str(t._creature_on_ray(eye, dir, true)))
	_check("...but the sight does not call it out as a target", not t.aim_on_target(eye, dir))
	t._on_player_shot()
	_check("one round wounds it in the state that travels", st.horse_wounds == 1 and t.get_horse_hp() == 2 and t._mounted)
	t._on_player_shot()
	_check("two", st.horse_wounds == 2 and t.get_horse_hp() == 1 and t._mounted)
	t._on_player_shot()
	_check("the third kills it and he comes off", st.horse_is_down() and t.get_horse_hp() == 0 and not t._mounted and t._unhorse_active)
	for i in int(LakeTrailChamber.UNHORSE_SECONDS * 60.0) + 10:
		t._tick_unhorse(1.0 / 60.0)
	_check("he is on foot at walking height", not t._unhorse_active and t._horse_left and is_equal_approx(t.eye_height, t.FPS_EYE_HEIGHT))
	_check("the body lies on its side", absf(t._horse.rotation.z) > 0.9, str(t._horse.rotation.z))
	_check("the body is no barrier: no prop row and no collider", t._town_props.size() == props_before and t._horse.find_children("*", "CollisionShape3D", true, false).is_empty())
	var hp_after: int = st.horse_wounds
	t._on_player_shot()
	_check("a round into the fallen horse changes nothing", st.horse_wounds == hp_after)
	t._retry_trail()
	_check("Dude's path brings a horse back: a retry starts in the saddle of a sound horse", t._mounted and t.get_horse_hp() == 3 and st.horse_is_sound())
	t.free()
	GameManager.ep2_stampede_done = keep


func _one_round_one_target() -> void:
	print("-- ONE ROUND, ONE TARGET")
	var keep: bool = GameManager.ep2_stampede_done
	GameManager.ep2_stampede_done = true
	var t: LakeTrailChamber = _trail()
	t._route_s = 30.0
	t._place_at_distance(30.0)
	# a bird put directly on the line of fire, in the air ahead of him
	var bird: Node3D = t._vultures.birds[0]
	var ahead: Vector3 = t._camera.global_position + Vector3(sin(t._travel_yaw), 0.3, cos(t._travel_yaw)) * 40.0
	bird.global_position = ahead
	_aim_trail(t, ahead)
	var eye: Vector3 = t._camera.global_position
	var dir: Vector3 = -t._camera.global_transform.basis.z
	_check("the sight turns red on a bird in the room", t.aim_on_target(eye, dir))
	t._on_player_shot()
	_check("the room's own shot wounds it through the weapon path", bool(t._vultures._states[0]["wounded"]), str(t._vultures._states[0]["wounded"]))
	t._retry_trail()
	_check("a retry restages the flock", t._vultures.alive_count() == 5 and not bool(t._vultures._states[0]["wounded"]))
	t.free()
	GameManager.ep2_stampede_done = keep


func _lake(st: Ep2ArmoryState, mounted: bool = true) -> LogansLakeChamber:
	var c: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	c.handoff = {"arrived_mounted": mounted}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(st)
	c.setup(0, [], 0)
	return c


func _aim_lake(c: LogansLakeChamber, at: Vector3) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	c._look_yaw = atan2(at.x - eye.x, at.z - eye.z)
	c._look_pitch = atan2(at.y - eye.y, Vector2(at.x - eye.x, at.z - eye.z).length())


func _lake_horse() -> void:
	print("-- THE HORSE AT LOGAN'S LAKE")
	var st := Ep2ArmoryState.post_hideout()
	var c: LogansLakeChamber = _lake(st)
	for i in 150:
		c.step(1.0 / 30.0)
	c._horse_state = "drink"
	c._player_pos = c._horse.position + Vector3(1.0, 0.0, 0.6)
	_check("a sound horse can be mounted", c.can_mount_horse(), "state %s" % c._horse_state)
	c._mount()
	_check("mounted", c._riding and c.is_riding_horse())
	for i in 30:
		c.step(1.0 / 30.0)
	c._dismount()
	_check("dismount", not c._riding and c._horse_state == "graze")
	c._player_pos = c._horse.position + Vector3(1.0, 0.0, 0.6)
	_check("the remount still works", c.can_mount_horse())
	c._mount()
	for i in 30:
		c.step(1.0 / 30.0)
	# a wound in the saddle: nobody rides a shot horse, and the horse must not be left behind under a rider who keeps going
	var aim: Vector3 = c._horse.global_position + Vector3(0.0, 1.05, 0.0) + c._horse.global_transform.basis.z * 0.5
	_aim_lake(c, aim)
	c._on_player_shot()
	_check("shot in the saddle: wounded, and he is down off it", st.horse_wounds == 1 and not c._riding and c._horse_state == "hurt", "%d %s %s" % [st.horse_wounds, c._riding, c._horse_state])
	c._player_pos = c._horse.position + Vector3(1.0, 0.0, 0.6)
	_check("a shot horse cannot be mounted", not c.can_mount_horse())
	c._player_pos = c._horse.position + Vector3(3.0, 0.0, 2.0)
	_aim_lake(c, c._horse.global_position + Vector3(0.0, 1.05, 0.0))
	c._on_player_shot()
	c._on_player_shot()
	_check("the third round kills it", st.horse_is_down() and c._horse_state == "dead", "%d %s" % [st.horse_wounds, c._horse_state])
	await get_tree().create_timer(0.7).timeout
	_check("it lies on its side where it stood, it does not vanish", c._horse.visible and absf(c._horse.rotation.z) > 1.3, str(c._horse.rotation.z))
	_check("no collider where it stood", c._horse.find_children("*", "CollisionShape3D", true, false).is_empty())
	var wounds: int = st.horse_wounds
	_aim_lake(c, c._horse.global_position + Vector3(0.0, 0.6, 0.0))
	c._on_player_shot()
	_check("a dead horse cannot be mounted or shot again", not c.can_mount_horse() and c._horse_state == "dead" and st.horse_wounds == wounds)
	c.free()
	var again := _lake(st, false)
	_check("coming back later: no horse at the lake, as the rule already says", again._horse_state == "gone" and not again._horse.visible)
	again.free()
	st.treat_horse()
	var healed := _lake(st, true)
	_check("Dude patched it up: back at the water next visit", healed._horse_state in ["drink", "lead"], healed._horse_state)
	# humans stay on their own systems
	_check("Logan is not a creature", healed._logan == null or Ep2CreatureHealth.of(healed._logan) == null)
	healed.free()


func _fresh_town() -> GoldTownChamber:
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.step(1.0 / 60.0)
	return c


func _fire_at_town(c: GoldTownChamber, target: Vector3) -> void:
	var eye: Vector3 = c.get_camera().global_position
	c._look_yaw = atan2(target.x - eye.x, target.z - eye.z)
	c._look_pitch = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	c._update_camera(0.0)
	c._law.player_shot(c.get_camera().global_position, (target - c.get_camera().global_position).normalized())


func _town_horses() -> void:
	print("-- TOWN AND YARD HORSES")
	GameManager.set_town_standing("warm")
	GameManager.town_debt_btc = 0
	var c: GoldTownChamber = _fresh_town()
	var law: Ep2TownLaw = c.get_town_law()
	var yard: Ep2StableYard = c._stable_yard
	_check("the yard exists in the town", yard != null and yard.horses.size() >= 5)
	if yard == null:
		c.free()
		return
	_check("Dude's yard horses are law targets (they are not named Horse*)", yard.horses[2] in law._horses and yard.horses[4] in law._horses)
	var rigs: int = 0
	for h in law._horses:
		if Ep2CreatureHealth.of(h) == null:
			rigs += 1
	_check("the law aims at the horse itself, never at its inner rig (which has no health and could never die)", rigs == 0, str(rigs))
	var rail: Node3D = c._visuals.find_child("Horse0", true, false) as Node3D
	var props: Array = c._town_col["props"]
	var walls: Array = c._town_col["walls"]
	var rail_at := Vector2(rail.position.x, rail.position.z)
	_check("a living horse at the rail is solid", Ep2GoldTown.collide(rail_at + Vector2(0.1, 0.0), 0.3, [], props).distance_to(rail_at + Vector2(0.1, 0.0)) > 0.05)
	var body_point: Vector3 = rail.global_position + Vector3(0.0, 1.05, 0.0)
	var from: Vector3 = rail.global_position + Vector3(1.5, 1.4, 4.5)
	for i in 2:
		law.player_shot(from, (body_point - from).normalized())
	_check("two rounds wound it: still standing, still solid", (Ep2CreatureHealth.of(rail) as Ep2CreatureHealth).hp == 1 and absf(rail.rotation.x) < 0.01 and law.horse_hits == 2, str(law.horse_hits))
	var last: Dictionary = law.player_shot(from, (body_point - from).normalized())
	_check("the third kills it", (Ep2CreatureHealth.of(rail) as Ep2CreatureHealth).dead and law.horse_hits == 3, str(last))
	await get_tree().create_timer(0.7).timeout
	_check("it goes over on its side, not onto its nose", absf(rail.rotation.x) > 1.3 and absf(rail.rotation.z) < 0.05, "%.2f %.2f" % [rail.rotation.x, rail.rotation.z])
	_check("no invisible barrier: the walk footprint is gone", Ep2GoldTown.collide(rail_at + Vector2(0.1, 0.0), 0.3, [], props).distance_to(rail_at + Vector2(0.1, 0.0)) < 0.01)
	var fines: int = law.horse_hits
	var over: Vector3 = rail.global_position + Vector3(0.0, 1.9, 0.0)
	var through: Dictionary = law.player_shot(over + Vector3(1.5, 0.0, 4.5), Vector3(-1.5, 0.0, -4.5).normalized())
	_check("the air it used to stand in stops nothing", str(through.get("kind", "")) != "horse" and law.horse_hits == fines, str(through))
	var low: Vector3 = rail.global_transform * Vector3(0.0, 1.05, 0.0)
	var corpse_shot: Dictionary = law.player_shot(low + Vector3(1.2, 2.5, 3.0), (low - (low + Vector3(1.2, 2.5, 3.0))).normalized())
	_check("a round into the body costs no second fine and no second death", law.horse_hits == fines, str(corpse_shot))
	# a yard horse: real solid row and a real collider, both gone
	var paddock: Node3D = yard.horses[3]
	var pad_at := Vector2(paddock.position.x, paddock.position.z)
	_check("a yard horse has a collider while it lives", paddock.get_node_or_null("YardBody") != null)
	var solid_before: bool = Ep2GoldTown.collide(pad_at + Vector2(0.1, 0.0), 0.3, [], props).distance_to(pad_at + Vector2(0.1, 0.0)) > 0.05
	var pad_body: Vector3 = paddock.global_position + Vector3(0.0, 1.05, 0.0)
	var pad_from: Vector3 = pad_body + Vector3(0.5, 0.5, 3.0)
	for i in 3:
		law.player_shot(pad_from, (pad_body - pad_from).normalized())
	await get_tree().create_timer(0.7).timeout
	_check("three rounds put a yard horse down through the law's own shot", (Ep2CreatureHealth.of(paddock) as Ep2CreatureHealth).dead and absf(paddock.rotation.x) > 1.3, "hp %d" % (Ep2CreatureHealth.of(paddock) as Ep2CreatureHealth).hp)
	_check("...its footprint and its collider are gone", solid_before and paddock.get_node_or_null("YardBody") == null and Ep2GoldTown.collide(pad_at + Vector2(0.1, 0.0), 0.3, [], props).distance_to(pad_at + Vector2(0.1, 0.0)) < 0.01)
	# Dude riding when his horse goes down
	var mount: Node3D = yard.horses[0]
	var dude: Ep2TownFolk = yard.actors[0]
	yard._begin_mount()
	yard._ride_state = "ride"
	(Ep2CreatureHealth.of(mount) as Ep2CreatureHealth).take_hit(3, mount.global_position + Vector3(0.0, 1.0, 0.0))
	_check("Dude's horse shot under him: he is off it, on the ground beside it", yard._ride_state == "" and dude.position.y < 0.05 and dude.position.distance_to(Vector3(mount.position.x, 0.0, mount.position.z)) < 3.0, "%s %s" % [yard._ride_state, dude.position])
	_check("he will not mount a dead horse again", not yard._horse_alive(0))
	yard._ride_next = 0.0
	yard._begin_mount()
	_check("...and the routine does not try", yard._ride_state == "")
	# recovery through Dude: he patches up the player's own horse, whatever happened to his yard
	c.armory.horse_wounds = Ep2ArmoryState.HORSE_WOUNDS_MAX
	c._player_pos = yard.dude_position() + Vector3(1.0, 0.0, 0.0)
	c._dude_treats_horse()
	_check("recoverable: Dude patches up the fallen mount", c.armory.horse_is_sound())
	# only animals are in the family
	var strays: Array = []
	for node in get_tree().get_nodes_in_group(Ep2CreatureHealth.HORSE_GROUP):
		if not (node.name.begins_with("Horse") or node.name.begins_with("StableHorse") or node.name == Ep2StableYard.WALKING_HORSE):
			strays.append(str(node.name))
	_check("the family is horses: no townsperson in it", strays.is_empty(), str(strays))
	var folk_with_health: int = 0
	for p in c.get_people().people:
		if Ep2CreatureHealth.of(p.folk) != null:
			folk_with_health += 1
	_check("the town's people stay on their own system", folk_with_health == 0)
	GameManager.town_standing = "warm"
	GameManager.town_debt_btc = 0
	GameManager.save_session()
	c.free()
