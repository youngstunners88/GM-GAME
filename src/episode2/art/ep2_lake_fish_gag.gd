class_name Ep2LakeFishGag
extends Node3D
## THE HUGE FISH (founder 2026-11-28: "a huge fish jumps over Logan with splash when Lil Blunt arrives"). Pure lake comedy, never gameplay:
## nobody catches it, nothing goes in the Tabs, no numbers. One absurdly oversized fish (comedy scale, ~2.8 m - Logan's own "liquidity")
## bursts out of the water on one side of his skiff, sails over his hat with its tail going, and belly-flops in on the other side with a
## second big splash. Logan flinches (Ep2LoganSkiff.flinch) and goes straight back to his line.
##
## It is a child of the boat, so every point here is in boat space; the lake advances it with its own delta (hidden rooms never tick and
## the armory pause freezes it). The lake owns the one-shot rule (once per visit).

signal landed

const DURATION := 1.75              # seconds in the air: long enough to read, short enough to be a gag
const LENGTH := 2.8                 # metres, nose to tail: oversized on purpose
const SPLASH_PATH := "res://src/episode2/extras/audio/river/body_splash.ogg"

var fish: Node3D
var _tail: Node3D
var _t: float = -1.0
var _from: Vector3
var _to: Vector3
var _peak: float = 0.0
var _water_y: float = 0.0
var _entered: bool = false
var _rings: Array[MeshInstance3D] = []
var _drops: Array[Node3D] = []
var splashes: int = 0               # how many splashes it has thrown (the gate reads it: exit + landing = 2)
var peak_reached: Vector3 = Vector3(0, -INF, 0)


func _init() -> void:
	name = "HugeFishGag"
	_build_fish()


## Launch from `from` (below the water) to `to` (below the water) with the top of the arc at `peak_y`; all in boat space.
func play(from: Vector3, to: Vector3, peak_y: float, water_y: float) -> void:
	_from = from
	_to = to
	_peak = peak_y
	_water_y = water_y
	_t = 0.0
	_entered = false
	splashes = 0
	peak_reached = Vector3(0, -INF, 0)
	fish.show()
	_place(0.0)
	_splash(Vector3(from.x, water_y, from.z), 1.0)


func is_playing() -> bool: return _t >= 0.0


func advance(delta: float) -> void:
	for ring in _rings.duplicate():
		var age: float = float(ring.get_meta("age")) + delta
		ring.set_meta("age", age)
		var k: float = clampf(age / 1.3, 0.0, 1.0)
		ring.scale = Vector3.ONE * lerpf(1.0, float(ring.get_meta("grow")), 1.0 - pow(1.0 - k, 2.0))
		(ring.material_override as StandardMaterial3D).albedo_color.a = .45 * (1.0 - k)
		if k >= 1.0:
			_rings.erase(ring)
			ring.queue_free()
	for fx in _drops.duplicate():
		var fx_age: float = float(fx.get_meta("age")) + delta
		fx.set_meta("age", fx_age)
		if fx_age > 2.5:                                  # particle life plus a margin, then gone (no orphan nodes on the lake)
			_drops.erase(fx)
			fx.queue_free()
	if _t < 0.0: return
	_t += delta
	var s: float = clampf(_t / DURATION, 0.0, 1.0)
	_place(s)
	if _tail != null: _tail.rotation.y = sin(_t * 26.0) * .55          # it thrashes the whole way over
	if not _entered and s > .55 and fish.position.y < _water_y:
		_entered = true
		_splash(Vector3(fish.position.x, _water_y, fish.position.z), 1.35)   # the belly-flop is the bigger one
	if s >= 1.0:
		_t = -1.0
		fish.hide()
		landed.emit()


func _place(s: float) -> void:
	var base: Vector3 = _from.lerp(_to, s)
	var h: float = _peak - maxf(_from.y, _to.y)
	var pos: Vector3 = base + Vector3(0, 4.0 * h * s * (1.0 - s), 0)
	fish.position = pos
	if pos.y > peak_reached.y: peak_reached = pos
	var tangent: Vector3 = (_to - _from) + Vector3(0, 4.0 * h * (1.0 - 2.0 * s), 0)
	if tangent.length() > .001:
		var fwd: Vector3 = tangent.normalized()
		var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < .98 else Vector3.BACK
		var b := Basis.looking_at(-fwd, up)           # looking_at points -Z; the fish's nose is +Z
		fish.basis = b * Basis(Vector3.FORWARD, .35 * sin(PI * s))     # a little showboat roll at the top


