extends Node
## The scoped Sharps and the Borchardt played in the REAL town chamber under its own light (founder 2026-11-05): equip, shoulder, look through the lens at a board 100 m out, fire,
## reload, switch away and back, at desktop and phone-landscape size. Prints the numbers design/ep2/armory/WEAPON_CONSISTENCY.md records.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/sharps_scope_shot.tscn

const RANGE := 100.0
const BOARD := Vector2(1.2, 1.8)

var out: String = ""
var vp: SubViewport = null
var c: GoldTownChamber = null


func _steps(n: int, aimed: bool) -> void:
	for i in n:
		c.set_aim(aimed)
		c.step(1.0 / 60.0)
		await get_tree().process_frame


func _shot(name: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SCOPE_SHOT ", name, " fov ", snappedf(c._camera.fov, 0.01), " ads ", snappedf(c._vm.gun.ads, 0.01), " scope ", snappedf(c._vm.scope_k(), 0.01), " gun_visible ", c._vm.rifle.visible)


## The board's height in pixels at the current fov and the screen height, from the camera's own projection.
func _board_px(target: Vector3) -> float:
	var cam: Camera3D = c._camera
	return absf(cam.unproject_position(target + Vector3(0.0, BOARD.y * 0.5, 0.0)).y - cam.unproject_position(target - Vector3(0.0, BOARD.y * 0.5, 0.0)).y)


## The stranger's Borchardt is the same file at real size: in his fist through the draw, then on the ground by the body, and searching him still pays out the gun.
func _stranger() -> void:
	c._advance_to(GoldTownChamber.Beat.DRAW)
	var g: int = 0
	while c.get_draw_state() != "go" and g < 900:
		c.step(1.0 / 60.0)
		await get_tree().process_frame
		g += 1
	for i in 25:
		c.step(1.0 / 60.0)
		await get_tree().process_frame
	var opp: Node3D = c.get_opponent()
	var gun: Node3D = c._revolver.find_child("Borchardt", true, false) as Node3D
	var head: Vector3 = opp.global_position + Vector3(0.0, 1.05, 0.0)
	print("STRANGER state ", c.get_draw_state(), " holds real pistol ", gun != null, " real ", c._opp_gun_real, " gun_scale ", gun.global_transform.basis.get_scale() if gun != null else Vector3.ZERO)
	c._set_eye_view(false)
	c._camera.global_position = head + opp.global_transform.basis.z * 2.0 + Vector3(0.9, 0.2, 0.0)
	c._camera.look_at(head, Vector3.UP)
	c._camera.fov = 45.0
	await _shot("stranger-draw")
	c._set_eye_view(true)
	var eye: Vector3 = c._player_pos + Vector3(0.0, c.eye_height, 0.0)
	var to: Vector3 = opp.global_position + Vector3(0.0, 1.1, 0.0) - eye
	c._look_yaw = atan2(to.x, to.z)
	c._look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	c.step(1.0 / 60.0)
	print("STRANGER shot ", c.shoot())
	for i in 200:
		c.step(1.0 / 60.0)
		await get_tree().process_frame
	print("STRANGER beat ", c.get_beat_name(), " draw ", c.get_draw_state())
	c._set_eye_view(false)
	if c.get_draw_state() != "won":
		c._drop_revolver()                     # the frame needs only the pistol on the ground; ep2_gold_town_test plays the real win and the loot
	var rev: Vector3 = c._revolver.global_position
	c._camera.global_position = rev + Vector3(0.8, 0.9, 0.8)
	c._camera.look_at(rev, Vector3.UP)
	c._camera.fov = 45.0
	await _shot("stranger-dropped")


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://sharps_scope"
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	c = (load("res://src/episode2/chamber/gold_town.tscn") as PackedScene).instantiate()
	vp.add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	c.armory.sniper_owned = true
	c.armory.acquire(Ep2ArmoryState.BUFF)
	c.armory.acquire(Ep2ArmoryState.BORCH)
	c.armory.acquire(Ep2ArmoryState.REM)
	await get_tree().process_frame
	# open ground on the lake road, looking away from the town
	var at: Vector3 = Ep2BudPatch.POS + Vector3(13.0, 0.0, 2.0)
	var yaw: float = PI * 0.5
	var aim_dir := Vector3(sin(yaw), 0.0, cos(yaw))
	var eye_y: float = at.y + c.eye_height
	var target := Vector3(at.x, eye_y, at.z) + aim_dir * RANGE
	var board := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(BOARD.x, BOARD.y, 0.1)
	board.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.12, 0.08)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board.material_override = mat
	vp.add_child(board)
	board.global_position = target
	board.rotation.y = yaw
	var hold := func() -> void:
		c._player_pos = at
		c._look_yaw = yaw
		c._look_pitch = 0.0
	for id in [Ep2ArmoryState.BORCH, Ep2ArmoryState.BUFF]:
		hold.call()
		print("SCOPE_SELECT ", id, " ", c.select_weapon(id), " control ", c.has_player_control())
		await _steps(40, false)
		await _shot("town-hip-" + id)
		hold.call()
		await _steps(60, true)
		await _shot("town-ads-" + id)
		await _steps(40, false)
	var sizes: Array = [Vector2i(1280, 720), Vector2i(844, 390)]
	for screen in sizes:
		vp.size = screen
		hold.call()
		await _steps(40, false)
		print("SCOPE_BOARD hip %s px %.1f" % [str(screen), _board_px(target)])
		hold.call()
		await _steps(60, true)
		hold.call()
		c._update_camera(0)
		var centre: Vector2 = Vector2(screen) * 0.5
		print("SCOPE_BOARD scoped %s px %.1f centre_offset_px %s" % [str(screen), _board_px(target), str(c._camera.unproject_position(target) - centre)])
		await _shot("scope-%dx%d" % [screen.x, screen.y])
		await _steps(40, false)
	vp.size = sizes[0]
	# the fire -> reload -> switch cycle on the real verbs
	hold.call()
	await _steps(60, true)
	var rounds: int = c._vm.gun.rounds
	var kick_before: float = c._vm.cam_kick
	var fired: bool = c.shoot()
	print("SCOPE_FIRE fired ", fired, " rounds ", rounds, " -> ", c._vm.gun.rounds, " kick_rad ", snappedf(c._vm.cam_kick - kick_before, 0.0001), " spread_deg ", snappedf(c._vm.gun.spread_deg(false, false), 0.001))
	await _shot("scope-fired")
	await _steps(80, false)                      # the Sharps' 1.1 s cycle first: a reload is refused until the block has dropped
	print("SCOPE_RELOAD started ", c.reload())
	await _steps(120, false)
	print("SCOPE_RELOAD rounds ", c._vm.gun.rounds, " reloading ", c._vm.gun.reloading)
	print("SCOPE_SWITCH to Remington ", c.select_weapon(Ep2ArmoryState.REM), " hud scope after step:")
	await _steps(10, false)
	print("SCOPE_SWITCH scope ", c._vm.scope_k(), " fov ", snappedf(c._camera.fov, 0.01), " visible ", c._vm.rifle.visible)
	await _steps(60, true)
	print("SCOPE_SWITCH Remington aimed fov ", snappedf(c._camera.fov, 0.01), " scope ", c._vm.scope_k())
	await _steps(30, false)
	print("SCOPE_SWITCH back to Sharps ", c.select_weapon(Ep2ArmoryState.BUFF))
	await _steps(60, true)
	print("SCOPE_SWITCH Sharps aimed fov ", snappedf(c._camera.fov, 0.01), " scope ", c._vm.scope_k(), " visible ", c._vm.rifle.visible)
	await _stranger()
	print("SCOPE_SHOTS_DONE")
	get_tree().quit()
