extends Node
## P1-9 (founder 2026-11-22: "He also parks straight onto the box of Rich and Utah ... speaks to Lil Blunt then walks elsewhere"):
## Lil Blunt at Rich's Gatling when Inferno rides back. From his eye: the quad parked clear of the crates, Inferno calling from beside it;
## from above: the park, the crates and his one path to the body and the saloon.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/inferno_park_shot.tscn -- out=<dir>
var _out := ".farm/inferno_park"


func _save(name: String) -> void:
	for j in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_process(false)
	c.set_physics_process(false)
	var opp: Ep2TownFolk = c.get_opponent()
	opp.position = GoldTownChamber.OPP_MARK
	opp.fall_dead()
	c._advance_to(GoldTownChamber.Beat.LOOT)
	c._won_t = -1000.0
	c._got_peacemaker = true
	var lb: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", Ep2GoldTown.GATLING_POST + Vector3(-Ep2GoldTown.GATLING_STAND_BACK, 0.0, 0.0))
	c._player_pos = lb
	c._advance_to(GoldTownChamber.Beat.BULL_BACK)
	for i in 60 * 40:
		c.step(1.0 / 60.0)
		if c._bull_task == "greeted": break
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	var q: Vector3 = c.get_quad().position
	cam.global_position = lb + Vector3(0.0, 1.6, 0.0)
	cam.look_at(q + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	await _save("1_from_the_gatling")
	cam.global_position = q + Vector3(-3.0, 14.0, -9.0)
	cam.look_at(q + Vector3(-1.5, 0.0, 1.5), Vector3.UP)
	await _save("2_park_from_above")
	print("INFERNO_PARK_SHOT_DONE ", _out)
	get_tree().quit()