func _splash(at: Vector3, size: float) -> void:
	splashes += 1
	var p := CPUParticles3D.new()
	p.name = "FishSplash"
	p.amount = int(110 * size)
	p.lifetime = 1.15
	p.one_shot = true
	p.explosiveness = .94
	p.local_coords = false
	var drop := SphereMesh.new()
	drop.radius = .045
	drop.height = .09
	drop.radial_segments = 6
	drop.rings = 3
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(.88, .96, 1.0, .9)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = .08
	drop.material = wet
	p.mesh = drop
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = .55 * size
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 3.2 * size
	p.initial_velocity_max = 6.4 * size
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = .6
	p.scale_amount_max = 1.6 * size
	add_child(p)
	p.position = at
	p.emitting = true
	p.set_meta("age", 0.0)
	_drops.append(p)
	var ring := MeshInstance3D.new()
	ring.name = "FishSplashRing"
	var torus := TorusMesh.new()
	torus.inner_radius = .5
	torus.outer_radius = .57
	ring.mesh = torus
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(.95, .98, 1.0, .45)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = foam
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("age", 0.0)
	ring.set_meta("grow", 3.4 * size)
	add_child(ring)
	ring.position = at + Vector3(0, .015, 0)
	ring.scale = Vector3(1, .12, 1)
	_rings.append(ring)
	if ResourceLoader.exists(SPLASH_PATH):
		var sfx := AudioStreamPlayer3D.new()
		sfx.stream = load(SPLASH_PATH) as AudioStream
		sfx.bus = "SFX"
		sfx.volume_db = 3.0 * size
		sfx.unit_size = 14.0
		sfx.pitch_scale = .82 if size > 1.0 else .95   # a big fish lands deep
		add_child(sfx)
		sfx.position = at
		if sfx.is_inside_tree(): sfx.play()
		sfx.set_meta("age", 0.0)
		_drops.append(sfx)


## A cartoon-big lake fish from primitives: olive back, cream belly, a gold flank stripe, a forked tail that thrashes, goggle eyes and an
## open "O" mouth. Nose is +Z. Built once, hidden until the gag.
func _build_fish() -> void:
	fish = Node3D.new()
	fish.name = "HugeFish"
	add_child(fish)
	var L: float = LENGTH
	_ellipsoid(fish, Vector3(.62, .78, L * .80), Vector3.ZERO, Color(.14, .19, .11), .5, 0.0)           # back
	_ellipsoid(fish, Vector3(.56, .52, L * .70), Vector3(0, -.15, .05), Color(.86, .82, .66), .45, 0.0) # belly
	_ellipsoid(fish, Vector3(.645, .12, L * .66), Vector3(0, .02, .02), Color(.86, .64, .18), .3, .7)   # gold flank stripe
	var fin_mat := _mat(Color(.17, .21, .12), .6, 0.0)
	# fins are thin triangles standing in the fish's own vertical plane (never boxes: boxes read as flat squares from the shore)
	_fin(fish, Vector3(.85, .5, .045), Vector3(0, .52, -.1), FIN_UP, fin_mat)
	for side in [-1.0, 1.0]:
		var pect := _fin(fish, Vector3(.42, .3, .035), Vector3(side * .30, -.2, .45), FIN_UP, fin_mat)
		pect.basis = Basis(Vector3.FORWARD, side * 2.2) * pect.basis
		var eye := _ellipsoid(fish, Vector3(.26, .26, .26), Vector3(side * .25, .14, L * .33), Color(.97, .97, .94), .2, 0.0)
		eye.name = "Eye"
		_ellipsoid(fish, Vector3(.12, .12, .12), Vector3(side * .35, .15, L * .35), Color(.04, .04, .04), .1, 0.0)
	_ellipsoid(fish, Vector3(.30, .22, .14), Vector3(0, -.06, L * .40), Color(.22, .06, .07), .7, 0.0)    # the "O" mouth
	_tail = Node3D.new()
	_tail.name = "Tail"
	fish.add_child(_tail)
	_tail.position = Vector3(0, 0, -L * .38)
	for lobe in [-1.0, 1.0]:
		# each lobe: apex at the tail root, broad end trailing back and out - a proper forked tail
		var tilt := Basis(Vector3.RIGHT, lobe * .62)
		var apex_dir: Vector3 = tilt * Vector3(0, 0, 1)
		var fin := _fin(_tail, Vector3(.5, .78, .045), Vector3(0, 0, -.05) - apex_dir * .39, FIN_BACK, fin_mat)
		fin.basis = tilt * fin.basis
	fish.hide()


func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _ellipsoid(parent: Node3D, size: Vector3, at: Vector3, c: Color, rough: float, metal: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1.0
	mi.mesh = sphere
	mi.material_override = _mat(c, rough, metal)
	parent.add_child(mi)
	mi.position = at
	mi.scale = size
	return mi


## PrismMesh (apex +Y, base along X, thickness Z) turned into the fish's vertical plane. FIN_UP: apex up, base along the body (dorsal).
## FIN_BACK: apex forward to the tail root, base spanning up-down behind it (tail lobes).
const FIN_UP := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
const FIN_BACK := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))

func _fin(parent: Node3D, size: Vector3, at: Vector3, turn: Basis, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	mi.mesh = prism
	mi.material_override = m
	parent.add_child(mi)
	mi.basis = turn
	mi.position = at
	return mi

