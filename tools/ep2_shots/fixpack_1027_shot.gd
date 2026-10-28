extends Node
## FOUNDER FIX PACK 2026-10-27 - the visual items in the real town chamber, its first-person camera and light (skills
## ep2-founder-fix-pack-1027, see-it-yourself): the stranger's Peacemaker in its holster and drawn, the Colt in the dirt by the body,
## the two shopkeepers behind their counters, Bam Bankman Free in the cell, the drink at the bar (Inferno's glass up, Lil Blunt's glass at
## the camera) and the saloon's table regulars.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/fixpack_1027_shot.tscn -- out=<dir>
var chamber: GoldTownChamber
var vp: SubViewport
var out := ".farm/fixpack1027"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	chamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	for i in 3:
		await get_tree().process_frame
	var opp: Ep2TownFolk = chamber.get_opponent()
	# 1. the duel: the stranger on his mark, the Peacemaker holstered on his hip (the rifle is lowered before the bell)
	chamber._advance_to(GoldTownChamber.Beat.DRAW)
	_step(0.5)
	_look(GoldTownChamber.OPP_MARK + Vector3(-0.2, 0.0, -3.2), opp.position + Vector3(-0.2, 1.0, 0.0))
	await _shot("1_peacemaker_holstered")
	# 2. the bell: he draws it
	chamber._opp_draws()
	_look(GoldTownChamber.OPP_MARK + Vector3(-0.2, 0.0, -3.2), opp.position + Vector3(-0.2, 1.35, 0.0))
	await _shot("2_peacemaker_drawn")
	# 3. he falls: the Colt in the dirt beside him, his blood
	opp.fall_dead()
	chamber._drop_revolver()
	for i in 90:
		opp.step(1.0 / 60.0)
	var colt: Node3D = chamber.get_revolver()
	_look(colt.position + Vector3(-1.4, 0.0, -1.6), colt.position + Vector3(0.0, 0.05, 0.0))
	await _shot("3_colt_by_the_body")
	# 4. the shopkeepers behind their counters, from just inside each door
	for row in GoldTownChamber.SHOPKEEPERS:
		var piece: String = str(row[0])
		var spots: Dictionary = Ep2GoldTown.shop_spots(piece)
		if spots.is_empty():
			continue
		_look(Ep2GoldTown.local_to_world(piece, Vector3(0.0, 0.0, -1.2)), (spots["face"] as Vector3) + Vector3(0.0, 1.4, 0.0))
		chamber._tick_shopkeepers(0.5)
		await _shot("4_shopkeeper_%s" % piece)
	# 5. Bam Bankman Free in the cell (the law shows him only during an arrest; shown here for the look)
	var law: Ep2TownLaw = chamber.get_town_law()
	var bam: Ep2TownFolk = law.get_bam() if law != null else null
	if bam != null:
		bam.visible = true
		bam.step(0.1)
		_look(Ep2GoldTown.local_to_world("Bldg_Jail", Ep2TownLaw.CELL_PLAYER_LOCAL), bam.position + Vector3(0.0, 1.55, 0.0))
		await _shot("5_bam_in_the_cell")
	# 6. the drink at the bar: Inferno beside Lil Blunt, both glasses up
	var bull: Ep2Actor = chamber.get_bull()
	var bar: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
	chamber._player_pos = bar
	bull.visible = true
	bull.position = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT + Vector3(1.4, 0.0, -0.1))
	if bull.anim != null and not bull.anim.has_animation(SmeltingFacilityChamber.BULL_SIP):
		bull.add_all_clips(SmeltingFacilityChamber.BULL_SIT_CLIPS)
	chamber._pour_two()
	bull.face_point(bar)
	chamber._drink_together()
	for i in 70:
		chamber._tick_drink(1.0 / 60.0)
		bull.step(1.0 / 60.0)
	_look(bar, bull.head_world() + Vector3(0.0, -0.6, 0.0))
	await _shot("6_the_drink")
	# 7. the saloon's tables: the regulars in their chairs
	_look(Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.0, 0.0, -1.0)), Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(1.0, 0.9, -5.0)))
	await _shot("7_saloon_sitters")
	print("FIXPACK_SHOTS_DONE ", out)
	get_tree().quit(0)


func _step(seconds: float) -> void:
	for i in int(seconds * 60.0):
		chamber.step(1.0 / 60.0)


func _look(ground: Vector3, focus: Vector3) -> void:
	chamber._player_pos = Vector3(ground.x, 0.0, ground.z)
	var eye: Vector3 = chamber._player_pos + Vector3(0, chamber.eye_height, 0)
	var d: Vector3 = focus - eye
	chamber._look_yaw = atan2(d.x, d.z)
	chamber._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	chamber._update_camera(0)
	chamber._sync_visuals()


func _shot(label: String) -> void:
	for f in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, label], 0.88)
