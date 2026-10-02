class_name FacilityShow
extends RefCounted
## The Smelting Facility's scripted performance as DATA: each beat is a list of steps (say a line, walk, reach,
## grab, give, pay, wait...) that this tiny sequencer plays one after another. Founder 2026-10-02: Inferno Bull
## introduces himself, walks to the gun wall, takes the Winchester off the rack, walks to Lil Blunt and hands it
## over, does the same with the miner's helmet, takes one Bitcoin for the pair, tells him the bears have taken the
## Gold Mine and asks him to hunt them together.
##
## Everything here is driven by step(delta) and Ep2Actor/IK timers, never by animation callbacks, so the headless
## test can play the whole show without a frame clock. Skill: ep2-bull-handoff-walk.

var f: Node = null                  # the SmeltingFacilityChamber
var running: bool = false
var _steps: Array = []
var _i: int = -1
var _t: float = 0.0
var _item: Node3D = null            # what the Bull currently carries
var _item_from: Transform3D = Transform3D.IDENTITY


func start(steps: Array) -> void:
	_steps = steps
	_i = -1
	running = true
	_next()


func step(delta: float) -> void:
	if not running or _i < 0 or _i >= _steps.size():
		return
	_t += delta
	if _tick(_steps[_i], delta):
		_next()


func _next() -> void:
	_i += 1
	_t = 0.0
	if _i >= _steps.size():
		running = false
		f._on_show_done()
		return
	_begin(_steps[_i])


# --- one step -------------------------------------------------------------------------------------------

func _begin(s: Dictionary) -> void:
	match str(s["do"]):
		"say":
			var id: String = str(s["id"])
			s["len"] = f._vo_len(id) + float(s.get("gap", 0.18))
			f._hold = float(s["len"])
			f._speak(id)
		"walk":
			f._bull.walk_to(s["to"], float(s.get("speed", -1.0)))
		"face":
			f._bull.face_point(s["at"])
		"reach":
			f._bull.reach(str(s.get("side", "Right")), s["at"], float(s.get("ramp", 0.5)), float(s.get("lean", 0.0)))
		"release":
			f._bull.release(str(s.get("side", "Right")), float(s.get("ramp", 0.4)))
		"clip":
			f._bull_play(str(s["name"]), float(s.get("speed", 1.0)))
		"grab":
			_grab(str(s["item"]))
		"give":
			_give_begin(s)
		"pay":
			f._begin_payment()
		"lb_hop":
			f._hop_v = float(s.get("v", 3.0))
		"call":
			(s["fn"] as Callable).call()
		"unseat":
			f._begin_stand_up()
		_:
			pass


func _tick(s: Dictionary, delta: float) -> bool:
	match str(s["do"]):
		"say":
			return _t >= float(s["len"])
		"wait":
			return _t >= float(s["t"])
		"walk":
			return not f._bull.is_walking()
		"face":
			return f._bull.is_facing(s["at"], 0.25) or _t > 1.6
		"reach":
			return f._bull.reach_weight(str(s.get("side", "Right"))) >= 0.97 and _t >= float(s.get("hold", 0.2)) + float(s.get("ramp", 0.5))
		"release":
			return _t >= float(s.get("t", 0.3))
		"clip":
			return _t >= float(s.get("t", 1.0))
		"give":
			return _give_tick(s)
		"pay":
			return f._payment_done()
		"unseat":
			return f._stand_up_done()
		_:
			return true


# --- items ----------------------------------------------------------------------------------------------

## The Bull takes the item from where it sits and carries it in his right hand (bone attachment).
func _grab(name: String) -> void:
	_item = f._rifle_node if name == "rifle" else f._helmet_node
	if _item == null or not is_instance_valid(_item):
		return
	var hand: Node3D = f._bull.holder("RightHand")
	if hand == null:
		return
	_item.reparent(hand, false)
	_item.position = f.RIFLE_IN_HAND_POS if name == "rifle" else f.HELMET_IN_HAND_POS
	_item.rotation = f.RIFLE_IN_HAND_ROT if name == "rifle" else Vector3.ZERO
	_item.scale = Vector3.ONE * (f.RIFLE_HAND_SCALE if name == "rifle" else f.HELMET_SCALE)


