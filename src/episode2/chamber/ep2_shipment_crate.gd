class_name Ep2ShipmentCrate
extends RefCounted
## THE SHIPMENT - one hero model for every place it shows (founder 2026-11-04, day-88 river cover lock section 5): Rich & Utah's trade
## case, the slow spin in Tabs, and the crate that rides the day-88 river. It is the founder's Meshy crate (timber, iron straps, rope,
## the Gold Mine stamp) streamed in the Episode 2 extras pack; until that pack has mounted every place shows the same procedural skiff
## and sealed crates (Ep2ArmoryShop._water_gear_model). Logistics gear, never a firearm: jail confiscation does not touch it.


## Where the model comes from right now: the streamed path, or "procedural" before the pack mounted. Tests compare this across places.
static func source() -> String:
	return Ep2Extras.SHIPMENT if Ep2Extras.has(Ep2Extras.SHIPMENT) else "procedural"


## A fresh instance of the shipment, tagged with its `shipment_source` meta. `size_m` > 0 fits its longest side to that many metres,
## centred on X/Z with its base on y = 0 (the trade case fits its own pieces, so it passes 0).
static func model(size_m: float = 0.0) -> Node3D:
	var src: String = source()
	var piece: Node3D
	if src != "procedural":
		piece = (load(src) as PackedScene).instantiate() as Node3D
	else:
		piece = Ep2ArmoryShop._water_gear_model()
	var root := Node3D.new()
	root.name = "Shipment"
	root.set_meta("shipment_source", src)
	root.add_child(piece)
	if size_m > 0.0:
		var box: AABB = Ep2ArmoryShop._bounds(piece)
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		if longest > 0.0001:
			var k: float = size_m / longest
			piece.scale = Vector3.ONE * k
			var c: Vector3 = box.get_center()
			piece.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)
	return root
