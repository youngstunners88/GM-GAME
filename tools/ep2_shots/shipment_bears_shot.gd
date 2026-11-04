extends Node
## Before/after captures for the 2026-11-04 "Shipment and Bears" notes: the certificate office seen from the street (A), the Sheriff and the
## resting townsfolk (B). Fixed eye-level views in the real town chamber, plus a printed read-out of what each view should show.
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tools/ep2_shots/shipment_bears_shot.tscn -- out=<dir>
## Rendered in a 1600x900 SubViewport (the tiling window manager squashes a real window).
var chamber: Ep2Interlude
var vp: SubViewport
var out := ".farm/shipment-bears"
var mode := "town"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("mode="):
			mode = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	# mode=woods: the founder's frame. After Inferno drops him off he is still in the WOODS chamber's copy of the town until the hand-over.
	chamber = load("res://src/episode2/chamber/woods_quad.tscn" if mode == "woods" else "res://src/episode2/chamber/gold_town.tscn").instantiate() as Ep2Interlude
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	if mode == "woods":
		if chamber.has_method("prebuild_finish"):
			chamber.call("prebuild_finish")
		chamber._hud.objective = "woods chamber town copy"
		await _office()
		print("SHIPMENT_BEARS_SHOT_DONE")
		get_tree().quit()
		return
	await _sim(0.5)
	if mode == "rest":
		await _rests()
		print("SHIPMENT_BEARS_SHOT_DONE")
		get_tree().quit()
		return
	await _office()
	await _sheriff()
	await _folk()
	print("SHIPMENT_BEARS_SHOT_DONE")
	get_tree().quit()


func _sim(seconds: float) -> void:
	for i in int(seconds * 60.0):
		chamber.step(1.0 / 60.0)
		if i % 20 == 0:
			await get_tree().process_frame


func _look(ground: Vector3, focus: Vector3) -> void:
	chamber._player_pos = Vector3(ground.x, 0.0, ground.z)
	var eye: Vector3 = chamber._player_pos + Vector3(0, chamber.eye_height, 0)
	var d: Vector3 = focus - eye
	chamber._look_yaw = atan2(d.x, d.z)
	chamber._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	chamber._update_camera(0)
	chamber._sync_visuals()


func _shot(label: String) -> void:
	for f in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, label], 0.88)


## A: the office from the player's real approach, street to threshold. The doorway must already show the room.
func _office() -> void:
	var door: Vector3 = Ep2GoldTown.door_world("Bldg_Certificates", 0.0)
	var inside: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 1.2, -5.0))
	print("OFFICE door world ", door, " kit_v2 ", Ep2GoldTown.kit_v2, " extras TOWN_KIT ", Ep2Extras.has(Ep2Extras.TOWN_KIT))
	for row in [["a1_street_far", 14.0], ["a2_street_near", 8.0], ["a3_porch_steps", 4.0], ["a4_doorway", 1.4], ["a5_threshold", 0.2], ["a6_inside", -1.6]]:
		_look(Ep2GoldTown.door_world("Bldg_Certificates", float(row[1])), inside)
		await _shot(mode + "_" + str(row[0]))


## B: the Sheriff on the boardwalk while the objective says "Cross the street to the SALOON" (the founder's frame).
func _sheriff() -> void:
	(chamber as GoldTownChamber)._advance_to(GoldTownChamber.Beat.TO_BAR)
	for i in 6:
		await _sim(2.0)
		var s: Ep2TownFolk = (chamber as GoldTownChamber).get_sheriff()
		print("SHERIFF t=", (i + 1) * 2, " pos ", s.position, " clip ", s.current_clip())
		_look(s.position + Vector3(2.6, 0, -3.2), s.position + Vector3(0, 0.9, 0))
		await _shot("b_sheriff_%02d" % ((i + 1) * 2))


## B: each woman's and elder's rest clip, held still in the open street, side on: is it a stance or a seat with nothing under it?
func _rests() -> void:
	var town: GoldTownChamber = chamber as GoldTownChamber
	var z: float = 1402.0
	for p in town._people.people:
		var f: Ep2TownFolk = p.folk
		if not str(p.id) in ["grandma", "grandmother", "dressmaker", "lady", "bob_girl", "braided_girl", "grandfather", "oldtimer"]:
			continue
		p.state = "pause"
		p.timer = 999.0
		f.stop()
		f.use_height = false
		f.place(Vector3(0.0, 0.0, z))
		f.hold_clip("Rest")
		f.face_yaw(PI * 0.5)
		f.rotation.y = PI * 0.5
		for i in 40:
			f.step(1.0 / 60.0)
		for d in 12:
			await RenderingServer.frame_post_draw
		_look(Vector3(2.8, 0, z + 0.6), Vector3(0, 0.75, z))
		await _shot("rest_%s" % str(p.id))
		f.place(Vector3(30.0, 0.0, z))
		z += 3.0


## B: every townsperson's stance after a while: who is playing a seated clip, and is there anything under them.
func _folk() -> void:
	var shots: int = 0
	await _sim(50.0)
	var town: GoldTownChamber = chamber as GoldTownChamber
	for p in town._people.people:
		var f: Ep2TownFolk = p.folk
		if not is_instance_valid(f):
			continue
		var clip: String = f.current_clip()
		print("FOLK %-14s pos (%.1f %.2f %.1f) clip %s state %s activity %s seat %d" % [str(p.id), f.position.x, f.position.y, f.position.z, clip, str(p.state), str(p.activity), int(p.seat)])
		if shots < 6 and (clip.to_lower().contains("rest") or clip.to_lower().contains("sit")):
			_look(f.position + Vector3(2.4, 0, 2.4), f.position + Vector3(0, 0.8, 0))
			await _shot("b_folk_%s_%s" % [str(p.id), clip.to_lower().replace("/", "_")])
			shots += 1
