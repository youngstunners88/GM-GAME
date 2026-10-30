extends Node
class Crossing extends SmeltingFacilityChamber:
	func _ready() -> void: pass
	func _exit_open() -> bool: return true
	func _resolve() -> void: _resolved=true
var failed:=0
var checks:=0
func check(label: String,ok: bool) -> void:
	checks+=1
	if not ok:failed+=1
	print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready() -> void:
	var room:=Crossing.new()
	add_child(room)
	room._portal_live=false
	for z in [14.0,15.5,16.39]:
		room._player_pos=Vector3(.7,0,z)
		room._try_exit()
		check("no early transition at z="+str(z),not room._resolved)
	check("an invisible preview never becomes a collision wall",room._walk_through_ok())
	room.handoff_ready=func() -> bool:return false
	check("an unfinished destination still blocks crossing",not room._walk_through_ok())
	room.handoff_ready=func() -> bool:return true
	room._player_pos=Vector3(.7,0,16.42)
	room._look_yaw=PI
	room._try_exit()
	check("looking backward crosses at the actual door",room._resolved)
	var hand: Dictionary=room.get_handoff()
	check("hidden preview carries the actual position",hand.has("lift_player") and hand.lift_player==room._player_pos+room.LIFT_OFFSET)
	check("backward gaze survives the physical handoff",hand.yaw==PI)
	room.free()
	print("EP2_DOOR_CROSSING: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
