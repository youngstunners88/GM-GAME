class_name RunnerGraybox
extends Node3D
## Episode 2 — Gold Mine Runner, GRAYBOX vertical slice (engine primitives).
##
## This is the throwaway proving-ground for the runner half of the runner↔
## chamber loop (see artifacts/episode2-gold-mine/spec/00_ARCHITECTURE.md §7a
## and the multi-model design review). NO art, NO Blender assets — box meshes
## and pure logic, so the *gameplay* is proven and phone-tested before any GPU
## hour or Blender session is spent. When real GLBs arrive they drop into the
## same node slots without touching this logic.
##
## Deliberately self-contained: it pulls in none of the Episode-1-specific
## gameplay autoloads (StateMachine, GameManager, etc.) so the graybox can be
## reasoned about and headless-tested in isolation. Economy wiring to
## goldmine_system.gd comes when the loop is proven, not in the graybox.
## `AudioManager` is the one exception — it's a project-wide music/audio
## singleton already used across every episode/level (not Episode-1-only
## gameplay state), so using it here is consistent with existing convention,
## not a break of the isolation goal above.
##
## Mode model (per Astra's reviewed architecture): the runner is one of the
## two modes under a future persistent session root. Here it runs standalone
## and emits `chamber_reached` at the chamber entrance — the signal the
## session root will use to swap to the 3D chamber scene, carrying player
## state across. The runner does NOT load the chamber itself.
##
## Hazard model (per multi-model design review,
## docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md): arrow and
## boulder hazards are deliberately OPPOSITE, not palette swaps of the
## legacy box obstacle:
##   - "box"     (legacy/default): cleared by jump. Unchanged behaviour —
##                the 7 pre-existing headless assertions keep meaning what
##                they meant before this hazard-type field existed.
##   - "arrow"   (balaclava bears firing down the lane): a flying projectile
##                — jumping does NOT clear it. Only ducking inside the cart
##                (cart walls block it) or being in a different lane clears
##                it. Ducking must be held for DUCK_MIN_HOLD before it counts,
##                so a one-frame duck-on-contact can't cheese the window.
##   - "boulder" (bears pushing rocks down the rails): crushes low — ducking
##                does NOT clear it. Only jump (clears the height) or being
##                in a different lane clears it.
## Zipline is modelled as a boolean mode (`_ziplining`) over a scripted
## z-range, not a fourth rail: it's a different plane of movement (an
## overhead cable), so while active it suspends lane-switching, duck, and
## jump, and cart-phase hazards (arrow/boulder/box) don't apply — you're off
## the rails, not dodging on them.

## Emitted once when the cart reaches the chamber entrance; the run halts.
signal chamber_reached
## Emitted each time an obstacle is struck; carries remaining health.
signal obstacle_hit(remaining_health: int)
## Emitted when health hits zero.
signal run_failed

# --- Tuning (graybox values; feel is tuned later, not law) --------------------
const RUN_SPEED := 12.0            # forward units/sec (+Z)
## Three rails, ordered LEFT-TO-RIGHT AS THE PLAYER SEES THEM — which means
## descending world X, not ascending.
##
## This is a handedness fact, not a preference. The chase camera looks down
## world +Z with +Y up; in a right-handed basis that puts world +X on the
## player's LEFT. Written the intuitive way round ([-2.5, 0.0, 2.5]) the
## controls invert on screen: `switch_lane_left()` decrements the index, which
## would have moved the cart to world -2.5 and therefore to screen RIGHT.
const LANE_X := [2.5, 0.0, -2.5]
const LANE_SWITCH_SPEED := 12.0    # how fast the cart slides between rails
const GRAVITY := 30.0
const JUMP_VELOCITY := 11.0        # ~0.73s airtime — clears an obstacle
const OBSTACLE_CLEAR_HEIGHT := 1.2 # cart y above this = jumped over it
const OBSTACLE_HIT_Z := 1.0        # z-window for a hit
const OBSTACLE_HIT_X := 0.8        # x-window (same-lane) for a hit
const START_HEALTH := 3
const DUCK_MIN_HOLD := 0.10        # seconds a duck must be held to block an arrow
## Float-accumulation slack for the duck-hold comparison: `delta` sums (e.g.
## 6× double(1/60)) can land a couple of ULPs *below* the nominal target
## (double(1/60)*6 ≈ 0.09999999999999999), which would wrongly read as "not
## yet held long enough" on the exact intended frame. Found by Kimi K3 code
## audit, docs/model-responses/2026-09-06-kimi-ep2-runner-hazards-audit.md #1.
const DUCK_HOLD_EPSILON := 0.001
const ZIP_HEIGHT := 2.5            # cart Y while ziplining (above jump-clear height)

