extends Node3D
## New Shit 1122 Part 3 gate (2026-11-24): the SFX bank + AudioManager.sfx_at (P3-A), breakable town glass (P3-B),
## pickup/cover sounds (P3-D) and the townsfolk's startle + screams (P3-E). Winchester bandits (P3-C) live in their own suites.
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_newshit_p3_test.tscn

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")

var _fail: int = 0
var _checks: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("EP2_NEWSHIT_P3:")
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		print("  [FAIL] AudioManager autoload missing")
		get_tree().quit(1)
		return
	await _sfx_bank(am)
	await _glass(am)
	await _crowd(am)
	await _pickup_cover(am)
	await _rifle_bandits(am)
	print("EP2_NEWSHIT_P3: %d checks, %d failed" % [_checks, _fail])
	if _fail == 0:
		print("EP2_NEWSHIT_P3: ALL PASS")
	get_tree().quit(0 if _fail == 0 else 1)

## P3-A: every bank id resolves to a short stream; sfx_at plays on SFX only, pools its voices and stays cheap.
func _sfx_bank(am: Node) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for id: StringName in am.SFX_BANK:
		var s: AudioStream = am.sfx_stream(id)
		_check("bank %s resolves" % id, s != null, am.sfx_path(id))
		if s != null:
			_check("bank %s <= 1.5 s" % id, s.get_length() <= 1.5, "(%.2f s)" % s.get_length())
	_check("unknown id is a silent no-op", am.sfx_at(&"no_such_sound_p3", Vector3.ZERO, self) == null)
	var music_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var t0: int = Time.get_ticks_usec()
	var voices: Array = []
	for i in 14:
		voices.append(am.sfx_at(am.SFX_BANK[i % am.SFX_BANK.size()], Vector3(i, 1, -3), self))
	var per_call_ms: float = float(Time.get_ticks_usec() - t0) / 14000.0
	_check("sfx_at returns a voice", voices[0] is AudioStreamPlayer3D)
	var on_sfx := true
	for v in voices:
		on_sfx = on_sfx and v != null and (v as AudioStreamPlayer3D).bus == &"SFX"
	_check("every voice is on the SFX bus (never Music)", on_sfx)
	var pool: Node = (voices[0] as Node).get_parent()
	_check("voices pooled per viewport (<= %d)" % am.SFX_POOL_VOICES, pool.get_child_count() <= am.SFX_POOL_VOICES,
		"(%d)" % pool.get_child_count())
	_check("voice sits where asked", (voices[13] as Node3D).global_position.is_equal_approx(Vector3(13, 1, -3)))
	_check("sfx_at stays cheap (%.2f ms/call)" % per_call_ms, per_call_ms < 4.0)
	_check("Music bus untouched", is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), music_db))
	_check("sfx_log records ids", am.sfx_log.size() > 0 and am.sfx_log[-1] == am.SFX_BANK[13 % am.SFX_BANK.size()])
	var d: AudioStreamPlayer3D = am.sfx_at(&"glass_crack", Vector3.ZERO, self, 0.0, 0.2)
	_check("delayed voice waits", d != null and not d.playing)
	await get_tree().create_timer(0.3).timeout
	_check("delayed voice plays after its delay", d != null and d.playing)
	cam.queue_free()


func _town() -> GoldTownChamber:
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.step(1.0 / 60.0)
	return c


func _glass_ids(am: Node) -> int:
	var n: int = 0
	for id in am.sfx_log:
		n += 1 if String(id).begins_with("glass_break") else 0
	return n


