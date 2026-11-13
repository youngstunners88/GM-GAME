extends Node
## TEXTURE SURVEY (founder 2026-11-11: "there are textures that just suck and need a facelift"): every Episode 2 room the player walks,
## from his own eye, looking four ways, rendered by the real Compatibility renderer into a fixed 1280x720 SubViewport (the window size
## does not matter, so it runs on the desktop as it is). One PNG per view under out=<dir>; one line per view naming the room.
##   godot --rendering-driver opengl3 --rendering-method gl_compatibility --path . res://tools/ep2_shots/texture_survey_shot.tscn -- out=.farm/texsurvey [rooms=a,b]
const ROOMS := {
	"hideout": "res://src/episode2/chamber/smelting_facility.tscn",
	"lift": "res://src/episode2/chamber/mine_lift.tscn",
	"woods": "res://src/episode2/chamber/woods_quad.tscn",
	"town": "res://src/episode2/chamber/gold_town.tscn",
	"trail": "res://src/episode2/chamber/lake_trail.tscn",
	"lake": "res://src/episode2/chamber/logans_lake.tscn",
	"ridge": "res://src/episode2/chamber/river_cover.tscn",
	"road": "res://src/episode2/chamber/auction_road.tscn",
}
var _out := ".farm/texsurvey"
var _only: PackedStringArray = PackedStringArray()
var _at: Array = []          # at=x,z,yaw[;x,z,yaw...]: extra views from these spots (the room's own floor height)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("rooms="): _only = a.substr(6).split(",", false)
		if a.begins_with("at="):
			for spot in a.substr(3).split(";", false):
				var v: PackedStringArray = spot.split(",")
				_at.append([float(v[0]), float(v[1]), float(v[2])])
	DirAccess.make_dir_recursive_absolute(_out)
	for id in ROOMS:
		if not _only.is_empty() and not _only.has(id): continue
		await _room(id)
	get_tree().quit()


func _room(id: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c: Node = (load(ROOMS[id]) as PackedScene).instantiate()
	if "intro_film" in c: c.set("intro_film", false)
	if id == "lake": c.set("handoff", {"after_day88": true})
	vp.add_child(c)
	if c.has_method("bind_armory"): c.call("bind_armory", Ep2ArmoryState.post_hideout())
	c.call("setup", 0, [], 0)
	c.set_physics_process(false)
	if c.has_method("prebuild_finish"): c.call("prebuild_finish")
	for i in 20: await get_tree().process_frame
	if c is SmeltingFacilityChamber: (c as SmeltingFacilityChamber)._on_video_film_finished()
	for i in 90: c.call("step", 1.0 / 30.0)
	var yaw0: float = float(c.get("_look_yaw"))
	var n: int = 0
	var specs: Array = [[0.0, -0.05], [1.3, -0.05], [-1.3, -0.05], [PI, -0.05], [0.0, -0.45]]
	if not _at.is_empty():
		specs = []
		yaw0 = 0.0
		for spot in _at: specs.append([spot[2], 0.0, Vector3(spot[0], 0.0, spot[1])])
	for spec in specs:
		if spec.size() > 2: c.set("_player_pos", spec[2])
		c.set("_look_yaw", yaw0 + float(spec[0]))
		c.set("_look_pitch", float(spec[1]))
		if c.has_method("_update_camera"): c.call("_update_camera", 0.0)
		c.call("step", 1.0 / 30.0)
		for i in 6: await get_tree().process_frame
		var img: Image = vp.get_texture().get_image()
		img.save_png("%s/%s_%d.png" % [_out, id, n])
		print("SURVEY %s_%d pos=%s yaw=%.2f" % [id, n, str(c.call("get_player_position")), yaw0 + float(spec[0])])
		n += 1
	vp.queue_free()
	await get_tree().process_frame