# --- Live state --------------------------------------------------------------
var _lane: int = 1                 # index into LANE_X; start centre
var _cart_y: float = 0.0
var _vy: float = 0.0
var _distance: float = 0.0         # world z travelled
var _health: int = START_HEALTH
var _running: bool = true
var _chamber_z: float = 200.0      # entrance distance

## Obstacles ahead: each {"z": float, "lane": int, "hit": bool, "type": String}.
## `type` in {"box", "arrow", "boulder"} — defaults to "box" (legacy: cleared
## by jump only) when a caller/test omits it, so the original 7 assertions
## keep their original meaning. Plain Array (not Array[Dictionary]) to avoid
## typed-array assignment friction from untyped `[]` / literal callers — this
## is a graybox, kept forgiving.
var _obstacles: Array = []

# --- Duck (arrow defense) -----------------------------------------------------
var _duck_held: bool = false
var _duck_hold_time: float = 0.0

# --- Zipline (a different plane of movement, not a rail) ----------------------
## Each {"start_z": float, "end_z": float}. While `_distance` is inside any
## segment, `_ziplining` is true and cart-phase logic (lane-switch, duck,
## jump, box/arrow/boulder hazards) is suspended.
var _zip_segments: Array = []
var _ziplining: bool = false
var _was_ziplining: bool = false  # edge-detects the zip→cart dismount frame

## Runner-section music. Founder direction (2026-09-09) supersedes the
## 2026-09-06 direction that goldmine_dreams/goldmine_high shuffle here
## "until further notice" — these two tracks are that further notice, and
## were delivered for the runner specifically. The previous two tracks are
## left on disk and in assets/audio-manifest.json (they are real client
## assets) but are no longer wired to any scene.
##
## Sequencing: `AudioManager.play_playlist()` already advances to the next
## track on each track's natural end and shuffles with no-immediate-repeat
## (see `_play_next_in_playlist`), which with a 2-track list means Run and
## Run_1 alternate and then continue indefinitely — the founder's option (b)
## "sequence into Run_1 once Run finishes", with zero new plumbing. It also
## routes playback through the **Music** bus (`current_music_player.bus =
## "Music"`), so the existing volume sliders/settings keep working; a bespoke
## AudioStreamPlayer here would have bypassed them.
##
## `force_first = true` so the runner always OPENS on Run.mp3 (the founder's
## "plays Run.mp3 during runner segments"), then shuffles from there —
## without it, play_playlist picks its first track at random.
const RUNNER_MUSIC_PLAYLIST := [
	"res://src/assets/music/runner_run.mp3",
	"res://src/assets/music/runner_run_1.mp3",
]

## Headless-built GLB props (tools/blender/build_asset.py, proven importable by
## tests/ep2_glb_pipeline_test.tscn). Every one of these has a primitive
## fallback below it — a GLB that fails to load must degrade to a visible box,
## never to nothing, because an invisible hazard is the worst bug this episode
## has shipped.
const CART_MODEL := "res://src/episode2/assets/minecart.glb"
const LANTERN_MODEL := "res://src/episode2/assets/lantern.glb"
const BOULDER_MODEL := "res://src/episode2/assets/boulder.glb"
const GOLD_PILE_MODEL := "res://src/episode2/assets/gold_pile.glb"
const ROCK_CHUNK_MODEL := "res://src/episode2/assets/rock_chunk.glb"
## PLACEHOLDER rider, not the hero character — see
## .claude/skills/hero-character-pipeline/SKILL.md. It exists because all three
## founder references are anchored by Lil Blunt's green silhouette in the cart,
## and without it the runner reads as an empty cart rolling itself downhill.
const RIDER_PLACEHOLDER_MODEL := "res://src/episode2/assets/lil_blunt_placeholder.glb"


