class_name Ep2FarmerTrip
extends RefCounted
## One simulation owner carries the actual road cart into town and a shop delivery.
const PARK := Vector3(-22,0,1421.5)
const PHASES := ["inbound","waiting","collect","handover","deliver","inspect","return","complete","interrupted"]
var cart: Ep2RoadCart
var town: GoldTownChamber
var phase: String="inbound"
var timer: float=0
var travelled: float=0
var delivered: bool=false
var points := PackedVector3Array()
var arc := PackedFloat32Array()
var worker: Ep2TownPeople.Person
var parcel: Node3D
var _crowd: Ep2TownPeople
var _collision: Array=[]

func enter_town(room: GoldTownChamber,woods: Node,saved: Dictionary={}) -> void:
	if town==room and is_instance_valid(cart):return
	town=room
	_crowd=room.get_people()
	if is_instance_valid(woods) and is_instance_valid(woods._cart):
		cart=woods._cart as Ep2RoadCart
		woods._cart_external=true
		cart.reparent(town._visuals,false)
	else:
		cart=Ep2RoadCart.new()
		town._visuals.add_child(cart)
		cart.build(WoodsQuadChamber.CART_MODEL,WoodsQuadChamber.CART_SCALE)
		var road: PackedVector3Array=Ep2LakeRoad.smooth(WoodsQuadChamber.RIDE_TRAIL,1.5)
		var start: Array=_sample(road,_lengths(road),WoodsQuadChamber.CART_S0)
		cart.position=start[0]+Vector3(-cos(start[1]),0,sin(start[1]))*WoodsQuadChamber.CART_LATERAL
		cart.rotation.y=start[1]
	_make_path(woods)
	parcel=_crowd._parcel()
	parcel.name="FarmerDelivery"
	cart.add_child(parcel)
	parcel.position=Vector3(.95,1.10,-.6)
	if not saved.is_empty():_restore(saved)
	_place()
	if phase!="inbound":cart.set_parked(true)
	# Shared mutable circles follow him and remain in the retained town survey.
	for z in [-2.5,0,2.3]:
		var circle: Array=[Vector2.ZERO,.9 if z<2 else .65]
		_collision.append([circle,float(z)])
		town._town_col.props.append(circle)
	_update_collision()

func _make_path(woods: Node) -> void:
	points=PackedVector3Array([cart.position])
	var road: PackedVector3Array=woods._ride_pts if is_instance_valid(woods) else Ep2LakeRoad.smooth(WoodsQuadChamber.RIDE_TRAIL,1.5)
	for i in range(1,road.size()-1,4):
		if road[i].z<=cart.position.z+.5 or road[i].z>=1374:continue
		var tangent: Vector3=(road[i+1]-road[i-1]).normalized()
		points.append(road[i]+Vector3(-tangent.z,0,tangent.x)*WoodsQuadChamber.CART_LATERAL)
	var last: Vector3=points[-1]
	var bends: Array=[Vector2(last.x,last.z)]
	if last.z<1374:
		bends.append_array([Vector2(-3.1,1379),Vector2(-4.5,1385),Vector2(-13,1388),Vector2(-20,1392),Vector2(-22,1402)])
	else:
		bends.append_array([Vector2(-5,1404),Vector2(-13,1404),Vector2(-20,1405),Vector2(-22,1412)])
	bends.append(Vector2(PARK.x,PARK.z))
	var curve: PackedVector3Array=Ep2LakeRoad.smooth(bends,1.5)
	for i in range(1,curve.size()):points.append(curve[i])
	arc=_lengths(points)

func _lengths(path: PackedVector3Array) -> PackedFloat32Array:
	var out:=PackedFloat32Array([0.0])
	for i in range(1,path.size()):out.append(out[-1]+path[i].distance_to(path[i-1]))
	return out

func _sample(path: PackedVector3Array,lengths: PackedFloat32Array,s: float) -> Array:
	var i: int=1
	s=clampf(s,0,lengths[-1])
	while i<lengths.size()-1 and lengths[i]<s:i+=1
	var a: Vector3=path[i-1]
	var b: Vector3=path[i]
	return [a.lerp(b,(s-lengths[i-1])/maxf(.001,lengths[i]-lengths[i-1])),atan2(b.x-a.x,b.z-a.z)]

func _place() -> void:
	var pose: Array=_sample(points,arc,travelled)
	cart.position=pose[0]
	cart.rotation.y=pose[1]

func tick(session: Node,delta: float) -> void:
	if not is_instance_valid(cart) or not is_instance_valid(town) or delta<=0 or not is_finite(delta) or session.get_tree().paused:return
	delta=minf(delta,.5)
	# Both outdoor rooms use the same survey; the mounted world adopts town visuals.
	var parent: Node3D=town._visuals
	if is_instance_valid(session._active) and session._active is WoodsQuadChamber:parent=session._active._visuals
	if cart.get_parent()!=parent:cart.reparent(parent,false)
	if phase=="inbound":
		var before: Vector3=cart.position
		travelled=minf(arc[-1],travelled+WoodsQuadChamber.CART_SPEED*delta)
		_place()
		cart.set_parked(false)
		cart.advance_motion(delta,cart.position.distance_to(before))
		if travelled>=arc[-1]:
			phase="waiting"
			cart.set_parked(true)
	else:
		cart.advance_motion(delta,0)
		_business(delta)
	_update_collision()

