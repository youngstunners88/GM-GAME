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
	# THE LAVA CROSSING (founder 2026-11-10): the path must open the frame he is over the flaming liquid, never after Inferno's line,
	# and the praise must be said exactly once however many times the show and the crossing tick both ask for it.
	var lava := SmeltingFacilityChamber.new()
	add_child(lava)
	lava._running = true
	lava._beat = lava.Beat.EXIT
	lava._lava_on = true
	lava._show_active = true                     # the show is still running (his "hop over" line is playing)
	lava._exit_line_end = 0.0                    # ...and "made it" has not started
	lava._player_pos = Vector3(0.0, 0.0, lava.CHANNEL_Z - 1.0)
	check("the far bank is still shut before he jumps", not lava._exit_open())
	lava._player_pos = Vector3(0.0, 0.0, lava.CHANNEL_Z + lava.LAVA_HALF + 1.0)
	check("crossing the lava opens the walkway while Inferno is still talking", lava._exit_open())
	var said: Array = []
	lava.line_spoken.connect(func(id: String) -> void: said.append(id))
	lava._elapsed = 10.0
	lava._line_end = 14.0                        # he is mid-line: the praise must queue, never talk over him
	lava._exit_made_it()
	lava._exit_made_it()
	check("the praise waits for the line in flight", said.is_empty() and lava._praise_at > 10.0)
	lava._elapsed = 14.1
	lava._exit_praise_tick()
	lava._exit_praise_tick()
	check("...then it is said once", said == ["vo_bull_lava_made_it"])
	lava.free()
	print("EP2_DOOR_CROSSING: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
