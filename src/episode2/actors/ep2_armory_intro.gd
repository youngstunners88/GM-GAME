class_name Ep2ArmoryIntro
extends RefCounted
## RICH AND UTAH INTRODUCE LIL BLUNT TO THE SHARPS 1874 BUFFALO GUN AND THE COLT GATLING GUN (founder 2026-10-20; skill ep2-armory-guns).
##
## One story beat inside the Armory, run by the two shopkeepers' Ep2ArmoryBrains (they are DIRECTED for its length, then released back to their work):
##   1. SHARPS  - Rich walks to the lit case, lifts the rifle out into his hand and introduces it (the buffalo hunters' gun, falling block, 30 in octagon
##                barrel, set triggers, tang sight), holds it out for Lil Blunt to look at, then locks it back. It is the long rifle on his counter: the
##                price is the shop's own (Ep2ArmoryState.SHOP "sniper"), paid in Episode 1 crypto, nothing handed over free.
##   2. GATLING - Utah takes him out the door to the yard, where the Colt Gatling stands on its post. It is NOT FOR SALE (never in the shop): Utah lays it
##                on the iron plates and cranks a burst, then steps aside and offers Lil Blunt the crank. The chamber's mounted mode does the rest.
## Dialogue is timed text (no voice key exists on this box; voice later reads design/ep2/armory/RICH_UTAH_LINES.md section 4 verbatim).
## Pure logic: `step(delta, player_world)` is called by the chamber, a fixed seed and fixed timings replay exactly (tests/ep2_armory_guns_test.gd).

signal said(who: String, text: String, seconds: float)
signal objective_changed(text: String)
signal sharps_lifted(in_hand: bool)            # the chamber swaps the case rifle for the one in Rich's hand
signal finished

enum Stage { IDLE, RICH_WALK, SHARPS_REACH, SHARPS_TALK, SHARPS_BACK, GATLING_WALK, GATLING_WAIT, GATLING_DEMO, GATLING_OFFER, GATLING_FREE, DONE }

const LINE_S := 4.2                              # a line stays up this long
## Rich at the lit case. {price} is filled from the shop's own price list.
const SHARPS_LINES: Array = [
	["RICH", "Lil Blunt. Come in off the street. Mind the glass. This is what the river wants."],
	["RICH", "A Sharps, Model 1874. The buffalo hunters called her the Buffalo Gun."],
	["UTAH", "Falling block. One shot, then you earn the next one."],
	["RICH", "Thirty-inch octagon barrel, double set triggers, a tang sight you can read at six hundred yards."],
	["RICH", "Set the back trigger and the front one breaks at a whisper. Take a look. Don't take her home yet."],
	["RICH", "{price} coin and she is yours, cartridges by the box. Coin, never credit."],
]
## Utah at the post.
const GATLING_CALL: Array = [["UTAH", "Now the one that is not for sale. Follow me out front."]]
const GATLING_LINES: Array = [
	["UTAH", "Colt Gatling Gun. Six barrels, a drum on top, a crank on the side."],
	["UTAH", "Doctor Gatling's patent, built by Colt. Turn the crank and the barrels turn with it. Watch the plates."],
]
const GATLING_AFTER: Array = [
	["UTAH", "Bolted to the porch. Not for coin, not for gold. Rich will not sell her and I will not let him."],
	["RICH", "She stays on the post, Lil Blunt. When the river comes you will want her near the bank."],
	["UTAH", "Go on. Take the crank. Short bursts. The drum is all there is."],
]
const CLOSING := ["UTAH", "Steady hands. Remember her when the shipment comes down."]
const FOLLOW_R := 7.0                            # how close he must come to Utah at the post for the demonstration to start
const FOLLOW_WAIT_MAX := 45.0                    # ...or Utah starts anyway
const FREE_MAX := 120.0                          # how long the offer stands before Utah closes it himself