## The item leaves the Bull's hand and goes to Lil Blunt over `t` seconds (rifle -> his hands, helmet -> his head).
func _give_begin(s: Dictionary) -> void:
	if _item == null or not is_instance_valid(_item):
		_item = f._rifle_node if str(s["item"]) == "rifle" else f._helmet_node
	if _item == null:
		return
	_item.reparent(f._visuals, true)
	_item_from = _item.global_transform


func _give_tick(s: Dictionary) -> bool:
	if _item == null or not is_instance_valid(_item):
		return true
	var dur: float = float(s.get("t", 0.7))
	var k: float = clampf(_t / dur, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var to: Vector3 = f.item_target(str(s["item"]))
	_item.global_position = _item_from.origin.lerp(to, k) + Vector3(0.0, 0.12 * sin(k * PI), 0.0)
	if k >= 1.0:
		f._item_delivered(str(s["item"]))
		_item = null
		return true
	return false


# --- the scripts ----------------------------------------------------------------------------------------

static func _say(id: String, gap: float = 0.18) -> Dictionary:
	return {"do": "say", "id": id, "gap": gap}


## Steps for a beat (empty = no script). `f` supplies the marks.
static func steps_for(f: Node, beat: int) -> Array:
	var B = f.Beat
	var lb: Vector3 = f.HAND_MARK
	var offer_spot: Vector3 = lb + Vector3(-1.05, 0.0, 0.0)
	var offer_hand: Vector3 = lb + Vector3(-0.3, 1.75, 0.0)
	match beat:
		B.DRINK:
			# Seated on his crate with his whiskey, he introduces himself: Blaze, Inferno, heat and debt.
			return [_say("vo_bull_intro1"), _say("vo_bull_intro2"), _say("vo_bull_intro3", 0.35),
				_say("vo_lb_intro_reply"), {"do": "wait", "t": 0.4}]
		B.SIZING:
			# He stands, names the price (one Bitcoin for the rifle and the helmet), and Lil Blunt pays.
			return [{"do": "unseat"}, _say("vo_bull_deal1"), _say("vo_bull_deal2", 0.3), _say("vo_lb_deal_ok", 0.1),
				{"do": "pay"}, {"do": "wait", "t": 0.5}]
		B.HANDOFF:
			return [
				{"do": "walk", "to": f.WALL_STAND},
				{"do": "face", "at": f.WALL_RACK_POS},
				{"do": "reach", "at": f.WALL_RACK_POS, "ramp": 0.55, "hold": 0.25, "lean": 0.15},
				{"do": "grab", "item": "rifle"},
				{"do": "release", "ramp": 0.5, "t": 0.45},
				{"do": "call", "fn": f._begin_carry_line.bind("vo_bull_rifle")},
				{"do": "walk", "to": offer_spot},
				{"do": "face", "at": lb},
				{"do": "reach", "at": offer_hand, "ramp": 0.6, "hold": 0.2, "lean": 0.35},
				{"do": "give", "item": "rifle", "t": 0.7},
				{"do": "lb_hop", "v": 2.6},
				{"do": "release", "ramp": 0.5, "t": 0.5},
				{"do": "wait", "t": 0.35}]
		B.HELMET:
			return [
				{"do": "walk", "to": f.HELMET_STAND},
				{"do": "face", "at": f.HELMET_PEG},
				{"do": "reach", "at": f.HELMET_PEG, "ramp": 0.55, "hold": 0.25, "lean": 0.1},
				{"do": "grab", "item": "helmet"},
				{"do": "release", "ramp": 0.5, "t": 0.45},
				{"do": "call", "fn": f._begin_carry_line.bind("vo_bull_helmet2")},
				{"do": "walk", "to": offer_spot},
				{"do": "face", "at": lb},
				{"do": "reach", "at": lb + Vector3(-0.2, 2.15, 0.0), "ramp": 0.6, "hold": 0.2, "lean": 0.3},
				{"do": "give", "item": "helmet", "t": 0.8},
				{"do": "lb_hop", "v": 3.6},
				{"do": "release", "ramp": 0.5, "t": 0.4},
				_say("vo_lb_thanks", 0.2),
				{"do": "wait", "t": 0.3}]
		B.TERMS:
			return [{"do": "walk", "to": f.companion_spot()}, {"do": "face", "at": f.get_player_position()},
				_say("vo_bull_bears", 0.3)]
		B.PROMISE:
			return [_say("vo_bull_partner", 0.3), _say("vo_lb_partner_ok", 0.2)]
		B.EXIT:
			return [_say("vo_bull_exit", 0.1)]
	return []
