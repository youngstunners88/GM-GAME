class_name Ep2WeaponDrop
extends Node3D
## WHAT A DEAD GUNMAN LEAVES (founder 2026-11-07): the gun he actually held and the rounds he carried for it, lying in the dirt where he
## fell until Lil Blunt takes them - by walking (or riding) over them, or with the interact control in reach. One rule for every room
## with armed men: the room calls `place()` when a man dies, `nearest()` for its prompt, and `take()` on contact or interact.
## The armory keeps the record (Ep2ArmoryState.record_drop / claim_drop, saved with the searched bodies), so a drop is taken once, a gun
## goes into the one armory (acquire) and its rounds into that gun's own reserve - there is no second inventory and nothing times out.
## A man who dies on a raft goes into the river with his gun: the room places nothing for him (ep2-world-common-sense).

## Walking or riding over the drop takes it.
const WALK_OVER := 0.9
## The prompt shows and the interact control takes it within this reach.
const REACH := 2.4

var drop_id: String = ""
var gun_id: String = ""


## Lays `gun` (the man's own held gun node, moved here) and a box of its rounds on the ground at `at` (parent frame) and records the drop.
## Returns the drop already lying there for `id`, or null once it has been taken (the gun node is then hidden: it went with the first one).
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
		# on its side in the dirt beside the hand that held it
		gun_node.transform = Transform3D(Basis.from_euler(Vector3(0.0, 0.9, PI * 0.5)), Vector3(-0.22, 0.045, 0.12))
		gun_node.visible = true
	# the cartridge box: card with a brass label, the size of a real box of fifty
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


## The drop Lil Blunt can take from `at` (the drops' parent frame, flat distance), nearest first, or null.
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


## Takes it into the armory. {} when nothing could be taken; once nothing is left on the ground the drop is gone from the world.
func take(armory: Ep2ArmoryState) -> Dictionary:
	var got: Dictionary = armory.claim_drop(drop_id) if armory != null else {}
	if not got.is_empty() and bool(armory.corpses[drop_id]["searched"]):
		visible = false
		queue_free()
	return got


## The prompt (no key name: the HUD adds one only where keys are shown; a phone lights its interact button instead).
func prompt() -> String:
	return "Take %s" % str(Ep2ArmoryState.NAMES.get(gun_id, "gun"))


## The line after taking it, e.g. "Borchardt Pistol taken · 8 rounds" or "+8 Borchardt Pistol rounds".
static func taken_text(got: Dictionary) -> String:
	var gun_name: String = str(Ep2ArmoryState.NAMES.get(str(got.get("gun", "")), "gun"))
	if bool(got.get("new", false)):
		return "%s taken · %d rounds" % [gun_name, int(got.get("rounds", 0))]
	return "+%d %s rounds" % [int(got.get("rounds", 0)), gun_name]
