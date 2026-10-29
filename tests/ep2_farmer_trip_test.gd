extends Node
var checks := 0
var failed := 0
func check(label: String,ok: bool) -> void:
	checks+=1
	if not ok:failed+=1
	print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready() -> void:
	var save_guard: RefCounted=preload("res://tests/ep2_save_guard.gd").new()
	process_mode=Node.PROCESS_MODE_ALWAYS
	GameManager.town_people_state={}
	var session:=Ep2SessionRoot.new()
	add_child(session)
	session.set_process(false)
	session.set_physics_process(false)
	var woods: WoodsQuadChamber=load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	session.add_child(woods)
	woods.setup()
	woods.set_physics_process(false)
	woods._cart_state=3
	woods._tick_cart(.25)
	var original: Ep2RoadCart=woods.get_cart_node()
	var driver: Node3D=original._farmer
	var start_distance: float=original.distance_m
	session._active=woods
	session._mode=session.Mode.CHAMBER
	session._chain_id="gold_town"
	session._enter_chamber_chained(0)
	session.set_process(false)
	session.set_physics_process(false)
	var town: GoldTownChamber=session._active
	town.set_physics_process(false)
	var trip: Ep2FarmerTrip=session.farmer_trip
	check("the actual road cart transfers into town",trip.cart==original and original.get_parent()==town._visuals)
	check("the original farmer rig and rolling phase survive",original._farmer==driver and is_equal_approx(original.distance_m,start_distance))
	check("parked woods gives the continuing trip one simulation owner",woods._cart_external and woods.get_parent() is SubViewport)
	var before: Vector3=original.position
	trip.tick(session,.25)
	check("the farmer continues moving while the player is in town",original.position.distance_to(before)>.5)
	var travelled: float=original.distance_m
	woods._tick_cart(1)
	check("the old woods cannot advance his wheels a second time",is_equal_approx(original.distance_m,travelled))
	get_tree().paused=true
	before=original.position
	trip.tick(session,1)
	check("Tabs or pause freezes the whole journey",original.position==before and is_equal_approx(original.distance_m,travelled))
	get_tree().paused=false
	var saved: Dictionary=trip.snapshot()
	check("the continuing road route is saved with its actual progress",saved.path.size()>20 and saved.id=="road_farmer" and float(saved.distance)>0)
	var restored:=Ep2FarmerTrip.new()
	restored.enter_town(town,null,saved)
	check("a fresh restore preserves the moving cart's exact survey position",restored.cart.position.distance_to(original.position)<.001)
	check("a fresh restore preserves the donkey and axle distance",absf(restored.cart.distance_m-original.distance_m)<.001)
	restored.cart.free()
	restored.clear()
	var stages: Dictionary={}
	var clear_of_walls: bool=true
	var carrying_save: Dictionary={}
	var carrying_town: Dictionary={}
	var carrying_position: Vector3
	var duel_tested: bool=false
	var duel_safe: bool=false
	var resumed: bool=false
	var parcel: Node3D=trip.parcel
	for i in 12000:
		trip.tick(session,.1)
		stages[trip.phase]=true
		if not duel_tested and trip.phase=="collect":
			duel_tested=true
			town.get_people().set_context("duel")
			for j in 140:
				town.get_people().step(.05,Vector3(50,0,1300))
				trip.tick(session,.05)
			duel_safe=trip.phase=="collect" and trip.parcel.get_parent()==original and not trip.delivered
			town.get_people().set_context("normal")
			for j in 480:
				town.get_people().step(.05,Vector3(50,0,1300))
				trip.tick(session,.05)
			resumed=trip.worker!=null and trip.worker.state not in ["flee","shelter"] and (trip.worker.folk.is_walking() or trip.phase!="collect")
		if carrying_save.is_empty() and trip.phase=="deliver" and trip._inside_store(trip.worker.folk.position):
			carrying_save=trip.snapshot()
			carrying_position=trip.worker.folk.position
			session._persist_town()
			carrying_town=GameManager.town_people_state.duplicate(true)
		if trip.phase=="inbound":
			for row in trip._collision:
				var centre: Vector2=row[0][0]
				if Ep2GoldTown.collide(centre,row[0][1],town._town_col.walls,[]).distance_to(centre)>.001:
					if clear_of_walls: print("FARMER_WALL_CONTACT ",original.position," circle=",centre)
					clear_of_walls=false
		if i%60==0:await get_tree().process_frame
		if trip.phase=="complete":break
	print("FARMER_PHASES ",stages," phase=",trip.phase," position=",original.position)
	check("he actually reaches the service yard",original.position.distance_to(Ep2FarmerTrip.PARK)<.01)
	check("a real town duel interrupts the errand without moving goods",duel_tested and duel_safe)
	check("his full approach remains outside the real building walls",clear_of_walls)
	check("a real existing worker collects the delivery",stages.has("collect") and stages.has("handover"))
	check("the worker walks into the actual store and back",stages.has("deliver") and stages.has("inspect") and stages.has("return") and trip.phase=="complete")
	check("the same parcel ends on the store counter",trip.delivered and trip.parcel==parcel and parcel.get_parent()==town._visuals)
	check("the background cast is not duplicated",town.get_people().people.size()==Ep2TownPeople.ROSTER.size())
	var planted: bool=original.parked
	for hoof in original.hoof_positions():planted=planted and absf(hoof.y)<.015
	check("a parked donkey has all four soles on the ground",planted)
	check("the same worker resumes the actual route after the draw",resumed)
	var complete: Dictionary=trip.snapshot()
	trip.clear()
	check("the worker returns to his own ambient routine",town.get_people().people.all(func(p):return p.external_owner==""))
	original.free()
	parcel.free()
	trip.enter_town(town,null,complete)
	check("restoring completed business never repeats the handover",trip.phase=="complete" and trip.delivered)
	check("restored wheel phase matches the saved journey",absf(trip.cart.distance_m-float(complete.distance))<.001)
	check("completed delivery restore remains the same town survey",trip.cart.position.distance_to(Ep2FarmerTrip.PARK)<.01)
	check("the actual interior/carry state can be saved",not carrying_save.is_empty())
	var old_cart: Ep2RoadCart=trip.cart
	var old_parcel: Node3D=trip.parcel
	trip.clear()
	old_cart.free()
	old_parcel.free()
	trip.enter_town(town,null,carrying_save)
	check("mid-delivery restore retains the real worker and exact height",trip.worker!=null and trip.worker.folk.position.distance_to(carrying_position)<.001)
	check("mid-delivery restore reconnects the same carried goods",trip.worker!=null and trip.worker.folk.held_prop("FarmerDelivery")==trip.parcel and not trip.delivered)
	GameManager.town_people_state=carrying_town
	var loaded:=Ep2SessionRoot.new()
	add_child(loaded)
	loaded.set_process(false)
	loaded.set_physics_process(false)
	loaded._chain_id="gold_town"
	loaded._enter_chamber_chained(0)
	loaded._active.set_physics_process(false)
	check("a real session load retains the whole town during a shop delivery",is_equal_approx(loaded._active.get_people().elapsed,float(carrying_town.elapsed)) and loaded.farmer_trip.worker!=null and loaded.farmer_trip.worker.folk.position.distance_to(carrying_position)<.001)
	loaded.free()
	var interrupted_worker: Ep2TownPeople.Person=trip.worker
	interrupted_worker.folk.fall_dead()
	trip.tick(session,.1)
	check("a dead delivery worker is never resurrected or replaced mid-carry",interrupted_worker.folk.dead and trip.worker==null and trip.phase=="interrupted")
	check("interrupted goods remain in the actual town",trip.parcel.get_parent()==town._visuals and not trip.delivered)
	trip.tick(session,1)
	check("an interruption cannot silently finish the delivery",trip.phase=="interrupted" and not trip.delivered)
	session.queue_free()
	await get_tree().process_frame
	save_guard.restore()
	print("EP2_FARMER_TRIP: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
