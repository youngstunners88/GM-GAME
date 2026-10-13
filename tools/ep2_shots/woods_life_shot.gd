extends Node
## REAL-RENDER proof of the LIVING WOODS (founder 2026-10-13: "they are not walking around, sleeping, reading magazines ...
## give them movements and awareness ... some bears fire back with their arrows"). From the player's own eye: each scout in his
## routine at a sneaking distance, a bear that has spotted him ('!' + roar), the climb onto the quad (no blink), the road fight
## (a picket drawing his bow, an arrow in the air), and a corpse that stays.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 1280x720 --path . res://tools/ep2_shots/woods_life_shot.tscn -- out=.farm/woods_life
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
var _out := ".farm/woods_life"
var w: WoodsQuadChamber = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	w = WOODS.instantiate()
	add_child(w)
	w.setup(0, [], 0)
	w.set_physics_process(false)
	w.debug_invulnerable = true
	await get_tree().process_frame
	_run(1.0)
	# 1) the scouts in their routines, seen from the trail side at a sneaking distance
	for spec in [["Twitch", 13.0, "1_twitch_patrol"], ["Professor Barnaby", 8.5, "2_barnaby_reads"], ["Old Moss", 9.0, "3_moss_sleeps"],
			["Mumbles", 12.0, "4_mumbles_roams"], ["Hattie", 16.0, "5_hattie_watch"]]:
		var br: Ep2BearBrain = w.get_bear(str(spec[0]))
		if br == null:
			continue
		var a: Ep2Actor = br.actor
		var to_trail: Vector3 = _nearest_trail(a.position) - a.position
		to_trail.y = 0.0
		var dir: Vector3 = to_trail.normalized() if to_trail.length() > 0.5 else Vector3.BACK
		w._player_pos = a.position + dir * float(spec[1])
		_look_at(a.position + Vector3(0.0, a.height_m * 0.45, 0.0))
		await _live(0.5)
		_look_at(a.position + Vector3(0.0, a.height_m * 0.45, 0.0))
		await _cap(str(spec[2]))
	# 2) spotted: Mumbles sees him - '!', the roar, the charge
	var mum: Ep2BearBrain = w.get_bear("Mumbles")
	if mum != null:
		w._player_pos = mum.actor.position + Vector3(9.0, 0.0, 4.0)
		mum.alarm(w._player_pos)
		await _live(0.6)
		_look_at(mum.actor.position + Vector3(0.0, 1.4, 0.0))
		await _cap("6_mumbles_spotted")
		await _live(1.2)
		_look_at(mum.actor.position + Vector3(0.0, 1.2, 0.0))
		await _cap("7_mumbles_charges")
		# drop him: the corpse stays
		var guard: int = 0
		while not mum.is_dead() and guard < 600:
			guard += 1
			mum.take_hit(w._player_pos)
			_run(0.05)
		await _live(3.6)
		_look_at(mum.actor.position + Vector3(0.0, 0.4, 0.0))
		await _cap("8_mumbles_down")
	# 3) the climb onto the quad: no blink, the eye glides onto the back seat
	w._player_pos = WoodsQuadChamber.QUAD_POS + Vector3(3.5, 0.0, -3.0)
	w._bull.position = WoodsQuadChamber.QUAD_POS + Vector3(3.0, 0.0, -1.2)
	w._advance_to(WoodsQuadChamber.Beat.REVEAL)
	var g: int = 0
	while w.get_beat_name() != "MOUNT" and g < 4000:
		g += 1
		_run(0.05)
	while not w.is_gliding() and g < 6000:
		g += 1
		_run(1.0 / 60.0)
	_run(0.45)
	await _cap("9_mount_glide")
	while w.get_beat_name() != "RIDE" and g < 8000:
		g += 1
		_run(0.05)
	_run(1.0)
	await _cap("10_ride_start")
	# 4) the road fight: a picket drawing his bow, an arrow in the air
	var got_draw: bool = false
	var got_arrow: bool = false
	var t: float = 0.0
	while w.get_beat_name() == "RIDE" and t < 120.0 and not (got_draw and got_arrow):
		t += 1.0 / 60.0
		w.step(1.0 / 60.0)
		if not got_draw:
			for b in w.get_bears("road"):
				var br2: Ep2BearBrain = b
				if br2.role() == "archer" and br2.is_alert() and Ep2BearKit.pose_name(br2.actor) == "aim" \
						and br2.actor.position.distance_to(w.get_player_position()) < 30.0:
					_look_at(br2.actor.position + Vector3(0.0, 1.3, 0.0))
					w.step(1.0 / 60.0)
					_look_at(br2.actor.position + Vector3(0.0, 1.3, 0.0))
					await _cap("11_road_archer_draws")
					got_draw = true
					break
		if not got_arrow:
			for ar in w._arrows:
				var d: Dictionary = ar
				if not bool(d["stuck"]) and (d["pos"] as Vector3).distance_to(w.get_player_position()) < 14.0:
					_look_at(d["pos"])
					await _cap("12_arrow_in_flight")
					got_arrow = true
					break
	print("road: arrows ", w.get_arrows_loosed(), " kills ", w.get_kills(), " t ", t)
	get_tree().quit()


func _nearest_trail(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd: float = 1e9
	for v in WoodsQuadChamber.SNEAK_TRAIL:
		var q := Vector3((v as Vector2).x, 0.0, (v as Vector2).y)
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = q
	return best


func _look_at(p: Vector3) -> void:
	var eye: Vector3 = w._player_pos + Vector3(0.0, w.eye_height, 0.0)
	var d: Vector3 = p - eye
	w._look_yaw = atan2(d.x, d.z)
	w._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _run(seconds: float) -> void:
	for i in int(seconds * 60.0):
		w.step(1.0 / 60.0)


## Like _run, but one real frame per step, so the AnimationPlayers play the clips in step with the logic (a fall, a charge).
func _live(seconds: float) -> void:
	for i in int(seconds * 60.0):
		w.step(1.0 / 60.0)
		await get_tree().process_frame


func _cap(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " beat ", w.get_beat_name(), " player ", w.get_player_position())
