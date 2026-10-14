extends Node
## Real Compatibility renders of the armory in the mine lift; explicit earned entry fixture.
var room: Ep2Interlude
var out := ".farm/armory"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out)
	room = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	add_child(room)
	var state := Ep2ArmoryState.new()
	state.acquire(Ep2ArmoryState.REM)
	state.acquire(Ep2ArmoryState.WIN)
	room.bind_armory(state)
	room.setup()
	room.set_physics_process(false)
	for i in 30:
		room.step(1.0 / 60.0)
	room._show_blocks_control = false
	await capture("1_winchester")
	room.select_weapon(Ep2ArmoryState.REM)
	for i in 30:
		room.step(1.0 / 60.0)
	await capture("2_remington")
	room.set_aim(true)
	for i in 30:
		room.step(1.0 / 60.0)
	await capture("3_remington_ads")
	room.set_aim(false)
	state.active_gun().rounds = 0
	for i in 30:
		room.step(1.0 / 60.0)
	await capture("4_empty_remington")
	state.record_corpse("fixture:spent_quiver", 3)
	state.claim_corpse("fixture:spent_quiver")
	room.toggle_armory()
	await capture("5_inventory_arrows")
	room.toggle_armory()
	room.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("ARMORY_CAPTURE: ", label)
