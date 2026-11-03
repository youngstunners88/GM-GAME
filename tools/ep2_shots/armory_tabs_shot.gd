extends Node
## Rich & Utah's counter with the nine weapon tabs and the Shipment -> Sharps -> rest chain, and Dude's patch, as a player sees them.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/armory_tabs_shot.tscn

var out: String = ""
var vp: SubViewport = null


func _shot(name: String, screen: Vector2i = Vector2i(1280, 720)) -> void:
	vp.size = screen
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("TABS_SHOT ", name)


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://armory_tabs"
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()                 # exact sizes, whatever the window manager does to the window
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var shop := Ep2ArmoryShop.new()
	vp.add_child(shop)
	var st := Ep2ArmoryState.new()
	shop.open_shop(st, 20)
	await _shot("1_locked_shipment")
	st.river_gear = true
	shop.show_tab(0)
	await _shot("2_sharps_next")
	st.sniper_owned = true
	for i in Ep2ArmoryShop.WEAPON_TABS.size():
		shop.show_tab(i)
		await _shot("tab_%d" % i)
	shop.show_tab(7)
	await _shot("phone_844x390", Vector2i(844, 390))
	await _shot("phone_390x844", Vector2i(390, 844))
	shop.index = 0
	await _shot("phone_crate_390x844", Vector2i(390, 844))
	shop.hide()
	var patch := Ep2BudPatchShop.new()
	vp.add_child(patch)
	patch.open_patch(5)
	await _shot("patch")
	print("TABS_SHOTS_DONE")
	get_tree().quit()
