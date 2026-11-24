extends Node
## New Shit 1122 Part 3 proof captures (Compatibility, like the web build): `gate_pod.sh shot tools/ep2_shots/newshit_p3_shot.tscn <dir> part=glass|crowd|rifle`
##   glass: before/after through 3 street windows + a broken-pane close-up       (P3-B)
##   crowd: before the shot / +0.3 s flinch / +1.5 s fleeing + the voices that played (P3-E)
##   rifle: low ready, aim, fire, recoil, ridge watcher, death + drop                (P3-C)

var out: String = "user://newshit_p3"
var part: String = "glass"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.trim_prefix("out=")
		if a.begins_with("part="): part = a.trim_prefix("part=")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	match part:
		"glass": await _glass()
		"crowd": await _crowd()
		"rifle": await _rifle()
	print("P3_SHOT_DONE ", part)
	get_tree().quit()


func _snap(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("P3_SHOT ", name)


func _hold(c: Node, at: Vector3, look: Vector3, frames: int = 10) -> void:
	for i in frames:
		c._player_pos = Vector3(at.x, at.y, at.z)
		var eye: Vector3 = at + Vector3(0, c.eye_height, 0)
		var d: Vector3 = look - eye
		c._look_yaw = atan2(d.x, d.z)
		c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
		c.step(1.0 / 60.0)
		await get_tree().process_frame


func _town() -> GoldTownChamber:
	var c: GoldTownChamber = (load("res://src/episode2/chamber/gold_town.tscn") as PackedScene).instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	return c


func _glass() -> void:
	var c: GoldTownChamber = await _town()
	var law: Ep2TownLaw = c.get_town_law()
	var k: int = 0
	for piece in ["Bldg_Saloon", "Bldg_Certificates", "Bldg_B"]:
		var n: Vector3 = law.front_normal(piece)
		var target: Vector3 = law.window_target(piece, 0)
		var stand: Vector3 = Vector3(target.x, 0, target.z) + n * 5.0 + n.cross(Vector3.UP).normalized() * 1.2
		await _hold(c, stand, target)
		await _snap("glass_%d_%s_before" % [k, piece])
		law.player_shot(stand + Vector3(0, c.eye_height, 0), target - (stand + Vector3(0, c.eye_height, 0)))
		await _hold(c, stand, target, 8)
		await _snap("glass_%d_%s_shot" % [k, piece])
		await _hold(c, stand, target, 90)
		await _snap("glass_%d_%s_after" % [k, piece])
		if k == 0:
			await _hold(c, Vector3(target.x, 0, target.z) + n * 1.7, target, 10)
			await _snap("glass_closeup")
		k += 1
	print("P3_GLASS broken=", law.broken_windows, " breaks=", law.glass.breaks)


func _crowd() -> void:
	var c: GoldTownChamber = await _town()
	var tp: Ep2TownPeople = c.get_people()
	await _hold(c, c._player_pos, c._player_pos + Vector3(0, 1.6, 6), 30)
	var woman: Ep2TownPeople.Person = null
	for p in tp.people:
		if Ep2TownPeople.sex_of(p.id) == "f" and p.state not in Ep2TownPeople.SHOP_STATES and not p.folk.use_height:
			woman = p
			break
	if woman == null:
		print("P3_CROWD no woman in the street")
		return
	var her: Vector3 = woman.folk.global_position
	var stand: Vector3 = her + Vector3(3.2, 0, 3.2)
	stand.y = 0.0
	await _hold(c, stand, her + Vector3(0, 1.3, 0), 6)
	await _snap("crowd_0_before")
	var am: Node = get_node("/root/AudioManager")
	var log0: int = tp.voice_log.size()
	var sfx0: int = am.sfx_log.size()
	tp.notify_danger(her + Vector3(1.2, 0, 0.8), 24.0, "shot")
	await _hold(c, stand, her + Vector3(0, 1.3, 0), 18)
	await _snap("crowd_1_plus0.3s_flinch")
	await _hold(c, stand, her + Vector3(0, 1.3, 0), 72)
	await _snap("crowd_2_plus1.5s_fleeing")
	var f := FileAccess.open(out + "/audio_log.txt", FileAccess.WRITE)
	f.store_line("voices: " + JSON.stringify(tp.voice_log.slice(log0)))
	f.store_line("sfx_at ids: " + str(am.sfx_log.slice(sfx0)))
	f.close()
	print("P3_CROWD voices=", tp.voice_log.slice(log0))


func _rifle() -> void:
	var c: LakeTrailChamber = (load("res://src/episode2/chamber/lake_trail.tscn") as PackedScene).instantiate() as LakeTrailChamber
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	c.debug_invulnerable = true
	await get_tree().process_frame
	var idx: int = -1
	for i in c._bandits.size():
		if str((c._bandits[i] as Dictionary).get("gun_id", "")) == Ep2ArmoryState.WIN:
			idx = i
			break
	if idx < 0:
		print("P3_RIFLE no rifleman")
		return
	var b: Dictionary = c._bandits[idx]
	var root: Node3D = b["root"]
	b["exposed"] = true
	root.position.y = (b["home"] as Vector3).y
	var folk: Ep2TownFolk = b["folk"]
	var at: Vector3 = c._bandit_world_position(b)
	var fwd := Vector3(sin(folk.facing), 0, cos(folk.facing))
	var side := fwd.cross(Vector3.UP).normalized()
	# contact sheet: he is stood in the open at the trail's edge (his rock and trees hide him in play, by design), facing the camera
	var trail: Vector3 = c._route_sample(float(b["s"]))[0]
	var away: Vector3 = (at - trail).normalized()
	root.position = trail + away * 3.0
	root.position.y = trail.y
	b["home"] = root.position
	folk.position = Vector3.ZERO
	at = c._bandit_world_position(b)
	var cam_at: Vector3 = trail - away * 3.2 + away.cross(Vector3.UP).normalized() * 1.4
	cam_at.y = trail.y + 0.1
	folk.face_yaw(atan2(cam_at.x - at.x, cam_at.z - at.z))
	fwd = Vector3(sin(folk.facing), 0, cos(folk.facing))
	var look: Vector3 = at + Vector3(0, 1.0, 0)
	# the trail starts mounted (the horse's head fills the player's eye): a capture camera beside him instead
	var cam := Camera3D.new()
	c.add_child(cam)
	cam.global_position = cam_at + Vector3(0, 1.55, 0)
	cam.look_at(look, Vector3.UP)
	cam.fov = 34.0
	cam.current = true
	folk.set_pose("idle")
	await _hold(c, cam_at, look, 8)
	await _snap("rifle_1_low_ready")
	c._begin_telegraph(idx)
	await _hold(c, cam_at, look, 30)
	await _snap("rifle_2_aim")
	c._fire_bandit(idx)
	await _hold(c, cam_at, look, 1)
	await _snap("rifle_3_fire")
	await _hold(c, cam_at, look, 6)
	await _snap("rifle_4_recoil")
	c._drop_bandit(idx)
	await _hold(c, cam_at, look, 70)
	await _snap("rifle_6_death_drop")
	var drop: Node3D = c._drops_root.get_node_or_null("Drop_trail_%d" % idx) as Node3D if c._drops_root != null else null
	if drop != null:
		cam.global_position = drop.global_position + Vector3(0.9, 1.7, 0.9)
		cam.look_at(drop.global_position + Vector3(-0.4, 0, -0.4), Vector3.UP)
		cam.fov = 50.0
		await _hold(c, cam_at, look, 4)
		await _snap("rifle_7_drop_closeup")
	c.queue_free()
	await get_tree().process_frame
	var r: RiverCoverChamber = (load("res://src/episode2/chamber/river_cover.tscn") as PackedScene).instantiate() as RiverCoverChamber
	add_child(r)
	r.setup(0, [], 0)
	r.set_physics_process(false)
	await get_tree().process_frame
	var ws: Array = r.get_watchers()
	if ws.is_empty():
		print("P3_RIFLE no watchers")
		return
	var w: Dictionary = ws[0]
	var wf: Ep2TownFolk = w["folk"]
	var river: Vector3 = w["river"]
	var wp: Vector3 = wf.global_position
	var along := river.cross(Vector3.UP).normalized()
	var cam2: Vector3 = wp - river * 1.2 + along * 4.0
	r.eye_height = 1.6
	for i in 10:
		r._player_pos = cam2
		var d: Vector3 = wp + Vector3(0, 1.2, 0) - (cam2 + Vector3(0, r.eye_height, 0))
		r._look_yaw = atan2(d.x, d.z)
		r._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
		r.step(1.0 / 60.0)
		await get_tree().process_frame
	await _snap("rifle_5_ridge_watcher")