var stage: int = Stage.IDLE
var rich: Ep2ArmoryBrain = null
var utah: Ep2ArmoryBrain = null
var gatling: Ep2GatlingPost = null
var sharps_price: int = 3
var demo_target: Vector3 = Vector3.ZERO          # a world point on the first plate: Utah lays the gun on it
var mounted: bool = false                        # set by the chamber
var player_bursts: int = 0                       # bursts Lil Blunt has fired from the post
var shown_lines: Array = []                      # every [who, text] said, in order (the test reads it)
var voice_seconds: Callable = Callable()         # the chamber supplies actual recorded duration; standalone logic keeps LINE_S

var _t: float = 0.0
var _i: int = 0
var _line_t: float = 0.0
var _lifted: bool = false
var _utah_arrived: bool = false
var _rich_arrived: bool = false
var _burst_done: bool = false
var _free_t: float = 0.0
var _demo_step: int = 0


func is_busy() -> bool:
	return stage != Stage.IDLE and stage != Stage.DONE


func is_done() -> bool:
	return stage == Stage.DONE


## Lil Blunt may take the crank once Utah has offered it (and for good afterwards).
func mount_allowed() -> bool:
	return stage == Stage.GATLING_OFFER or stage == Stage.GATLING_FREE or stage == Stage.DONE


func begin() -> void:
	if stage != Stage.IDLE:
		return
	stage = Stage.RICH_WALK
	_t = 0.0
	_i = 0
	_rich_arrived = false
	_utah_arrived = false
	rich.directed_arrived.connect(_on_arrived)
	utah.directed_arrived.connect(_on_arrived)
	rich.direct("sniper_case", "Idle", Vector3(0.4, 1.5, -3.1))
	utah.direct("front_mid", "Idle", Vector3(0.4, 1.5, -3.1))
	objective_changed.emit("Rich is calling you over to the lit case.")


## Hand both men back to their work and put everything away (the beat ended, or the room is being left).
func cancel() -> void:
	if stage == Stage.IDLE or stage == Stage.DONE:
		return
	_finish_directing()
	if _lifted:
		_lifted = false
		sharps_lifted.emit(false)
	stage = Stage.DONE
	finished.emit()


## Skip the introduction outright (a visit that has already had it, or a test): put anything away and mark it DONE, so the Gatling is
## free to take even when the introduction never began.
func skip() -> void:
	cancel()
	stage = Stage.DONE


func _on_arrived(who: String, _spot: String) -> void:
	if who == "rich":
		_rich_arrived = true
	elif who == "utah":
		_utah_arrived = true


func step(delta: float, player_world: Vector3) -> void:
	if stage == Stage.IDLE or stage == Stage.DONE:
		return
	_t += delta
	_line_t = maxf(0.0, _line_t - delta)
	match stage:
		Stage.RICH_WALK:
			if _rich_arrived:
				stage = Stage.SHARPS_REACH
				_t = 0.0
				rich.direct_here("Reach", player_world, true)
		Stage.SHARPS_REACH:
			rich.folk.face_point(player_world)
			if not _lifted and _t >= 1.3:
				_lifted = true
				sharps_lifted.emit(true)
			if _t >= 2.9:
				stage = Stage.SHARPS_TALK
				_t = 0.0
				_i = 0
				_say_next(SHARPS_LINES, "InspectRifle")
		Stage.SHARPS_TALK:
			rich.folk.face_point(player_world)
			utah.folk.face_point(player_world)
			if _line_t <= 0.0:
				if _i >= SHARPS_LINES.size():
					stage = Stage.SHARPS_BACK
					_t = 0.0
					rich.direct_here("PutDown", player_world, true)
				else:
					# the rifle held up while he describes it, then offered, then back to rest
					_say_next(SHARPS_LINES, "InspectRifle" if _i == 1 or _i == 3 else ("Reach" if _i == 4 else "Talk"))
		Stage.SHARPS_BACK:
			rich.folk.face_point(player_world)
			if _lifted and _t >= 1.4:
				_lifted = false
				sharps_lifted.emit(false)
			if _t >= 2.9:
				rich.release()
				_begin_gatling()
		Stage.GATLING_WALK:
			if _line_t <= 0.0 and _utah_arrived:
				stage = Stage.GATLING_WAIT
				_t = 0.0
				objective_changed.emit("Join Utah at the Gatling post, out front.")
		Stage.GATLING_WAIT:
			utah.folk.face_point(demo_target)
			if player_world.distance_to(utah.folk.position) < FOLLOW_R or _t > FOLLOW_WAIT_MAX:
				stage = Stage.GATLING_DEMO
				_t = 0.0
				_i = 0
				_demo_step = 0
				utah.direct_here("Crank", demo_target, true)
				_say_next(GATLING_LINES, "")
		Stage.GATLING_DEMO:
			_step_demo(delta)
		Stage.GATLING_OFFER:
			if mounted:
				stage = Stage.GATLING_FREE
				_free_t = 0.0
				objective_changed.emit("At the Gatling: click to fire, [E] to step away.")
			elif _line_t <= 0.0 and _i < GATLING_AFTER.size():
				_say_next(GATLING_AFTER, "")
		Stage.GATLING_FREE:
			_free_t += delta
			utah.folk.face_point(demo_target)
			# he fired a burst, or he stepped away after trying it, or the offer stood long enough: Utah closes it
			if (player_bursts > 0 and not mounted and _line_t <= 0.0) or _free_t > FREE_MAX:
				_close()


