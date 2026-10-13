extends Node
## How long each background build step of the bear woods takes (the slices run while the lift rises: a step over ~16 ms is a
## dropped frame there). Prints every step's ms and the total.
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")


func _ready() -> void:
	var w: WoodsQuadChamber = WOODS.instantiate()
	add_child(w)
	w.prebuild_begin(true)
	var times: Array = []
	var i: int = 0
	while i < w._pb_steps.size():
		var t0: int = Time.get_ticks_usec()
		(w._pb_steps[i] as Callable).call()
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		i += 1
	var total: float = 0.0
	var worst: float = 0.0
	for k in times.size():
		total += float(times[k])
		worst = maxf(worst, float(times[k]))
		print("step %2d  %6.1f ms" % [k, float(times[k])])
	print("steps %d total %.0f ms worst %.1f ms  trees %d bears %d" % [times.size(), total, worst, w._trees.size(), w.get_bears().size()])
	get_tree().quit()
