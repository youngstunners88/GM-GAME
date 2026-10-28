extends Node
## Gate for the INTERLUDE chain (founder 2026-10-09): the hideout's lava river gives way to the MINE LIFT (two floors up,
## a hidden lever, Inferno lays out the plan to "Inferno Bull 2"), then the BEAR WOODS (sneak, the camouflaged flame quad,
## the ride to "Deep Mining 3", the spyglass on the bear camp), where the playable slice ends with TO BE CONTINUED.
##
## What it locks:
##  * THE LEVER IS INCONSPICUOUS: same material as the wall, small, unlit - and Inferno still pulls it, on camera.
##  * THE CAGE REALLY CLIMBS two floors (past MID_Y to TOP_Y), the plan lines play in order, the gate opens at the top.
##  * THE SONGS: "Inferno Bull 2" in the shaft, "Deep Mining 3" once they are on the quad - never the other way round.
##  * THE QUAD IS HIDDEN under leaves until Inferno throws them off; stealth: walking is free, running near a bear is heard.
##  * THE SESSION CHAINS: hideout result -> mine_lift -> woods_quad -> session_complete, each commit guarded (no double pay).
##  * IT IS A FIRST-PERSON SHOOTER (founder 2026-10-09): the Winchester is IN LIL BLUNT'S HANDS - on the camera, hands on it, loaded,
##    firing, aiming, reloading - in the lift, the woods, the quad ride and the spy point. It is never slung on his back again.
## Run: godot --headless res://tests/ep2_interlude_test.tscn

const LIFT := preload("res://src/episode2/chamber/mine_lift.tscn")
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")

