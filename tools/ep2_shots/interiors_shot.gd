extends Node
## THE TOWN'S ROOMS, FURNISHED (founder 2026-10-25: "Town interiors - more furnished furniture and subtle details (Certificate, Saloon,
## Armory, Jail as touched)"): fixed eye-level views of the saloon, the certificate office and the jail in the real town chamber, for a
## before / after board (run the same script on master for "before").
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/interiors_shot.tscn -- out=<dir>
## Rendered in a 1600x900 SubViewport (the tiling window manager squashes a real window).
var chamber: GoldTownChamber
var vp: SubViewport
var out := ".farm/interiors"

## [label, building ("" = world coordinates), eye ground point (local), look-at point (local)]
const VIEWS: Array = [
	["saloon_wide", "Bldg_Saloon", Vector3(0.0, 0.0, -0.7), Vector3(-0.6, 1.5, -9.0)],
	["saloon_bar", "Bldg_Saloon", Vector3(1.2, 0.0, -5.6), Vector3(-1.6, 1.4, -10.6)],
	["saloon_tables", "Bldg_Saloon", Vector3(1.6, 0.0, -6.4), Vector3(-3.2, 1.4, -3.4)],
	["saloon_piano", "Bldg_Saloon", Vector3(3.0, 0.0, -5.4), Vector3(4.8, 0.9, -10.6)],
	["office_counter", "Bldg_Certificates", Vector3(0.9, 0.0, -1.5), Vector3(0.6, 1.3, -6.0)],
	["office_left", "Bldg_Certificates", Vector3(1.8, 0.0, -2.2), Vector3(-3.2, 1.2, -4.6)],
	["office_back", "Bldg_Certificates", Vector3(-0.6, 0.0, -3.0), Vector3(2.6, 1.0, -8.4)],
	["jail_office", "Bldg_Jail", Vector3(0.9, 0.0, -0.8), Vector3(2.4, 0.9, -3.0)],
	["jail_stove", "Bldg_Jail", Vector3(0.6, 0.0, -3.0), Vector3(-3.0, 0.6, -0.7)],
	["jail_cell", "Bldg_Jail", Vector3(-1.0, 0.0, -4.2), Vector3(-1.2, 0.05, -5.3)],
	# Rich & Utah's two-storey Armory (when drawn)
	["armory_back", "Bldg_Armory", Vector3(0.4, 0.0, -3.4), Vector3(2.6, 1.0, -10.4)],
	["armory_stair", "Bldg_Armory", Vector3(2.0, 0.0, -6.6), Vector3(4.2, 0.6, -6.9)],
	["armory_guns", "Bldg_Armory", Vector3(2.4, 0.0, -2.4), Vector3(4.84, 2.0, -1.25)],
	["armory_door", "Bldg_Armory", Vector3(0.6, 0.0, -4.2), Vector3(-1.8, 1.3, -0.7)],
	["armory_bench", "Bldg_Armory", Vector3(-1.2, 0.0, -7.2), Vector3(-3.2, 0.9, -9.6)],
	# the street's facades (porch posts, cornice corbels, window hoods, the saloon's balcony)
	["street_left", "", Vector3(3.0, 0.0, 1416.0), Vector3(-9.0, 3.2, 1426.0)],
	["street_right", "", Vector3(-3.0, 0.0, 1418.0), Vector3(9.0, 3.4, 1428.0)],
	["street_saloon", "", Vector3(1.5, 0.0, 1411.0), Vector3(9.0, 4.6, 1414.0)],
	["porch_close", "", Vector3(4.5, 0.0, 1409.5), Vector3(6.55, 2.7, 1412.0)],
	["cornice_close", "", Vector3(3.0, 0.0, 1407.0), Vector3(9.0, 8.8, 1411.0)],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	chamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	for i in 30:
		chamber.step(1.0 / 60.0)
		await get_tree().process_frame
	for v in VIEWS:
		var bld: String = str(v[1])
		if bld != "" and (Ep2GoldTown.entry(bld).is_empty() or (bld == "Bldg_Jail" and not Ep2GoldTown.jail_v1)
				or (bld == "Bldg_Armory" and not Ep2GoldTown.armory_v2)):
			continue
		var g: Vector3 = Ep2GoldTown.local_to_world(bld, v[2]) if bld != "" else v[2]
		var f: Vector3 = Ep2GoldTown.local_to_world(bld, v[3]) if bld != "" else v[3]
		_look(g, f)
		await _shot(str(v[0]))
	print("INTERIORS_SHOT_DONE")
	get_tree().quit()


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
