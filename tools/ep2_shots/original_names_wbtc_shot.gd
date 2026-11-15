extends Node
## Actual town HUD, counter and Tabs after purchasing with Episode 1 WBTC.
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var output: String = ".farm/original-names-wbtc"
var vp: SubViewport
var town: GoldTownChamber

func grab(label: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(output.path_join(label + ".png"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(output)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	town = TOWN.instantiate()
	vp.add_child(town)
	town.setup(0, [], 0)
	await get_tree().process_frame
	town.set_process(false)
	town.set_physics_process(false)
	town.skip_armory_intro()
	GameManager.token_purse = {"eth": 0, "btc": 0, "sol": 0}
	GameManager.titanx_collected = 0
	GoldMineSystem.wbtc_balance = 60
	town._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.ARMORY_SPOT)
	town._advance_to(GoldTownChamber.Beat.ARMORY)
	town.step(0.1)
	town._open_shop()
	await grab("counter_wbtc")
	for item in ["river_gear", "sniper"] + Ep2ArmoryState.SHOP_GUNS:
		if not town.armory.owns(item):
			assert(town.buy(item, 0, "wbtc"))
	for screen in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]:
		vp.size = screen
		town._shop.index = 5
		await grab("counter_%dx%d" % [screen.x, screen.y])
	town._close_shop()
	vp.size = Vector2i(1280, 720)
	for id in [Ep2ArmoryState.WIN, Ep2ArmoryState.REM, Ep2ArmoryState.MP18]:
		town.armory.select(id)
		town._sync_held_weapon()
		town.step(0.1)
		await grab("held_" + id)
	town.toggle_armory()
	for screen in [Vector2i(1280, 720), Vector2i(390, 844)]:
		vp.size = screen
		await grab("tabs_%dx%d" % [screen.x, screen.y])
	print("ORIGINAL_NAMES_WBTC_SHOT done")
	get_tree().quit()
