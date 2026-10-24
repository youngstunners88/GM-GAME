extends Node
## The weapon tab with Lil Blunt's crypto purse (founder 2026-10-24) at desktop and phone sizes, drawn by the real Ep2WeaponSelector.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/purse_tab_shot.tscn -- out=<dir>
var _out := ".farm/purse_tab"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	GameManager.token_purse = {"eth": 12, "btc": 3, "sol": 27}
	GoldMineSystem.wbtc_balance = 2
	GameManager.titanx_collected = 40
	for spec in [["desktop", Vector2i(1600, 900)], ["phone", Vector2i(390, 844)]]:
		var vp := SubViewport.new()
		vp.size = spec[1]
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.transparent_bg = false
		add_child(vp)
		var sel := Ep2WeaponSelector.new()
		var st := Ep2ArmoryState.new()
		sel.state = st
		sel.highlighted = Ep2ArmoryState.WIN
		vp.add_child(sel)
		for i in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, spec[0]])
		vp.queue_free()
	print("PURSE_TAB_SHOT_DONE")
	get_tree().quit()
