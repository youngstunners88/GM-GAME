extends Node
## The personal-armory selection tab (hold Tab) with all three weapons owned: the three cards side by side, each with Lil Blunt's hand (skill ep2-weapon-selector-icons).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/weapon_selector_shot.tscn -- out=<dir>
var _out := ".farm/selector"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var state := Ep2ArmoryState.post_hideout()
	state.acquire(Ep2ArmoryState.REM)
	state.record_corpse("a", 4, true)
	state.claim_corpse("a")
	var sel := Ep2WeaponSelector.new()
	sel.state = state
	sel.size = Vector2(1600, 900)
	vp.add_child(sel)
	for pick in [Ep2ArmoryState.BOW, Ep2ArmoryState.REM]:
		sel.preview(pick)
		for i in 5:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/selector_%s.png" % [_out, pick])
	print("WEAPON_SELECTOR_SHOT done ", _out)
	get_tree().quit()