func _update_collision() -> void:
	for row in _collision:
		var at: Vector3=cart.position+cart.basis*Vector3(0,0,row[1])
		row[0][0]=Vector2(at.x,at.z)

func _plan(target: Vector3,indoor: bool=false) -> bool:
	if indoor and Ep2GoldTown.shop_spots("Bldg_A").is_empty():return false
	var at: Vector3=worker.folk.position
	if indoor and _inside_store(at):
		target.y=Ep2GoldTown.shop_floor_y("Bldg_A",target)
		worker.folk.walk_path([target],worker.speed)
		return true
	var end: Vector3=Ep2GoldTown.shop_spots("Bldg_A").out if indoor else target
	var route: Array=[]
	for point in _crowd.navigation.path(Vector2(at.x,at.z),Vector2(end.x,end.z)):
		route.append(Vector3(point.x,0,point.y))
	if route.is_empty() and at.distance_to(end)>2:return false
	route.append(end)
	if indoor:
		var xf: Transform3D=Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_A"))
		route.append(xf*Vector3(0,Ep2GoldTown.PORCH_Y,1.3))
		var door: Vector3=Ep2GoldTown.shop_spots("Bldg_A").door
		door.y=Ep2GoldTown.shop_floor_y("Bldg_A",door)
		target.y=Ep2GoldTown.shop_floor_y("Bldg_A",target)
		route.append(door)
		route.append(target)
	worker.folk.use_height=true
	worker.folk.walk_path(route,worker.speed)
	return true

func _inside_store(at: Vector3) -> bool:
	var xf: Transform3D=Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_A"))
	var local: Vector3=xf.affine_inverse()*at
	return local.z<-.3 and local.z>-7.7 and absf(local.x)<3.2

func _leave_store() -> void:
	var shop: Dictionary=Ep2GoldTown.shop_spots("Bldg_A")
	if _inside_store(worker.folk.position):
		var porch: Vector3=Ep2GoldTown.local_to_world("Bldg_A",Vector3(0,Ep2GoldTown.PORCH_Y,1.3))
		var door: Vector3=shop.door
		door.y=Ep2GoldTown.shop_floor_y("Bldg_A",door)
		worker.folk.walk_path([door,porch,shop.out],worker.speed)
	else:_plan(shop.out)

func _business(delta: float) -> void:
	if phase in ["complete","interrupted"]:return
	if phase=="waiting":
		if Ep2GoldTown.shop_spots("Bldg_A").is_empty():return
		timer=maxf(0,timer-delta)
		if timer>0:return
		for id in ["bald_worker","rancher","youth"]:
			worker=_crowd.reserve_delivery(id)
			if worker!=null:break
		if worker==null:return
		if not _plan(PARK+Vector3(1.45,0,-.6)):
			_crowd.release_delivery(worker)
			worker=null
			timer=5
			return
		phase="collect"
		return
	if worker==null or not is_instance_valid(worker.folk) or worker.folk.dead:
		var carrying: bool=is_instance_valid(parcel) and parcel.get_parent()!=cart and not delivered
		if carrying:
			parcel.reparent(town._visuals,true)
			parcel.position.y=Ep2GoldTown.shop_floor_y("Bldg_A",parcel.position)+.08
		if worker!=null:_crowd.release_delivery(worker)
		worker=null
		phase="interrupted" if carrying else ("complete" if delivered else "waiting")
		return
	if _crowd._mode!="normal" or worker.state in ["flee","shelter"]:return
	worker.folk.step(delta)
	match phase:
		"collect":
			if not worker.folk.is_walking():
				if worker.folk.position.distance_to(PARK+Vector3(1.45,0,-.6))>.25:
					_plan(PARK+Vector3(1.45,0,-.6))
					return
				worker.folk.face_point(PARK+Vector3(.95,0,-.6))
				worker.folk.hold_clip("Inspect")
				cart.greet()
				timer=3
				phase="handover"
		"handover":
			if worker.folk.position.distance_to(PARK+Vector3(1.45,0,-.6))>.5:
				phase="collect" if parcel.get_parent()==cart else "deliver"
				if phase=="collect":_plan(PARK+Vector3(1.45,0,-.6))
				else:_plan(Ep2GoldTown.shop_spots("Bldg_A").counter,true)
				return
			timer-=delta
			if timer<=1.5 and parcel.get_parent()==cart:_carry()
			if timer<=0:
				if _plan(Ep2GoldTown.shop_spots("Bldg_A").counter,true):phase="deliver"
				else:timer=2
		"deliver":
			if not worker.folk.is_walking():
				if worker.folk.position.distance_to(Ep2GoldTown.shop_spots("Bldg_A").counter)>.25:
					_plan(Ep2GoldTown.shop_spots("Bldg_A").counter,true)
					return
				parcel.reparent(town._visuals,false)
				parcel.scale=Vector3.ONE
				parcel.position=Ep2GoldTown.local_to_world("Bldg_A",Ep2GoldTown.WALKIN_SHOPS.Bldg_A[1]+Vector3(0,1.10,-.05))
				worker.folk.drop_prop("FarmerDelivery")
				worker.folk.hold_clip("Inspect")
				delivered=true
				timer=2
				phase="inspect"
		"inspect":
			timer-=delta
			if timer<=0:
				_leave_store()
				phase="return"
		"return":
			if not worker.folk.is_walking():
				if worker.folk.position.distance_to(Ep2GoldTown.shop_spots("Bldg_A").out)>.25:
					_leave_store()
					return
				_crowd.release_delivery(worker)
				worker=null
				phase="complete"

