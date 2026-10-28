extends Node
var out := "docs/episode2-quality/map-ride-vo-residuals-20261028/cameras"
func cap(label: String) -> void:
 for i in 3: await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out+"/"+label+".png")
 print("CAMERA ",label)
func _ready() -> void:
 DirAccess.make_dir_recursive_absolute(out)
 var town: GoldTownChamber=preload("res://src/episode2/chamber/gold_town.tscn").instantiate()
 add_child(town);town.setup(0,[],0);town.set_physics_process(false)
 town._show_active=false;town._show_blocks_control=false;town._hold=0
 town._player_pos=town.DUEL_MARK
 town._advance_to(town.Beat.DRAW)
 for i in 30: town.step(1.0/60.0)
 await cap("draw_holstered")
 town._draw_state="go";town.draw_weapon()
 for i in 10: town.step(1.0/60.0)
 await cap("draw_enter_raised")
 town.free()
 var c: LakeTrailChamber=preload("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 add_child(c);c.setup(0,[],0);c.set_physics_process(false);c.debug_invulnerable=true
 c.step(0.01)
 await cap("saddle_departure")
 c._look_yaw=0;c._look_pitch=0;c.step(0.01)
 await cap("town_still_behind")
 c._player_pos=Vector3(13,0,170);c._look_yaw=0;c.step(0.01)
 await cap("mounted_back_in_town")
 c._place_at_distance(150);c._look_yaw=c._travel_yaw+PI;c._look_pitch=-0.03;c.step(.01)
 await cap("ambush_aim_behind")
 c.free()
 get_tree().quit()
