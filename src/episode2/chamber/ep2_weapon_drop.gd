class_name Ep2WeaponDrop
extends Node3D
## What a dead gunman leaves (founder 2026-11-07, docs/architecture/adr-ep2-weapon-drops.md): his own gun and its rounds where he fell,
## taken once by walking over it or interact. The record is Ep2ArmoryState.record_drop/claim_drop (saved; no timer, no second inventory).

const WALK_OVER := 0.9      # m: walking or riding over it takes it
const REACH := 2.4          # m: prompt + interact

var drop_id: String = ""
var gun_id: String = ""


## Lays the man's own `gun_node` and a box of rounds at `at` (parent frame). Returns the drop already lying there, or null once taken.
static func place(parent: Node3D, armory: Ep2ArmoryState, id: String, gun: String, rounds: int, at: Vector3, yaw: float,
		gun_node: Node3D = null) -> Ep2WeaponDrop:
	var node_name: String = ("Drop_" + id).validate_node_name()
	var lying: Ep2WeaponDrop = parent.get_node_or_null(NodePath(node_name)) as Ep2WeaponDrop
	if lying != null or armory == null or not armory.record_drop(id, gun, rounds):
		if gun_node != null:
			gun_node.visible = false
		return lying
	var drop := Ep2WeaponDrop.new()
	drop.name = node_name
	drop.drop_id = id
	drop.gun_id = gun
	parent.add_child(drop)
	drop.position = at
	drop.rotation.y = yaw
	if gun_node != null:
		if gun_node.get_parent() != null:
			gun_node.reparent(drop, false)
		else:
			drop.add_child(gun_node)
		# on its side in the dirt
		gun_node.transform = Transform3D(Basis.from_euler(Vector3(0.0, 0.9, PI * 0.5)), Vector3(-0.22, 0.045, 0.12))
		gun_node.visible = true
	# a card cartridge box with a brass label
	var box := MeshInstance3D.new()
	box.name = "AmmoBox"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.045, 0.075)
	box.mesh = mesh
	var card := StandardMaterial3D.new()
	card.albedo_color = Color(0.46, 0.33, 0.20)
	card.roughness = 0.9
	box.material_override = card
	box.position = Vector3(0.2, 0.0225, -0.1)
	box.rotation.y = 0.5
	drop.add_child(box)
	var label := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.112, 0.016, 0.077)
	label.mesh = strip
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.64, 0.40)
	brass.roughness = 0.5
	label.material_override = brass
	box.add_child(label)
	return drop


## The nearest drop within `reach` of `at` (parent frame, flat), or null.
static func nearest(parent: Node, at: Vector3, reach: float = REACH) -> Ep2WeaponDrop:
	if parent == null:
		return null
	var best: Ep2WeaponDrop = null
	var best_d: float = reach
	for child in parent.get_children():
		var drop: Ep2WeaponDrop = child as Ep2WeaponDrop
		if drop == null or not drop.visible:
			continue
		var d: float = Vector2(drop.position.x - at.x, drop.position.z - at.z).length()
		if d < best_d:
			best = drop
			best_d = d
	return best


## Into the armory; {} when nothing was taken. Gone from the world once nothing is left.
func take(armory: Ep2ArmoryState) -> Dictionary:
	var got: Dictionary = armory.claim_drop(drop_id) if armory != null else {}
	if not got.is_empty() and bool(armory.corpses[drop_id]["searched"]):
		visible = false
		queue_free()
	return got


## No key name here: the room adds one only where keys are shown.
func prompt() -> String:
	return "Take %s" % str(Ep2ArmoryState.NAMES.get(gun_id, "gun"))


static func taken_text(got: Dictionary) -> String:
	var gun_name: String = str(Ep2ArmoryState.NAMES.get(str(got.get("gun", "")), "gun"))
	if bool(got.get("new", false)):
		return "%s taken · %d rounds" % [gun_name, int(got.get("rounds", 0))]
	return "+%d %s rounds" % [int(got.get("rounds", 0)), gun_name]