func _carry() -> void:
	parcel.get_parent().remove_child(parcel)
	if not worker.folk.attach_prop(parcel,"RightHand",Vector3(0,-.08,.06)):
		cart.add_child(parcel)
		parcel.position=Vector3(.95,1.10,-.6)

func snapshot() -> Dictionary:
	var path: Array=[]
	for point in points:path.append([point.x,point.y,point.z])
	var record: Dictionary={"id":"road_farmer","phase":phase,"s":travelled,"timer":timer,"path":path,"distance":cart.distance_m,"clock":cart._time,"greeting":cart.greeting_time,"delivered":delivered}
	if phase=="interrupted" and is_instance_valid(parcel):record["dropped_position"]=[parcel.position.x,parcel.position.y,parcel.position.z]
	if worker!=null:
		var goals: Array=[]
		if worker.folk.is_walking():
			for p in [worker.folk._goal]+worker.folk._path:goals.append([p.x,p.y,p.z])
		var pos: Vector3=worker.folk.position
		record["worker"]={"id":worker.id,"position":[pos.x,pos.y,pos.z],"goals":goals,"carrying":parcel.get_parent()!=cart and not delivered}
	return record

func _vec(value: Variant) -> Variant:
	if not value is Array or value.size()!=3:return null
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n))>10000:return null
	return Vector3(value[0],value[1],value[2])

func _number(value: Variant,fallback: float,low: float,high: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):return fallback
	return clampf(float(value),low,high)

func _restore(data: Dictionary) -> void:
	var rows: Variant=data.get("path",[])
	if not rows is Array or rows.size()<2 or rows.size()>2048:return
	var restored := PackedVector3Array()
	for row in rows:
		var p: Variant=_vec(row)
		if p==null:return
		restored.append(p)
	points=restored
	arc=_lengths(points)
	travelled=_number(data.get("s",0),0,0,arc[-1])
	phase=str(data.get("phase","inbound"))
	if phase not in PHASES:phase="inbound"
	timer=_number(data.get("timer",0),0,0,10)
	delivered=bool(data.get("delivered",false))
	cart.distance_m=_number(data.get("distance",0),0,0,10000000)
	cart._time=_number(data.get("clock",0),0,0,10000000)
	cart.greeting_time=_number(data.get("greeting",-1),-1,-1,3)
	if delivered:
		parcel.reparent(town._visuals,false)
		parcel.position=Ep2GoldTown.local_to_world("Bldg_A",Ep2GoldTown.WALKIN_SHOPS.Bldg_A[1]+Vector3(0,1.10,-.05))
	if phase=="interrupted":
		parcel.reparent(town._visuals,false)
		var dropped: Variant=_vec(data.get("dropped_position",[]))
		parcel.position=dropped if dropped!=null else PARK+Vector3(1.45,.08,-.6)
	var w: Variant=data.get("worker",{})
	if not w is Dictionary or w.is_empty():
		if phase not in ["inbound","complete","interrupted"]:phase="waiting"
		return
	worker=_crowd.reserve_delivery(str(w.get("id","")),true)
	if worker==null:
		phase="waiting" if not delivered else "complete"
		return
	var pos: Variant=_vec(w.get("position",[]))
	worker.folk.use_height=true
	if pos!=null:worker.folk.place(pos)
	var goals: Array=[]
	var stored_goals: Variant=w.get("goals",[])
	if not stored_goals is Array:stored_goals=[]
	for row in stored_goals.slice(0,128):
		var goal: Variant=_vec(row)
		if goal!=null:goals.append(goal)
	if not goals.is_empty():worker.folk.walk_path(goals,worker.speed)
	else:worker.folk.hold_clip("Inspect")
	if bool(w.get("carrying",false)) and not delivered:_carry()

func clear() -> void:
	if worker!=null and _crowd!=null:_crowd.release_delivery(worker)
	if is_instance_valid(town):
		for row in _collision:town._town_col.props.erase(row[0])
	worker=null
	cart=null
	town=null
	_crowd=null
	_collision.clear()
