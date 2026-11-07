class_name Ep2SharpsCase
extends Node3D
## RICH'S LIT CASE AND THE SHARPS IN IT (founder 2026-11-07: "improve the way Rich takes it out the glass so that it's not tacky").
##
## Before: Rich stood a step behind the case and reached into the air; at 1.3 s the case rifle (the procedural kit gun) vanished through the
## closed glass and a different model appeared at his hip. Now one rifle (Ep2ArmoryPose.make_rifle, the scoped showcase Sharps) lies in the case
## and is the one he holds. From the intro's own stage clock (Ep2ArmoryIntro.stage_time) this node poses, every tick:
##   the glass lid (Arm2_CaseLid, hinged on its far top edge),
##   the rifle (free in the world while it moves, on his hand bone once it is his), and
##   his two arms (Ep2ArmIK on his UE skeleton): right hand to the lid's pull, lifts it, to the grip, raises the rifle clear of the glass and
##   brings it to his chest, where the left hand takes the fore-end; at the end the arms hand back to the held clip. The put-back is the reverse,
##   and he shuts the lid with his hand.
## Pure function of (stage, seconds): a replay or a skipped frame lands in the same pose.
const POSE := preload("res://src/episode2/actors/ep2_armory_pose.gd")
const SOLVE := preload("res://src/episode2/actors/ep2_ranch_pose.gd")
const Stage := Ep2ArmoryIntro.Stage
## Building-local frame of the Armory (tools/ep2_blender/build_armory2.py): the case is 0.5 x 0.45 x 1.7 m centred on (2.6, -5.2), felt top y 0.92.
const FELT_Y := 0.925
const CASE_CENTRE := Vector3(2.6, 0.0, -5.2)
const RIFLE_X := 2.47                    # off the centre line toward Rich's side, and clear of the lamp tube (x 2.6) as it rises
const LIFT := 0.50                       # how far the rifle rises before it turns to his chest: its belly clears the case top (1.355)
const LID_OPEN := 1.30                   # radians the lid stands open (about 75 degrees)
const PULL := Vector3(2.36, 1.36, -5.45) # the brass pull on Rich's edge of the lid (closed); kept in step with build_armory2.py
const REACH_SPOT := Vector3(2.03, 0.0, -5.45)   # where he stands to reach in: between the counter's end and the case
## Seconds in SHARPS_REACH (out) and SHARPS_BACK (back). Ep2ArmoryIntro owns the stage lengths and the moments the rifle changes hands.
const OUT := {"to_pull": 0.5, "lid": 1.0, "to_grip": 1.5, "lift": 2.1, "to_chest": 2.9}
const BACK := {"to_case": 1.05, "down": 1.65, "to_pull": 2.15, "lid": 2.75, "let_go": 3.25}

var rifle: Node3D = null                 # the rifle while it is not in his hand (in the case, or moving)
var lid: Node3D = null
var lid_angle: float = 0.0
var _xf: Transform3D = Transform3D.IDENTITY      # building -> world
var _hinge: Vector3 = Vector3(2.85, 1.355, -5.2)
var _rest: Transform3D = Transform3D.IDENTITY    # the rifle's grip frame in the case (world)
var _rich: Ep2TownFolk = null
var _ik: Dictionary = {}                 # "Right"/"Left" -> Ep2ArmIK
var _from_hand: Transform3D = Transform3D.IDENTITY   # where the rifle was when he let go of it (the put-back starts there)
var _played: String = ""


## Lay the rifle in the case and find the lid. `kit_rifle` (the old procedural one in the building) is hidden for good. False when the streamed
## rifle is missing: the room then keeps the kit rifle and the old behaviour.
func setup(building: Transform3D, rich: Ep2TownFolk, lid_node: Node3D, kit_rifle: Node3D) -> bool:
	_xf = building
	_rich = rich
	rifle = POSE.make_rifle()
	if rifle == null:
		return false
	add_child(rifle)
	if kit_rifle != null:
		kit_rifle.visible = false
	lid = lid_node
	if lid != null:
		var hinge: Node3D = lid.find_child("Hinge_case", true, false) as Node3D
		if hinge != null:
			_hinge = hinge.position
	# lie it upright on its lever and butt, muzzle to the shop front, centred along the case
	var bb: AABB = Ep2ArmoryShop._bounds(rifle)
	var grip := Vector3(RIFLE_X, FELT_Y - bb.position.y, CASE_CENTRE.z - bb.get_center().z)
	_rest = _xf * Transform3D(Basis.IDENTITY, grip)
	rifle.global_transform = _rest
	if rich != null:
		_install_ik(rich)
	return true


