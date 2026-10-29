extends Node
var out := "/workspace/work/town-continuity-1029/candidate"
var vp: SubViewport
var town: GoldTownChamber
func shot(label: String,eye: Vector3,target: Vector3) -> void:
	town._player_pos=eye
	var d: Vector3=target-(eye+Vector3.UP*town.eye_height)
	town._look_yaw=atan2(d.x,d.z)
	town._look_pitch=atan2(d.y,Vector2(d.x,d.z).length())
	town._update_camera(0)
	for i in 3:await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join(label+".png"))
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	vp=SubViewport.new()
	vp.size=Vector2i(1280,720)
	vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var session:=Ep2SessionRoot.new()
	vp.add_child(session)
	session.set_process(false)
	session.set_physics_process(false)
	session.armory=Ep2ArmoryState.post_hideout()
	GameManager.town_people_state={}
	session._chain_id="gold_town"
	session._enter_chamber_chained(0)
	town=session._active
	town.set_physics_process(false)
	town._advance_to(town.Beat.GEARED)
	town._show_active=false
	town._show_blocks_control=false
	town._hold=0
	town.release_look()
	town._set_eye_view(true)
	var trip: Ep2FarmerTrip=session.farmer_trip
	var seen: Dictionary={}
	for i in 14000:
		trip.tick(session,.1)
		if trip.worker!=null:
			var ap: AnimationPlayer=trip.worker.folk.anim_player()
			if ap!=null:
				ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				ap.advance(.1)
		var label: String=""
		if trip.phase=="inbound" and trip.travelled>80:label="farmer-on-road"
		if trip.phase=="waiting":label="farmer-arrived"
		if trip.phase=="handover":label="farmer-before-pickup" if trip.timer>1.5 else "farmer-handed-over"
		if trip.phase=="deliver" and trip.worker.folk.position.x>-10:label="worker-entering-shop"
		if trip.phase=="inspect":label="delivery-on-counter"
		if trip.phase=="complete":label="farmer-business-complete"
		if label!="" and not seen.has(label):
			seen[label]=true
			if label=="delivery-on-counter":
				await shot(label,Ep2GoldTown.local_to_world("Bldg_A",Vector3(0,0,-1.5)),trip.parcel.position)
			elif label=="worker-entering-shop":
				var at: Vector3=trip.worker.folk.position
				await shot(label,Ep2GoldTown.shop_spots("Bldg_A").out+Vector3(2.8,0,3.5),at+Vector3(0,1.1,0))
			else:await shot(label,trip.cart.position+Vector3(-5.5,0,2.5),trip.cart.position+Vector3(0,1.05,0))
		if trip.phase=="complete":break
	print("FARMER_TRIP_REVIEW ",seen)
	get_tree().quit()
