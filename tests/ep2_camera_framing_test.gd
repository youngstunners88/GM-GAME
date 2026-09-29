extends Node
## Gate for skill ep2-runner-camera-light. Founder 2026-09-29: "the way Lil Blunt is positioned in the
## middle cart makes it difficult to see what's going on." The hero must sit in the lower part of the
## frame, and the track ahead (the vanishing corridor) must be visible ABOVE his hat.
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_camera_framing_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	var live: Node3D = SCENE.instantiate()
	add_child(live)
	var leg: Dictionary = Episode2Tracks.LEG_DESCENT
	live.setup(float(leg["chamber_z"]), leg["obstacles"], leg["zip_segments"], leg["archers"], true,
		{"rail_events": leg["rail_events"], "carts_start": leg["carts_start"], "speed": leg["speed"]})
	for _i in 120:
		await get_tree().process_frame
	var view: Node = live.get_node("View")
	var cam: Camera3D = view._camera
	var vr: Rect2 = get_viewport().get_visible_rect()
	var rider_z: float = live.get_distance()
	var rx: float = float(live.get_cart_x())
	var feet: Vector2 = cam.unproject_position(Vector3(rx, view._rider.position.y, rider_z))
	var hat: Vector2 = cam.unproject_position(Vector3(rx, view._cart_rim_y + 0.9, rider_z))   # seated: hat ~0.9 m above the rim
	var far: Vector2 = cam.unproject_position(Vector3(rx, 0.5, rider_z + 24.0))
	var fy: float = feet.y / vr.size.y
	var hy: float = hat.y / vr.size.y
	var ay: float = far.y / vr.size.y
	print("  feet y=%.2f  hat y=%.2f  24 m ahead y=%.2f (fractions of screen height)" % [fy, hy, ay])
	_check("the hero's hat is in the lower 60% of the frame (%.2f)" % hy, hy > 0.38)
	_check("hero centre is below screen centre (%.2f)" % ((fy + hy) * 0.5), (fy + hy) * 0.5 > 0.50)
	_check("24 m of track ahead is visible ABOVE his hat (%.2f < %.2f)" % [ay, hy], ay < hy - 0.03)
	_check("that track point is on screen (%.2f)" % ay, ay > 0.05 and ay < 0.95)
	_check("the hero is at most 45%% of the screen tall (%.2f)" % (fy - hy), fy - hy < 0.45)
	print("CAMERA FRAMING: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