## Instance a GLB prop, or return null so the caller can fall back.
func _prop(path: String, pos: Vector3, scale: float = 1.0, yaw: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var n: Node3D = packed.instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	if yaw != 0.0:
		n.rotate_y(yaw)
	_visuals.add_child(n)
	return n

@onready var _cart: Node3D = $Cart

# --- Graybox visuals ----------------------------------------------------------
#
# Hazards are pure DATA in `_obstacles` — z/lane/type dictionaries the physics
# reads. Nothing ever drew them, so a browser playtest showed a player losing
# health to obstacles that were literally invisible: unplayable, while every
# headless gate stayed green (they assert health/positions, never pixels).
#
# These spawn one mesh per hazard, shaped by the verb that clears it, so the
# player can read the track. Cosmetic only — no logic reads them back.
#
# Surfaces come from `Ep2Palette`, which traces every value back to the three
# founder reference images. The flat COL_* constants that used to live here
# (a #d92e33 red arrow, a #b87330 orange crate) were invented for legibility
# and matched nothing in the references — the reference mine is dark rock,
# weathered timber, brass and gold lit by warm lanterns. Colour choices now
# live in one file that says where each number came from.
var _visuals: Node3D = null

func _add_visual(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_visuals.add_child(mi)

## Push the shared Episode 2 art direction onto this scene's static nodes, and
## hang the lanterns that actually light the tunnel.
##
## Done in code rather than as .tscn sub-resources so `Ep2Palette` stays the ONE
## place a surface is defined — two scenes each carrying their own inline
## StandardMaterial3D blocks is how "everything is grey" became a four-file
## problem in the first place.
func _apply_art() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = Ep2Palette.make_environment()
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		var key := Ep2Palette.make_key_light()
		sun.light_color = key.light_color
		sun.light_energy = key.light_energy
		sun.shadow_enabled = key.shadow_enabled
		key.queue_free()
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground:
		ground.material_override = Ep2Palette.make("rock_deep")
	# Swap the placeholder cart box for the real GLB prop.
	#
	# minecart.glb is built headlessly by tools/blender/build_asset.py (Path E
	# in the asset-pipeline spec) and is already proven to import as 7 real
	# meshes by tests/ep2_glb_pipeline_test.tscn. It carries its own Blender
	# materials — timber hull, metal rim and wheels, gold leaf emblem — so it is
	# NOT re-materialised from the palette here.
	#
	# The box stays in the scene as the fallback: if the GLB ever fails to load,
	# a wood-coloured box is a far better failure than an invisible player.
	var cart := get_node_or_null("Cart/CartMesh") as MeshInstance3D
	if cart:
		cart.material_override = Ep2Palette.make("wood_light")
	var cart_root := get_node_or_null("Cart")
	if cart_root and ResourceLoader.exists(CART_MODEL):
		var packed: PackedScene = load(CART_MODEL)
		if packed:
			var model: Node3D = packed.instantiate()
			# Blender +Y is the cart's forward; glTF's Y-up conversion turns that
			# into -Z, and the runner travels +Z — so it needs a half turn or the
			# cart rides backwards.
			model.rotate_y(PI)
			# Wheels have radius 0.42 centred at 0.25 in Blender Z, so the model's
			# lowest point sits below its own origin; lift it onto the rails.
			model.position = Vector3(0.0, 0.17, 0.0)
			cart_root.add_child(model)
			if cart:
				cart.visible = false
	if cart_root and ResourceLoader.exists(RIDER_PLACEHOLDER_MODEL):
		var rp: PackedScene = load(RIDER_PLACEHOLDER_MODEL)
		if rp:
			var rider: Node3D = rp.instantiate()
			# Seated height tuned against a real capture: at y=0.72 the head sat
			# level with the cart rim and the green silhouette — the thing that
			# anchors all three references — was clipped by his own cart.
			rider.position = Vector3(0.0, 1.02, 0.12)
			rider.scale = Vector3.ONE * 1.15
			cart_root.add_child(rider)

	_build_tunnel()

	# Lanterns down the tunnel. On-model (every reference hangs lamps on the
	# timber) AND the readability fix — at ambient 0.18 the track needs real
	# light sources, not a brighter ambient, or nothing reads as "bright".
	# Spacing follows Astra's 8-12 m note; 14 m here because the cart covers
	# 12 m/s and closer spacing turned into continuous warm fill in testing.
	var track_len: float = _chamber_z + 40.0
	var z: float = 12.0
	var side: float = 1.0
	while z < track_len:
		var lamp := Ep2Palette.make_lantern_light()
		lamp.position = Vector3((_wall_x_at(z) - 1.1) * side, 3.4, z)
		_visuals.add_child(lamp)
		if _prop(LANTERN_MODEL, lamp.position - Vector3(0.0, 0.42, 0.0), 1.15) == null:
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.4
			bulb.mesh = sm
			bulb.material_override = Ep2Palette.make("lantern")
			bulb.position = lamp.position
			_visuals.add_child(bulb)
		z += 14.0
		side = -side


## Enclose the track in rock.
##
## This is the one piece of GEOMETRY in the art pass, and the browser capture is
## why. With materials alone the runner was a lit ribbon floating in pure black:
## there were no surfaces for the lanterns to fall on, so a correct warm palette
## still rendered as a blue-black void. Every founder reference is an ENCLOSED
## tunnel — the rock is most of the frame. Six boxes buy the whole read.
## Inner face of the wall at a given z — the veins and posts have to follow the
## segmented wall or they float in mid-air where a bay opens out.
func _wall_x_at(z: float) -> float:
	var i: int = int(floor((z + 20.0) / 20.0))
	if (i % 4) == 2:
		return 8.34
	return 5.54 + float(i % 3) * 0.35


func _build_tunnel() -> void:
	var track_len: float = _chamber_z + 60.0

	# SEGMENTED walls, not two long boxes. The fidelity review's finding #4 was
	# that the result read as "a rectangular shaft, not a cavern" — the
	# references have uneven openings and occasional tall, wide pockets. The
	# gameplay route stays perfectly straight; only the enclosure breathes.
	# Deterministic per-segment offsets (index arithmetic, no RNG) so two
	# captures of the same track are comparable.
	const SEG := 20.0
	var segs: int = int(ceil(track_len / SEG))
	for i in segs:
		var z0: float = -20.0 + float(i) * SEG
		var pocket: bool = (i % 4) == 2                 # every fourth bay opens out
		var half_w: float = 8.4 if pocket else (5.6 + float(i % 3) * 0.35)
		var h: float = 9.0 if pocket else (7.0 + float(i % 2) * 0.8)
		for side in [-1.0, 1.0]:
			var wall := BoxMesh.new()
			wall.size = Vector3(0.6, h, SEG)
			_add_visual(wall, Ep2Palette.make("rock"),
				Vector3(half_w * side, h * 0.5 - 0.8, z0 + SEG * 0.5))
		var ceiling := BoxMesh.new()
		ceiling.size = Vector3(half_w * 2.0 + 1.2, 0.6, SEG)
		_add_visual(ceiling, Ep2Palette.make("rock_deep"),
			Vector3(0.0, h - 0.8, z0 + SEG * 0.5))
		# Loose rock on the floor of the wide bays, so a pocket reads as a
		# worked-out chamber rather than a gap in the wall.
		if pocket:
			_prop(ROCK_CHUNK_MODEL, Vector3(6.6 * (1.0 if (i % 8) == 2 else -1.0), -0.45, z0 + 9.0), 2.2)

	# Gold veins in the walls — the glitter that reads as "this is a GOLD mine"
	# rather than "this is a tunnel". Deterministic spacing, not random: a fixed
	# track must look the same on every run so a capture is comparable to the
	# last one.
	# Many SMALL veins, not a few big ones. The first attempt used 2.2 m slabs
	# and the browser capture showed them as flat yellow rectangles taped to the
	# wall — ore reads as scattered glitter, which is what all three references
	# show. Deterministic placement (index arithmetic, no RNG) so two captures
	# of the same track are comparable.
	var z: float = 6.0
	var i: int = 0
	while z < track_len - 20.0:
		var side2: float = 1.0 if (i % 2 == 0) else -1.0
		for k in 3:
			var vein := BoxMesh.new()
			var scale: float = 0.22 + float((i + k) % 3) * 0.14
			vein.size = Vector3(0.12, scale, scale * 1.6)
			_add_visual(vein, Ep2Palette.make("gold_vein"),
				Vector3(_wall_x_at(z) * side2,
					0.9 + float((i * 3 + k) % 5) * 1.05,
					z + float(k) * 1.3))
		z += 4.5
		i += 1

	# Timber support frames, per every reference — they also give the tunnel a
	# sense of speed that a smooth wall cannot.
	var bz: float = 10.0
	while bz < track_len - 20.0:
		var wx: float = _wall_x_at(bz) - 0.55
		for side3 in [-1.0, 1.0]:
			var post := BoxMesh.new()
			post.size = Vector3(0.45, 6.0, 0.45)
			_add_visual(post, Ep2Palette.make("wood"), Vector3(wx * side3, 2.6, bz))
		var beam := BoxMesh.new()
		beam.size = Vector3(wx * 2.0 + 0.5, 0.45, 0.45)
		_add_visual(beam, Ep2Palette.make("wood"), Vector3(0.0, 5.6, bz))
		bz += 18.0


## Rebuild every cosmetic mesh for the current track. Called from setup(), so a
## reused instance never keeps the previous run's hazards on screen.
func _build_visuals() -> void:
	if _visuals and is_instance_valid(_visuals):
		_visuals.queue_free()
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_apply_art()

	# Lane rails, so the three rails are readable at speed. Iron, per ref 3.
	for x in LANE_X:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.18, 0.12, _chamber_z + 40.0)
		_add_visual(rail, Ep2Palette.make("iron"), Vector3(float(x), -0.42, (_chamber_z + 40.0) * 0.5))

	# Sleepers. The fidelity review found the outer track boundaries reading
	# more clearly than the railway itself; in every reference it is the rhythm
	# of the cross-ties that explains where the route goes. Spaced 3 m so the
	# count stays modest on a web export.
	var tie_z: float = 0.0
	while tie_z < _chamber_z + 40.0:
		var tie := BoxMesh.new()
		tie.size = Vector3(6.6, 0.12, 0.5)
		_add_visual(tie, Ep2Palette.make("wood"), Vector3(0.0, -0.5, tie_z))
		tie_z += 3.0

	# Gold piles as scenery — the references never show a lone nugget, gold is
	# always heaped. Placed off the rails so they never read as collectible.
	for gp in [Vector3(-4.3, -0.4, _chamber_z * 0.35), Vector3(4.3, -0.4, _chamber_z * 0.62),
			Vector3(-4.3, -0.4, _chamber_z * 0.88)]:
		_prop(GOLD_PILE_MODEL, gp, 1.6)

	# Hazards, shaped and placed by the verb that clears them.
	for o in _obstacles:
		var lane: int = int(o.get("lane", 1))
		var z: float = float(o.get("z", 0.0))
		var t: String = str(o.get("type", "box"))
		var x: float = float(LANE_X[clampi(lane, 0, LANE_X.size() - 1)])
		match t:
			"arrow":
				# Sits at head height — you DUCK under it. Brown shaft with a
				# steel tip (ref 1), lightly emissive: an arrow is the smallest
				# and fastest hazard in the game, arriving at head height in a
				# dark cave, so it needs to catch the light.
				var a := BoxMesh.new()
				a.size = Vector3(1.9, 0.28, 0.28)
				_add_visual(a, Ep2Palette.make("arrow"), Vector3(x, 1.45, z))
				var tip := BoxMesh.new()
				tip.size = Vector3(0.34, 0.30, 0.30)
				_add_visual(tip, Ep2Palette.make("arrow_head"), Vector3(x - 0.95, 1.45, z))
			"boulder":
				# Pale granite — in ref 1 the boulders are the lightest large
				# objects in frame, which is what separates them from the wall.
				if _prop(BOULDER_MODEL, Vector3(x, 0.7, z), 1.0) == null:
					var b := SphereMesh.new()
					b.radius = 0.75
					b.height = 1.5
					_add_visual(b, Ep2Palette.make("boulder"), Vector3(x, 0.55, z))
			_:
				# Timber crate with brass banding, same family as the carts.
				var c := BoxMesh.new()
				c.size = Vector3(1.5, 1.0, 1.0)
				_add_visual(c, Ep2Palette.make("crate"), Vector3(x, 0.45, z))
				var band := BoxMesh.new()
				band.size = Vector3(1.56, 0.16, 1.06)
				_add_visual(band, Ep2Palette.make("brass"), Vector3(x, 0.82, z))

	# Overhead zip cable over each zip segment.
	for seg in _zip_segments:
		var s0: float = float(seg.get("start_z", 0.0))
		var s1: float = float(seg.get("end_z", 0.0))
		if s1 <= s0:
			continue
		# Braided steel, per ref 2 — cool and metallic against the warm mine.
		var cable := BoxMesh.new()
		cable.size = Vector3(0.12, 0.12, s1 - s0)
		_add_visual(cable, Ep2Palette.make("steel_cable"), Vector3(0.0, ZIP_HEIGHT + 0.9, (s0 + s1) * 0.5))

	# Chamber entrance marker — a lit gate so the goal is visible from the track.
	var gate := BoxMesh.new()
	gate.size = Vector3(7.5, 0.4, 0.4)
	_add_visual(gate, Ep2Palette.make("gate"), Vector3(0.0, 2.6, _chamber_z))

func _ready() -> void:
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)
	AudioManager.play_playlist(RUNNER_MUSIC_PLAYLIST, true)