## Where the rifle's grip lies in the case (world): the intro has Rich look at it while he works there.
func rest_point() -> Vector3:
	return _rest.origin


func _install_ik(rich: Ep2TownFolk) -> void:
	var found: Array = rich.model.find_children("*", "Skeleton3D", true, false) if rich.model != null else []
	if found.is_empty():
		return
	var sk: Skeleton3D = found[0]
	for side in ["Right", "Left"]:
		var ik := Ep2ArmIK.new()
		ik.name = "CaseReach" + side
		ik.side = side
		var names := PackedStringArray()
		for part in [side + "Arm", side + "ForeArm", side + "Hand", "Hips"]:
			var b: int = SOLVE._find(sk, part)
			if b < 0:
				ik.free()
				return
			names.append(sk.get_bone_name(b))
		ik.bone_names = names
		ik.influence = 0.0
		sk.add_child(ik)
		_ik[side] = ik


## The rifle is his now (the intro's sharps_lifted): onto the hand bone, out of the world.
func give_to_hand() -> Node3D:
	if _rich == null:
		return null
	var held: Node3D = POSE.attach_rifle(_rich)
	if held != null and rifle != null:
		rifle.visible = false
	return held


## He lets go (the intro's sharps_lifted(false)): the rifle stays exactly where his hand had it, then this node moves it home.
func take_from_hand() -> void:
	if _rich != null:
		var held: Node3D = _rich.held_prop("Sharps")
		_from_hand = held.global_transform if held != null else _chest()
		_rich.drop_prop("Sharps")
	else:
		_from_hand = _rest
	if rifle != null:
		rifle.visible = true
		rifle.global_transform = _from_hand


## Everything home at once: rifle on the felt, lid shut, arms his own (the beat was cancelled, or a room is being left).
func settle() -> void:
	if rifle != null:
		rifle.visible = true
		rifle.global_transform = _rest
	_set_lid(0.0)
	for ik in _ik.values():
		(ik as Ep2ArmIK).influence = 0.0
		(ik as Ep2ArmIK).reaching = false
	_played = ""


## Pose everything for `stage` at `t` seconds into it (called after the intro has stepped).
func update(stage: int, t: float) -> void:
	if rifle == null:
		return
	match stage:
		Stage.SHARPS_REACH:
			_out(t)
		Stage.SHARPS_TALK:
			_set_lid(LID_OPEN)
			_arms(0.0, Vector3.ZERO, 0.0, Vector3.ZERO)
		Stage.SHARPS_BACK:
			_back(t)
		_:
			# out of the beat (it ended, or was cancelled mid-way): whatever is not in his hand goes home
			if rifle.visible and (lid_angle != 0.0 or not rifle.global_transform.is_equal_approx(_rest)):
				settle()
			_arms(0.0, Vector3.ZERO, 0.0, Vector3.ZERO)


func _out(t: float) -> void:
	var grip_wrist: Vector3 = _rest * POSE.wrist_on_rifle("Right")
	if t < OUT["to_pull"]:
		_set_lid(0.0)
		_arms(_ease(t / OUT["to_pull"]), _pull_wrist(0.0), 0.0, Vector3.ZERO)
	elif t < OUT["lid"]:
		var k: float = _ease((t - OUT["to_pull"]) / (OUT["lid"] - OUT["to_pull"]))
		_set_lid(LID_OPEN * k)
		_arms(1.0, _pull_wrist(lid_angle), 0.0, Vector3.ZERO)
	elif t < OUT["to_grip"]:
		_set_lid(LID_OPEN)
		var k: float = _ease((t - OUT["lid"]) / (OUT["to_grip"] - OUT["lid"]))
		_arms(1.0, _pull_wrist(LID_OPEN).lerp(grip_wrist, k), 0.0, Vector3.ZERO)
	elif t < OUT["lift"]:
		_set_lid(LID_OPEN)
		var k: float = _ease((t - OUT["to_grip"]) / (OUT["lift"] - OUT["to_grip"]))
		_place(_rest.translated(Vector3.UP * LIFT * k))
	elif t < OUT["to_chest"]:
		_set_lid(LID_OPEN)
		var k: float = _ease((t - OUT["lift"]) / (OUT["to_chest"] - OUT["lift"]))
		_place(_raised().interpolate_with(_chest(), k), k)
	elif t < Ep2ArmoryIntro.IN_HAND_AT:
		# at his chest: the arms take the rifle's own clip (blending in under the solved arms) before it goes on his hand bone
		_set_lid(LID_OPEN)
		_play("SharpsCounter")
		_place(_chest(), 1.0)
	else:
		_set_lid(LID_OPEN)
		var k: float = 1.0 - _ease((t - Ep2ArmoryIntro.IN_HAND_AT) / 0.4)
		var chest: Transform3D = _chest()
		_arms(k, chest * POSE.wrist_on_rifle("Right"), k, chest * POSE.wrist_on_rifle("Left"))


