extends Node
## Wildlife and creature combat in the real renderer (founder 2026-11-05): the flock against the sky, a vulture kill, the birds at a
## carcass, the herd coming, a bison hit and down, and horses dead on the trail, at the lake and in town with the player on foot.
## Drawn through a fixed-size SubViewport sharing the room's world, so a tiling window manager cannot crop it.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/wildlife_combat_shot.tscn

const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")

var out: String = ""
var view: SubViewport = null
var cam: Camera3D = null


func _shot(label: String, eye: Vector3, at: Vector3, fov: float = 50.0) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for i in 4:
		await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out + "/" + label + ".png")
	print("WILDLIFE_SHOT ", label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://wildlife"
	DirAccess.make_dir_recursive_absolute(out)
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	cam = Camera3D.new()
	cam.far = 1500.0
	view.add_child(cam)
	cam.current = true
	await _trail_shots()
	await _lake_shots()
	await _town_shots()
	print("WILDLIFE_SHOTS_DONE")
	get_tree().quit()


func _trail_shots() -> void:
	GameManager.ep2_stampede_done = false
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._wire_chamber(trail)
	trail.setup()
	trail.set_physics_process(false)
	trail.debug_invulnerable = true
	trail._route_s = 150.0
	trail._place_at_distance(150.0)
	trail._update_horse(0.0)
	var flock: Ep2TrailVultures = trail._vultures
	var ground: Vector3 = trail._player_pos + Vector3(0.0, 2.2, 0.0)
	await _frames(40)
	var middle: Vector3 = flock.global_position + Vector3(0.0, 29.0, 0.0)
	await _shot("flock_sky_player_view", ground, middle, 68.0)
	await _shot("flock_sky_tele", ground, flock.birds[0].global_position, 30.0)
	# one bird close, wings in the glide, seen from below and level
	var bird: Node3D = flock.birds[2]
	await _shot("vulture_close_below", bird.global_position + Vector3(2.5, -5.0, 2.5), bird.global_position, 40.0)
	await _shot("vulture_close_level", bird.global_position - bird.global_transform.basis.z * 6.0 + Vector3(0.0, 0.3, 0.0), bird.global_position, 40.0)
	# a wound, then a kill, watched from under it
	var from_ground: Vector3 = bird.global_position + Vector3(6.0, -20.0, 6.0)
	flock.shoot(from_ground, (bird.global_position - from_ground).normalized())
	await _frames(3)
	await _shot("vulture_hit_feathers", bird.global_position + Vector3(4.0, -3.0, 4.0), bird.global_position, 40.0)
	await _frames(120)
	await _shot("vulture_wounded_sags", ground, flock.global_position + Vector3(0.0, 26.0, 0.0), 40.0)
	from_ground = bird.global_position + Vector3(6.0, -14.0, 6.0)
	flock.shoot(from_ground, (bird.global_position - from_ground).normalized())
	await _frames(35)
	await _shot("vulture_falling", bird.global_position + Vector3(9.0, -2.0, 9.0), bird.global_position, 45.0)
	var guard: int = 0
	while not bool(flock._states[2]["settled"]) and guard < 900:
		await get_tree().process_frame
		guard += 1
	await _shot("vulture_dead_on_ground", bird.global_position + Vector3(3.0, 1.7, 3.0), bird.global_position, 45.0)
	# the herd, a real wounded animal and a real kill, through the room's own trigger
	var keep_birds: Ep2CarrionVultures = trail._carrion
	trail._route_s = LakeTrailChamber.STAMPEDE_S + 1.0
	trail._place_at_distance(trail._route_s)
	trail._update_horse(0.0)
	trail._tick_stampede(0.1)
	var st: Ep2Stampede = trail._stampede
	var away: Vector3 = trail._player_pos - st.heading * 300.0
	var eye: Vector3 = trail._player_pos + Vector3(0.0, 2.2, 0.0)
	for i in 90:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	var centre: Vector3 = _herd_centre(st)
	await _shot("herd_forming_far", eye, centre + Vector3(0.0, 1.0, 0.0), 50.0)
	# Move the rider onto the herd's line, so the player view is the true head-on approach.
	var head_on: Vector3 = _herd_centre(st) + st.heading * 34.0 + Vector3(0.0, 2.2, 0.0)
	while st._t < Ep2Stampede.TELEGRAPH + 3.0:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	head_on = _herd_centre(st) + st.heading * 34.0 + Vector3(0.0, 2.2, 0.0)
	await _shot("herd_approaching_head_on", head_on, _herd_centre(st) + Vector3(0.0, 1.0, 0.0), 55.0)
	var lead: Dictionary = st.herd[1]
	var side: Vector3 = Vector3(st.heading.z, 0.0, -st.heading.x)
	for k in 3:
		for i in 11:                                        # about a third of a stride between pictures, so the gait reads
			st.step(1.0 / 60.0, away)
			await get_tree().process_frame
		var p: Vector3 = lead["pos"]
		await _shot("bison_side_stride_%d" % k, p - side * 11.0 + Vector3(0.0, 1.2, 0.0) + st.heading * 1.0, p + Vector3(0.0, 1.0, 0.0), 42.0)
	var victim: Dictionary = st.herd[2]
	var vp: Vector3 = victim["pos"]
	var gun_eye: Vector3 = vp + st.heading * 20.0 + Vector3(0.0, 1.6, 0.0)
	st.shoot(gun_eye, (vp + Vector3(0.0, 1.15, 0.0) - gun_eye).normalized(), false)
	for i in 8:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	vp = victim["pos"]
	await _shot("bison_hit_stagger", vp + st.heading * 13.0 - side * 4.0 + Vector3(0.0, 1.5, 0.0), vp + Vector3(0.0, 1.0, 0.0), 45.0)
	gun_eye = vp + st.heading * 20.0 + Vector3(0.0, 1.6, 0.0)
	st.shoot(gun_eye, (vp + Vector3(0.0, 1.15, 0.0) - gun_eye).normalized(), true)
	for i in 14:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	vp = victim["pos"]
	await _shot("bison_going_down", vp + st.heading * 11.0 - side * 5.0 + Vector3(0.0, 1.5, 0.0), vp + Vector3(0.0, 0.8, 0.0), 45.0)
	while not st.done:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	for i in 90:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	vp = victim["node"].global_position
	await _shot("bison_down_settled", vp + st.heading * 7.0 - side * 4.0 + Vector3(0.0, 1.8, 0.0), vp + Vector3(0.0, 0.5, 0.0), 45.0)
	# birds come for it
	keep_birds.add_body(vp, 1.7)
	keep_birds._send_bird(keep_birds.bodies.size() - 1)
	keep_birds._send_bird(keep_birds.bodies.size() - 1)
	for i in int((Ep2CarrionVultures.DESCEND_S + 0.5) * 10.0):
		keep_birds.step(0.1, away)
	await _frames(3)
	await _shot("carrion_feeding", vp + st.heading * 5.5 - side * 3.0 + Vector3(0.0, 1.3, 0.0), vp + Vector3(0.0, 0.4, 0.0), 45.0)
	var feeder: Node3D = keep_birds.birds[0]["node"]
	await _shot("carrion_bird_close", feeder.global_position + Vector3(2.2, 0.8, 2.2), feeder.global_position + Vector3(0.0, 0.3, 0.0), 40.0)
	# the mount dies under him: on foot, the body beside the trail
	trail._route_s = 40.0
	trail._place_at_distance(40.0)
	trail._mounted = true
	trail._horse_left = false
	trail._horse_hp = 1
	trail._update_horse(0.0)
	trail._wound_mount()
	for i in int(LakeTrailChamber.UNHORSE_SECONDS * 60.0) + 5:
		trail._tick_unhorse(1.0 / 60.0)
	await _frames(3)
	var on_foot: Vector3 = trail._player_pos + Vector3(0.0, trail.eye_height, 0.0)
	await _shot("trail_mount_dead_player_on_foot", on_foot, trail._horse.global_position + Vector3(0.0, 0.5, 0.0), 68.0)
	session.queue_free()
	await _frames(3)


func _herd_centre(st: Ep2Stampede) -> Vector3:
	var c := Vector3.ZERO
	var n: int = 0
	for b in st.herd:
		if not bool(b["dead"]):
			c += b["pos"]
			n += 1
	return c / float(maxi(n, 1))


func _lake_shots() -> void:
	var st := Ep2ArmoryState.post_hideout()
	var c: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	c.handoff = {"arrived_mounted": true}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(st)
	c.setup(0, [], 0)
	for i in 90:
		c.step(1.0 / 30.0)
	await _frames(3)
	c._horse_state = "drink"
	var h: Node3D = c._horse
	c._player_pos = h.position + Vector3(3.0, 0.0, 2.0)
	st.horse_wounds = 2
	var eye: Vector3 = c._player_pos + Vector3(0.0, c.eye_height, 0.0)
	await _shot("lake_horse_before_kill", eye, h.global_position + Vector3(0.0, 1.0, 0.0), 60.0)
	var aim: Vector3 = h.global_position + Vector3(0.0, 1.05, 0.0)
	c._look_yaw = atan2(aim.x - eye.x, aim.z - eye.z)
	c._look_pitch = atan2(aim.y - eye.y, Vector2(aim.x - eye.x, aim.z - eye.z).length())
	c._on_player_shot()
	await get_tree().create_timer(0.8).timeout
	await _shot("lake_horse_dead_player_on_foot", eye, h.global_position + Vector3(0.0, 0.4, 0.0), 60.0)
	c.queue_free()
	await _frames(3)


func _town_shots() -> void:
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.step(1.0 / 60.0)
	await _frames(5)
	var law: Ep2TownLaw = c.get_town_law()
	var rail: Node3D = c._visuals.find_child("Horse0", true, false) as Node3D
	var from: Vector3 = rail.global_position + Vector3(1.5, 1.4, 4.5)
	await _shot("town_horse_alive", rail.global_position + Vector3(2.5, 1.7, 6.0), rail.global_position + Vector3(0.0, 0.9, 0.0), 55.0)
	for i in 3:
		law.player_shot(from, (rail.global_position + Vector3(0.0, 1.05, 0.0) - from).normalized())
	await get_tree().create_timer(0.8).timeout
	await _shot("town_horse_dead", rail.global_position + Vector3(2.5, 1.7, 6.0), rail.global_position + Vector3(0.0, 0.3, 0.0), 55.0)
	await _shot("town_horse_dead_ground_level", rail.global_position + Vector3(7.0, 0.35, 1.5), rail.global_position + Vector3(0.0, 0.3, 0.8), 40.0)
	var yard: Ep2StableYard = c._stable_yard
	var pad: Node3D = yard.horses[3]
	var pad_body: Vector3 = pad.global_position + Vector3(0.0, 1.05, 0.0)
	var pad_from: Vector3 = pad_body + Vector3(0.5, 0.5, 3.0)
	for i in 3:
		law.player_shot(pad_from, (pad_body - pad_from).normalized())
	await get_tree().create_timer(0.8).timeout
	await _shot("yard_horse_dead", pad.global_position + Vector3(3.5, 1.7, 5.0), pad.global_position + Vector3(0.0, 0.4, 0.0), 55.0)
	GameManager.town_standing = "warm"
	GameManager.town_debt_btc = 0
	c.queue_free()
	await _frames(3)