func _begin_gatling() -> void:
	stage = Stage.GATLING_WALK
	_t = 0.0
	_utah_arrived = false
	_i = 0
	_say(GATLING_CALL[0][0], GATLING_CALL[0][1])
	utah.direct("gatling_stand", "Idle", demo_target, true)
	objective_changed.emit("Follow Utah out the door.")


## Utah lays the gun on the first plate, cranks a burst, then the closing lines (the gun and the plates are the chamber's).
func _step_demo(delta: float) -> void:
	utah.folk.face_point(demo_target)
	match _demo_step:
		0:
			if gatling != null:
				gatling.aim_toward(demo_target, delta, 1.5)
			if _line_t <= 0.0:
				if _i < GATLING_LINES.size():
					_say_next(GATLING_LINES, "")                 # he explains the gun while he lays it on the plate
				elif gatling == null or gatling.aim_error(demo_target) < 0.05 or _t > 12.0:
					_demo_step = 1
					_t = 0.0
		1:
			if gatling != null:
				gatling.fire_burst(1.6)
				gatling.aim_toward(demo_target + Vector3(0.0, 0.0, 0.0), delta, 0.8)
			if _t > 2.2:
				_demo_step = 2
				_t = 0.0
				if gatling != null:
					gatling.cease()
				_i = 0
				_say_next(GATLING_AFTER, "Talk")
		2:
			if _line_t <= 0.0:
				if _i < GATLING_AFTER.size():
					_say_next(GATLING_AFTER, "Talk")
				else:
					stage = Stage.GATLING_OFFER
					_t = 0.0
					utah.direct("gatling_look", "Idle", demo_target, true)
					objective_changed.emit("Take the crank [E].")


func _close() -> void:
	_say(CLOSING[0], CLOSING[1])
	_finish_directing()
	stage = Stage.DONE
	objective_changed.emit("")
	finished.emit()


func _finish_directing() -> void:
	if rich != null:
		if rich.directed_arrived.is_connected(_on_arrived):
			rich.directed_arrived.disconnect(_on_arrived)
		rich.release()
	if utah != null:
		if utah.directed_arrived.is_connected(_on_arrived):
			utah.directed_arrived.disconnect(_on_arrived)
		utah.release()
	if gatling != null:
		gatling.cease()


func _say_next(lines: Array, clip: String) -> void:
	var ln: Array = lines[_i]
	_i += 1
	_say(str(ln[0]), str(ln[1]).replace("{price}", _price_words()))
	var who: Ep2ArmoryBrain = rich if str(ln[0]) == "RICH" else utah
	if clip != "" and who != null and who.directed:
		who.folk.hold_clip(clip)


func _say(who: String, text: String) -> void:
	shown_lines.append([who, text])
	_line_t = LINE_S
	if not voice_seconds.is_null():
		_line_t = maxf(LINE_S, float(voice_seconds.call(who, text)))
	said.emit(who, text, _line_t - 0.15)


func _price_words() -> String:
	var words: Array = ["No", "One", "Two", "Three", "Four", "Five", "Six"]
	return words[sharps_price] if sharps_price >= 0 and sharps_price < words.size() else str(sharps_price)