## Configure the segment before/at spawn. Call before the run advances.
## `obstacles` entries missing "type" default to "box" (legacy jump-clears).
## Also resets all run state — safe to call again on a reused instance
## (Kimi audit #5c: a stale `_running = false` from a prior run_failed/
## chamber_reached would otherwise make every step() silently a no-op).
func setup(chamber_z: float, obstacles: Array = [], zip_segments: Array = []) -> void:
	_chamber_z = chamber_z
	_obstacles = obstacles.duplicate(true)
	for o in _obstacles:
		o["hit"] = false
		if not o.has("type"):
			o["type"] = "box"
	_zip_segments = zip_segments.duplicate(true)

	_lane = 1
	_cart_y = 0.0
	_vy = 0.0
	_distance = 0.0
	_health = START_HEALTH
	_running = true
	_duck_held = false
	_duck_hold_time = 0.0
	_ziplining = false
	_was_ziplining = false
	_build_visuals()
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)

func _physics_process(delta: float) -> void:
	if not _running:
		return
	_advance(delta)

## Split out so a headless test can step the sim deterministically without a
## real frame clock: call `step(delta)` directly.
func step(delta: float) -> void:
	if _running:
		_advance(delta)

func _advance(delta: float) -> void:
	# Forward auto-run.
	_distance += RUN_SPEED * delta

	_ziplining = _in_any_zip_segment(_distance)

	# Duck hold time does NOT accumulate while ziplining — you let go of duck
	# to grab the cable, so a duck held before/through a zip segment can't
	# carry effective cover out the other side (Kimi audit #5b: the doc
	# comment always claimed duck was suspended during zip, but only
	# duck_start() was actually gated — the timer kept counting regardless).
	if _duck_held and not _ziplining:
		_duck_hold_time += delta
	else:
		_duck_hold_time = 0.0

	if _ziplining:
		# A different plane of movement (overhead cable) — lane, duck, and
		# jump are all suspended; cart-phase hazards don't apply here.
		_cart_y = ZIP_HEIGHT
		_vy = 0.0
		if _cart:
			_cart.position = Vector3(_cart.position.x, _cart_y, _distance)
		_was_ziplining = true
	else:
		if _was_ziplining:
			# Clean dismount: land back on the rail immediately rather than
			# falling from ZIP_HEIGHT under gravity. Without this, ~0.3s of
			# residual fall time after zip-exit both free-clears any
			# box/boulder in that window (still "airborne" above
			# OBSTACLE_CLEAR_HEIGHT) and makes jump() a dead no-op (Kimi
			# audit #5a).
			_cart_y = 0.0
			_vy = 0.0
			_was_ziplining = false

		# Vertical (jump/gravity), clamped to the rail floor.
		if _cart_y > 0.0 or _vy != 0.0:
			_vy -= GRAVITY * delta
			_cart_y += _vy * delta
			if _cart_y <= 0.0:
				_cart_y = 0.0
				_vy = 0.0

		# Horizontal lerp toward the active rail.
		var target_x: float = LANE_X[_lane]
		var cur_x: float = _cart.position.x if _cart else target_x
		cur_x = move_toward(cur_x, target_x, LANE_SWITCH_SPEED * delta)

		if _cart:
			_cart.position = Vector3(cur_x, _cart_y, _distance)

		_check_obstacles(cur_x)

	# Chamber entrance reached → stop and signal the (future) session root.
	if _distance >= _chamber_z:
		_running = false
		chamber_reached.emit()

