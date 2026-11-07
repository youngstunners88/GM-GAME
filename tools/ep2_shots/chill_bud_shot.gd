extends Node
## Real ranch/shop and selectable health-tab evidence. OUT=<absolute dir>.
var out: String
var vp: SubViewport
var c: GoldTownChamber
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_environment("OUT")
	if out == "": out = "user://chill_bud_shots"
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	if OS.get_environment("ONLY_TABS") == "1":
		await tabs()
		get_tree().quit()
		return
	c = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	vp.add_child(c)
	c.setup(0, [], 0)
	c.set_process(false)
	c.set_physics_process(false)
	await get_tree().process_frame
	var bed: Vector3 = Ep2BudPatch.POS
	for spot in [["patch-front", Vector3(0, 0, 2.6), -0.22], ["patch-left", Vector3(-2.4, 0, 2.2), -0.22], ["patch-tree", Vector3(4.3, 0, 2.0), -0.10]]:
		var at: Vector3 = bed + spot[1]
		for i in 20:
			c._player_pos = at
			c._look_yaw = atan2(bed.x - at.x, bed.z - at.z)
			c._look_pitch = float(spot[2])
			c.step(1.0 / 60.0)
			await get_tree().process_frame
		await grab(str(spot[0]))
	GameManager.purse_add("btc", 4)
	c._open_patch()
	await grab("shop")
	c._close_patch()
	c.queue_free()
	await get_tree().process_frame
	c = null
	await tabs()
	print("CHILL_BUD_SHOT_DONE")
	get_tree().quit()
func grab(label: String) -> void:
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out + "/" + label + ".png")
	print("CHILL_BUD_SHOT ", label)

func tabs() -> void:
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	GameManager.add_chill_buds(2)
	# Only damageable rooms consume buds; exercise the real woods host.
	var woods: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	vp.add_child(woods)
	woods.setup()
	woods.set_process(false)
	woods.set_physics_process(false)

	woods._health = 1
	woods._hud.health = 1
	woods._show_active = false
	woods._show_blocks_control = false
	woods.get_hud().toggle_armory()
	woods.get_hud()._panel.select_bud()
	await grab("tabs-selected")
	var before: int = GameManager.chill_buds
	var ok: bool = woods.use_chill_bud()
	print("CHILL_BUD_HEAL success=", ok, " health=", woods.get_health(), " spent=", before - GameManager.chill_buds)
	await grab("tabs-healed")
	for screen in [Vector2i(844,390), Vector2i(390,844)]:
		vp.size = screen
		await grab("tabs-%dx%d" % [screen.x, screen.y])
	woods.get_hud().close_armory(false)
