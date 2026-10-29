extends Node
## Actual town/player-camera motion strip and trade-panel proof; never exported.
var out := "/workspace/work/fix-doc-1029/views"
var vp: SubViewport

func frames(n: int) -> void:
	for i in n: await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frames(2)
	vp.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var town: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	vp.add_child(town)
	town.setup()
	town.set_physics_process(false)
	town._show_active = false
	town._show_blocks_control = false
	town._hold = 0.0
	town._advance_to(town.Beat.ARMORY)
	town._show_active = false
	town.release_look()
	for folk in [town._sheriff, town._utah]:
		var start: Vector3 = Vector3(0, 0, 1425) if folk == town._sheriff else Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(1.8, 0, -2.2))
		folk.place(start)
		folk.rotation.y = 0
		folk.facing = 0
		var ap: AnimationPlayer = folk.anim_player()
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		ap.play("GroundedWalk")
		for side in ["front", "side"]:
			for sample in 6:
				var t: float = sample * float(Ep2GroundedWalk.config.cycle_seconds) / 6.0
				folk.position = start + Vector3(0, 0, float(Ep2GroundedWalk.config.reference_speed) * t)
				ap.seek(t, true)
				ap.advance(0.0)
				town._player_pos = folk.position + (Vector3(0, 0, 3.5) if side == "front" else Vector3(3.5, 0, 0))
				town._look_yaw = PI if side == "front" else -PI/2
				town._look_pitch = -0.12
				town._update_camera(0.0)
				await shot(str(folk.name).to_lower() + "-" + side + "-%02d" % sample)
	var shop := Ep2ArmoryShop.new()
	var layer := CanvasLayer.new()
	vp.add_child(layer)
	layer.layer = 100
	layer.add_child(shop)
	shop.open_shop(town.armory, 20)
	await shot("trade-close")
	print("FIX_DOCUMENT_REVIEW_DONE")
	get_tree().quit()