## P3-B: the kit's real panes are the law's windows; a shot pane breaks once (hole, rim, shards, one sound), the second round
## passes through; another man's round breaks glass without billing Lil Blunt; the look survives a rebuild; no kit = old openings.
func _glass(am: Node) -> void:
	var c: GoldTownChamber = _town()
	var law: Ep2TownLaw = c.get_town_law()
	_check("town law has a glass node", law != null and law.glass != null)
	if law == null or law.glass == null:
		return
	var piece: String = "Bldg_Saloon"
	var n: int = law.window_count(piece)
	_check("the saloon's windows are its real panes (> 2)", n > 2, "(%d)" % n)
	var total: int = 0
	for p in ["Bldg_Certificates", "Bldg_A", "Bldg_B", "Bldg_C", "Bldg_D", "Bldg_E", "Bldg_F", "Bldg_Armory"]:
		total += law.window_count(p)
	_check("street fronts carry real panes (%d)" % total, total >= 16)
	_check("glass material is transparent", Ep2TownGlass.glass_material().transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
		and Ep2TownGlass.glass_material().albedo_color.a < 0.4)
	var normal: Vector3 = law.front_normal(piece)
	var target: Vector3 = law.window_target(piece, 0)
	var before: int = _glass_ids(am)
	law.player_shot(target + normal * 5.0, -normal)
	_check("a shot pane breaks", law.broken_windows == 1 and law.glass.breaks == 1, str(law.last_shot.get("kind", "")))
	_check("one glass_break sound plays", _glass_ids(am) == before + 1, str(am.sfx_log.slice(-3)))
	_check("the pane leaves a jagged hole + cracked rim", law.glass.find_children("BrokenPane_*", "", true, false).size() >= 0
		and c.find_children("BrokenPane_*", "MeshInstance3D", true, false).size() == 1)
	_check("the building's glass is now a copy without that pane", c.find_children("TownGlassCopy", "MeshInstance3D", true, false).size() == 1)
	_check("shards fly", law.glass.moving_shards() == Ep2TownGlass.SHARDS_PER_BREAK)
	for i in 150:
		c.step(1.0 / 60.0)
	_check("shards come to rest on the ground", law.glass.moving_shards() == 0)
	law.player_shot(target + normal * 5.0, -normal)
	_check("the second round passes through (no second break, no second sound)", law.broken_windows == 1
		and _glass_ids(am) == before + 1)
	var fine_before: bool = law.pending_fine()
	var other: Vector3 = law.window_target(piece, 1)
	var hit: bool = law.stray_round(other + normal * 6.0, -normal, 10.0)
	_check("a stranger's round breaks glass too", hit and law.broken_windows == 2)
	_check("...and Lil Blunt is not billed for it", law.pending_fine() == fine_before)
	_check("a broken pane is remembered for the play session", Ep2TownGlass.BROKEN.size() == 2)
	c.queue_free()
	await get_tree().process_frame
	var c2: GoldTownChamber = _town()
	var law2: Ep2TownLaw = c2.get_town_law()
	_check("after a rebuild the same panes are still broken", law2.window_count(piece) == n
		and c2.find_children("BrokenPane_*", "MeshInstance3D", true, false).size() == 2)
	c2.queue_free()
	var bare := Ep2TownGlass.new()
	add_child(bare)
	_check("no kit glass: register finds nothing (law keeps its two authored openings)", bare.register("x@0,0", Node3D.new(), Transform3D.IDENTITY).is_empty())
	bare.queue_free()
	Ep2TownGlass.BROKEN.clear()
	await get_tree().process_frame


