extends Node
## Rich's counter with the BTC / WBTC / MORE pay buttons (founder 2026-11-22). Real renderer:
##   godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 \
##     res://tools/ep2_shots/shop_pay_shot.tscn -- out=<png>


func _ready() -> void:
	var out: String = "user://shop_pay.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	GameManager.token_purse = {"eth": 3, "btc": 2, "sol": 0}
	GoldMineSystem.wbtc_balance = 7
	var shop := Ep2ArmoryShop.new()
	shop.purse_of = func(t: String) -> int: return GameManager.purse_balance(t)
	add_child(shop)
	var armory := Ep2ArmoryState.new()
	armory.river_gear = true
	shop.tender = "wbtc"
	shop.open_shop(armory, 0)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()