func _back(t: float) -> void:
	_set_lid(LID_OPEN if t < BACK["to_pull"] else lid_angle)
	if t < Ep2ArmoryIntro.OUT_OF_HAND_AT:
		_arms(0.0, Vector3.ZERO, 0.0, Vector3.ZERO)
		return
	_play("Counter")
	if t < BACK["to_case"]:
		var k: float = _ease((t - Ep2ArmoryIntro.OUT_OF_HAND_AT) / (BACK["to_case"] - Ep2ArmoryIntro.OUT_OF_HAND_AT))
		_place(_from_hand.interpolate_with(_raised(), k), 1.0 - k)
	elif t < BACK["down"]:
		var k: float = _ease((t - BACK["to_case"]) / (BACK["down"] - BACK["to_case"]))
		_place(_raised().interpolate_with(_rest, k))
	elif t < BACK["to_pull"]:
		rifle.global_transform = _rest
		var k: float = _ease((t - BACK["down"]) / (BACK["to_pull"] - BACK["down"]))
		_arms(1.0, (_rest * POSE.wrist_on_rifle("Right")).lerp(_pull_wrist(LID_OPEN), k), 0.0, Vector3.ZERO)
	elif t < BACK["lid"]:
		rifle.global_transform = _rest
		var k: float = _ease((t - BACK["to_pull"]) / (BACK["lid"] - BACK["to_pull"]))
		_set_lid(LID_OPEN * (1.0 - k))
		_arms(1.0, _pull_wrist(lid_angle), 0.0, Vector3.ZERO)
	else:
		rifle.global_transform = _rest
		_set_lid(0.0)
		var k: float = 1.0 - _ease((t - BACK["lid"]) / (BACK["let_go"] - BACK["lid"]))
		_arms(k, _pull_wrist(0.0), 0.0, Vector3.ZERO)


## The rifle at `at`, with his right hand on its grip and (weight `left`) his left on its fore-end.
func _place(at: Transform3D, left: float = 0.0) -> void:
	rifle.visible = true
	rifle.global_transform = at
	_arms(1.0, at * POSE.wrist_on_rifle("Right"), left, at * POSE.wrist_on_rifle("Left"))


func _raised() -> Transform3D:
	return _rest.translated(Vector3.UP * LIFT)


## The rifle's place when he holds it (the held clips' grip, Ep2ArmoryPose.install_rifle), from where he stands now.
func _chest() -> Transform3D:
	return _rich.global_transform * POSE.rifle_frame(_rich) if _rich != null else _raised()


## His wrist on the lid's pull, with the lid at `angle`.
func _pull_wrist(angle: float) -> Vector3:
	var pull: Vector3 = _hinge + Basis(Vector3(0, 0, 1), -angle) * (PULL - _hinge)
	return _xf * (pull + Vector3(-0.07, 0.05, 0.0))


func _set_lid(angle: float) -> void:
	lid_angle = angle
	if lid == null:
		return
	lid.transform = _xf * Transform3D(Basis(Vector3(0, 0, 1), -angle), _hinge) * Transform3D(Basis.IDENTITY, -_hinge)


func _arms(right: float, right_at: Vector3, left: float, left_at: Vector3) -> void:
	for side in _ik:
		var ik: Ep2ArmIK = _ik[side]
		var w: float = right if side == "Right" else left
		ik.influence = clampf(w, 0.0, 1.0)
		ik.reaching = w > 0.001
		ik.target_world = right_at if side == "Right" else left_at


func _play(clip: String) -> void:
	if _rich == null or _played == clip:
		return
	_played = clip
	_rich.hold_clip(clip)
	_rich.play_clip(clip)


static func _ease(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