## P3-E: a shot startles everyone in earshot (rooted + flinch, then flee); the women scream; <= 3 voices; 6 s per person; the glass
## break alarms the street; outside the radius nobody reacts; the duel still holds the crowd.
func _crowd(am: Node) -> void:
	var c: GoldTownChamber = _town()
	var tp: Ep2TownPeople = c.get_people()
	var law: Ep2TownLaw = c.get_town_law()
	var woman: Ep2TownPeople.Person = null
	for p in tp.people:
		if Ep2TownPeople.sex_of(p.id) == "f" and p.state not in Ep2TownPeople.SHOP_STATES and not p.folk.dead:
			woman = p
			break
	_check("a woman is out in the street", woman != null)
	if woman == null:
		c.queue_free()
		return
	var where: Vector3 = woman.folk.position + Vector3(1.5, 0, 0)
	var log0: int = tp.voice_log.size()
	tp.notify_danger(where, 24.0, "shot")
	var voices: Array = tp.voice_log.slice(log0)
	_check("a close shot raises 1..3 voices", voices.size() >= 1 and voices.size() <= 3, str(voices))
	var ids: Array = voices.map(func(v: Dictionary) -> String: return str(v["id"]))
	var unique := {}
	for x in ids: unique[x] = true
	_check("no take is played twice in one bang", unique.size() == ids.size(), str(ids))
	_check("a woman in range screams", voices.any(func(v: Dictionary) -> bool: return str(v["id"]).begins_with("scream_f")), str(voices))
	var startled: int = 0
	var outside_ok := true
	for p in tp.people:
		var d: float = Vector2(p.folk.position.x - where.x, p.folk.position.z - where.z).length()
		var s: bool = tp._startle_left.has(p.id)
		if d <= 18.0 and s: startled += 1
		if d > 18.0 and s: outside_ok = false
	_check("people within 18 m are startled (%d)" % startled, startled >= 1)
	_check("people outside 18 m do not react", outside_ok)
	var delays_ok: bool = voices.all(func(v: Dictionary) -> bool: return float(v["delay"]) >= 0.2 and float(v["delay"]) <= 0.75)
	_check("voices come 0.2-0.75 s after the bang (startle + offset)", delays_ok, str(voices))
	tp.notify_danger(where, 24.0, "glass")
	_check("one tick is one event: still <= 3 voices", tp.voice_log.size() - log0 <= 3, str(tp.voice_log.slice(log0)))
	var start: Vector3 = woman.folk.position
	for i in 18:
		c.step(1.0 / 60.0)
	_check("+0.3 s: the woman is rooted, flinching", woman.folk.position.distance_to(start) < 0.08 and woman.folk.startle_amount() > 0.0,
		"moved %.3f flinch %.2f" % [woman.folk.position.distance_to(start), woman.folk.startle_amount()])
	for i in 72:
		c.step(1.0 / 60.0)
	_check("+1.5 s: she is running for cover", woman.state in ["flee", "shelter"] and woman.folk.position.distance_to(start) > 0.3,
		"%s moved %.2f" % [woman.state, woman.folk.position.distance_to(start)])
	var log1: int = tp.voice_log.size()
	tp.notify_danger(where, 24.0, "shot")
	var again: Array = tp.voice_log.slice(log1).map(func(v: Dictionary) -> String: return str(v["who"]))
	var twice := false
	for v in voices:
		twice = twice or str(v["who"]) in again
	_check("nobody screams twice inside 6 s", not twice, str(again))
	# the broken window alarms the street (P3-E's one line in Ep2TownLaw._hit_window)
	var piece := "Bldg_Certificates"
	var normal: Vector3 = law.front_normal(piece)
	var target: Vector3 = law.window_target(piece, 0)
	for i in 420:
		c.step(1.0 / 60.0)                                 # past the cooldown
	woman.folk.position = Vector3(target.x, 0, target.z) + normal * 3.0 + normal.cross(Vector3.UP).normalized() * 2.5   # beside the line of fire
	var log2: int = tp.voice_log.size()
	law.player_shot(target + normal * 5.0, -normal)
	_check("a broken window calls notify_danger(glass)", tp.voice_log.slice(log2).any(func(v: Dictionary) -> bool: return v["kind"] == "glass"),
		str(tp.voice_log.slice(log2)))
	var miners: Node = c.get("_miners")
	if miners != null and miners.get("miners") != null and not (miners.get("miners") as Array).is_empty():
		var m0: Node3D = (miners.get("miners") as Array)[0].folk
		miners.notify_danger(m0.position + Vector3(2, 0, 0))
		_check("a miner shouts at a shot nearby", str(miners.get("last_shout")).begins_with("shout_m"), str(miners.get("last_shout")))
	tp.set_context("duel")
	var log3: int = tp.voice_log.size()
	tp._startle_left.clear()
	tp.notify_danger(where, 24.0, "shot")
	_check("the duel still holds the crowd: no startle, no screams", tp.voice_log.size() == log3 and tp._startle_left.is_empty())
	c.queue_free()
	await get_tree().process_frame


func _count(am: Node, id: StringName, from: int) -> int:
	var n: int = 0
	for x in am.sfx_log.slice(from):
		n += 1 if x == id else 0
	return n