func _in_any_zip_segment(distance: float) -> bool:
	for seg in _zip_segments:
		if distance >= float(seg["start_z"]) and distance <= float(seg["end_z"]):
			return true
	return false

## Effective duck: held for at least DUCK_MIN_HOLD, so a one-frame duck
## exactly on hazard contact can't cheese the window (per design review).
## Epsilon-guarded — see DUCK_HOLD_EPSILON.
func _is_ducking_effective() -> bool:
	return _duck_held and _duck_hold_time + DUCK_HOLD_EPSILON >= DUCK_MIN_HOLD

func _check_obstacles(cur_x: float) -> void:
	for o in _obstacles:
		if o.get("hit", false):
			continue
		if absf(_distance - float(o["z"])) > OBSTACLE_HIT_Z:
			continue
		if absf(cur_x - LANE_X[int(o["lane"])]) > OBSTACLE_HIT_X:
			continue
		if _is_cleared(o.get("type", "box")):
			continue
		o["hit"] = true
		_health -= 1
		obstacle_hit.emit(_health)
		if _health <= 0:
			_running = false
			run_failed.emit()
			return  # stop scanning this frame — don't double-emit on a
			        # second same-frame hit after death (Kimi audit #5d)

## Clear rules are deliberately opposite per hazard type (design review):
## "box"/"boulder" — cleared by jump height only, duck does NOT help (a
## boulder crushes low). "arrow" — cleared by ducking only, jump does NOT
## help (a flying projectile still hits an airborne body).
func _is_cleared(hazard_type: String) -> bool:
	match hazard_type:
		"arrow":
			return _is_ducking_effective()
		_: # "box", "boulder"
			return _cart_y >= OBSTACLE_CLEAR_HEIGHT

