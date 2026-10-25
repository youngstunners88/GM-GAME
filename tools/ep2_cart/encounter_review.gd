extends Node
## Actual WoodsQuad passenger camera, preserved dialogue and pass logic.
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
var w: WoodsQuadChamber
var out := "/workspace/work/cart-rebuild/encounter"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	w = WOODS.instantiate()
	add_child(w)
	w.setup(0, [], 0)
	w.set_physics_process(false)
	w.debug_invulnerable = true
	await get_tree().process_frame
	for b in w.get_bears():
		(b as Ep2BearBrain).actor.visible = false
		(b as Ep2BearBrain).aware = Ep2BearBrain.Aware.DEAD
	w._advance_to(WoodsQuadChamber.Beat.RIDE)
	var guard: int = 0
	while not w.is_riding() and guard < 1800:
		guard += 1
		w.step(1.0 / 60.0)
	w._cart_s = WoodsQuadChamber.CART_S0
	(w.get_cart_node() as Ep2RoadCart).reset_motion()
	w._ride_s = WoodsQuadChamber.CART_S0 - 110.0
	w._ride_speed = WoodsQuadChamber.RIDE_SPEED
	var said: Array = []
	w.line_spoken.connect(func(id): said.append(id))
	var shots: Dictionary = {}
	for i in 3600:
		w.step(1.0 / 60.0)
		var cart := w.get_cart_node() as Ep2RoadCart
		var gap: float = w._cart_s - w._ride_s
		# Mouse-look toward the passing farmer from Lil Blunt's actual passenger eye.
		var eye: Vector3 = w.get_player_position() + Vector3(0, w.eye_height, 0)
		var target: Vector3 = cart.global_position + Vector3(0, 1.2, 0)
		var d: Vector3 = target - eye
		w._look_yaw = atan2(d.x, d.z)
		w._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
		var key: String = ""
		if gap < 22.0 and not shots.has("approach"): key = "approach"
		if cart.greeting_time > 0.6 and not shots.has("greeting"): key = "greeting"
		if cart.greeting_time > 1.4 and not shots.has("greeting_mid"): key = "greeting_mid"
		if gap < 5.0 and not shots.has("alongside"): key = "alongside"
		if gap < -4.0 and not shots.has("passed"): key = "passed"
		if key != "":
			shots[key] = true
			# Apply changed gaze without advancing the encounter.
			w.step(0.0)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out + "/" + key + ".png")
			print("ENCOUNTER_SHOT ", key, " gap=", gap, " greet=", cart.greeting_time, " eye=", eye)
		if w.get_cart_state() == 3: break
	print("ENCOUNTER_REVIEW lines=", said, " state=", w.get_cart_state(), " shots=", shots.keys())
	get_tree().quit(0 if shots.size() == 5 and w.get_cart_state() == 3 else 1)