## P3-D: a new gun is lifted (gun_pickup), the same gun again is ammo (ammo_pickup); cover in/out and a reload in cover each fire their
## sound exactly once.
func _pickup_cover(am: Node) -> void:
	var a := Ep2ArmoryState.new()
	var bor: String = Ep2ArmoryState.BORCH
	var holder := Node3D.new()
	add_child(holder)
	var d1: Ep2WeaponDrop = Ep2WeaponDrop.place(holder, a, "p3:1", bor, 8, Vector3(1, 0, 1), 0.0)
	var n0: int = am.sfx_log.size()
	d1.take(a)
	_check("a dead man's new gun plays gun_pickup once", _count(am, &"gun_pickup", n0) == 1 and _count(am, &"ammo_pickup", n0) == 0)
	var d2: Ep2WeaponDrop = Ep2WeaponDrop.place(holder, a, "p3:2", bor, 6, Vector3(2, 0, 1), 0.0)
	var n1: int = am.sfx_log.size()
	d2.take(a)
	_check("the same gun again is ammo: ammo_pickup once", _count(am, &"ammo_pickup", n1) == 1 and _count(am, &"gun_pickup", n1) == 0)
	holder.queue_free()
	var RIVER: PackedScene = load("res://src/episode2/chamber/river_cover.tscn")
	var r: Node = RIVER.instantiate()
	add_child(r)
	await get_tree().process_frame
	var n2: int = am.sfx_log.size()
	r.call("_set_cover", true)
	r.call("_set_cover", true)
	_check("taking cover plays cover_enter once", _count(am, &"cover_enter", n2) == 1)
	var n3: int = am.sfx_log.size()
	var reloaded: bool = r.reload()
	_check("a reload in cover plays rifle_reload_close exactly when it reloads",
		_count(am, &"rifle_reload_close", n3) == (1 if reloaded else 0), "reloaded=%s" % reloaded)
	var n4: int = am.sfx_log.size()
	r.call("_set_cover", false)
	r.call("_set_cover", false)
	_check("rising from cover plays cover_exit once", _count(am, &"cover_exit", n4) == 1 and _count(am, &"cover_enter", n4) == 0)
	var n5: int = am.sfx_log.size()
	r.reload()
	_check("a reload out of cover is not the close cover sound", _count(am, &"rifle_reload_close", n5) == 0)
	r.queue_free()
	await get_tree().process_frame


