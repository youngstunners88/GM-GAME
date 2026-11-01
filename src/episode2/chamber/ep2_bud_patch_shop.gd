class_name Ep2BudPatchShop
extends Ep2ArmoryShop
## DUDE'S CHILL BUD PATCH, the purchase panel (founder 2026-11-01: buy more "just like the way he purchases from the armory"). The same
## leather-and-brass cabinet as Rich & Utah's counter, with the patch's stock (Ep2BudPatch.STOCK), its own heading, and a Chill Bud
## plant turning slowly in the display case. Like the armory it only raises `buy_requested`; the room debits the purse and stores the
## buds in Tabs. Buds are never "owned": the patch always sells while the purse can pay.


func _init() -> void:
	heading_small = "DUDE'S PATCH"
	heading = "CHILL BUDS"
	footer_a = "GROWN RIGHT HERE ON THE RANCH  ·  STORED IN YOUR TABS"
	footer_b = "ONE BUD BRINGS BACK ALL THREE HEARTS"


func _catalogue() -> Array:
	return Ep2BudPatch.STOCK


func _item(id: String) -> Dictionary:
	return Ep2BudPatch.item(id)


func _owned(_item_row: Dictionary) -> bool:
	return false


func _available(item: Dictionary) -> bool:
	return purse >= int(item["price"])


func _showcase_key_for(_item_row: Dictionary) -> String:
	return "chill_bud"


func _showcase_model(_key: String) -> Node3D:
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.30, 0.58, 0.22)
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bud_mat := StandardMaterial3D.new()
	bud_mat.albedo_color = Color(0.52, 0.70, 0.30)
	return Ep2BudPatch._plant(Ep2BudPatch._leaflet(), leaf_mat, bud_mat, 0.6, 0.0)


## Drawn without an armory state (the base panel draws nothing until one is bound).
func open_patch(coin_purse: int) -> void:
	open_shop(Ep2ArmoryState.new(), coin_purse)
