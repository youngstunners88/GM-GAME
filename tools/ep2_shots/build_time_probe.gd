extends Node
## How long does the hideout take to build (a synchronous freeze, and a film stutter if it runs while the film plays)?
func _ready() -> void:
	var f: SmeltingFacilityChamber = preload("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	f.intro_film = true
	add_child(f)
	var t0 := Time.get_ticks_msec()
	f.setup(0, [], 0)
	print("BUILDPROBE setup(film) ms=", Time.get_ticks_msec() - t0)
	var t1 := Time.get_ticks_msec()
	f._ensure_room()
	print("BUILDPROBE _ensure_room ms=", Time.get_ticks_msec() - t1)
	get_tree().quit()
