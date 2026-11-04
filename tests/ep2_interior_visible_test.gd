extends Node
## Founder 2026-11-04 (screenshot 1, "the contents of the certificates office need to be visible"): the room behind an open town door is there
## on approach, in EVERY copy of the town. The objective in his frame came from the WOODS chamber: after the drop-off he stands in the woods'
## copy of the town until the hand-over, and that copy was built with no interiors, so the office filled up only as he reached it.
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


## Every drawn node of the office in this room, by name: what a person on the street could see through the door.
func _office_contents(root: Node) -> Dictionary:
	var found: Dictionary = {}
	for name in ["Int_Counter_Bldg_Certificates", "Int_Shelves_Bldg_Certificates", "Int_Desk_Bldg_Certificates", "Int_Stove_Bldg_Certificates", "LicenseWall"]:
		var n: Node3D = root.find_child(name, true, false) as Node3D
		found[name] = n != null and n.is_visible_in_tree()
	return found


func _lit_office(root: Node) -> bool:
	var lamp: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.0, 3.0, -4.0))
	for l in root.find_children("*", "OmniLight3D", true, false):
		if (l as OmniLight3D).global_position.distance_to(lamp) < 0.5:
			return (l as OmniLight3D).is_visible_in_tree()
	return false


func _ready() -> void:
	print("-- EP2 INTERIORS VISIBLE ON APPROACH")
	var woods: WoodsQuadChamber = WOODS.instantiate() as WoodsQuadChamber
	add_child(woods)
	woods.set_physics_process(false)
	woods.setup(0, [], 0)
	var seen: Dictionary = _office_contents(woods)
	for k in seen:
		check("the woods' copy of the town: %s stands in the office before he reaches it" % k, bool(seen[k]))
	check("the woods' copy: the office lamp is lit (a dark room shows nothing from the street)", _lit_office(woods))
	var sheriff: Node3D = woods.find_child("OfficeSheriff", true, false) as Node3D
	var dean: Node3D = woods.find_child("OfficeMikeDean", true, false) as Node3D
	check("the woods' copy: the Sheriff is at his mark", sheriff != null and sheriff.is_visible_in_tree())
	check("the woods' copy: Mike Dean is behind his counter", dean != null and dean.is_visible_in_tree())
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	seen = _office_contents(town)
	for k in seen:
		check("the town chamber: %s stands in the office" % k, bool(seen[k]))
	if sheriff != null and dean != null:
		check("no pop at the hand-over: the Sheriff stands where the woods showed him", sheriff.global_position.distance_to(town.get_sheriff().global_position) < 0.2,
			"%s vs %s" % [sheriff.global_position, town.get_sheriff().global_position])
		var town_dean: Node3D = town.find_child("MinisterMikeDean", true, false) as Node3D
		check("no pop at the hand-over: Mike Dean stands where the woods showed him", town_dean != null and dean.global_position.distance_to(town_dean.global_position) < 0.2)
	# the objective on screen in that stretch is the story's current one, not the old certificate wording
	var src: String = FileAccess.get_file_as_string("res://src/episode2/chamber/woods_quad.gd")
	check("the drop-off's objective speaks of the Miner's License, not the old 'sort you a certificate'", not ("sort you a certificate" in src))
	woods.free()
	town.free()
	print("INTERIOR_VISIBLE: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