# --- Input-facing API (driven by real input later; tests call directly) ------

## Move one rail left (toward index 0) if possible. No-op while ziplining —
## a different plane of movement, not a rail.
func switch_lane_left() -> void:
	if _ziplining:
		return
	_lane = maxi(0, _lane - 1)

## Move one rail right (toward index 2) if possible. No-op while ziplining.
func switch_lane_right() -> void:
	if _ziplining:
		return
	_lane = mini(LANE_X.size() - 1, _lane + 1)

## Jump, only from the ground (no double-jump in the graybox). No-op while
## ziplining — you're already off the rails.
func jump() -> void:
	if _ziplining:
		return
	if is_zero_approx(_cart_y) and is_zero_approx(_vy):
		_vy = JUMP_VELOCITY

## Start ducking (holds until duck_end()). No-op while ziplining. Must be
## held for DUCK_MIN_HOLD before it counts as effective cover — see
## _is_ducking_effective().
func duck_start() -> void:
	if _ziplining:
		return
	_duck_held = true

## Release duck. Effective-duck timer resets immediately (no cover on release).
func duck_end() -> void:
	_duck_held = false
	_duck_hold_time = 0.0

# --- Read-only accessors for tests / HUD -------------------------------------
func get_distance() -> float: return _distance
func get_lane() -> int: return _lane
func get_cart_x() -> float: return _cart.position.x if _cart else LANE_X[_lane]
func get_cart_y() -> float: return _cart_y
func get_health() -> int: return _health
func is_running() -> bool: return _running
func is_ducking() -> bool: return _is_ducking_effective()
func is_ziplining() -> bool: return _ziplining