## P3-C: the trail's Winchester men are the two-handed Hammer rifleman; the flash leaves his rifle's muzzle; killed, his own rifle (split
## out of his hands) lies with his rounds: owning the 1886 it is ammo, without it it is the gun; pistol men are unchanged; the record
## survives a save; the ridge has its watchers and they drop the same way.
func _rifle_bandits(am: Node) -> void:
	var TRAIL: PackedScene = load("res://src/episode2/chamber/lake_trail.tscn")
	var c: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(c)
	c.set_physics_process(false)
	c.setup(0, [], 0)
	c.debug_invulnerable = true
	var rifles: Array = []
	var pistols: int = 0
	for i in c._bandits.size():
		var b: Dictionary = c._bandits[i]
		if str(b.get("gun_id", "")) == Ep2ArmoryState.WIN: rifles.append(i)
		elif not bool(b["rider"]): pistols += 1
	_check("the trail mixes Winchester men and pistol men (%d + %d)" % [rifles.size(), pistols], rifles.size() >= 4 and pistols >= 8)
	_check("crew total unchanged (18 ambushers + the rider)", c._bandits.size() == 19)
	if rifles.size() < 2:
		c.queue_free()
		return
	var i0: int = rifles[0]
	var b0: Dictionary = c._bandits[i0]
	var f0: Ep2TownFolk = b0["folk"]
	var meshes: Array = f0.model.find_children("*", "MeshInstance3D", true, false).map(func(n: Node) -> String: return String(n.name))
	_check("a Winchester man is the two-handed Hammer rifleman (Idle + Draw)", "Idle" in meshes and "Draw" in meshes, str(meshes))
	c._fire_bandit(i0)
	var chest: Vector3 = c._bandit_world_position(b0) + Vector3(0, 1.25, 0)
	var muzzle: Vector3 = b0.get("muzzle", chest)
	var want: Vector3 = f0.global_transform * Ep2HammerLoadout.muzzle_local(float(b0["height"]))
	_check("the flash leaves the rifle's muzzle, not his chest", muzzle.distance_to(want) < 0.01 and muzzle.distance_to(chest) > 0.3,
		"muzzle %s chest %s" % [muzzle, chest])
	# owning the Winchester (his default rifle): the dead man's 1886 is ammo
	if not c.armory.owns(Ep2ArmoryState.WIN):
		c.armory.owned[Ep2ArmoryState.WIN] = true
	var before: int = c.armory.firearm(Ep2ArmoryState.WIN).reserve
	c._drop_bandit(i0)
	var d0: Ep2WeaponDrop = c._drops_root.get_node_or_null("Drop_trail_%d" % i0) as Ep2WeaponDrop
	_check("his rifle lies by him", d0 != null and d0.gun_id == Ep2ArmoryState.WIN)
	if d0 != null:
		var gun: MeshInstance3D = d0.get_node_or_null("HammerWinchester") as MeshInstance3D
		_check("it is HIS rifle, lifted out of his hands (not a stand-in)", gun != null and gun.mesh != null and gun.mesh.get_surface_count() > 0)
		if gun != null and gun.mesh != null:
			var box: AABB = gun.mesh.get_aabb()
			var length: float = box.size.z * gun.scale.z
			_check("the whole 1886 came away (%.2f m long, %.3f m wide)" % [length, box.size.x * gun.scale.x], length > 0.85 and length < 1.35,
				str(box))
		var body_tris: int = 0
		for n in f0.model.find_children("Idle", "MeshInstance3D", true, false):
			var m: Mesh = (n as MeshInstance3D).mesh
			for k in m.get_surface_count():
				body_tris += (m.surface_get_arrays(k)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		_check("his body keeps everything but the rifle", body_tris > 8000 and body_tris < 9999, "%d" % body_tris)
		_check("prompt says rounds when he owns the gun", d0.prompt().contains("rounds"), d0.prompt())
		d0.take(c.armory)
		_check("owning the 1886: the reserve rises by his 6 rounds", c.armory.firearm(Ep2ArmoryState.WIN).reserve == mini(before + 6, Ep2ArmoryState.RESERVE_CAP),
			"%d -> %d" % [before, c.armory.firearm(Ep2ArmoryState.WIN).reserve])
	# without the Winchester: the next rifleman's gun is picked up as the gun
	var i1: int = rifles[1]
	c.armory.owned.erase(Ep2ArmoryState.WIN)
	c._drop_bandit(i1)
	var d1: Ep2WeaponDrop = c._drops_root.get_node_or_null("Drop_trail_%d" % i1) as Ep2WeaponDrop
	var got: Dictionary = d1.take(c.armory) if d1 != null else {}
	_check("without it, the 1886 is picked up as the gun", c.armory.owns(Ep2ArmoryState.WIN) and bool(got.get("new", false)), str(got))
	var copy := Ep2ArmoryState.new()
	copy.restore(JSON.parse_string(JSON.stringify(c.armory.snapshot())))
	_check("the dead riflemen's records survive a save", copy.corpses.has("trail:%d" % i0) and str(copy.corpses["trail:%d" % i0]["gun"]) == Ep2ArmoryState.WIN)
	c.queue_free()
	await get_tree().process_frame
	var RIVER: PackedScene = load("res://src/episode2/chamber/river_cover.tscn")
	var r: RiverCoverChamber = RIVER.instantiate() as RiverCoverChamber
	add_child(r)
	r.setup(0, [], 0)
	var watchers: Array = r.get_watchers()
	_check("the ridge has Hammer's Winchester watchers", watchers.size() == RiverCoverChamber.WATCH_POSTS.size()
		and watchers.all(func(w: Dictionary) -> bool: return str(w["gun"]) == Ep2ArmoryState.WIN))
	if not watchers.is_empty():
		var w: Dictionary = watchers[0]
		var wf: Ep2TownFolk = w["folk"]
		var on_path: bool = (r.ridge_nearest(wf.global_position)[0] as Vector3).distance_to(wf.global_position) < RiverCoverChamber.RIDGE_HALF + 0.2
		_check("a watcher stands at his lookout on the path's river side", on_path)
		var river: Vector3 = w["river"]
		_check("...facing the river (watching the shipment)", Vector3(sin(wf.facing), 0, cos(wf.facing)).dot(river) > 0.7)
		var btc_before: float = GameManager.purse_btc_balance()
		r.damage_watcher(w, true)
		r.damage_watcher(w, true)
		var paid_once: bool = GameManager.purse_btc_balance() == btc_before + 0.25
		if watchers.size() > 1:
			r.damage_watcher(watchers[1])
		var unattributed_death_was_unpaid: bool = watchers.size() > 1 and GameManager.purse_btc_balance() == btc_before + 0.25
		var wd: Ep2WeaponDrop = r._drops_root.get_node_or_null("Drop_ridge_0") as Ep2WeaponDrop
		_check("the watcher drops his rifle, only the player kill pays, and it pays once",
			wd != null and wd.get_node_or_null("HammerWinchester") != null and paid_once and unattributed_death_was_unpaid)
	r.queue_free()
	await get_tree().process_frame