var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run(c: Node, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _until(c: Node, limit: float, pred: Callable) -> bool:
	for i in int(limit * 60.0):
		if pred.call():
			return true
		c.step(1.0 / 60.0)
	return pred.call()


func _manifest_text(id: String) -> String:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	for e in m["voice"]:
		if str(e["id"]) == id:
			return str(e["text"])
	return ""


func _manifest_speed(id: String) -> float:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	for e in m["voice"]:
		if str(e["id"]) == id:
			return float((e.get("voice_settings", {}) as Dictionary).get("speed", 1.0))
	return 0.0


func _music_path() -> String:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null or am.current_music_player == null or not is_instance_valid(am.current_music_player):
		return ""
	var st: AudioStream = am.current_music_player.stream
	return st.resource_path if st else ""


func _ready() -> void:
	await get_tree().process_frame

	# ---------------------------------------------------------------- 1. the mine lift
	print("-- MINE LIFT")
	var lift: MineLiftChamber = LIFT.instantiate()
	add_child(lift)
	var said: Array = []
	lift.line_spoken.connect(func(id): said.append(id))
	var results: Array = []
	lift.chamber_cleared.connect(func(r): results.append(r))
	lift.setup(0, [], 0)
	await get_tree().process_frame
	_check("starts at ARRIVE with Lil Blunt in the tunnel and control his", lift.get_beat_name() == "ARRIVE" and lift.has_player_control(), lift.get_beat_name())
	_check("Inferno Bull 2 starts the moment they are in the shaft", "inferno_bull2" in _music_path(), _music_path())
	_check("the interlude exposes the host's story-room vocabulary (title card, FPS mode, no miner-rig verbs)", lift.get_title_card() == "THE MINE LIFT"
		and lift.start_rig() == false and lift.get_episode_mode() == Episode2Mode.Mode.FPS and lift.is_fps())
	# --- FIRST PERSON: the rifle is in his hands
	_run(lift, 0.3)
	var vm: Ep2Viewmodel = lift.get_viewmodel()
	_check("the Winchester viewmodel exists and sits on the camera (it IS the player's view)", vm != null and vm.rifle != null and vm.rifle.get_parent() == lift.get_camera())
	_check("Lil Blunt's hands and the founder's rifle are on it", vm != null and vm.rifle.get_node_or_null("Hands/HandsModel") != null)
	_check("the rifle is loaded: full tube and the reserve", lift.get_ammo() == Ep2Winchester.MAG and lift.get_reserve() == Ep2Winchester.RESERVE_START, "%d/%d" % [lift.get_ammo(), lift.get_reserve()])
	_check("the third-person body is hidden in first person (the eye is his)", not lift._player_node.visible and vm.rifle.visible)
	_check("the rifle is NEVER slung on his back: the body carries it in the hand, nothing is slung", lift._player_node.find_child("SlungRifle", true, false) == null and lift._player_node.find_child("HeldRifle", true, false) != null)
	_check("the camera is his eye (about 1.55 m above his feet), not a boom behind him",
		absf(lift.get_camera().position.y - (lift.get_player_position().y + Ep2Interlude.FPS_EYE_HEIGHT)) < 0.12
		and Vector2(lift.get_camera().position.x - lift.get_player_position().x, lift.get_camera().position.z - lift.get_player_position().z).length() < 0.2,
		str(lift.get_camera().position) + " vs " + str(lift.get_player_position()))
	_check("the HUD shows the ammo and the crosshair", lift.get_hud() != null and lift.get_hud().show_ammo and lift.get_hud().show_crosshair and lift.get_hud().rounds == Ep2Winchester.MAG)
	var hip_fov: float = lift.get_camera().fov
	lift.set_aim(true)
	_run(lift, 0.5)
	_check("RMB aims down the sights (the view narrows)", lift.is_ads() and lift.get_camera().fov < hip_fov - 10.0, "%.1f -> %.1f" % [hip_fov, lift.get_camera().fov])
	lift.set_aim(false)
	_run(lift, 0.5)
	var rounds0: int = lift.get_ammo()
	var shot_ok: bool = lift.shoot()
	_check("LMB fires a round: the tube drops by one, the muzzle report plays", shot_ok and lift.get_ammo() == rounds0 - 1 and vm.shots_played == 1, "%s %d shots %d" % [shot_ok, lift.get_ammo(), vm.shots_played])
	_check("...and the lever must be racked before the next shot", lift.shoot() == false and lift.get_ammo() == rounds0 - 1)
	_run(lift, 1.0)
	_check("the lever clack follows the shot", vm.levers_played >= 1)
	var cam_kick_seen: bool = vm.cam_kick >= 0.0
	_check("R loads shells back into the tube, one at a time", lift.reload() and (_until(lift, 3.0, func(): return lift.get_ammo() == Ep2Winchester.MAG)) and lift.get_reserve() == Ep2Winchester.RESERVE_START - 1, "%d/%d" % [lift.get_ammo(), lift.get_reserve()])
	_check("the first-person control hint names aim and reload", cam_kick_seen and "RMB" in Episode2Mode.control_hint(Episode2Mode.Mode.FPS) and "reload" in Episode2Mode.control_hint(Episode2Mode.Mode.FPS))
	# --- the lever (founder 2026-10-13): INSIDE the cage, iron like the cage's frame (hidden in plain sight), riding up with it
	var lv: Node3D = lift.get_lever_node()
	_check("the lever is INSIDE the cage (a child of the cage, within its walls)", lv != null and lv.get_parent() == lift._cage
		and absf(lv.position.x) < MineLiftChamber.CAGE_HALF and absf(lv.position.z) < MineLiftChamber.CAGE_HALF)
	var disguised: bool = true
	var meshes: int = 0
	for mi in lv.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var m: MeshInstance3D = mi
		if m.material_override is StandardMaterial3D and (m.material_override as StandardMaterial3D).emission_enabled:
			disguised = false
	_check("...made of the cage's own rusted iron, nothing lit or coloured", disguised and meshes >= 2)
	# --- the bars are solid (founder 2026-10-13: "why are they walking through the pole bars")
	var side_in: Vector3 = lift._cage_bars(Vector3(-2.6, 0.0, 0.0), Vector3(-1.5, 0.0, 0.0))
	_check("Lil Blunt cannot walk through the cage's side bars", absf(side_in.x) >= MineLiftChamber.CAGE_HALF, str(side_in))
	var door_in: Vector3 = lift._cage_bars(Vector3(0.0, 0.0, -2.05), Vector3(0.0, 0.0, -1.6))
	_check("...but walks in through the open walkway doorway", absf(door_in.z - (-1.6)) < 0.01, str(door_in))
	var top_out: Vector3 = lift._cage_bars(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 2.2))
	_check("...and cannot leave through the shut surface gate", top_out.z <= MineLiftChamber.CAGE_HALF - MineLiftChamber.BODY_R + 0.001, str(top_out))
	# --- ARRIVE: Inferno walks to the cage while he talks; Lil Blunt walks in
	_until(lift, 25.0, func(): return said.has("vo_bull_lift1") and not lift.is_show_active())
	_check("Inferno tells him to step on the lift", said.has("vo_bull_lift1"))
	_check("...and walks into the cage himself, through the doorway", lift.get_bull().position.distance_to(MineLiftChamber.CAGE_STAND_BULL) < 0.5, str(lift.get_bull().position))
	lift.set_move_input(Vector2(0.0, 1.0))
	_until(lift, 8.0, func(): return lift.get_beat_name() != "ARRIVE")
	lift.set_move_input(Vector2.ZERO)
	_check("walking onto the cage ends ARRIVE", lift.get_beat_name() in ["BOARD", "LEVER"], lift.get_beat_name())
	# --- LEVER: Inferno says there is no use looking, walks to it and pulls it
	_until(lift, 4.0, func(): return lift.get_beat_name() == "LEVER")
	_check("-> LEVER; the show runs but does NOT lock the player (one motion: he keeps the rifle and can look around)", lift.get_beat_name() == "LEVER" and lift.has_player_control() and lift.is_show_active())
	_run(lift, 2.0)
	var eye_p: Vector3 = lift.get_player_position() + Vector3(0.0, Ep2Interlude.FPS_EYE_HEIGHT, 0.0)
	var to_lever: Vector3 = lift.get_lever_position() - eye_p
	_check("the scripted beat STAYS in first person (no cut to a body): the rifle is on screen and his eye turns to the lever Inferno pulls",
		not lift._player_node.visible and vm.rifle.visible and lift.get_hud().visible and absf(angle_difference(lift.get_look_yaw(), atan2(to_lever.x, to_lever.z))) < 0.6,
		"yaw %.2f want %.2f" % [lift.get_look_yaw(), atan2(to_lever.x, to_lever.z)])
	_until(lift, 30.0, func(): return lift.get_beat_name() == "RISE")
	_check("the handle is pulled silently, then the cage starts", not said.has("vo_bull_lift_lever") and lift.get_beat_name() == "RISE", str(said))
	_check("the lever swung (he actually pulled it)", lift._lever_t >= 1.0)
	_check("the walkway gate dropped shut behind them", lift._gate_in_k < 0.05)
	_check("Inferno never left the cage to pull it", absf(lift.get_bull().position.x) < MineLiftChamber.CAGE_HALF and absf(lift.get_bull().position.z) < MineLiftChamber.CAGE_HALF, str(lift.get_bull().position))
	_check("control returns to the player for the ride", lift.has_player_control())
	_run(lift, 0.2)
	_check("...and so does his eye: the rifle is back in his hands on screen", not lift._player_node.visible and vm.rifle.visible and lift.get_hud().visible)
	# --- RISE: two floors
	var st: Dictionary = {"mid": false, "prev": 0.0, "mono": true}      # a lambda captures plain values by copy: mutate a Dictionary
	var ride_ok: bool = _until(lift, MineLiftChamber.RISE_SECONDS + 40.0, func():
		var y: float = lift.get_cage_y()
		if y < float(st["prev"]) - 0.001:
			st["mono"] = false
		st["prev"] = y
		if y > MineLiftChamber.MID_Y - 0.5 and y < MineLiftChamber.MID_Y + 0.5:
			st["mid"] = true
		return lift.get_beat_name() == "SURFACE")
	_check("the cage climbs, steadily, past the first floor and on to the surface (two floors)", ride_ok and bool(st["mid"]) and bool(st["mono"]), "y=%.2f %s" % [lift.get_cage_y(), str(st)])
	_check("Lil Blunt rides it up (he is at the surface level)", absf(lift.get_player_position().y - MineLiftChamber.TOP_Y) < 0.05, str(lift.get_player_position()))
	_check("the plan: sneak, the quad, spy on the bears - Inferno then Lil Blunt's answer, in order",
		said.find("vo_bull_plan1") >= 0 and said.find("vo_bull_plan1") < said.find("vo_bull_plan2") and said.find("vo_bull_plan2") < said.find("vo_bull_plan3")
		and said.find("vo_bull_plan3") < said.find("vo_lb_plan_reply"), str(said))
	_until(lift, 6.0, func(): return lift.is_gate_open())
	_check("the gate slides open at the top", lift.is_gate_open())
	_check("surface exit has no blocking arrival narration", not said.has("vo_bull_lift_arrive"))
	_until(lift, 10.0, func(): return not lift.is_show_active())
	lift._look_yaw = 0.0                                # he turns from the lever wall to the daylight (the mouse, in play)
	lift.set_move_input(Vector2(0.0, 1.0))
	_until(lift, 12.0, func(): return results.size() == 1)
	lift.set_move_input(Vector2.ZERO)
	_check("walking out into the daylight resolves the chamber", results.size() == 1, lift.get_beat_name() + " " + str(lift.get_player_position()))
	if results.size() == 1:
		var r: Dictionary = results[0]
		_check("it is a story chamber that mints nothing", bool(r.get("story", false)) and int(r.get("gold_awarded", -1)) == 0 and int(r.get("gold_forfeited", -1)) == 0)
		_check("...and chains to the bear woods", str(r.get("next_chamber", "")) == "woods_quad")
	lift.queue_free()

	# ---------------------------------------------------------------- 2. the woods
	print("-- BEAR WOODS")
	var w: WoodsQuadChamber = WOODS.instantiate()
	add_child(w)
	var said2: Array = []
	w.line_spoken.connect(func(id): said2.append(id))
	var res2: Array = []
	w.chamber_cleared.connect(func(r): res2.append(r))
	w.setup(0, [], 0)
	w.debug_invulnerable = true          # this run walks the whole chamber; the fight + failure are tested in section 3
	await get_tree().process_frame
	_check("starts at SNEAK", w.get_beat_name() == "SNEAK" and w.has_player_control(), w.get_beat_name())
	_run(w, 0.3)
	var wvm: Ep2Viewmodel = w.get_viewmodel()
	_check("the woods are first person too: the Winchester in his hands, his body hidden, ammo on the HUD",
		w.is_fps() and w.get_episode_mode() == Episode2Mode.Mode.FPS and wvm != null and wvm.rifle.get_parent() == w.get_camera()
		and wvm.rifle.get_node_or_null("Hands/HandsModel") != null and not w._player_node.visible and w.get_hud().show_ammo and w.get_ammo() == Ep2Winchester.MAG)
	_check("the woods can hurt him, so his 3 hearts are on the HUD", w.get_hud().show_health and w.get_health() == 3 and w.get_hud().health == 3)
	_check("the quad is hidden under leaves and branches (a real pile of them)", w.is_quad_hidden() and w.get_cover_bit_count() >= 80, str(w.get_cover_bit_count()))
	# the old-growth wood (founder 2026-10-10: "cartoon junk" -> realism; trees in the wind; birds; ElevenLabs soundscape), now ~1 km long
	var trunk_n: int = 0
	var trunk_layers: int = 0
	var crowns: MultiMeshInstance3D = null
	for n in w._visuals.get_children():
		if str(n.name).begins_with("ForestTrunks_"):
			trunk_layers += 1
			trunk_n += (n as MultiMeshInstance3D).multimesh.instance_count
		if crowns == null and str(n.name).begins_with("ForestCrowns_"):
			crowns = n
	var t0: MultiMeshInstance3D = w._visuals.get_node_or_null("ForestTrunks_0") as MultiMeshInstance3D
	_check("the wood is the textured old-growth kit (bark trunks + fir-branch crowns), not cones and cylinders",
		t0 != null and crowns != null and trunk_n >= 600 and t0.multimesh.mesh is ArrayMesh
		and (t0.material_override as StandardMaterial3D).albedo_texture != null, "%d trunks" % trunk_n)
	_check("...built in slices along the trail and road, each with a draw distance (a 1 km wood at the old web cost)",
		trunk_layers >= 12 and t0.visibility_range_end > 100.0, "%d slices" % trunk_layers)
	var cm: ShaderMaterial = crowns.material_override as ShaderMaterial if crowns != null else null
	_check("the crowns sway in the wind (wind shader on the branch cards)", cm != null and cm.shader.resource_path.ends_with("ep2_foliage_wind.gdshader")
		and float(cm.get_shader_parameter("sway")) > 0.1)
	var wl: Ep2Wildlife = w._wildlife
	var bird0: Vector3 = (wl._birds[0][0] as Node3D).position if wl != null and not wl._birds.is_empty() else Vector3.ZERO
	_run(w, 1.0)
	_check("birds fly in the wood (a few, moving)", wl != null and wl.get_bird_count() >= 5 and (wl._birds[0][0] as Node3D).position.distance_to(bird0) > 3.0)
	# the founder's TRIPO bears, not the Meshy ones (2026-10-10): the rigged bear file is the Tripo body on the bear skeleton,
	# its bow-less arms lowered out of the archer T, plus two Tripo bear-archer sentries drawing on the approach
	var cb: Ep2Actor = (w.get_scouts()[0] as Ep2BearBrain).actor
	var bear_tris: int = 0
	for mi in cb.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null:
			bear_tris += (mi as MeshInstance3D).mesh.get_faces().size() / 3
	_check("the woods bears are the founder's Tripo bear (dense hyper-real body, arms lowered)",
		bear_tris > 30000 and cb.skeleton != null and cb.skeleton.get_node_or_null("ArmsDown") != null, "tris %d" % bear_tris)
	# the spy camp is gone (founder 2026-10-14): the ride now runs out of the woods to the gold-rush town
	_check("no bear camp, no spy ridge, no sentries: the ride heads for town", not ("SPY" in WoodsQuadChamber.Beat)
		and w._visuals.find_children("BearArcherSentry*", "", false, false).is_empty())
	_check("the ElevenLabs woods soundscape is loaded (ambience loop, gust, 3 bird calls, flutter)", wl != null and wl._ambience.stream != null and wl._gust.stream != null
		and Ep2Wildlife.CALLS.all(func(p): return ResourceLoader.exists(p)) and ResourceLoader.exists(Ep2Wildlife.FLUTTER))
	# LIVING BEARS (founder 2026-10-13): named, each with his own routine and senses
	var scouts: Array = w.get_scouts()
	var routines: Dictionary = {}
	var names: Dictionary = {}
	for b in w.get_bears():
		routines[(b as Ep2BearBrain).routine()] = true
		names[(b as Ep2BearBrain).display_name()] = true
	_check("every bear is somebody: a name, a routine of his own (patrol, read, sleep, roam, watch)",
		names.size() == w.get_bears().size() and routines.has("patrol") and routines.has("read") and routines.has("sleep") and routines.has("roam") and routines.has("watch"),
		str(routines.keys()))
	var reader: Ep2BearBrain = w.get_bear("Professor Barnaby")
	var sleeper: Ep2BearBrain = w.get_bear("Old Moss")
	var walker: Ep2BearBrain = w.get_bear("Twitch")
	_run(w, 0.5)
	_check("Professor Barnaby READS (seated on his stump, Bear Monthly in his paws)", reader != null and Ep2BearKit.pose_name(reader.actor) == "sit_read"
		and reader.actor.has_meta("prop_magazine") and (reader.actor.get_meta("prop_magazine") as Node3D).visible and reader.actor.has_meta("prop_stump"))
	_check("Old Moss SLEEPS (lying down, z's over him)", sleeper != null and Ep2BearKit.pose_name(sleeper.actor) == "sleep" and sleeper.actor.has_meta("prop_zzz"))
	var tw0: Vector3 = walker.actor.position if walker != null else Vector3.ZERO
	_run(w, 4.0)
	_check("Twitch WALKS his beat (a real walk, not a slide on the spot)", walker != null and walker.actor.position.distance_to(tw0) > 2.0
		and walker.actor.current_clip() == walker.actor.walk_clip, "%.1f m %s" % [walker.actor.position.distance_to(tw0), walker.actor.current_clip()])
	var archers_with_bows: int = 0
	for b in w.get_bears("road"):
		if (b as Ep2BearBrain).role() == "archer" and (b as Ep2BearBrain).actor.has_meta("bow"):
			archers_with_bows += 1
	_check("the logging road is picketed: at least 12 road bears, archers carrying bows", w.get_bears("road").size() >= 12 and archers_with_bows >= 5,
		"%d road, %d bows" % [w.get_bears("road").size(), archers_with_bows])
	# a LARGER world: the bears are far from Inferno's door (they can smell a forge)
	var nearest: float = 1e9
	for b in w.get_bears():
		nearest = minf(nearest, (b as Ep2BearBrain).actor.position.distance_to(WoodsQuadChamber.SPAWN))
	var bear_far_z: float = 0.0
	for b in w.get_bears():
		bear_far_z = maxf(bear_far_z, (b as Ep2BearBrain).actor.position.z)
	_check("no bear within 40 m of the mine door; ~1.2 km of road to the town; no bear past the last pines",
		nearest > 40.0 and w.get_ride_length() > 1100.0 and bear_far_z < WoodsQuadChamber.FOREST_END_Z,
		"nearest %.0f m, road %.0f m, last bear z %.0f" % [nearest, w.get_ride_length(), bear_far_z])
	_check("the town is built along the road's end (the same Ep2GoldTown the town chamber builds)",
		w._visuals.find_child("Bldg_Certificates*", true, false) != null or w._visuals.find_child("Town*", true, false) != null)
	_check("no music of the quad ride yet", "deep_mining3" not in _music_path(), _music_path())
	# walking behind Inferno along the trail is free: no bear notices
	var guard: int = 0
	while w.get_beat_name() == "SNEAK" and guard < 24000:
		guard += 1
		var bull_pos: Vector3 = w.get_bull().position
		var me: Vector3 = w.get_player_position()
		var to := Vector2(bull_pos.x - me.x, bull_pos.z - me.z)
		if to.length() > 3.2:
			w._look_yaw = atan2(to.x, to.y)
			w.set_move_input(Vector2(0.0, 1.0), false)
		else:
			w.set_move_input(Vector2.ZERO)
		w.step(1.0 / 60.0)
	w.set_move_input(Vector2.ZERO)
	_check("following Inferno at a walk brings them past every scout to the thicket (-> REVEAL) with no bear alerted",
		w.get_beat_name() == "REVEAL" and w.get_noise_hits() == 0 and w.get_alert_count() == 0, "%s hits %d alerts %d" % [w.get_beat_name(), w.get_noise_hits(), w.get_alert_count()])
	_check("...and Inferno named the scouts as they passed them", said2.has("vo_bull_scout_barnaby") and said2.has("vo_bull_scout_moss") and said2.has("vo_bull_scout_hattie"),
		str(said2))
	_run(w, 2.5)
	var to_quad: Vector3 = (WoodsQuadChamber.QUAD_POS + Vector3(0.0, 1.3, 0.0)) - (w.get_player_position() + Vector3(0.0, Ep2Interlude.FPS_EYE_HEIGHT, 0.0))
	_check("the reveal is seen through HIS eyes with the rifle in his hands: his view turns to the quad, no cut to a cinema camera",
		not w._player_node.visible and wvm.rifle.visible and w.get_hud().visible and absf(angle_difference(w.get_look_yaw(), atan2(to_quad.x, to_quad.z))) < 0.6,
		"yaw %.2f want %.2f" % [w.get_look_yaw(), atan2(to_quad.x, to_quad.z)])
	_until(w, 40.0, func(): return w.get_beat_name() == "MOUNT" or w.get_beat_name() == "RIDE")
	_check("the leaves come off (the quad is revealed)", not w.is_quad_hidden() and said2.has("vo_bull_quad_reveal") and said2.has("vo_lb_quad_ok"))
	# NO BLINK (founder 2026-10-13: "improve the transitions"): his eye climbs onto the back seat in one continuous move
	var max_fade: float = 0.0
	var max_jump: float = 0.0
	var prev_eye: Vector3 = w.get_camera().global_position
	var glided: bool = false
	for i in 60 * 12:
		if w.get_beat_name() == "RIDE":
			break
		w.step(1.0 / 60.0)
		max_fade = maxf(max_fade, w.get_hud().fade)
		var e: Vector3 = w.get_camera().global_position
		max_jump = maxf(max_jump, e.distance_to(prev_eye))
		prev_eye = e
		glided = glided or w.is_gliding()
	_check("he climbs on behind Inferno WITHOUT a blink: the screen never dips, the eye glides onto the back seat (no jump)",
		max_fade < 0.05 and glided and max_jump < 0.25, "fade %.2f jump %.2f m" % [max_fade, max_jump])
	_check("-> RIDE, the quad is on the road", w.get_beat_name() == "RIDE" and w.is_riding() and said2.has("vo_bull_quad_mount"))
	_check("Deep Mining 3 only now (the moment they mount)", "deep_mining3" in _music_path(), _music_path())
	_run(w, 1.5)
	_check("on the back seat he is still first person, the rifle in his hands (\"hold that rifle steady\")", w.is_fps() and wvm.rifle.visible and not w._player_node.visible and w.get_hud().visible)
	_check("it is the MODELLED flame quad (flame_quad.glb, four spinning Wheel_* nodes), not the box stand-in", w.is_quad_modelled() and w.get_quad_wheel_count() == 4, "%s %d" % [w.is_quad_modelled(), w.get_quad_wheel_count()])
	var driver: Ep2Actor = w.get_bull()
	# Founder 2026-10-11 ("elbow partially invisible"): the arm IK + spine lean tore his sculpted elbow, so the ride has NO reach;
	# he sits (seated clip) and his arms stay at the imported rest pose.
	_check("Inferno SITS on the quad (seated clip), arms NOT dragged by IK (the elbow tears), he does not stand in the air",
		driver.current_clip() == WoodsQuadChamber.BULL_SIT_CLIP and driver.reach_weight("Left") < 0.01 and driver.reach_weight("Right") < 0.01 and not WoodsQuadChamber.BULL_GRIPS_IK,
		"%s L%.2f R%.2f" % [driver.current_clip(), driver.reach_weight("Left"), driver.reach_weight("Right")])
	var qn: Node3D = w.get_quad_node()
	var seat_eye: Vector3 = w.get_camera().global_position
	var fwd := Vector3(sin(w._quad_yaw), 0.0, cos(w._quad_yaw))
	_check("Lil Blunt's eye is on the rear of the seat, above the seat and BEHIND Inferno's hips (he looks over the driver, not into him)",
		seat_eye.y > qn.global_position.y + WoodsQuadChamber.SEAT_TOP + 0.9 and (seat_eye - driver.global_position).dot(fwd) < -0.6,
		"eye y %.2f behind %.2f" % [seat_eye.y - qn.global_position.y, (seat_eye - driver.global_position).dot(fwd)])
	_run(w, 2.5)
	_check("the passenger's view rides the quad: it turns with the heading", absf(angle_difference(w._look_yaw, w._quad_yaw)) < 0.2, "look %.2f quad %.2f" % [w._look_yaw, w._quad_yaw])
	var ride_hits: int = w.get_noise_hits()
	_check("he can fire from the back seat (the engine covers it: no stealth penalty)", w.shoot() and w.get_noise_hits() == ride_hits)
	_check("Deep Mining 3 is playing on the quad", "deep_mining3" in _music_path(), _music_path())
	var q0: Vector3 = w.get_quad_node().position
	_run(w, 3.0)
	_check("the quad moves along the road (rails: the player does not steer)", w.get_quad_node().position.distance_to(q0) > 15.0, str(w.get_quad_node().position))
	_check("both ride it: Inferno up front, Lil Blunt behind", absf(w.get_bull().position.distance_to(w.get_quad_node().position)) < 3.0 and absf(w.get_player_position().distance_to(w.get_quad_node().position)) < 4.5)
	# THE ROAD FIGHT: the pickets wake to the engine; archers loose arrows at him; he shoots back from the back seat
	var road_alerted: int = 0
	var shot_at: Dictionary = {}
	var ride_t: float = 0.0
	var alert_since: Dictionary = {}
	while w.get_beat_name() == "RIDE" and ride_t < 300.0:
		ride_t += 1.0 / 60.0
		# aim at the nearest live, alert road bear in front within 35 m, and fire when the lever allows
		var tgt: Ep2BearBrain = null
		var best_d: float = 35.0
		for b in w.get_bears("road"):
			var br: Ep2BearBrain = b
			if br.is_dead() or not br.is_alert():
				continue
			# a human passenger needs a moment to pick out a bear that has just turned on him (and an archer gets his draw off)
			if not alert_since.has(br.display_name()):
				alert_since[br.display_name()] = ride_t
			if ride_t - float(alert_since[br.display_name()]) < 1.8:
				continue
			var dd: float = br.actor.position.distance_to(w.get_player_position())
			if dd < best_d:
				best_d = dd
				tgt = br
		if tgt != null:
			var eye3: Vector3 = w.get_player_position() + Vector3(0.0, w.eye_height, 0.0)
			var aim: Vector3 = tgt.actor.position + Vector3(0.0, tgt.actor.height_m * 0.55, 0.0) - eye3
			w._look_yaw = atan2(aim.x, aim.z)
			w._look_pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
			w.set_aim(true)
			if w.get_viewmodel().gun.ads > 0.95 and w.shoot():
				shot_at[tgt.display_name()] = true
			if w.get_ammo() == 0:
				w.reload()
		else:
			w.set_aim(false)
		w.step(1.0 / 60.0)
	w.set_aim(false)
	for b in w.get_bears("road"):
		if (b as Ep2BearBrain).is_alert() or (b as Ep2BearBrain).is_dead() or (b as Ep2BearBrain).aware == Ep2BearBrain.Aware.SEARCH:
			road_alerted += 1
	_check("the engine wakes the road: pickets turn on the quad", road_alerted >= 6, "%d alerted" % road_alerted)
	_check("archers fire back: real arrows are loosed at him on the ride", w.get_arrows_loosed() >= 3, "%d arrows" % w.get_arrows_loosed())
	var corpse: Ep2BearBrain = null
	for b in w.get_bears("road"):
		if (b as Ep2BearBrain).is_dead():
			corpse = b
	_check("he shoots bears off the road from the back seat (kills land)", w.get_kills() >= 2 and corpse != null, "%d kills, shot at %s" % [w.get_kills(), str(shot_at.keys())])
	_check("the ride is long (out of the wood, across the desert): over 90 s on the road", ride_t > 90.0, "%.0f s" % ride_t)
	_check("the bears thin out: none attacks in the desert (every picket stands in the wood)", w.get_bears("road").all(func(b): return (b as Ep2BearBrain).actor.position.z < WoodsQuadChamber.FOREST_END_Z))
	_check("the ride ends IN the town's main street (-> DROPOFF) in first person", w.get_beat_name() == "DROPOFF" and w.is_fps()
		and absf(w.get_quad_node().position.z - Ep2GoldTown.DROP_POINT.z) < 6.0 and absf(w.get_quad_node().position.x) < Ep2GoldTown.STREET_HALF,
		"%s %s" % [w.get_beat_name(), str(w.get_quad_node().position)])
	_check("the desert light took over from the woods' gold (thin fog)", w._env_node.environment.fog_density < 0.004, "%.4f" % w._env_node.environment.fog_density)
	_check("the corpses stay where they fell (no fade, no vanish)", corpse != null and is_instance_valid(corpse.actor) and corpse.actor.is_inside_tree()
		and Ep2BearKit.pose_name(corpse.actor) == "dead")
	_until(w, 25.0, func(): return said2.has("vo_lb_drop"))
	_check("Bull drops him off: the Blondie line, the certificate office + the bar, Lil Blunt answers - in order",
		said2.find("vo_bull_drop1") >= 0 and said2.find("vo_bull_drop1") < said2.find("vo_bull_drop2") and said2.find("vo_bull_drop2") < said2.find("vo_lb_drop"), str(said2))
	_check("Lil Blunt is OFF the quad, on his feet in the street, the rifle still in his hands", not w.is_riding() and w.is_fps() and wvm.rifle.visible
		and w.get_player_position().y < 0.2, str(w.get_player_position()))
	var qz0: Vector3 = w.get_quad_node().position
	_until(w, 30.0, func(): return w.is_bull_gone() or res2.size() == 1)
	_check("...and Bull RIDES OFF on the quad, up the street and away", w.is_bull_gone() and w.get_quad_node().position.distance_to(qz0) > 40.0,
		str(w.get_quad_node().position))
	_until(w, 5.0, func(): return res2.size() == 1)
	_check("the woods chain to the gold town (no TO BE CONTINUED here any more)", res2.size() == 1 and str(res2[0].get("next_chamber", "")) == "gold_town"
		and not bool(res2[0].get("end_session", false)), str(res2))
	_check("...and it mints nothing", res2.size() == 1 and int(res2[0].get("gold_awarded", -1)) == 0)
	w.queue_free()

	# ---------------------------------------------------------------- 3. stealth, awareness, the fight, failure + retry
	print("-- LIVING WOODS: senses, combat, checkpoint")
	var w2: WoodsQuadChamber = WOODS.instantiate()
	add_child(w2)
	var said3: Array = []
	w2.line_spoken.connect(func(id): said3.append(id))
	w2.setup(0, [], 0)
	await get_tree().process_frame
	var moss: Ep2BearBrain = w2.get_bear("Old Moss")
	var barn: Ep2BearBrain = w2.get_bear("Professor Barnaby")
	# walking past a sleeper is free; running past him wakes him
	w2._player_pos = moss.actor.position + Vector3(-6.5, 0.0, -6.0)
	w2._look_yaw = 0.0
	w2.set_move_input(Vector2(0.0, 1.0), false)
	_run(w2, 2.5)
	w2.set_move_input(Vector2.ZERO)
	_check("WALKING past Old Moss while he sleeps: he sleeps on", moss.is_unaware() and Ep2BearKit.pose_name(moss.actor) == "sleep" and w2.get_noise_hits() == 0,
		"%s %s" % [moss.awareness_name(), Ep2BearKit.pose_name(moss.actor)])
	w2._player_pos = moss.actor.position + Vector3(-4.0, 0.0, -5.0)
	w2._look_yaw = 0.0
	w2.set_move_input(Vector2(0.0, 1.0), true)
	_run(w2, 1.0)
	w2.set_move_input(Vector2.ZERO)
	_check("RUNNING past him is heard: he wakes (a ?), it is a noise hit and Inferno shushes", not moss.is_unaware() and w2.get_noise_hits() >= 1 and said3.has("vo_bull_woods_quiet"),
		"%s hits %d" % [moss.awareness_name(), w2.get_noise_hits()])
	_run(w2, 2.6)
	_check("...and he gets up off the ground to come and look (the fall played backward, then a walk)", Ep2BearKit.pose_name(moss.actor) != "sleep",
		Ep2BearKit.pose_name(moss.actor))
	# standing in front of the reader: he looks up from his magazine, SEES him, roars and charges; Inferno opens fire
	w2._player_pos = Vector3(-1e3, 0.0, -1e3)
	_run(w2, 0.2)
	var bf := Vector3(sin(barn.actor.facing), 0.0, cos(barn.actor.facing))
	w2._player_pos = barn.actor.position + bf * 5.0
	w2._look_yaw = atan2(-bf.x, -bf.z)
	w2.get_bull().position = w2._player_pos + Vector3(2.0, 0.0, 1.5)
	var hp0: int = w2.get_health()
	_until(w2, 14.0, func(): return barn.is_alert())
	_check("Professor Barnaby, nose in his magazine, still SEES him when he stands right in front (sight meter fills, '!')",
		barn.is_alert() and w2.get_alert_count() >= 1, barn.awareness_name())
	_until(w2, 10.0, func(): return w2.get_health() < hp0 or barn.is_dead())
	_check("...he roars and charges: a claw swipe costs a heart, or Inferno drops him first",
		w2.get_health() < hp0 or barn.is_dead(), "hp %d dead %s bull shots %d" % [w2.get_health(), barn.is_dead(), w2.get_bull_shots()])
	_check("Inferno shouts and defends him (he fires on the bear, no arm IK)", said3.has("vo_bull_spotted") and w2.get_bull_shots() >= 1
		and w2.get_bull().reach_weight("Left") < 0.01 and w2.get_bull().reach_weight("Right") < 0.01, "shots %d" % w2.get_bull_shots())
	var tries: int = 0
	while not barn.is_dead() and tries < 60 * 20:
		tries += 1
		var e3: Vector3 = w2.get_player_position() + Vector3(0.0, w2.eye_height, 0.0)
		var a3: Vector3 = barn.actor.position + Vector3(0.0, 1.2, 0.0) - e3
		w2._look_yaw = atan2(a3.x, a3.z)
		w2._look_pitch = atan2(a3.y, Vector2(a3.x, a3.z).length())
		w2.set_aim(true)
		if w2.get_viewmodel().gun.ads > 0.95:
			w2.shoot()
		if w2.get_ammo() == 0:
			w2.reload()
		w2._invuln = 1.0                      # keep the test player standing while he shoots it out
		w2.step(1.0 / 60.0)
	w2.set_aim(false)
	_check("a shot bear goes down", barn.is_dead(), barn.awareness_name())
	var fell_at: Vector3 = barn.actor.position
	_run(w2, 5.0)
	_check("...and his body stays where he fell (dead pose, still there 5 s later)", is_instance_valid(barn.actor) and barn.actor.is_inside_tree()
		and barn.actor.position.distance_to(fell_at) < 0.1 and Ep2BearKit.pose_name(barn.actor) == "dead")
	# an archer: in her sector she sees him, draws (the warning) and looses a real arrow
	var hat: Ep2BearBrain = w2.get_bear("Hattie")
	# a spot in her sector with a clear line of sight (the old growth hides most of the wood from her)
	var spot: Vector3 = hat.actor.position
	for dist in [14.0, 17.0, 11.0, 20.0, 9.0]:
		for da in [0.0, 0.2, -0.2, 0.4, -0.4]:
			var yaw_c: float = float(hat.p["face"]) + float(da)
			var c3: Vector3 = hat.actor.position + Vector3(sin(yaw_c), 0.0, cos(yaw_c)) * float(dist)
			if spot == hat.actor.position and not w2._los_blocked(Vector2(hat.actor.position.x, hat.actor.position.z), Vector2(c3.x, c3.z)):
				spot = c3
	w2._player_pos = spot
	w2._invuln = 0.0
	var arrows0: int = w2.get_arrows_loosed()
	_until(w2, 14.0, func(): return w2.get_arrows_loosed() > arrows0)
	_check("Hattie spots him in her sector, draws and looses an ARROW (a real projectile in the air)", w2.get_arrows_loosed() > arrows0
		and w2._arrows.size() >= 1, "%d arrows, %s" % [w2.get_arrows_loosed(), hat.awareness_name()])
	# out of hearts -> the checkpoint at the mine exit; everything comes back together
	w2._invuln = 0.0
	w2._health = 1
	w2._hurt("claw")
	_check("the last heart ends the attempt: input stops, the screen goes down", w2.is_failing() and not w2.has_player_control())
	_run(w2, 1.2)
	_run(w2, 0.6)
	var barn2: Ep2BearBrain = w2.get_bear("Professor Barnaby")
	_check("RETRY from the mine exit: Lil Blunt at the door with 3 hearts, the beat back to SNEAK, Inferno's retry line",
		w2.get_attempt() == 1 and w2.get_health() == 3 and w2.get_beat_name() == "SNEAK" and w2.get_player_position().distance_to(WoodsQuadChamber.SPAWN) < 0.5
		and said3.has("vo_bull_retry") and w2.has_player_control(), "attempt %d hp %d %s" % [w2.get_attempt(), w2.get_health(), w2.get_beat_name()])
	_check("...and the wood is restored with him: Barnaby alive and reading again, the quad back under its leaves, a full tube",
		barn2 != null and not barn2.is_dead() and Ep2BearKit.pose_name(barn2.actor) == "sit_read" and w2.is_quad_hidden() and w2.get_ammo() == Ep2Winchester.MAG
		and w2.get_live_bear_count() == w2.get_bears().size())
	_run(w2, 1.0)
	_check("the screen comes back up at the mine exit", w2.get_hud().fade < 0.5, "%.2f" % w2.get_hud().fade)
	w2.queue_free()

	# ---------------------------------------------------------------- 4. the session chain
	print("-- SESSION CHAIN")
	var root: Ep2SessionRoot = ROOT.instantiate()
	add_child(root)
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	var commits: Array = []
	root.chamber_committed.connect(func(i, r): commits.append(r))
	var done: Array = []
	root.session_complete.connect(func(): done.append(true))
	# the hideout hands over with next_chamber = mine_lift; drive the root exactly as the facility would
	root._chamber_segment = 0
	root._on_chamber_cleared({"story": true, "chamber": "smelting_facility", "gold_awarded": 0, "gold_forfeited": 0, "btc_paid": 1, "next_chamber": "mine_lift"})
	await get_tree().process_frame
	_check("the hideout's result loads the MINE LIFT (no runner leg in between)", root.get_mode() == Ep2SessionRoot.Mode.CHAMBER and root.get_active() is MineLiftChamber)
	_check("a story chamber's result is committed once", commits.size() == 1)
	# ---- the HIDEOUT -> LIFT cut: the lift is built behind the range lesson / lava river and the exit door holds until it is ready
	var hf: SmeltingFacilityChamber = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	hf.intro_film = false
	var root2: Ep2SessionRoot = ROOT.instantiate()
	add_child(root2)
	root2.add_child(hf)
	root2._active = hf
	root2._wire_chamber(hf)
	hf.setup(0, [], 0)
	hf.set_physics_process(false)
	await get_tree().process_frame
	hf._on_video_film_finished()
	hf.prebuild_requested.emit("mine_lift")
	_check("the hideout's range lesson starts building the LIFT in the background (off-screen)", root2._pb_node is MineLiftChamber and root2._pb_node.get_parent() is SubViewport)
	hf._beat = SmeltingFacilityChamber.Beat.EXIT
	hf._show_active = false
	hf._hold = 0.0
	hf._player_pos = SmeltingFacilityChamber.EXIT_POSITION
	var hf_resolved: Array = []
	hf.chamber_cleared.connect(func(r): hf_resolved.append(r))
	hf.step(0.016)
	_check("at the exit door the hideout WAITS for the lift to be built (a pause at worst, never a blackout)", hf_resolved.is_empty() and hf.is_waiting_for_handoff())
	hf._look_yaw = 0.3
	root2.step(0.016)      # (the root is idle in this test: it finishes the background build, the hideout steps itself)
	hf.step(0.016)
	_check("...the moment it is built the door opens: the hideout resolves toward the lift", hf_resolved.size() == 1 and str(hf_resolved[0].get("next_chamber", "")) == "mine_lift")
	root2.queue_free()

	# ---- THE OPEN DOOR (founder 2026-10-24: "no transition at that point ... the door should be open and we should be able to see the
	# elevator from within the smelting facility"): the doorway shows the built lift room, he walks through, the cut lands him there.
	var hp: SmeltingFacilityChamber = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	hp.intro_film = false
	var root3: Ep2SessionRoot = ROOT.instantiate()
	add_child(root3)
	root3.add_child(hp)
	root3._active = hp
	root3._wire_chamber(hp)
	hp.setup(0, [], 0)
	hp.set_physics_process(false)
	await get_tree().process_frame
	hp._on_video_film_finished()
	hp.prebuild_requested.emit("mine_lift")
	root3.step(0.016)                                   # the lift finishes building behind the hideout
	var pl: MineLiftChamber = root3._pb_node as MineLiftChamber
	hp._beat = SmeltingFacilityChamber.Beat.EXIT
	hp._show_active = false
	hp._hold = 0.0
	hp._player_pos = Vector3(0.0, 0.0, SmeltingFacilityChamber.EXIT_POSITION.z - 2.0)
	var cam: Camera3D = hp._camera
	_check("the hideout has its camera in the tree for the doorway view", cam != null and cam.is_inside_tree())
	if cam != null:
		cam.global_transform = Transform3D(Basis(), Vector3(0.0, 1.6, SmeltingFacilityChamber.EXIT_POSITION.z - 2.0)).looking_at(Vector3(0.0, 1.8, SmeltingFacilityChamber.PORTAL_Z), Vector3.UP)
	root3._drive_portal()
	_check("facing the open door, the doorway shows the built lift room", hp._portal_live and hp._portal_quad != null and hp._portal_quad.visible and root3._portal_on)
	_check("...rendered at screen size from a camera mirroring his, 30 m down the lift's z",
		root3._pb_vp.size == Vector2i(root3.get_viewport().get_visible_rect().size)
			and pl.get_camera().global_position.distance_to(cam.global_position + SmeltingFacilityChamber.LIFT_OFFSET) < 0.01)
	_check("...with the lift's tunnel plug and back wall out of the way (they stand between that camera and the cavern)",
		pl._mouth_open and not pl._mouth_plug.visible and not pl._mouth_wall.visible)
	_check("...and no second Inferno in it while the real one is still in the hideout", not pl._bull.visible)
	hp._bull.position = Vector3(0.7, 0.0, SmeltingFacilityChamber.PORTAL_Z + 1.5)
	root3._drive_portal()
	_check("Inferno through the doorway ahead of him is drawn on the lift side, where he stands", pl._bull.visible
		and pl._bull.position.distance_to(hp._bull.position + SmeltingFacilityChamber.LIFT_OFFSET) < 0.01)
	_check("the floor runs on through the open door while the doorway shows the lift",
		hp._collide(Vector3(0.0, 0.0, SmeltingFacilityChamber.PORTAL_Z + 0.2)).z > SmeltingFacilityChamber.EXIT_POSITION.z + 1.0)
	var hp_res: Array = []
	hp.chamber_cleared.connect(func(r): hp_res.append(r))
	hp._player_pos = Vector3(0.3, 0.0, SmeltingFacilityChamber.PORTAL_Z - 0.05)
	hp.step(0.016)
	_check("a step short of the doorway is still the hideout (no early cut)", hp_res.is_empty())
	hp._player_pos = Vector3(0.3, 0.0, SmeltingFacilityChamber.PORTAL_Z + 0.02)
	var hand: Dictionary = hp.get_handoff()
	hp.step(0.016)
	_check("through the doorway the hideout hands over to the lift", hp_res.size() == 1 and str(hp_res[0].get("next_chamber", "")) == "mine_lift")
	_check("...carrying where he stands and where Inferno stands, in the lift's frame",
		hand.has("lift_player") and absf((hand["lift_player"] as Vector3).z - (MineLiftChamber.PORTAL_Z + 0.02)) < 0.01 and hand.has("lift_bull"))
	root3._chain_id = "mine_lift"
	root3._enter_chamber_chained(0)
	var la: MineLiftChamber = root3.get_active() as MineLiftChamber
	_check("the SAME lift room that was in the doorway is now the room he is in", la == pl and la.handoff_seamless)
	_check("...and he is at its mouth where the doorway showed him, not 2.6 m on at the old start point",
		absf(la.get_player_position().z - (MineLiftChamber.PORTAL_Z + 0.02)) < 0.05 and absf(la.get_player_position().x - 0.3) < 0.01,
		str(la.get_player_position()))
	_check("...with Inferno still ahead of him on the bridge", la._bull.visible and la._bull.position.z > la.get_player_position().z)
	root3.queue_free()

	# ---- NO BLACKOUTS (founder 2026-10-11): the wood is built BEHIND the lift, in an off-screen viewport, and the hand-over is one cut
	var lift_node: MineLiftChamber = root.get_active()
	_check("entering the lift starts building the WOODS in the background (hosted off-screen, the lift stays the active chamber)",
		root._pb_node is WoodsQuadChamber and root._pb_node.get_parent() is SubViewport and root.get_active() == lift_node)
	_check("...and the lift holds its exit until the wood is built (no freeze at the surface)", not root.is_prebuilt("woods_quad") and not lift_node._handoff_ok())
	root.step(0.016)
	_check("the background build completes (the deterministic step finishes it)", root.is_prebuilt("woods_quad") and lift_node._handoff_ok())
	lift_node._look_yaw = 0.5
	lift_node._look_pitch = 0.1
	var woods_node: Node = root._pb_node
	root._on_chamber_cleared({"story": true, "chamber": "mine_lift", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "woods_quad"})
	_check("the hand-over is the SAME instance that was built behind the lift, in the main tree, its camera current",
		root.get_active() == woods_node and woods_node.get_parent() == root and (woods_node as Ep2Interlude).get_camera().current)
	_check("the visited lift is retained in an isolated disabled world, with no camera/sky/light leaking into the wood", lift_node.get_viewport()!=root.get_viewport() and lift_node.process_mode==Node.PROCESS_MODE_DISABLED and root.world_routes.rooms.has("mine_lift"))
	_check("one motion: the gaze carries over (yaw 0.5, pitch 0.1) and no title card is shown",
		absf((woods_node as Ep2Interlude).get_look_yaw() - 0.5) < 0.01 and (woods_node as Ep2Interlude).handoff_seamless)
	await get_tree().process_frame
	_check("the lift chains to the WOODS", root.get_active() is WoodsQuadChamber and commits.size() == 2)
	var swallowed: int = commits.size()
	root._on_chamber_cleared({"story": true, "chamber": "woods_quad", "gold_awarded": 0, "gold_forfeited": 0, "end_session": true, "to_be_continued": true})
	_check("the woods end the session (TO BE CONTINUED)", done.size() == 1 and commits.size() == swallowed + 1 and root.get_mode() == Ep2SessionRoot.Mode.IDLE)
	root.queue_free()

	# ---------------------------------------------------------------- 5. the founder's songs and the new lines
	print("-- SONGS + LINES")
	_check("Inferno Bull 2 is in the build and wired to the lift", ResourceLoader.exists(MineLiftChamber.MUSIC))
	_check("Deep Mining 3 is in the build and wired to the quad", ResourceLoader.exists(WoodsQuadChamber.MUSIC))
	for sid in ["ep2_lava_burn", "ep2_lift_start", "ep2_lift_loop", "ep2_lift_arrive", "ep2_quad_start", "ep2_quad_loop", "ep2_leaves_pull"]:
		_check("sfx %s exists" % sid, ResourceLoader.exists("res://src/assets/sounds/%s.mp3" % sid))
	var all_ok: bool = true
	var natural: bool = true
	var clean: bool = true
	var ids: Array = ["vo_bull_woods_shot", "vo_bull_lava1", "vo_bull_lava2", "vo_bull_lava_nudge", "vo_bull_lava_made_it", "vo_bull_lift1", "vo_bull_lift_lever", "vo_bull_plan1",
		"vo_bull_plan2", "vo_bull_plan3", "vo_lb_plan_reply", "vo_bull_lift_arrive", "vo_bull_woods_sneak", "vo_bull_woods_quiet", "vo_bull_quad_reveal",
		"vo_lb_quad_ok", "vo_bull_quad_mount"]
	for id in ids:
		if not ResourceLoader.exists("res://src/assets/sounds/voice/%s.mp3" % id) or _manifest_text(id) == "":
			all_ok = false
		if id.begins_with("vo_bull") and _manifest_speed(id) < 1.0:
			natural = false
		if "iamond" in _manifest_text(id):
			clean = false
	_check("all %d new voice lines are generated and in the manifest" % ids.size(), all_ok)
	_check("Inferno speaks at a natural pace (speed >= 1.0) on every new line", natural)
	_check("no Diamonds mechanic is stapled into the interlude speech", clean)
	var plan_text: String = _manifest_text("vo_bull_plan1") + _manifest_text("vo_bull_plan2") + _manifest_text("vo_bull_plan3")
	_check("the plan is the founder's: sneak through the wood, the quad (I drive, you shoot), spy on the bears",
		"sneak" in plan_text and "quad" in plan_text and "drive" in plan_text and "shoot" in plan_text and "spy" in plan_text, plan_text)
	_check("the lava warning says it burns and tells him to hop", "cooks" in _manifest_text("vo_bull_lava1") and "Hop" in _manifest_text("vo_bull_lava2"))

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_INTERLUDE: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_INTERLUDE: %d FAILED" % _fail)
		get_tree().quit(1)
