class_name RunnerView
extends Node3D
## Episode 2 runner — PRESENTATION layer.
##
## Draws the gold-mine descent: parallel rails on timber trestles over a pit, one
## ore cart per rail rolling as a convoy, Lil Blunt riding with his GOLDEN
## REVOLVER in one hand (mouse-aimed) and his pickaxe in the other, bear archers
## on scaffolds, boarders leaping into the cart, boulders, ziplines, and a
## textured rock tunnel with glowing gold veins.
##
## Separation of concerns: this node only READS the simulation (the parent
## RunnerGraybox) and listens to its signals. Archer placement comes from the
## sim's ARCHER_* consts / archer_world_pos() so the drawn bear and the mouse
## ray test can never disagree.
##
## Art: every surface's mood comes from the Episode 2 palette (resolved at
## runtime by path). The founder called the flat-palette stage "shit and grey",
## so the tunnel, timber and track bed now use seamless textures with world
## triplanar mapping, TINTED by the palette albedo so the palette still governs
## the mood. Every asset load is guarded: a missing texture falls back to the
## palette colour; a missing model falls back to a primitive — never to nothing.
##
## HUD: the view owns a CanvasLayer with the reticle (gold; red over a bear),
## six bullet pips, the reload bar and hints. Mouse cursor visibility is the
## session root's job.
##
## MOTION + EMOTION (2026-09-27): Lil Blunt and the bears are Meshy-RIGGED
## skeletal characters. RunnerMotion (runner_motion.gd) decides the clip from the
## sim; this view only plays it. The revolver and pickaxe follow the real hand
## bones. Carts are drawn per rail with a life cycle — rolling, WRECKED (tumbles
## into the pit where the boulder hit), dead (gone), and SPAWNING (rolls in on a
## siding / drops from a chute). Gold nuggets, buffer stops, speed streaks and a
## HUD cart strip make the attrition rules readable at 20-30 m/s.

const Sim := preload("res://src/episode2/runner/runner_graybox.gd")
const PALETTE_PATH := "res://src/episode2/art/ep2_palette.gd"
const RIDER_MODEL := "res://src/episode2/assets/lil_blunt.glb"
const ARCHER_MODEL := "res://src/episode2/assets/bear_archer.glb"
const REVOLVER_MODEL := "res://src/episode2/assets/golden_revolver.glb"
const PICKAXE_MODEL := "res://src/episode2/assets/pickaxe.glb"
const ORE_CART_MODEL := "res://src/episode2/assets/ore_cart.glb"
const CART_MODEL := "res://src/episode2/assets/minecart.glb"
const LANTERN_MODEL := "res://src/episode2/assets/lantern.glb"
const BOULDER_ROCK_MODEL := "res://src/episode2/assets/boulder_rock.glb"
const BOULDER_MODEL := "res://src/episode2/assets/boulder.glb"
const GOLD_PILE_MODEL := "res://src/episode2/assets/gold_pile.glb"
const ROCK_CHUNK_MODEL := "res://src/episode2/assets/rock_chunk.glb"
const TEX_DIR := "res://src/episode2/assets/textures/"
# Founder-made Meshy models (2026-09-28; src/episode2/assets/founder_meshy_sources.json).
const TUNNEL_SHELL_MODEL := "res://src/episode2/assets/mine_tunnel_shell.glb"
const LEAF_CART_MODEL := "res://src/episode2/assets/leaf_cart.glb"
const WRECK_A_MODEL := "res://src/episode2/assets/leaf_cart_wreck_a.glb"
const WRECK_B_MODEL := "res://src/episode2/assets/leaf_cart_wreck_b.glb"
const ZIP_POSE_MODEL := "res://src/episode2/assets/lil_blunt_zipline.glb"
const Motion := preload("res://src/episode2/runner/runner_motion.gd")
const AimMod := preload("res://src/episode2/runner/runner_aim_modifier.gd")
const TEX_BTC := "tex_btc_coin.png"
const TEX_ROCK := "tex_rock_wall.jpg"
const TEX_VEIN := "tex_gold_vein.jpg"
const TEX_TIMBER := "tex_timber.jpg"
const TEX_GRAVEL := "tex_gravel.jpg"
const SFX_DIR := "res://src/assets/sounds/"
const SFX_FILES := {
	"shot": "ep2_revolver_shot.mp3",
	"reload": "ep2_revolver_reload.mp3",
	"empty": "ep2_revolver_empty.mp3",
	"bear_hit": "ep2_bear_hit.mp3",
	"swing": "ep2_pickaxe_swing.mp3",
}

# --- Layout constants (view-only; the sim owns every gameplay number) ---------
const TRACK_PAD := 60.0
const TIE_SPACING := 1.1
const POST_SPACING := 5.5
const PIT_DEPTH := 14.0
const ARROW_Y := 1.45              # head height — the duck line
const ARROW_LEAD := 22.0
const BOULDER_ROLL := 0.85
const BOULDER_R := 1.35
const BOULDER_MODEL_R := 0.75      # boulder.glb's native radius
const BOULDER_ROCK_NATIVE := 1.2   # boulder_rock.glb's widest native extent
const TELEGRAPH_RANGE := 42.0
const RIDER_HEIGHT := 2.0            # founder: "I can't see Lil Blunt" — bigger + hero-lit
const RIDER_NATIVE_H := 0.9        # lil_blunt.glb if its AABB can't be measured
const RIDER_FLOOR := 0.62           # seated: head + hat clear the leaf cart rim (founder model)
const RIDER_YAW := 0.0             # Meshy faces +Z == away from camera
const HOP_ARC := 1.1
const CABLE_CLEARANCE := 1.55
const CART_Y := -0.3
const CART_MODEL_LIFT := 0.17
const CART_WHEEL_R := 0.42
const ORE_CART_NATIVE_LEN := 2.24  # ore_cart.glb long axis (X), x ±1.12
const ORE_CART_LEN := 2.1
const ORE_CART_Y := -0.15          # its baked rail piece sits on our rail bottom
const BEAR_NATIVE_H := 1.8
# Tunnel shell: native floor cut at y -0.34, open both ends, 1.87 long; stretched
# in X so its inner walls land on SHELL_WALL_X while its 3-track spacing matches ours.
const SHELL_SCALE := Vector3(11.9, 11.0, 8.3)  # Y raised so the zip cable (5.85 m) clears the timber beams
const SHELL_NATIVE_FLOOR := -0.34
const SHELL_STEP := 15.2            # slight overlap of the 15.5 m module
const SHELL_WALL_X := 5.5
const RAIL_TOP := -0.31
const LEAF_CART_LEN := 1.85
const ZIP_POSE_H := 2.9             # zipline pose incl. the raised pickaxe
const ARCHER_HEIGHT := 2.9           # founder: bears need to read at 20-30 m/s
const BOARDER_HEIGHT := 1.9
const BOARDER_LEAP_LEAD := 14.0    # the leap starts this far before the cart reaches z
const BOARDER_ARC := 1.6
const GUN_NATIVE_LEN := 0.2        # golden_revolver.glb x ±0.10
const GUN_LENGTH := 0.45
const GUN_HAND := Vector3(-0.42, 1.0, 0.22)   # screen-right = world -X
const AXE_HAND := Vector3(0.42, 1.05, 0.15)   # the other hand
const AXE_NATIVE_H := 0.6
const AXE_LENGTH := 0.95
const AXE_SWING_TIME := 0.25
const AXE_START := 1.31            # rad; sweep 150° to -1.31
const AXE_ARC := 2.62
const BREAK_TILT := 1.22           # ~70° muzzle-up during reload
const AIM_FALLBACK := 40.0
const TUNNEL_SEG := 20.0
const TUNNEL_HEADROOM := 3.0
const FRAME_TOP := 7.4
const LANTERN_SPACING := 14.0
const LANTERN_Y := 3.4
## Textures are multiplied by albedo_color; the palette albedos are very dark
## (rock ≈ 0.17), so the tint is lifted toward white first or the texture reads
## black. The hue — the mood — still comes from the palette.
const TEX_TINT_LIFT := 0.5

# --- Readability colours (gameplay verbs, not mine surfaces) -------------------
const C_JUMP := Color(1.0, 0.82, 0.18)
const C_DUCK := Color(1.0, 0.22, 0.20)
const C_HOP := Color(1.0, 0.50, 0.10)
const C_SHOOT := Color(0.35, 0.85, 1.0)
const C_SWIPE := Color(0.78, 0.45, 1.0)     # violet — pickaxe swipe
const C_ZIP := Color(0.95, 0.85, 0.40)
const C_HEADLAMP := Color(1.0, 0.92, 0.6)
const C_TRACER := Color(1.0, 0.84, 0.45)
const C_RETICLE := Color(1.0, 0.82, 0.3)
const C_RETICLE_HOT := Color(1.0, 0.18, 0.15)
const C_PIP := Color(1.0, 0.8, 0.3)
const C_PIP_SPENT := Color(0.35, 0.3, 0.22, 0.45)

const FALLBACK_ALBEDO := {
	"rock": Color(0.173, 0.180, 0.200),
	"rock_deep": Color(0.122, 0.129, 0.149),
	"gold_vein": Color(0.851, 0.675, 0.282),
	"wood": Color(0.318, 0.196, 0.110),
	"wood_light": Color(0.420, 0.290, 0.184),
	"brass": Color(0.604, 0.439, 0.224),
	"iron": Color(0.608, 0.627, 0.659),
	"steel_cable": Color(0.467, 0.486, 0.514),
	"gold": Color(0.929, 0.765, 0.373),
	"lantern": Color(1.0, 0.757, 0.439),
	"spark": Color(1.0, 0.698, 0.349),
	"boulder": Color(0.467, 0.467, 0.451),
	"crate": Color(0.478, 0.322, 0.153),
	"arrow": Color(0.678, 0.502, 0.314),
	"arrow_head": Color(0.467, 0.475, 0.486),
	"gate": Color(0.306, 0.788, 0.478),
	"bandit": Color(0.169, 0.165, 0.157),
	"bandit_cloth": Color(0.431, 0.388, 0.314),
}
# --- Cart life cycle / gold / speed (view-only) ---------------------------------
const WRECK_TIME := 1.6            # a smashed cart tumbles into the pit this long
const SPAWN_LEAD := 26.0           # an incoming cart is visible on its siding this far ahead
const SIDING_OFFSET := 3.6         # siding rail runs this far outside its lane
const CHUTE_HEIGHT := 5.0          # centre spawns drop from an ore chute
const GOLD_Y := 0.95
const FOV_BASE := 66.0
const FOV_PER_MS := 1.1            # +deg per m/s above 20
const C_DANGER := Color(1.0, 0.25, 0.15)
const C_GOLD_HUD := Color(1.0, 0.84, 0.3)
const FALLBACK_EMISSIVE := {"lantern": 1.1, "spark": 2.2, "gate": 0.9, "gold": 0.5, "gold_vein": 0.12}

## TEST-ONLY render bisection switches, filled from ?ep2off= by ep2_entry.gd.
## Keys: boulders, shadows, streaks, rig, strips, gold, halo, stress, hero,
## detail, dust. Always
## empty in normal play.
static var debug_off: Dictionary = {}

var _sim: Node = null
var _world: Node3D = null
var _carts: Array[Node3D] = []
var _cart_wheels: Array = []
var _rider: Node3D = null
var _rider_model: Node3D = null
var _rider_scale: float = 1.0
var _hook: MeshInstance3D = null
var _gun_pivot: Node3D = null
var _gun_spin_node: Node3D = null
var _gun_spin: float = 0.0
var _muzzle_flash: MeshInstance3D = null
var _muzzle_flash_t: float = 0.0
var _axe_pivot: Node3D = null
var _axe_t: float = 99.0
var _camera: Camera3D = null
var _sparks: CPUParticles3D = null
var _lights: Array[OmniLight3D] = []
var _lantern_pos: PackedVector3Array = PackedVector3Array()
var _archer_nodes: Dictionary = {}
var _archer_fall: Dictionary = {}
var _arrow_nodes: Array = []
var _boulder_nodes: Array = []
var _boarders: Array = []
var _labels: Array = []
var _zip_markers: Array = []
var _pocket_segs: Dictionary = {}
var _tracer: MeshInstance3D = null
var _tracer_t: float = 0.0
var _flash: OmniLight3D = null
var _shake: float = 0.0
var _mats: Dictionary = {}
var _scenes: Dictionary = {}
var _palette: Script = null
var _palette_loaded: bool = false
var _palette_methods: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _prev_x: float = 0.0
var _hop_from_x: float = 0.0
var _hop_to_x: float = 0.0
var _last_lane: int = 1

# Aim (mouse ray), refreshed every frame.
var _aim_ok: bool = false
var _aim_origin: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.BACK
var _aim_point: Vector3 = Vector3.ZERO
var _aim_hit: String = ""

# HUD (persists across rebuilds; child of this node, not the world).
var _hud: CanvasLayer = null
var _reticle: Control = null
var _reticle_hot: bool = false
var _pips: Array[ColorRect] = []
var _reload_bg: ColorRect = null
var _reload_fill: ColorRect = null
var _reload_label: Label = null
var _hint_label: Label = null

# SFX players (persist across rebuilds).
var _sfx: Dictionary = {}

# Motion + emotion (rigged characters).
var _rider_anim: RefCounted = null         # RunnerMotion.Anim
var _rider_skel: Skeleton3D = null
var _bone_r: int = -1
var _bone_l: int = -1
var _bone_head: int = -1
var _aim_mod: Node = null                   # RunnerAimModifier on the rider's skeleton
var _dust: CPUParticles3D = null
var _shell_mode: bool = false
var _zip_model: Node3D = null
var _zip_top: float = 0.0            # zip pose's native top (pickaxe) height
var _zip_scale: float = 1.0
var _wreck_pieces: Array = []        # [{"node", "vel", "spin", "t"}]
var _t_hit: float = 99.0
var _t_shot: float = 99.0
var _t_swipe: float = 99.0
var _t_hop: float = 99.0
var _t_cheer: float = 99.0
var _archer_anims: Dictionary = {}          # id -> RunnerMotion.Anim
var _emote: Label3D = null
var _popups: Array = []                     # [{"node": Label3D, "t": float}]
# Carts: per-lane life cycle. {"state": "roll"|"wreck"|"dead"|"spawn", "t", "z", "spin"}
var _cart_fx: Array = []
var _debris: CPUParticles3D = null
var _gold_nodes: Array = []                 # parallel to obstacles (null when not gold)
var _gold_burst: CPUParticles3D = null
var _streaks: CPUParticles3D = null
# HUD additions.
var _cart_strip: Control = null
var _gold_label: Label = null
var _blocked_t: float = 99.0
var _blocked_lane: int = -1
var _danger_t: float = INF


# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

## Called by the sim's setup(). Tears down the previous track and builds this one.
func rebuild(sim: Node) -> void:
	_sim = sim
	_rng.seed = 20260923
	if _world and is_instance_valid(_world):
		if _world.get_parent() == self:
			remove_child(_world)
		_world.queue_free()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_carts.clear()
	_cart_wheels.clear()
	_archer_nodes.clear()
	_archer_fall.clear()
	_arrow_nodes.clear()
	_boulder_nodes.clear()
	_boarders.clear()
	_labels.clear()
	_zip_markers.clear()
	_lights.clear()
	_pocket_segs.clear()
	_archer_anims.clear()
	_popups.clear()
	_cart_fx.clear()
	_gold_nodes.clear()
	_rider_anim = null
	_rider_skel = null
	_aim_mod = null
	_zip_model = null
	_wreck_pieces.clear()
	_shell_mode = ResourceLoader.exists(TUNNEL_SHELL_MODEL) and not debug_off.has("shell")
	_t_hit = 99.0
	_t_shot = 99.0
	_t_swipe = 99.0
	_t_hop = 99.0
	_t_cheer = 99.0
	_blocked_t = 99.0
	_tracer_t = 0.0
	_shake = 0.0
	_axe_t = 99.0
	_gun_spin = 0.0
	_muzzle_flash_t = 0.0

	# Archers and boarders stand in wide bays so their scaffolds never clip rock.
	for a in _sim.get_archers():
		var az: float = float(a["z"])
		for dz in [-3.0, 0.0, 3.0]:
			_pocket_segs[_seg_index(az + float(dz))] = true
	for o in _sim.get_obstacles():
		var od: Dictionary = o
		if str(od.get("type", "")) == "boarder":
			var bz: float = float(od["z"])
			for dz2 in [-3.0, 0.0, 3.0]:
				_pocket_segs[_seg_index(bz + float(dz2))] = true

	var chamber_z: float = float(_sim.get_chamber_z())
	var length: float = chamber_z + TRACK_PAD
	_apply_art()
	_build_track(length)
	_build_tunnel(length)
	_build_lanterns(length)
	_build_dressing(chamber_z)
	_build_carts()
	_build_rider()
	_build_hands()
	_build_archers()
	_build_hazards()
	_build_boarders()
	_build_gold()
	if not debug_off.has("detail"):
		_build_mine_detail(length)
	_build_rail_events()
	if debug_off.has("stress"):
		# TEST-ONLY: 1500 extra instances. Godot 4.3 non-threaded web builds drew
		# NO 3D above 1000 instances (godotengine/godot#96968) until
		# project.godot raised threaded_cull_minimum_instances; this proves it.
		var sb := _box(Vector3(0.2, 0.2, 0.2))
		for k in 1500:
			_mesh_node(sb, _timber_mat(), Vector3(-6.5 if k % 2 == 0 else 6.5, 3.0 + float(k % 7) * 0.4, float(k) * 0.6))
	_build_ziplines()
	_build_portal(chamber_z)
	_build_camera()
	_build_fx()
	_ensure_hud()
	_ensure_audio()
	_connect_sim()
	_prev_x = float(_sim.get_cart_x())
	_hop_from_x = _prev_x
	_hop_to_x = _prev_x
	_last_lane = int(_sim.get_lane())

func _connect_sim() -> void:
	var pairs := {
		"obstacle_hit": _on_hit,
		"shot_fired": _on_shot,
		"archer_down": _on_archer_down,
		"zip_caught": _on_zip_caught,
		"zip_missed": _on_zip_missed,
		"shot_resolved": _on_shot_resolved,
		"dry_fire": _on_dry_fire,
		"reload_started": _on_reload_started,
		"boarder_repelled": _on_boarder_repelled,
		"pickaxe_swing": _on_pickaxe_swing,
		"cart_wrecked": _on_cart_wrecked,
		"cart_spawned": _on_cart_spawned,
		"hop_blocked": _on_hop_blocked,
		"rider_bailed": _on_rider_bailed,
		"gold_collected": _on_gold_collected,
	}
	for sig in pairs:
		var cb: Callable = pairs[sig]
		if _sim.has_signal(sig) and not _sim.is_connected(sig, cb):
			_sim.connect(sig, cb)

func _process(delta: float) -> void:
	if _sim == null or _world == null or not is_instance_valid(_world):
		return
	var dist: float = float(_sim.get_distance())
	_update_convoy(dist)
	_update_rider(dist, delta)
	_update_archers(dist, delta)
	_update_arrows(dist)
	_update_boulders(dist)
	_update_boarders(dist, delta)
	_update_labels(dist)
	_update_lights(dist)
	_update_camera(dist, delta)
	_update_aim()
	_update_gun(delta)
	_update_axe(delta)
	_update_fx(delta)
	_update_gold(dist, delta)
	_update_wrecks(delta)
	_update_popups(delta)
	_update_hud()

# ------------------------------------------------------------------------------
# Palette (runtime-resolved)
# ------------------------------------------------------------------------------

func _palette_script() -> Script:
	if _palette_loaded:
		return _palette
	_palette_loaded = true
	if not ResourceLoader.exists(PALETTE_PATH):
		return null
	var s: Script = load(PALETTE_PATH) as Script
	if s == null or not s.can_instantiate():
		return null
	for md in s.get_script_method_list():
		var d: Dictionary = md
		_palette_methods[str(d.get("name", ""))] = true
	_palette = s
	return _palette

func _palette_call(method: String, args: Array) -> Variant:
	var s: Script = _palette_script()
	if s == null or not _palette_methods.has(method):
		return null
	return s.callv(method, args)

## Palette surface (shared, cached). Never mutate what this returns.
func _pal(key: String) -> StandardMaterial3D:
	var ck: String = "pal:" + key
	if _mats.has(ck):
		var cached: StandardMaterial3D = _mats[ck]
		return cached
	var m: StandardMaterial3D = null
	var r: Variant = _palette_call("make", [key])
	if r is StandardMaterial3D:
		m = r
	if m == null:
		m = _fallback_mat(key)
	_mats[ck] = m
	return m

func _fallback_mat(key: String) -> StandardMaterial3D:
	var c: Color = FALLBACK_ALBEDO.get(key, Color(0.5, 0.5, 0.5))
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if FALLBACK_EMISSIVE.has(key):
		var ee: float = FALLBACK_EMISSIVE[key]
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = ee
	return m

func _make_lantern_light() -> OmniLight3D:
	var v: Variant = _palette_call("make_lantern_light", [])
	if v is OmniLight3D:
		var pl: OmniLight3D = v
		return pl
	if v is Node:
		var stray: Node = v
		stray.free()
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.718, 0.396)
	o.light_energy = 3.6
	o.omni_range = 17.0
	o.omni_attenuation = 1.5
	o.shadow_enabled = false
	return o

# ------------------------------------------------------------------------------
# Textured surfaces
# ------------------------------------------------------------------------------

## Palette-tinted, world-triplanar textured material. Falls back to the plain
## palette material if the texture is missing. `glow` makes the texture its own
## emission map (gold veins), coloured by the palette's gold_vein emission.
func _tex_mat(tex_file: String, pal_key: String, uv: float, glow: bool = false) -> StandardMaterial3D:
	var ck: String = "tex:%s:%s:%.3f:%s" % [tex_file, pal_key, uv, str(glow)]
	if _mats.has(ck):
		var cached: StandardMaterial3D = _mats[ck]
		return cached
	var base: StandardMaterial3D = _pal(pal_key)
	var path: String = TEX_DIR + tex_file
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		_mats[ck] = base
		return base
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = base.albedo_color.lightened(TEX_TINT_LIFT)
	m.roughness = base.roughness
	m.metallic = minf(base.metallic, 0.2)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true    # instances are scaled boxes: tile in world units
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * uv
	if glow:
		var gv: StandardMaterial3D = _pal("gold_vein")
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission = gv.emission if gv.emission_enabled else Color(1.0, 0.76, 0.3)
		m.emission_energy_multiplier = 0.25
	_mats[ck] = m
	return m

func _rock_mat() -> StandardMaterial3D:
	return _tex_mat(TEX_ROCK, "rock", 0.35)

func _rock_deep_mat() -> StandardMaterial3D:
	return _tex_mat(TEX_ROCK, "rock_deep", 0.35)

func _vein_wall_mat() -> StandardMaterial3D:
	return _tex_mat(TEX_VEIN, "rock", 0.35, true)

func _timber_mat() -> StandardMaterial3D:
	return _tex_mat(TEX_TIMBER, "wood", 0.8)

func _gravel_mat() -> StandardMaterial3D:
	return _tex_mat(TEX_GRAVEL, "rock", 0.6)

# ------------------------------------------------------------------------------
# Materials, meshes, props
# ------------------------------------------------------------------------------

func _mat(key: String, c: Color, emit: float = 0.0, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

func _glow_mat(key: String, c: Color, alpha: float) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

func _mesh_node(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else _world).add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _multi(mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_world.add_child(mmi)
	return mmi

func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		var cached: PackedScene = _scenes[path]
		return cached
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scenes[path] = ps
	return ps

## Instance a GLB without parenting it, or null if it can't be loaded.
func _inst(path: String) -> Node3D:
	var ps: PackedScene = _scene(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	return n

func _prop(path: String, pos: Vector3, scale: float = 1.0, yaw: float = 0.0, parent: Node3D = null) -> Node3D:
	var n: Node3D = _inst(path)
	if n == null:
		return null
	n.position = pos
	n.scale = Vector3.ONE * scale
	if yaw != 0.0:
		n.rotate_y(yaw)
	(parent if parent else _world).add_child(n)
	return n

## Relative transform of `n` expressed in `ancestor`'s space.
func _rel_xform(ancestor: Node, n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		var c3 := cur as Node3D
		if c3:
			t = c3.transform * t
		cur = cur.get_parent()
	return t

## Height box of a Meshy-RIGGED character. A skinned mesh's own AABB is already
## in metres; its Armature node can carry a 0.01 scale (the bear's does, Lil
## Blunt's doesn't), so _measure()'s node-chain transform made the bear read
## 100x too small and drew it 130x too big — off-screen above the scaffold.
func _measure_rig(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var bb: AABB = mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out

## Model-space AABB of every mesh under `root` (root's own transform excluded).
## Returns an empty AABB if nothing could be measured (e.g. dummy renderer).
func _measure(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var bb: AABB = _rel_xform(root, mi) * mi.mesh.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out

func _lane_xs() -> Array:
	return Sim.LANE_X

## Archer data uses side -1 = screen-left, +1 = screen-right. The camera looks
## down +Z, so screen-left is world +X — hence the minus sign.
func _side_x(side: float, dist_from_centre: float) -> float:
	return -side * dist_from_centre

## A bear (bear_archer.glb scaled to `height`) under a plain root node, so the
## fall/leap animation and the headlamp work regardless of model scale.
## A bear: the Meshy-RIGGED bear when present (its RunnerMotion.Anim is stored
## as meta "anim"), else the static model, else a capsule.
func _bear(height: float) -> Node3D:
	var root := Node3D.new()
	var rig: Node3D = _inst(Motion.BEAR_RIG) if not debug_off.has("rig") else null
	if rig:
		var rb: AABB = _measure_rig(rig)
		var rh: float = rb.size.y if rb.size.y > 0.01 else BEAR_NATIVE_H
		rig.scale = Vector3.ONE * (height / rh)
		root.add_child(rig)
		var an: RefCounted = Motion.Anim.new(rig, Motion.BEAR_CLIPS)
		if an.ok():
			root.set_meta("anim", an)
			an.want("idle", 0.0)
		return root
	var model: Node3D = _inst(ARCHER_MODEL)
	if model:
		var bb: AABB = _measure(model)
		var h: float = bb.size.y if bb.size.y > 0.01 else BEAR_NATIVE_H
		model.scale = Vector3.ONE * (height / h)
		root.add_child(model)
	else:
		var cap := CapsuleMesh.new()
		cap.radius = height * 0.22
		cap.height = height
		_mesh_node(cap, _pal("bandit"), Vector3(0.0, height * 0.5, 0.0), root)
	return root

# ------------------------------------------------------------------------------
# Art pass: environment + key light
# ------------------------------------------------------------------------------

func _apply_art() -> void:
	var root: Node = get_parent()
	if root == null:
		return
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		var env_v: Variant = _palette_call("make_environment", [])
		if env_v is Environment:
			var env: Environment = env_v
			we.environment = env
	var key_v: Variant = _palette_call("make_key_light", [])
	if key_v is DirectionalLight3D:
		var key: DirectionalLight3D = key_v
		var sun := root.get_node_or_null("Sun") as DirectionalLight3D
		if sun:
			sun.light_color = key.light_color
			sun.light_energy = key.light_energy
			sun.shadow_enabled = key.shadow_enabled and not debug_off.has("shadows")
		key.free()
	elif key_v is Node:
		var stray: Node = key_v
		stray.free()

# ------------------------------------------------------------------------------
# Static world
# ------------------------------------------------------------------------------

func _build_track(length: float) -> void:
	var ties: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var beams: Array[Transform3D] = []
	for lx in _lane_xs():
		var x: float = float(lx)
		var z := -20.0
		while z < length:
			ties.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.5, z)))
			z += TIE_SPACING
		for side in [-0.55, 0.55]:
			rails.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, length + 20.0)),
				Vector3(x + float(side), -0.38, (length - 20.0) * 0.5)))
		z = -20.0
		while z < length:
			for side in [-0.85, 0.85]:
				posts.append(Transform3D(Basis.IDENTITY, Vector3(x + float(side), -0.6 - PIT_DEPTH * 0.5, z)))
			z += POST_SPACING
		# Gravel ballast deck under the sleepers.
		_mesh_node(_box(Vector3(2.3, 0.12, length + 20.0)), _gravel_mat(),
			Vector3(x, -0.63, (length - 20.0) * 0.5))
	var z2 := -20.0
	while z2 < length:
		beams.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.75, z2)))
		beams.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -4.5, z2 + POST_SPACING * 0.5)))
		z2 += POST_SPACING
	_multi(_box(Vector3(2.0, 0.14, 0.34)), _timber_mat(), ties)
	_multi(_box(Vector3(0.12, 0.14, 1.0)), _pal("iron"), rails)
	_multi(_box(Vector3(0.26, PIT_DEPTH, 0.26)), _timber_mat(), posts)
	_multi(_box(Vector3(7.8, 0.22, 0.28)), _timber_mat(), beams)

func _seg_index(z: float) -> int:
	return int(floor((z + 20.0) / TUNNEL_SEG))

func _is_pocket(i: int) -> bool:
	if _shell_mode:
		return false
	return (i % 4) == 2 or _pocket_segs.has(i)

func _half_w_at_seg(i: int) -> float:
	if _shell_mode:
		return SHELL_WALL_X + 0.06
	if _is_pocket(i):
		return 8.4
	return 5.6 + float(i % 3) * 0.35

func _wall_x_at(z: float) -> float:
	return _half_w_at_seg(_seg_index(z)) - 0.06

## Segmented rock tunnel. One wall segment in four is gold-veined (textured +
## emissive) so the veins glow in the dark between lanterns.
func _build_tunnel(length: float) -> void:
	var segs: int = int(ceil((length + 20.0) / TUNNEL_SEG))
	var bottom: float = -PIT_DEPTH - 0.6
	if _shell_mode and _build_tunnel_shell(length, bottom):
		return
	for i in segs:
		var z0: float = -20.0 + float(i) * TUNNEL_SEG
		var pocket: bool = _is_pocket(i)
		var half_w: float = _half_w_at_seg(i)
		var h: float = (9.0 if pocket else (7.0 + float(i % 2) * 0.8)) + TUNNEL_HEADROOM
		var top: float = h - 0.8
		var wall_mat: StandardMaterial3D = _vein_wall_mat() if (i % 4) == 1 else _rock_mat()
		for side in [-1.0, 1.0]:
			_mesh_node(_box(Vector3(0.6, top - bottom, TUNNEL_SEG)), wall_mat,
				Vector3(half_w * float(side), (top + bottom) * 0.5, z0 + TUNNEL_SEG * 0.5))
		_mesh_node(_box(Vector3(half_w * 2.0 + 1.2, 0.6, TUNNEL_SEG)), _rock_deep_mat(),
			Vector3(0.0, top, z0 + TUNNEL_SEG * 0.5))
		if pocket:
			for side in [-1.0, 1.0]:
				var shelf_w: float = half_w - 5.0
				_mesh_node(_box(Vector3(shelf_w, 0.6, TUNNEL_SEG)), _rock_mat(),
					Vector3(float(side) * (half_w + 5.0) * 0.5, -0.75, z0 + TUNNEL_SEG * 0.5))
			if (i % 4) == 2 and not _pocket_segs.has(i):
				_prop(ROCK_CHUNK_MODEL, Vector3(6.6 * (1.0 if (i % 8) == 2 else -1.0), -0.45, z0 + 9.0), 2.2)

	_mesh_node(_box(Vector3(20.0, 0.2, length + 60.0)), _rock_deep_mat(),
		Vector3(0.0, bottom, (length - 20.0) * 0.5))

	var veins: Array[Transform3D] = []
	var z: float = 6.0
	var i2: int = 0
	while z < length - 40.0:
		var side2: float = 1.0 if (i2 % 2 == 0) else -1.0
		for k in 3:
			var vz: float = z + float(k) * 1.3
			var s: float = 0.22 + float((i2 + k) % 3) * 0.14
			veins.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, s, s * 1.6)),
				Vector3((_wall_x_at(vz) - 0.24) * side2, 0.9 + float((i2 * 3 + k) % 5) * 1.05, vz)))
		z += 4.5
		i2 += 1
	_multi(_box(Vector3.ONE), _pal("gold_vein"), veins)

	var posts: Array[Transform3D] = []
	var beams: Array[Transform3D] = []
	var post_h: float = FRAME_TOP - bottom
	var bz: float = 10.0
	while bz < length - 40.0:
		var wx: float = _wall_x_at(bz) - 0.55
		for side3 in [-1.0, 1.0]:
			posts.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.45, post_h, 0.45)),
				Vector3(wx * float(side3), (FRAME_TOP + bottom) * 0.5, bz)))
		beams.append(Transform3D(Basis.IDENTITY.scaled(Vector3(wx * 2.0 + 0.5, 0.45, 0.45)),
			Vector3(0.0, FRAME_TOP, bz)))
		bz += 18.0
	_multi(_box(Vector3.ONE), _timber_mat(), posts)
	_multi(_box(Vector3.ONE), _timber_mat(), beams)

## The founder's Meshy tunnel ("Three Track Gold Mine Stage") with its dead end
## and floor cut away, tiled down the whole run over our 3-rail trestle and pit.
## Returns false (procedural tunnel instead) if the model can't load.
func _build_tunnel_shell(length: float, bottom: float) -> bool:
	var probe: Node3D = _inst(TUNNEL_SHELL_MODEL)
	if probe == null:
		return false
	probe.free()
	var y0: float = RAIL_TOP - 0.1 - SHELL_NATIVE_FLOOR * SHELL_SCALE.y
	var z: float = -24.0
	var k: int = 0
	while z < length + 20.0:
		var sh: Node3D = _inst(TUNNEL_SHELL_MODEL)
		sh.scale = SHELL_SCALE
		# Alternate 180-degree turns so the repeat reads less like a tile.
		if k % 2 == 1:
			sh.rotation.y = PI
		sh.position = Vector3(0.0, y0, z + SHELL_STEP * 0.5)
		_world.add_child(sh)
		z += SHELL_STEP
		k += 1
	_mesh_node(_box(Vector3(20.0, 0.2, length + 60.0)), _rock_deep_mat(),
		Vector3(0.0, bottom, (length - 20.0) * 0.5))
	return true

func _build_lanterns(length: float) -> void:
	_lantern_pos = PackedVector3Array()
	var arms: Array[Transform3D] = []
	var z: float = 12.0
	var side: float = 1.0
	while z < length - 20.0:
		var wx: float = _wall_x_at(z)
		var p := Vector3((wx - 1.1) * side, LANTERN_Y, z)
		_lantern_pos.append(p)
		if _prop(LANTERN_MODEL, p - Vector3(0.0, 0.42, 0.0), 1.15) == null:
			var sm := SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.4
			_mesh_node(sm, _pal("lantern"), p)
		var arm_len: float = 0.96
		arms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(arm_len, 0.12, 0.12)),
			Vector3(side * (wx - 1.1 + arm_len * 0.5), LANTERN_Y + 0.55, z)))
		z += LANTERN_SPACING
		side = -side
	_multi(_box(Vector3.ONE), _timber_mat(), arms)
	for _i in 4:
		var l: OmniLight3D = _make_lantern_light()
		_world.add_child(l)
		_lights.append(l)

func _build_dressing(chamber_z: float) -> void:
	for gp in [Vector3(-4.3, -0.4, chamber_z * 0.35), Vector3(4.3, -0.4, chamber_z * 0.62),
			Vector3(-4.3, -0.4, chamber_z * 0.88)]:
		var p: Vector3 = gp
		_mesh_node(_box(Vector3(2.0, 0.25, 2.2)), _timber_mat(), Vector3(p.x, p.y - 0.15, p.z))
		_prop(GOLD_PILE_MODEL, p, 1.6)

func _collect_wheels(root: Node, cart: Node3D, out: Array) -> void:
	for ch in root.get_children():
		var n3 := ch as Node3D
		var nm: String = String(ch.name)
		if n3 and (nm.begins_with("Wheel") or nm.begins_with("Hub")):
			var rel: Transform3D = _rel_xform(cart, n3.get_parent())
			var axis: Vector3 = rel.basis.inverse() * Vector3.RIGHT
			if axis.length_squared() < 0.000001:
				axis = Vector3.RIGHT
			out.append({"node": n3, "rest": n3.basis, "axis": axis.normalized()})
			continue
		_collect_wheels(ch, cart, out)

## One ore_cart.glb per rail (long axis yawed onto Z); fallback minecart.glb,
## then a box.
func _build_carts() -> void:
	for lx in _lane_xs():
		var c := Node3D.new()
		c.name = "Cart"
		c.position = Vector3(float(lx), CART_Y, 0.0)
		_world.add_child(c)
		var wheels: Array = []
		var leaf: Node3D = _inst(LEAF_CART_MODEL)
		var ore: Node3D = null if leaf else _inst(ORE_CART_MODEL)
		if leaf:
			_fit_on_rail(leaf, LEAF_CART_LEN, CART_Y)
			c.add_child(leaf)
		elif ore:
			ore.scale = Vector3.ONE * (ORE_CART_LEN / ORE_CART_NATIVE_LEN)
			ore.rotation.y = PI * 0.5
			ore.position = Vector3(0.0, ORE_CART_Y, 0.0)
			c.add_child(ore)
			_collect_wheels(ore, c, wheels)
		else:
			var model: Node3D = _prop(CART_MODEL, Vector3(0.0, CART_MODEL_LIFT, 0.0), 1.0, PI, c)
			if model:
				_collect_wheels(model, c, wheels)
				for n in model.find_children("*", "Node3D", true, false):
					var nm: String = String(n.name)
					if nm.begins_with("EmblemDisc_y") or nm.begins_with("Leaflet_y"):
						(n as Node3D).visible = false
			else:
				_mesh_node(_box(Vector3(1.6, 1.0, 2.2)), _timber_mat(), Vector3(0.0, 0.8, 0.0), c)
		_carts.append(c)
		_cart_wheels.append(wheels)
		var alive: bool = not _sim.has_method("is_cart_alive") or bool(_sim.is_cart_alive(_carts.size() - 1))
		_cart_fx.append({"state": "roll" if alive else "dead", "t": 0.0, "z": 0.0, "spin": 0.0})
		c.visible = alive

## Scale a Meshy prop so its long (Z) side is `length` and set it centred with its
## wheels on the rail top, relative to a parent at height `parent_y`.
func _fit_on_rail(n: Node3D, length: float, parent_y: float) -> void:
	var bb: AABB = _measure(n)
	var s: float = length / bb.size.z if bb.size.z > 0.01 else 1.0
	n.scale = Vector3.ONE * s
	var cx: float = bb.position.x + bb.size.x * 0.5
	var cz: float = bb.position.z + bb.size.z * 0.5
	n.position = Vector3(-cx * s, RAIL_TOP - parent_y - bb.position.y * s, -cz * s)

func _build_rider() -> void:
	_rider = Node3D.new()
	_rider.name = "Rider"
	_world.add_child(_rider)
	_rider_model = _inst(Motion.RIDER_RIG) if not debug_off.has("rig") else null
	if _rider_model:
		var an: RefCounted = Motion.Anim.new(_rider_model, Motion.RIDER_CLIPS)
		if an.ok():
			_rider_anim = an
			an.want("idle", 0.0)
			var sks: Array = _rider_model.find_children("*", "Skeleton3D", true, false)
			if not sks.is_empty():
				_rider_skel = sks[0]
				_bone_r = _rider_skel.find_bone("RightHand")
				_bone_l = _rider_skel.find_bone("LeftHand")
				_bone_head = _rider_skel.find_bone("Head")
				_rider_skel.skeleton_updated.connect(_place_weapons)
				if _bone_r >= 0:
					_aim_mod = AimMod.new()
					_aim_mod.name = "GunArmAim"
					_aim_mod.influence = 0.0
					_rider_skel.add_child(_aim_mod)
	else:
		_rider_model = _inst(RIDER_MODEL)
	if _rider_model:
		var bb: AABB = _measure_rig(_rider_model) if _rider_anim else _measure(_rider_model)
		var h: float = bb.size.y if bb.size.y > 0.01 else RIDER_NATIVE_H
		_rider_scale = RIDER_HEIGHT / h
	else:
		_rider_model = Node3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = RIDER_HEIGHT
		_mesh_node(cap, _pal("leaf_green"), Vector3(0.0, RIDER_HEIGHT * 0.5, 0.0), _rider_model)
		_rider_scale = 1.0
	_rider_model.scale = Vector3.ONE * _rider_scale
	_rider_model.rotation.y = RIDER_YAW
	_rider.add_child(_rider_model)
	var hook := CylinderMesh.new()
	hook.top_radius = 0.05
	hook.bottom_radius = 0.05
	hook.height = CABLE_CLEARANCE - 0.2
	_hook = _mesh_node(hook, _pal("iron"),
		Vector3(0.15, RIDER_HEIGHT + (CABLE_CLEARANCE - 0.2) * 0.5, 0.0), _rider)
	_hook.visible = false
	# Hero lighting: a warm key from behind-above (the side the camera sees) and a
	# cool rim from the front, so he reads against the dark tunnel at any speed.
	var key := OmniLight3D.new()
	key.visible = not debug_off.has("hero")
	key.light_color = Color(1.0, 0.86, 0.62)
	key.light_energy = 1.6
	key.omni_range = 5.0
	key.position = Vector3(0.7, RIDER_HEIGHT + 0.7, -1.7)
	_rider.add_child(key)
	var rim := OmniLight3D.new()
	rim.visible = not debug_off.has("hero")
	rim.light_color = Color(0.62, 0.78, 1.0)
	rim.light_energy = 1.0
	rim.omni_range = 4.0
	rim.position = Vector3(-0.4, RIDER_HEIGHT + 0.4, 1.4)
	_rider.add_child(rim)
	# Emotion bubble: "!" when his own cart is about to be destroyed.
	_emote = Label3D.new()
	_emote.text = "!"
	_emote.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_emote.font_size = 140
	_emote.pixel_size = 0.01
	_emote.outline_size = 22
	_emote.modulate = C_DANGER
	_emote.outline_modulate = Color(0.1, 0.02, 0.0, 0.95)
	_emote.no_depth_test = true
	_emote.position = Vector3(0.0, RIDER_HEIGHT + 0.55, 0.0)
	_emote.visible = false
	_rider.add_child(_emote)
	# Founder's zipline pose (pickaxe hooked on the cable, golden revolver aimed):
	# shown instead of the rigged body while he rides a cable.
	_zip_model = _inst(ZIP_POSE_MODEL)
	if _zip_model:
		var zb: AABB = _measure(_zip_model)
		_zip_scale = ZIP_POSE_H / zb.size.y if zb.size.y > 0.01 else 1.0
		_zip_top = zb.position.y + zb.size.y
		_zip_model.scale = Vector3.ONE * _zip_scale
		_zip_model.visible = false
		_rider.add_child(_zip_model)

## Golden revolver in the screen-right hand, pickaxe in the other.
## Gun rig: pivot (aim, -Z = muzzle) → spin node (barrel-axis spin on reload) → model.
func _build_hands() -> void:
	_gun_pivot = Node3D.new()
	_gun_pivot.name = "GunHand"
	_gun_pivot.position = GUN_HAND
	_rider.add_child(_gun_pivot)
	_gun_spin_node = Node3D.new()
	_gun_pivot.add_child(_gun_spin_node)
	var gun: Node3D = _inst(REVOLVER_MODEL)
	if gun:
		var bb: AABB = _measure(gun)
		var native: float = bb.size.x if bb.size.x > 0.01 else GUN_NATIVE_LEN
		var s: float = GUN_LENGTH / native
		gun.scale = Vector3.ONE * s
		gun.rotation.y = -PI * 0.5          # model muzzle (-X) → pivot -Z
		gun.position = Vector3(0.0, -0.1 * s, 0.0)   # barrel line on the spin axis
		_gun_spin_node.add_child(gun)
	else:
		var barrel := CylinderMesh.new()
		barrel.top_radius = 0.035
		barrel.bottom_radius = 0.035
		barrel.height = GUN_LENGTH
		var bm := _mesh_node(barrel, _pal("gold"), Vector3.ZERO, _gun_spin_node)
		bm.rotation.x = PI * 0.5
		_mesh_node(_box(Vector3(0.07, 0.18, 0.09)), _pal("gold"), Vector3(0.0, -0.1, GUN_LENGTH * 0.35), _gun_spin_node)
	var fm := SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.24
	_muzzle_flash = _mesh_node(fm, _mat("muzzle_flash", Color(1.0, 0.85, 0.45), 8.0),
		Vector3(0.0, 0.0, -GUN_LENGTH * 0.5 - 0.08), _gun_pivot)
	_muzzle_flash.visible = false

	_axe_pivot = Node3D.new()
	_axe_pivot.name = "AxeHand"
	_axe_pivot.position = AXE_HAND
	_rider.add_child(_axe_pivot)
	var axe: Node3D = _inst(PICKAXE_MODEL)
	if axe:
		var abb: AABB = _measure(axe)
		var ah: float = abb.size.y if abb.size.y > 0.01 else AXE_NATIVE_H
		var sa: float = AXE_LENGTH / ah
		axe.scale = Vector3.ONE * sa
		var base_y: float = abb.position.y if abb.size.y > 0.01 else 0.0
		axe.position = Vector3(0.0, -base_y * sa - 0.12, 0.0)   # grip in the fist
		_axe_pivot.add_child(axe)
	else:
		_mesh_node(_box(Vector3(0.06, AXE_LENGTH, 0.06)), _timber_mat(),
			Vector3(0.0, AXE_LENGTH * 0.5 - 0.12, 0.0), _axe_pivot)
		_mesh_node(_box(Vector3(0.5, 0.08, 0.08)), _pal("iron"),
			Vector3(0.0, AXE_LENGTH - 0.14, 0.0), _axe_pivot)
	_axe_pivot.visible = false

func _build_archers() -> void:
	var scaffold_posts: Array[Transform3D] = []
	var decks: Array[Transform3D] = []
	for a in _sim.get_archers():
		var side: float = float(a["side"])
		var z: float = float(a["z"])
		var x: float = _side_x(side, Sim.ARCHER_X)
		_scaffold_at(x, z, scaffold_posts, decks)
		var bear: Node3D = _bear(ARCHER_HEIGHT)
		bear.position = Vector3(x, Sim.ARCHER_Y, z)
		var to_track := Vector3(-signf(x), 0.0, -0.55).normalized()
		bear.rotation.y = atan2(to_track.x, to_track.z)
		_world.add_child(bear)
		var lamp_mesh := SphereMesh.new()
		lamp_mesh.radius = 0.08
		lamp_mesh.height = 0.16
		_mesh_node(lamp_mesh, _mat("headlamp", C_HEADLAMP, 8.0),
			Vector3(0.0, ARCHER_HEIGHT * 0.86, 0.25), bear)
		var ll := OmniLight3D.new()
		ll.light_color = Color(1.0, 0.8, 0.5)
		ll.light_energy = 1.6
		ll.omni_range = 4.5
		ll.position = Vector3(0.0, ARCHER_HEIGHT * 0.9, 0.6)
		bear.add_child(ll)
		# Key light from the track side so the bear pops out of the dark bay.
		var bk := OmniLight3D.new()
		bk.light_color = Color(1.0, 0.7, 0.45)
		bk.light_energy = 2.6
		bk.omni_range = 6.5
		bk.position = Vector3(-signf(x) * 2.2, ARCHER_HEIGHT * 0.7, -1.8)
		bear.add_child(bk)
		var lp := Vector3(x + signf(x) * 1.0, Sim.ARCHER_Y + 0.3, z + 0.9)
		if _prop(LANTERN_MODEL, lp - Vector3(0.0, 0.3, 0.0), 0.9) == null:
			_mesh_node(_box(Vector3(0.3, 0.42, 0.3)), _pal("lantern"), lp)
		_archer_nodes[str(a["id"])] = bear
		if bear.has_meta("anim"):
			_archer_anims[str(a["id"])] = bear.get_meta("anim")
	if scaffold_posts.size() > 0:
		_multi(_box(Vector3(0.24, Sim.ARCHER_Y + PIT_DEPTH, 0.24)), _timber_mat(), scaffold_posts)
		_multi(_box(Vector3(2.8, 0.22, 2.6)), _timber_mat(), decks)

func _scaffold_at(x: float, z: float, posts: Array[Transform3D], decks: Array[Transform3D]) -> void:
	if _shell_mode:
		# Wall ledge inside the tunnel shell: two struts under the outer edge only,
		# so nothing stands between the ledge and the outer rail's cart.
		for dz0 in [-1.0, 1.0]:
			posts.append(Transform3D(Basis.IDENTITY, Vector3(x + signf(x) * 0.7,
				Sim.ARCHER_Y - 0.1 - (Sim.ARCHER_Y + PIT_DEPTH) * 0.5, z + float(dz0) * 1.0)))
		decks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.65, 1.0, 1.0)), Vector3(x + signf(x) * 0.35, Sim.ARCHER_Y - 0.1, z)))
		return
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			posts.append(Transform3D(Basis.IDENTITY,
				Vector3(x + float(dx) * 1.1, Sim.ARCHER_Y - 0.1 - (Sim.ARCHER_Y + PIT_DEPTH) * 0.5, z + float(dz) * 1.0)))
	decks.append(Transform3D(Basis.IDENTITY, Vector3(x, Sim.ARCHER_Y - 0.1, z)))

func _arrow_mesh_node() -> Node3D:
	var root := Node3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.06
	shaft.bottom_radius = 0.06
	shaft.height = 1.9
	var s := _mesh_node(shaft, _pal("arrow"), Vector3.ZERO, root)
	s.rotation.z = PI * 0.5
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.14
	head.height = 0.38
	var h := _mesh_node(head, _pal("arrow_head"), Vector3(1.1, 0.0, 0.0), root)
	h.rotation.z = -PI * 0.5
	var fletch := _mesh_node(_box(Vector3(0.28, 0.2, 0.02)), _pal("bandit_cloth"),
		Vector3(-0.7, 0.0, 0.0), root)
	fletch.rotation.x = 0.4
	_mesh_node(_box(Vector3(2.6, 0.05, 0.05)), _glow_mat("arrow_trail", C_DUCK, 0.45), Vector3(-2.2, 0.0, 0.0), root)
	_world.add_child(root)
	return root

func _boulder_node(x: float, z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, BOULDER_R - 0.35, z)
	_world.add_child(pivot)
	var rock: Node3D = _inst(BOULDER_ROCK_MODEL)
	if rock:
		var bb: AABB = _measure(rock)
		var native: float = BOULDER_ROCK_NATIVE
		var centre := Vector3(0.0, 0.5, 0.0)
		if bb.size.y > 0.01:
			native = maxf(bb.size.y, maxf(bb.size.x, bb.size.z))
			centre = bb.get_center()
		var s: float = BOULDER_R * 2.0 / native
		rock.scale = Vector3.ONE * s
		rock.position = -centre * s        # roll about its own centre
		pivot.add_child(rock)
	elif _prop(BOULDER_MODEL, Vector3.ZERO, BOULDER_R / BOULDER_MODEL_R, 0.0, pivot) == null:
		var sm := SphereMesh.new()
		sm.radius = BOULDER_R
		sm.height = BOULDER_R * 2.0
		_mesh_node(sm, _tex_mat(TEX_ROCK, "boulder", 0.5), Vector3.ZERO, pivot)
	return pivot

func _build_hazards() -> void:
	var obs_all: Array = _sim.get_obstacles()
	for oi in obs_all.size():
		var o: Dictionary = obs_all[oi]
		var lane: int = clampi(int(o["lane"]), 0, _lane_xs().size() - 1)
		var x: float = float(_lane_xs()[lane])
		var z: float = float(o["z"])
		var t: String = str(o["type"])
		var arrow_node: Node3D = null
		var boulder_node: Node3D = null
		match t:
			"arrow":
				arrow_node = _arrow_mesh_node()
				arrow_node.visible = false
				_add_telegraph(x, z, C_DUCK, "DUCK" if not _sim.can_shoot() else "DUCK / SHOOT", oi)
			"boulder":
				boulder_node = _boulder_node(x, z)
				_add_telegraph(x, z, C_HOP, "HOP!")
			"boarder", "gold":
				pass                        # built by _build_boarders() / _build_gold()
			_:
				var crate := _mesh_node(_box(Vector3(1.4, 1.0, 1.0)), _tex_mat(TEX_TIMBER, "crate", 0.9), Vector3(x, 0.15, z))
				_mesh_node(_box(Vector3(1.46, 0.14, 1.06)), _pal("brass"), Vector3(0.0, 0.3, 0.0), crate)
				_add_telegraph(x, z, C_JUMP, "JUMP")
		_arrow_nodes.append(arrow_node)
		_boulder_nodes.append(boulder_node)
	if _sim.can_shoot():
		for a in _sim.get_archers():
			var lbl := _label("SHOOT", C_SHOOT)
			lbl.position = Vector3(_side_x(float(a["side"]), Sim.ARCHER_X), Sim.ARCHER_Y + 3.6, float(a["z"]))
			_labels.append({"node": lbl, "z": float(a["z"]), "strip": null, "archer": str(a["id"])})

## Each boarder: a bear on the nearest side's scaffold that leaps into the
## rider's cart, plus its SWIPE telegraph (which follows the rider's rail).
func _build_boarders() -> void:
	var posts: Array[Transform3D] = []
	var decks: Array[Transform3D] = []
	var obs_all: Array = _sim.get_obstacles()
	var n_b: int = 0
	for oi in obs_all.size():
		var o: Dictionary = obs_all[oi]
		if str(o.get("type", "")) != "boarder":
			continue
		var z: float = float(o["z"])
		var side: float = 1.0 if (n_b % 2) == 0 else -1.0
		var best_dz: float = INF
		for a in _sim.get_archers():
			var dz: float = absf(float(a["z"]) - z)
			if dz < best_dz:
				best_dz = dz
				side = float(a["side"])
		n_b += 1
		var sx: float = _side_x(side, Sim.ARCHER_X)
		_scaffold_at(sx, z, posts, decks)
		var bear: Node3D = _bear(BOARDER_HEIGHT)
		bear.position = Vector3(sx, Sim.ARCHER_Y, z)
		_world.add_child(bear)
		var lbl := _label("SWIPE! F / right-click", C_SWIPE)
		lbl.font_size = 80
		lbl.position = Vector3(0.0, 3.3, z)
		_boarders.append({"obs": oi, "z": z, "node": bear, "label": lbl, "start_x": sx,
			"state": "idle", "t": 0.0, "from": Vector3.ZERO})
	if posts.size() > 0:
		_multi(_box(Vector3(0.24, Sim.ARCHER_Y + PIT_DEPTH, 0.24)), _timber_mat(), posts)
		_multi(_box(Vector3(2.8, 0.22, 2.6)), _timber_mat(), decks)

func _label(text: String, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.pixel_size = 0.012
	l.outline_size = 18
	l.modulate = c
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	l.no_depth_test = true
	l.visible = false
	_world.add_child(l)
	return l

func _add_telegraph(x: float, z: float, c: Color, verb: String, obs_index: int = -1) -> void:
	var strip := _mesh_node(_box(Vector3(1.9, 0.04, 6.0)), _glow_mat("strip_" + verb, c, 0.35),
		Vector3(x, -0.36, z - 1.5))
	strip.visible = false
	for e in _labels:
		if e.get("verb", "") == verb and is_equal_approx(float(e["z"]), z):
			var xs: Array = e["xs"]
			xs.append(x)
			var mean := 0.0
			for v in xs:
				mean += float(v)
			(e["node"] as Label3D).position.x = mean / float(xs.size())
			(e["strips"] as Array).append(strip)
			if obs_index >= 0:
				(e["obs"] as Array).append(obs_index)
			return
	var lbl := _label(verb, c)
	lbl.position = Vector3(x, 3.3, z)
	_labels.append({"node": lbl, "z": z, "strip": null, "strips": [strip], "archer": "", "verb": verb,
		"xs": [x], "obs": ([obs_index] if obs_index >= 0 else [])})

func _build_ziplines() -> void:
	var segs: Array = _sim.get_zip_segments()
	var cable_y: float = Sim.ZIP_HEIGHT + RIDER_HEIGHT + CABLE_CLEARANCE - 0.2
	for i in segs.size():
		var s0: float = float(segs[i]["start_z"])
		var s1: float = float(segs[i]["end_z"])
		if s1 <= s0:
			continue
		var cable := CylinderMesh.new()
		cable.top_radius = 0.045
		cable.bottom_radius = 0.045
		cable.height = s1 - s0 + 4.0
		var cm := _mesh_node(cable, _pal("steel_cable"), Vector3(0.0, cable_y, (s0 + s1) * 0.5))
		cm.rotation.x = PI * 0.5
		for pz in [s0 - 2.0, s1 + 2.0]:
			for gx in [-4.6, 4.6]:
				_mesh_node(_box(Vector3(0.45, cable_y + PIT_DEPTH + 0.8, 0.45)), _timber_mat(),
					Vector3(float(gx), (cable_y - PIT_DEPTH) * 0.5 + 0.4, float(pz)))
			_mesh_node(_box(Vector3(9.8, 0.4, 0.45)), _timber_mat(),
				Vector3(0.0, cable_y + 0.45, float(pz)))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.16
		ring.outer_radius = 0.26
		var rm := _mesh_node(ring, _mat("zip_ring", C_ZIP, 1.4, 0.3, 0.8), Vector3(0.0, cable_y, s0))
		rm.rotation.x = PI * 0.5
		_zip_markers.append({"ring": rm, "z": s0})
		var chained: bool = i > 0 and s0 - float(segs[i - 1]["end_z"]) <= Sim.ZIP_CHAIN_GAP
		var verb := "JUMP → next line" if chained else "JUMP → ZIPLINE"
		var lbl := _label(verb, C_ZIP)
		lbl.font_size = 72
		lbl.position = Vector3(0.0, cable_y - 0.6, s0 - (2.0 if chained else 0.0))
		_labels.append({"node": lbl, "z": s0, "strip": null, "archer": "", "near": 9.0})

## Gold nuggets: glowing, spinning pickups on their rail (bait toward risk).
##
## UNSHADED on purpose. The first version reused gold_pile.glb (metallic 0.85,
## roughness 0.22, emissive) at pickup scale, spinning on the rail — and in the
## web build (Compatibility / WebGL2) every frame with one in view rendered NO 3D
## AT ALL: HUD only, for ~3 s per gold cluster. Bisected in Chromium with
## ?ep2off=: gold off → zero blank frames; halo off → still blank. Unshaded
## pickups have no lighting maths to go wrong; they read as gold from colour,
## silhouette, spin and the halo.
func _build_gold() -> void:
	# BITCOIN coins (founder 2026-09-27: "I like the gold coins. Lets make them
	# Bitcoin branded"). A gold rim + the ₿ face texture on both sides + a soft
	# halo: 4 unshaded instances per coin.
	var obs_all: Array = _sim.get_obstacles()
	var face_mat := StandardMaterial3D.new()
	face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face_mat.alpha_scissor_threshold = 0.5
	var tex_path: String = TEX_DIR + TEX_BTC
	if ResourceLoader.exists(tex_path):
		face_mat.albedo_texture = load(tex_path) as Texture2D
	else:
		face_mat.albedo_color = Color(1.0, 0.8, 0.28)
	var face := QuadMesh.new()
	face.size = Vector2(0.9, 0.9)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.44
	rim.bottom_radius = 0.44
	rim.height = 0.07
	rim.radial_segments = 20
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.albedo_color = Color(0.86, 0.62, 0.16)
	var halo := SphereMesh.new()
	halo.radius = 0.5
	halo.height = 1.0
	halo.radial_segments = 8
	halo.rings = 4
	for oi in obs_all.size():
		var o: Dictionary = obs_all[oi]
		if str(o.get("type", "")) != "gold":
			_gold_nodes.append(null)
			continue
		var lane: int = clampi(int(o["lane"]), 0, _lane_xs().size() - 1)
		var n := Node3D.new()
		n.position = Vector3(float(_lane_xs()[lane]), GOLD_Y, float(o["z"]))
		_world.add_child(n)
		var rm := _mesh_node(rim, rim_mat, Vector3.ZERO, n)
		rm.rotation.x = PI * 0.5
		_mesh_node(face, face_mat, Vector3(0.0, 0.0, -0.037), n).rotation.y = PI
		_mesh_node(face, face_mat, Vector3(0.0, 0.0, 0.037), n)
		if not debug_off.has("halo"):
			_mesh_node(halo, _glow_mat("gold_halo", Color(1.0, 0.8, 0.3), 0.16), Vector3.ZERO, n).scale = Vector3.ONE * 1.5
		_gold_nodes.append(n)

## Gold-mine dressing from the founder key art: gold ore glinting in the walls,
## wall lanterns, timber walkways with lanterns high on the walls, and glowing
## gold heaps + parked, gold-filled ore carts on the ledges. MultiMesh-heavy so
## the web build stays cheap (and well clear of research/001).
func _build_mine_detail(length: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7701
	# 1. Ore clusters in the walls.
	var ore: Array[Transform3D] = []
	var z: float = 4.0
	while z < length - 10.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.5:
				var wx: float = _wall_x_at(z) - 0.3
				var cy: float = rng.randf_range(0.2, 6.2)
				for _k in rng.randi_range(2, 5):
					# Glints, not blobs: first capture read as yellow popcorn at 0.08-0.22.
					var sc: float = rng.randf_range(0.035, 0.09)
					var b := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3.ONE * sc)
					ore.append(Transform3D(b, Vector3(wx * float(side), cy + rng.randf_range(-0.35, 0.35), z + rng.randf_range(-0.5, 0.5))))
		z += rng.randf_range(1.2, 2.4)
	var nug := SphereMesh.new()
	nug.radius = 1.0
	nug.height = 2.0
	nug.radial_segments = 5
	nug.rings = 3
	_multi(nug, _mat("wall_ore", Color(0.95, 0.68, 0.2), 1.1, 0.35, 0.7), ore)
	# 2. Wall lantern glows between the real lantern props.
	var glows: Array[Transform3D] = []
	var brackets: Array[Transform3D] = []
	z = 5.0
	var sd: float = -1.0
	while z < length - 10.0:
		var wx2: float = _wall_x_at(z) - 0.45
		glows.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.16, 0.22, 0.16)), Vector3(wx2 * sd, 2.6, z)))
		brackets.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.5, 0.08, 0.08)), Vector3((wx2 + 0.2) * sd, 2.85, z)))
		z += 7.0
		sd = -sd
	_multi(nug, _mat("wall_lantern", Color(1.0, 0.72, 0.36), 5.0), glows)
	_multi(_box(Vector3.ONE), _timber_mat(), brackets)
	# 3. Timber walkways high on the walls, each with a lantern.
	var decks: Array[Transform3D] = []
	var legs: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	z = 30.0
	var ws: float = 1.0
	while z < length - 20.0:
		var wx3: float = _wall_x_at(z) - 1.0
		var y3: float = 4.6
		decks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.6, 0.14, 7.0)), Vector3(wx3 * ws, y3, z)))
		rails.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.08, 0.08, 7.0)), Vector3((wx3 - 0.75) * ws, y3 + 0.8, z)))
		for dz in [-3.2, 0.0, 3.2]:
			legs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.14, 0.9, 0.14)), Vector3((wx3 - 0.75) * ws, y3 + 0.45, z + float(dz))))
			legs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.16, 1.4, 0.16)), Vector3((wx3 - 0.6) * ws, y3 - 0.7, z + float(dz))))
		lamps.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, 0.24, 0.18)), Vector3((wx3 - 0.6) * ws, y3 + 1.1, z + 2.0)))
		z += rng.randf_range(34.0, 52.0)
		ws = -ws
	_multi(_box(Vector3.ONE), _timber_mat(), decks)
	_multi(_box(Vector3.ONE), _timber_mat(), legs)
	_multi(_box(Vector3.ONE), _timber_mat(), rails)
	_multi(nug, _mat("wall_lantern", Color(1.0, 0.72, 0.36), 5.0), lamps)
	# 4. Gold heaps on the ledges; a gold-filled ore cart parked every ~90 m.
	var heap: Array[Transform3D] = []
	z = 22.0
	var hs: float = 1.0
	var n_cart: int = 0
	while z < length - 20.0:
		var hx: float = (_wall_x_at(z) - 1.0) * hs
		var cart_here: bool = n_cart % 3 == 0
		if cart_here:
			var cart: Node3D = _inst(LEAF_CART_MODEL)
			if cart:
				var holder := Node3D.new()
				holder.position = Vector3(hx, 0.0, z)
				_world.add_child(holder)
				_fit_on_rail(cart, LEAF_CART_LEN, 0.1)
				holder.add_child(cart)
		for _k in 22:
			var r: float = rng.randf_range(0.0, 0.6)
			var a: float = rng.randf() * TAU
			var sc2: float = rng.randf_range(0.06, 0.13)
			var top: float = (0.75 if cart_here else 0.0) + (0.55 - r) * 0.7
			heap.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc2),
				Vector3(hx + cos(a) * r * 0.8, top - 0.2, z + sin(a) * r * (1.4 if cart_here else 0.9))))
		z += rng.randf_range(26.0, 38.0)
		hs = -hs
		n_cart += 1
	_multi(nug, _mat("ledge_gold", Color(0.98, 0.74, 0.26), 0.9, 0.3, 0.7), heap)

## Rail events drawn where they happen: a siding (outer rails) or ore chute
## (centre) for every replacement cart, a buffer stop for every rail end.
func _build_rail_events() -> void:
	if not _sim.has_method("get_rail_events"):
		return
	for e in _sim.get_rail_events():
		var lane: int = clampi(int(e["lane"]), 0, _lane_xs().size() - 1)
		var lx: float = float(_lane_xs()[lane])
		var z: float = float(e["z"])
		if str(e["type"]) == "end":
			var buf := _mesh_node(_box(Vector3(1.8, 0.9, 0.6)), _timber_mat(), Vector3(lx, 0.05, z + 0.8))
			_mesh_node(_box(Vector3(1.9, 0.12, 0.66)), _pal("iron"), Vector3(0.0, 0.3, 0.0), buf)
			var lamp := SphereMesh.new()
			lamp.radius = 0.16
			lamp.height = 0.32
			_mesh_node(lamp, _mat("buffer_lamp", C_DANGER, 6.0), Vector3(0.0, 0.8, 0.0), buf)
			_add_telegraph(lx, z, C_DANGER, "RAIL ENDS")
		else:
			if absf(lx) < 0.1:
				var chute := _mesh_node(_box(Vector3(2.2, 0.25, 4.0)), _timber_mat(),
					Vector3(lx, CHUTE_HEIGHT + 1.4, z - 2.0))
				chute.rotation.x = 0.35
				for px in [-1.2, 1.2]:
					_mesh_node(_box(Vector3(0.22, CHUTE_HEIGHT + 2.0, 0.22)), _timber_mat(),
						Vector3(lx + float(px), (CHUTE_HEIGHT + 2.0) * 0.5 - 0.4, z - 0.5))
			else:
				var side: float = signf(lx)
				var z0: float = z - SPAWN_LEAD - 8.0
				var a := Vector3(lx + side * SIDING_OFFSET, -0.36, z0)
				var b := Vector3(lx, -0.36, z)
				for rail_dx in [-0.55, 0.55]:
					var rail := _mesh_node(_box(Vector3(0.1, 0.12, a.distance_to(b))), _pal("iron"),
						(a + b) * 0.5 + Vector3(float(rail_dx), 0.0, 0.0))
					rail.rotation.y = atan2(b.x - a.x, b.z - a.z)
			var lbl := _label("NEW CART ▸", Color(0.55, 1.0, 0.55))
			lbl.font_size = 64
			lbl.position = Vector3(lx, 2.9, z)
			_labels.append({"node": lbl, "z": z, "strip": null, "archer": "", "near": 2.0})

func _update_gold(dist: float, delta: float) -> void:
	var obs: Array = _sim.get_obstacles()
	for i in mini(_gold_nodes.size(), obs.size()):
		var n: Node3D = _gold_nodes[i]
		if n == null:
			continue
		var o: Dictionary = obs[i]
		if bool(o.get("taken", false)):
			if n.visible:
				n.visible = false
				if _gold_burst:
					_gold_burst.position = n.position
					_gold_burst.restart()
					_gold_burst.emitting = true
				_popup("+1 BTC", C_GOLD_HUD, n.position + Vector3(0.0, 1.2, 1.5))
			continue
		var ahead: float = float(o["z"]) - dist
		n.visible = ahead > -2.0 and ahead < 90.0 and not debug_off.has("gold")
		n.rotation.y += delta * 3.0
		n.position.y = GOLD_Y + sin(Time.get_ticks_msec() * 0.004 + float(i)) * 0.12

func _popup(text: String, c: Color, pos: Vector3) -> void:
	var l := _label(text, c)
	l.font_size = 72
	l.position = pos
	l.visible = true
	_popups.append({"node": l, "t": 0.0})

func _update_popups(delta: float) -> void:
	var keep: Array = []
	for pd in _popups:
		var d: Dictionary = pd
		var l: Label3D = d["node"]
		if l == null or not is_instance_valid(l):
			continue
		var t: float = float(d["t"]) + delta
		d["t"] = t
		l.position.y += delta * 1.4
		l.position.z = float(_sim.get_distance()) + 4.0 if _sim else l.position.z
		l.modulate.a = clampf(1.2 - t, 0.0, 1.0)
		if t > 1.2:
			l.queue_free()
		else:
			keep.append(d)
	_popups = keep

func _build_portal(z: float) -> void:
	var h := 7.5
	for x in [-4.8, 4.8]:
		_mesh_node(_box(Vector3(0.9, h + PIT_DEPTH, 0.9)), _timber_mat(),
			Vector3(float(x), (h - PIT_DEPTH) * 0.5, z))
	_mesh_node(_box(Vector3(11.0, 0.9, 1.0)), _timber_mat(), Vector3(0.0, h, z))
	_mesh_node(_box(Vector3(9.0, h + 0.5, 0.2)), _pal("gate"), Vector3(0.0, h * 0.5 - 0.4, z + 3.0))
	var gold_mat: StandardMaterial3D = _pal("gold")
	var gold: Color = gold_mat.albedo_color
	var l := OmniLight3D.new()
	l.light_color = gold
	l.light_energy = 6.0
	l.omni_range = 26.0
	l.position = Vector3(0.0, 3.5, z - 1.0)
	_world.add_child(l)
	var plate := _label("GOLD MINE PROTOCOL", gold)
	plate.position = Vector3(0.0, h + 1.2, z - 0.6)
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.rotation.y = PI
	plate.visible = true
	plate.no_depth_test = false

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.near = 0.1
	_camera.far = 160.0
	_world.add_child(_camera)
	_camera.current = true

func _build_fx() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.35
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(0.9, 0.05, 0.9)
	_sparks.direction = Vector3(0.0, 0.6, -1.0)
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 6.0
	_sparks.gravity = Vector3(0.0, -12.0, 0.0)
	_sparks.scale_amount_min = 0.03
	_sparks.scale_amount_max = 0.06
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 4
	sm.rings = 2
	_sparks.mesh = sm
	_sparks.material_override = _pal("spark")
	_world.add_child(_sparks)

	var tracer := CylinderMesh.new()
	tracer.top_radius = 0.03
	tracer.bottom_radius = 0.03
	tracer.height = 1.0
	_tracer = _mesh_node(tracer, _mat("tracer", C_TRACER, 6.0), Vector3.ZERO)
	_tracer.visible = false
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.85, 0.5)
	_flash.omni_range = 7.0
	_flash.light_energy = 0.0
	_world.add_child(_flash)

	# Cart smash: splintered planks + iron bits.
	_debris = CPUParticles3D.new()
	_debris.one_shot = true
	_debris.emitting = false
	_debris.amount = 36
	_debris.lifetime = 1.2
	_debris.explosiveness = 0.95
	_debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_debris.emission_box_extents = Vector3(0.8, 0.4, 1.0)
	_debris.direction = Vector3(0.0, 1.0, 0.3)
	_debris.spread = 70.0
	_debris.initial_velocity_min = 5.0
	_debris.initial_velocity_max = 11.0
	_debris.angular_velocity_min = -540.0
	_debris.angular_velocity_max = 540.0
	_debris.gravity = Vector3(0.0, -22.0, 0.0)
	_debris.scale_amount_min = 0.6
	_debris.scale_amount_max = 1.4
	_debris.mesh = _box(Vector3(0.5, 0.08, 0.16))
	_debris.material_override = _timber_mat()
	_world.add_child(_debris)

	# Gold pickup sparkle.
	_gold_burst = CPUParticles3D.new()
	_gold_burst.one_shot = true
	_gold_burst.emitting = false
	_gold_burst.amount = 18
	_gold_burst.lifetime = 0.5
	_gold_burst.explosiveness = 1.0
	_gold_burst.direction = Vector3(0.0, 1.0, 0.0)
	_gold_burst.spread = 180.0
	_gold_burst.initial_velocity_min = 2.5
	_gold_burst.initial_velocity_max = 5.0
	_gold_burst.gravity = Vector3(0.0, -6.0, 0.0)
	_gold_burst.scale_amount_min = 0.06
	_gold_burst.scale_amount_max = 0.12
	var gs := SphereMesh.new()
	gs.radius = 0.5
	gs.height = 1.0
	gs.radial_segments = 4
	gs.rings = 2
	_gold_burst.mesh = gs
	_gold_burst.material_override = _mat("gold_spark", Color(1.0, 0.85, 0.35), 4.0)
	_world.add_child(_gold_burst)

	# Speed streaks rushing past the camera (camera-local, scale with speed).
	_streaks = CPUParticles3D.new()
	_streaks.local_coords = true
	_streaks.amount = 48
	_streaks.lifetime = 0.55
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(7.0, 4.0, 3.0)
	_streaks.position = Vector3(0.0, 0.0, -26.0)
	_streaks.direction = Vector3(0.0, 0.0, 1.0)
	_streaks.spread = 2.0
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 42.0
	_streaks.initial_velocity_max = 58.0
	_streaks.mesh = _box(Vector3(0.025, 0.025, 1.8))
	_streaks.material_override = _glow_mat("speed_streak", Color(1.0, 0.9, 0.7), 0.35)
	# Gold dust drifting in the lantern light (world-space, spawned around the camera).
	_dust = CPUParticles3D.new()
	_dust.amount = 70
	_dust.lifetime = 3.5
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(5.0, 3.0, 9.0)
	_dust.position = Vector3(0.0, 0.0, -10.0)
	_dust.direction = Vector3(0.0, 0.3, 0.0)
	_dust.spread = 180.0
	_dust.gravity = Vector3(0.0, -0.05, 0.0)
	_dust.initial_velocity_min = 0.05
	_dust.initial_velocity_max = 0.3
	_dust.scale_amount_min = 0.015
	_dust.scale_amount_max = 0.04
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.0
	dm.radial_segments = 4
	dm.rings = 2
	_dust.mesh = dm
	_dust.material_override = _glow_mat("gold_dust", Color(1.0, 0.85, 0.5), 0.55)
	if _camera and not debug_off.has("dust"):
		_camera.add_child(_dust)
		_camera.add_child(_streaks)
	else:
		_world.add_child(_streaks)

# ------------------------------------------------------------------------------
# HUD + audio (built once, persist across rebuilds)
# ------------------------------------------------------------------------------

func _ensure_hud() -> void:
	if _hud and is_instance_valid(_hud):
		return
	_hud = CanvasLayer.new()
	_hud.name = "RunnerHUD"
	_hud.layer = 5
	add_child(_hud)
	_reticle = Control.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.size = Vector2(56.0, 56.0)
	_reticle.draw.connect(_draw_reticle)
	_hud.add_child(_reticle)
	_pips.clear()
	for _i in Sim.CYLINDER:
		var p := ColorRect.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = Vector2(12.0, 26.0)
		p.color = C_PIP
		_hud.add_child(p)
		_pips.append(p)
	_reload_bg = ColorRect.new()
	_reload_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_bg.size = Vector2(124.0, 10.0)
	_reload_bg.color = Color(0.1, 0.08, 0.05, 0.75)
	_hud.add_child(_reload_bg)
	_reload_fill = ColorRect.new()
	_reload_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_fill.size = Vector2(0.0, 6.0)
	_reload_fill.color = C_PIP
	_hud.add_child(_reload_fill)
	_reload_label = _hud_label("RELOADING", C_PIP)
	_hint_label = _hud_label("R — reload", Color(1.0, 0.95, 0.85))
	_gold_label = _hud_label("BTC 0", C_GOLD_HUD)
	_gold_label.add_theme_font_size_override("font_size", 26)
	_cart_strip = Control.new()
	_cart_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cart_strip.size = Vector2(220.0, 70.0)
	_cart_strip.draw.connect(_draw_cart_strip)
	_hud.add_child(_cart_strip)

func _hud_label(text: String, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.visible = false
	_hud.add_child(l)
	return l

func _draw_reticle() -> void:
	if _reticle == null:
		return
	var c: Vector2 = _reticle.size * 0.5
	var col: Color = C_RETICLE_HOT if _reticle_hot else C_RETICLE
	_reticle.draw_arc(c, 14.0, 0.0, TAU, 32, col, 2.5, true)
	for d in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
		var dv: Vector2 = d
		_reticle.draw_line(c + dv * 7.0, c + dv * 22.0, col, 2.5, true)
	_reticle.draw_circle(c, 2.0, col)
	if _sim != null and bool(_sim.is_reloading()):
		var prog: float = float(_sim.get_reload_progress())
		_reticle.draw_arc(c, 20.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, C_PIP, 3.0, true)

func _update_hud() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var running: bool = _sim != null and bool(_sim.is_running())
	_hud.visible = running
	if not running:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vs: Vector2 = vp.get_visible_rect().size
	var mp: Vector2 = vp.get_mouse_position()
	_reticle.position = mp - _reticle.size * 0.5
	_reticle_hot = _aim_hit != ""
	_reticle.queue_redraw()
	var armed: bool = bool(_sim.can_shoot())
	var ammo: int = int(_sim.get_ammo())
	var reloading: bool = bool(_sim.is_reloading())
	for i in _pips.size():
		var p: ColorRect = _pips[i]
		p.visible = armed
		p.position = Vector2(vs.x - 30.0 - float(_pips.size() - 1 - i) * 18.0, vs.y - 46.0)
		p.color = C_PIP if i < ammo else C_PIP_SPENT
	var bar_pos := Vector2(vs.x - 150.0, vs.y - 64.0)
	_reload_bg.visible = armed and reloading
	_reload_fill.visible = armed and reloading
	_reload_label.visible = armed and reloading
	_reload_bg.position = bar_pos
	_reload_fill.position = bar_pos + Vector2(2.0, 2.0)
	_reload_fill.size = Vector2(120.0 * float(_sim.get_reload_progress()), 6.0)
	_reload_label.position = bar_pos + Vector2(0.0, -30.0)
	_hint_label.visible = armed and not reloading and ammo <= 2
	_hint_label.position = Vector2(vs.x - 150.0, vs.y - 92.0)
	if _gold_label:
		_gold_label.visible = true
		var spd: float = float(_sim.get_speed()) if _sim.has_method("get_speed") else Sim.RUN_SPEED
		var g: int = int(_sim.get_gold()) if _sim.has_method("get_gold") else 0
		_gold_label.text = "BTC  %d      %d m/s" % [g, int(round(spd))]
		_gold_label.position = Vector2(24.0, 18.0)
	if _cart_strip:
		_cart_strip.position = Vector2(vs.x * 0.5 - _cart_strip.size.x * 0.5, vs.y - 84.0)
		_cart_strip.queue_redraw()

## Bottom-centre convoy readout, laid out like the screen (lane 0 = left):
## live carts gold, wrecked carts dark with a red X, your cart outlined, a green
## "+" over a dead rail whose replacement is coming, a red "!" over a rail about
## to be destroyed, and a red flash when a hop is refused.
func _draw_cart_strip() -> void:
	if _cart_strip == null or _sim == null or not _sim.has_method("is_cart_alive"):
		return
	var dist: float = float(_sim.get_distance())
	var spd: float = maxf(float(_sim.get_speed()), 1.0)
	var lane: int = int(_sim.get_lane())
	var font: Font = ThemeDB.fallback_font
	for i in 3:
		var r := Rect2(Vector2(8.0 + float(i) * 70.0, 28.0), Vector2(58.0, 30.0))
		var alive: bool = bool(_sim.is_cart_alive(i))
		_cart_strip.draw_rect(r, C_PIP if alive else Color(0.18, 0.12, 0.1, 0.8))
		_cart_strip.draw_circle(r.position + Vector2(12.0, 32.0), 5.0, Color(0.15, 0.12, 0.1))
		_cart_strip.draw_circle(r.position + Vector2(46.0, 32.0), 5.0, Color(0.15, 0.12, 0.1))
		if not alive:
			_cart_strip.draw_line(r.position + Vector2(8, 4), r.end - Vector2(8, 4), C_DANGER, 4.0)
			_cart_strip.draw_line(Vector2(r.end.x - 8, r.position.y + 4), Vector2(r.position.x + 8, r.end.y - 4), C_DANGER, 4.0)
		if i == lane and not bool(_sim.is_ziplining()):
			_cart_strip.draw_rect(r.grow(4.0), Color(1, 1, 1, 0.95), false, 3.0)
		if i == _blocked_lane and _blocked_t < 0.4:
			_cart_strip.draw_rect(r.grow(6.0), C_DANGER, false, 4.0)
		var mark := ""
		var mc := Color.WHITE
		if alive and Motion.danger_eta(_sim, i, dist, spd) < Motion.DANGER_SECS:
			mark = "!"
			mc = C_DANGER
		elif not alive:
			for e in _sim.get_rail_events():
				if int(e["lane"]) == i and str(e["type"]) == "spawn" and not bool(e["done"]) \
						and float(e["z"]) - dist < 80.0:
					mark = "+"
					mc = Color(0.55, 1.0, 0.55)
					break
		if mark != "" and font:
			_cart_strip.draw_string(font, r.position + Vector2(22.0, -4.0), mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, mc)

func _ensure_audio() -> void:
	if not _sfx.is_empty():
		return
	var bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for key in SFX_FILES:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		var path: String = SFX_DIR + str(SFX_FILES[key])
		if ResourceLoader.exists(path):
			p.stream = load(path) as AudioStream
		add_child(p)
		_sfx[key] = p

func _play(key: String) -> void:
	var p: AudioStreamPlayer = _sfx.get(key)
	if p == null or p.stream == null or not p.is_inside_tree():
		return
	p.play()

# ------------------------------------------------------------------------------
# Per-frame
# ------------------------------------------------------------------------------

## Each rail's cart: rolling with the convoy, WRECKED (tumbles into the pit where
## it was hit and falls behind), dead (hidden unless a replacement is rolling in
## on its siding / dropping from the chute), then rolling again once spawned.
func _update_convoy(dist: float) -> void:
	var spin: float = dist / CART_WHEEL_R
	var xs: Array = _lane_xs()
	var dt: float = get_process_delta_time()
	for i in _carts.size():
		var c: Node3D = _carts[i]
		var lx: float = float(xs[i])
		var st: String = "roll"
		if i < _cart_fx.size():
			var fx: Dictionary = _cart_fx[i]
			st = str(fx["state"])
			if st == "wreck":
				var t: float = float(fx["t"]) + dt
				fx["t"] = t
				var out: float = signf(lx) if absf(lx) > 0.1 else float(fx["spin"])
				c.position = Vector3(lx + out * 2.4 * t, CART_Y + 3.2 * t - 11.0 * t * t, float(fx["z"]) + 5.0 * t)
				c.rotation = Vector3(-2.2 * t, 0.9 * out * t, -out * 3.6 * t)
				c.visible = t < WRECK_TIME
				if t >= WRECK_TIME:
					fx["state"] = "dead"
				continue
			if st == "dead":
				c.visible = _spawn_preview(i, c, lx, dist)
				if not c.visible:
					continue
		if st == "roll":
			c.visible = true
			c.position = Vector3(lx, CART_Y + sin(dist * 1.7 + i * 2.1) * 0.025, dist)
			c.rotation = Vector3(0.0, 0.0, sin(dist * 1.1 + i) * 0.015)
		var wheels: Array = _cart_wheels[i]
		for w in wheels:
			var wn: Node3D = w["node"]
			if wn == null or not is_instance_valid(wn):
				continue
			var axis: Vector3 = w["axis"]
			var rest: Basis = w["rest"]
			wn.basis = Basis(axis, spin) * rest

## A replacement cart approaching its spawn z: outer rails roll in along an
## angled siding, the centre drops from an ore chute. Returns true while shown.
func _spawn_preview(lane: int, c: Node3D, lx: float, dist: float) -> bool:
	if not _sim.has_method("get_rail_events"):
		return false
	for e in _sim.get_rail_events():
		if int(e["lane"]) != lane or str(e["type"]) != "spawn" or bool(e["done"]):
			continue
		var ahead: float = float(e["z"]) - dist
		if ahead < 0.0 or ahead > SPAWN_LEAD:
			continue
		var u: float = 1.0 - ahead / SPAWN_LEAD
		var ease: float = 1.0 - (1.0 - u) * (1.0 - u)
		if absf(lx) < 0.1:
			c.position = Vector3(lx, CART_Y + CHUTE_HEIGHT * (1.0 - ease), dist)
			c.rotation = Vector3(0.25 * (1.0 - u), 0.0, 0.0)
		else:
			var side: float = signf(lx)
			c.position = Vector3(lx + side * SIDING_OFFSET * (1.0 - ease), CART_Y, dist)
			c.rotation = Vector3(0.0, -side * 0.3 * (1.0 - ease), 0.0)
		return true
	return false

func _update_rider(dist: float, delta: float) -> void:
	var x: float = float(_sim.get_cart_x())
	var y: float = float(_sim.get_cart_y())
	var zipping: bool = _sim.is_ziplining()
	var ducking: bool = _sim.is_duck_held() and not zipping

	_t_hit += delta
	_t_shot += delta
	_t_swipe += delta
	_t_hop += delta
	_t_cheer += delta
	_blocked_t += delta
	var lane: int = int(_sim.get_lane())
	if lane != _last_lane:
		_hop_from_x = x
		_hop_to_x = float(_lane_xs()[lane])
		_last_lane = lane
		_t_hop = 0.0
	if _rider_anim:
		var mood: String = Motion.pick_rider(zipping, ducking, y > 0.05 and not zipping,
			bool(_sim.is_reloading()), _t_hit, _t_shot, _t_swipe, _t_hop, _t_cheer)
		_rider_anim.want(mood)
	var spd: float = float(_sim.get_speed()) if _sim.has_method("get_speed") else Sim.RUN_SPEED
	_danger_t = Motion.danger_eta(_sim, lane, dist, spd) if not zipping else INF
	if _emote:
		_emote.visible = _danger_t < Motion.DANGER_SECS and _sim.is_running()
		var pulse: float = 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
		_emote.scale = Vector3.ONE * pulse
	var arc := 0.0
	var span: float = absf(_hop_to_x - _hop_from_x)
	if span > 0.01 and not zipping:
		var t: float = clampf(absf(x - _hop_from_x) / span, 0.0, 1.0)
		arc = 4.0 * HOP_ARC * t * (1.0 - t)

	var target_y: float = RIDER_FLOOR + y + arc
	var sy: float = 1.0
	if zipping:
		target_y = Sim.ZIP_HEIGHT
	elif ducking:
		# The rigged crouch clip already folds him to ~65 % height; the squash is
		# only the fallback for an un-rigged model.
		target_y = RIDER_FLOOR - (0.8 if _rider_anim else 0.45)   # sink below the rim
		sy = 0.9 if _rider_anim else 0.5
	_rider.position = Vector3(x, target_y, dist)
	_rider_model.scale = _rider_model.scale.lerp(Vector3(_rider_scale, _rider_scale * sy, _rider_scale),
		clampf(delta * 18.0, 0.0, 1.0))
	# Upper body turns toward where he's aiming (clamped; he stays facing the run).
	if _aim_ok and _rider_model:
		var yaw_t: float = clampf(atan2(_aim_point.x - x, maxf(_aim_point.z - dist, 1.0)), -0.6, 0.6)
		_rider_model.rotation.y = lerp_angle(_rider_model.rotation.y, RIDER_YAW + yaw_t, clampf(delta * 8.0, 0.0, 1.0))
	# Gun arm aims at the reticle (RunnerAimModifier), eased off whenever the
	# hands are busy: reload, pickaxe swipe, duck, zipline, hit reaction.
	if _aim_mod:
		var armed_now: bool = bool(_sim.can_shoot())
		var busy: bool = zipping or ducking or bool(_sim.is_reloading()) or _t_swipe < Motion.SWIPE_HOLD \
			or _t_hit < Motion.HIT_HOLD * 0.6
		var w: float = 1.0 if armed_now and not busy else 0.0
		_aim_mod.influence = move_toward(float(_aim_mod.influence), w, delta * 6.0)
		_aim_mod.target = _aim_point if _aim_ok else Vector3(x, 1.8, dist + 30.0)
		_aim_mod.kick = maxf(0.0, float(_aim_mod.kick) - delta * 3.0)
	# Weapons ride the real hand bones when rigged (placed in _place_weapons on
	# skeleton_updated — the only time Godot 4.3 exposes the AIMED pose);
	# otherwise the fixed hand offsets.
	if _rider_skel and _bone_r >= 0:
		pass
	else:
		var crouch: float = _rider_model.scale.y / _rider_scale if _rider_scale > 0.0 else 1.0
		if _gun_pivot:
			_gun_pivot.position = Vector3(GUN_HAND.x, GUN_HAND.y * crouch, GUN_HAND.z)
		if _axe_pivot:
			_axe_pivot.position = Vector3(AXE_HAND.x, AXE_HAND.y * crouch, AXE_HAND.z)
	_hook.visible = zipping and _zip_model == null
	if _zip_model:
		_zip_model.visible = zipping
		_rider_model.visible = not zipping
		if zipping:
			# Pickaxe head on the cable; turn so the revolver (model -X) faces the aim.
			var cable_y: float = Sim.ZIP_HEIGHT + RIDER_HEIGHT + CABLE_CLEARANCE - 0.2
			_zip_model.position = Vector3(0.0, cable_y - target_y - _zip_top * _zip_scale, 0.0)
			var aim_d: Vector3 = (_aim_point - Vector3(x, target_y + 1.5, dist)) if _aim_ok else Vector3(-1.0, 0.0, 1.0)
			var yaw: float = clampf(atan2(aim_d.z, -aim_d.x), 0.35, PI - 0.35)
			_zip_model.rotation.y = lerp_angle(_zip_model.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
			_zip_model.rotation.z = sin(dist * 0.6) * 0.1
	_rider.rotation.z = (-(x - _prev_x) * 6.0) if not zipping else sin(dist * 0.6) * 0.12
	_prev_x = x
	_sparks.position = Vector3(x, -0.2, dist - 0.8)
	_sparks.emitting = not zipping and _sim.is_running()

## Revolver and pickaxe onto the hand bones, AFTER the aim modifier ran.
func _place_weapons() -> void:
	if _rider == null or _rider_skel == null or not _rider_skel.is_inside_tree():
		return
	var inv: Transform3D = _rider.global_transform.affine_inverse()
	if _gun_pivot and _bone_r >= 0:
		_gun_pivot.position = inv * (_rider_skel.global_transform * _rider_skel.get_bone_global_pose(_bone_r)).origin
	if _axe_pivot and _bone_l >= 0:
		_axe_pivot.position = inv * (_rider_skel.global_transform * _rider_skel.get_bone_global_pose(_bone_l)).origin

func _nearest_lane_x(x: float) -> float:
	var best: float = float(_lane_xs()[0])
	for lx in _lane_xs():
		if absf(float(lx) - x) < absf(best - x):
			best = float(lx)
	return best

func _update_archers(dist: float, delta: float) -> void:
	for id in _archer_fall.keys():
		var n: Node3D = _archer_nodes.get(id)
		if n == null:
			continue
		var t: float = float(_archer_fall[id]) + delta
		_archer_fall[id] = t
		if _archer_anims.has(id):
			(_archer_anims[id] as RefCounted).want("die", 0.08)
			n.visible = t < 2.6
			continue
		n.rotation.x = minf(t * 5.0, 1.5)
		n.position.y = Sim.ARCHER_Y - t * t * 6.0
		if t > 1.2:
			n.visible = false
	# Bear lights only near the rider: the web (Compatibility) renderer draws an
	# extra pass per light per object, and six bears x two lights stalled leg 2
	# in a software-rendered browser.
	for a0 in _sim.get_archers():
		var ln: Node3D = _archer_nodes.get(str(a0["id"]))
		if ln:
			var near: bool = float(a0["z"]) - dist > -6.0 and float(a0["z"]) - dist < 60.0
			for c in ln.get_children():
				if c is OmniLight3D:
					(c as OmniLight3D).visible = near
	for a in _sim.get_archers():
		if not a["alive"]:
			continue
		var n2: Node3D = _archer_nodes.get(str(a["id"]))
		var an2: RefCounted = _archer_anims.get(str(a["id"]))
		if n2 and an2:
			var spd2: float = float(_sim.get_speed()) if _sim.has_method("get_speed") else Sim.RUN_SPEED
			var ahead2: float = float(a["z"]) - dist
			var to_rel: float = (ahead2 - ARROW_LEAD) / maxf(spd2, 1.0)
			an2.want(Motion.pick_archer(true, to_rel, ahead2))
			# Track the rider: a bear that turns to follow you reads as a threat.
			if _rider and ahead2 > -6.0 and ahead2 < 80.0:
				var to_r: Vector3 = _rider.global_position - n2.global_position
				n2.rotation.y = lerp_angle(n2.rotation.y, atan2(to_r.x, to_r.z), clampf(delta * 5.0, 0.0, 1.0))
			continue
		if n2:
			var dz: float = float(a["z"]) - dist
			n2.position.y = Sim.ARCHER_Y + (sin(dist * 4.0) * 0.04 if dz < ARROW_LEAD * 1.5 and dz > -4.0 else 0.0)

func _update_arrows(dist: float) -> void:
	var obs: Array = _sim.get_obstacles()
	for i in mini(obs.size(), _arrow_nodes.size()):
		var node: Node3D = _arrow_nodes[i]
		if node == null:
			continue
		var o: Dictionary = obs[i]
		var z: float = float(o["z"])
		if o.get("cancelled", false):
			node.visible = false
			continue
		var to_go: float = z - dist
		if to_go > ARROW_LEAD or to_go < -3.0:
			node.visible = false
			continue
		var lane_x: float = float(_lane_xs()[clampi(int(o["lane"]), 0, _lane_xs().size() - 1)])
		var from_side: float = _archer_side(str(o.get("archer", "")))
		var start_x: float = _side_x(from_side, Sim.ARCHER_X)
		var t: float = clampf(1.0 - to_go / ARROW_LEAD, 0.0, 1.0)
		node.visible = true
		node.position = Vector3(lerpf(start_x, lane_x, t), ARROW_Y + sin(t * PI) * 0.8, z)
		var dir: float = signf(lane_x - start_x) if absf(lane_x - start_x) > 0.01 else 1.0
		node.rotation = Vector3(0.0, 0.0 if dir > 0.0 else PI, cos(t * PI) * 0.35 * dir)

func _archer_side(id: String) -> float:
	for a in _sim.get_archers():
		if str(a["id"]) == id:
			return float(a["side"])
	return 1.0

func _update_boulders(dist: float) -> void:
	var obs: Array = _sim.get_obstacles()
	for i in mini(obs.size(), _boulder_nodes.size()):
		var node: Node3D = _boulder_nodes[i]
		if node == null:
			continue
		var z: float = float(obs[i]["z"])
		var vz: float = z + (z - dist) * BOULDER_ROLL
		node.position.z = vz
		node.visible = vz - dist < 70.0 and vz - dist > -12.0 and not debug_off.has("boulders")
		node.rotation.x = vz / BOULDER_R

## Boarder states: idle (on the scaffold → leaping in) · riding (hit: it landed
## in the cart) · knocked (repelled by the pickaxe) · falling (fell away).
func _update_boarders(dist: float, delta: float) -> void:
	if _boarders.is_empty():
		return
	var obs: Array = _sim.get_obstacles()
	var cx: float = float(_sim.get_cart_x())
	var cy: float = float(_sim.get_cart_y())
	var land_y: float = RIDER_FLOOR + cy + 0.15
	for b in _boarders:
		var bd: Dictionary = b
		var oi: int = int(bd["obs"])
		if oi >= obs.size():
			continue
		var o: Dictionary = obs[oi]
		var node: Node3D = bd["node"]
		var lbl: Label3D = bd["label"]
		var z: float = float(bd["z"])
		var sx: float = float(bd["start_x"])
		var out: float = signf(sx) if absf(sx) > 0.01 else 1.0
		var state: String = str(bd["state"])
		if state == "idle":
			if bool(o.get("repelled", false)):
				state = "knocked"
				bd["t"] = 0.0
				bd["from"] = Vector3(node.position.x, node.position.y, node.position.z - dist)
			elif bool(o.get("hit", false)):
				state = "riding"
				bd["t"] = 0.0
			elif dist > z + 2.0:
				state = "falling"
				bd["t"] = 0.0
				bd["from"] = Vector3(node.position.x, node.position.y, node.position.z - dist)
			bd["state"] = state
		var t: float = float(bd["t"]) + delta
		bd["t"] = t
		if node.has_meta("anim"):
			var ban: RefCounted = node.get_meta("anim")
			match state:
				"idle":
					ban.want("leap" if z - dist < BOARDER_LEAP_LEAD else "stomp")
				"riding":
					ban.want("stomp")
				_:
					ban.want("flinch")
		match state:
			"idle":
				var u: float = clampf(1.0 - (z - dist) / BOARDER_LEAP_LEAD, 0.0, 1.0)
				node.position = Vector3(lerpf(sx, cx, u),
					lerpf(Sim.ARCHER_Y, land_y, u) + 4.0 * BOARDER_ARC * u * (1.0 - u),
					maxf(z, dist) + 0.6 * u)
				var to_track := Vector3(-out, 0.0, -0.4).normalized()
				node.rotation = Vector3(-0.3 * u, atan2(to_track.x, to_track.z), 0.0)
				node.visible = z - dist < TELEGRAPH_RANGE + 25.0
			"riding":
				node.position = Vector3(cx, land_y, dist + 0.6)
				node.visible = true
				if t > 0.7:
					bd["state"] = "falling"
					bd["t"] = 0.0
					bd["from"] = Vector3(node.position.x, node.position.y, 0.6)
			"knocked", "falling":
				var f: Vector3 = bd["from"]
				var knocked: bool = state == "knocked"
				var vx: float = out * (9.0 if knocked else 3.5)
				var vy: float = 6.0 if knocked else 2.0
				node.position = Vector3(f.x + vx * t, f.y + vy * t - 10.0 * t * t,
					dist + f.z + (2.0 if knocked else -1.0) * t)
				node.rotation.z = -out * t * (7.0 if knocked else 3.0)
				node.visible = t < 1.6
		var ahead: float = z - dist
		lbl.position = Vector3(cx, 3.3, z)
		lbl.visible = str(bd["state"]) == "idle" and ahead > 1.0 and ahead < TELEGRAPH_RANGE

func _update_labels(dist: float) -> void:
	var obs: Array = _sim.get_obstacles()
	for e in _labels:
		var z: float = float(e["z"])
		var ahead: float = z - dist
		var show: bool = ahead > float(e.get("near", 1.0)) and ahead < TELEGRAPH_RANGE
		var archer_id: String = str(e["archer"])
		if archer_id != "":
			show = show and _archer_alive(archer_id)
		var live := true
		var linked: Array = e.get("obs", [])
		if linked.size() > 0:
			live = false
			for i in linked:
				var idx: int = int(i)
				if idx >= obs.size():
					live = true
					break
				var od: Dictionary = obs[idx]
				if not bool(od.get("cancelled", false)):
					live = true
					break
		show = show and live
		(e["node"] as Label3D).visible = show
		for st in e.get("strips", []):
			(st as MeshInstance3D).visible = live and ahead > -2.0 and ahead < TELEGRAPH_RANGE + 10.0 \
				and not debug_off.has("strips")
	for m in _zip_markers:
		var r: MeshInstance3D = m["ring"]
		var pulse: float = 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		r.scale = Vector3.ONE * pulse
		r.visible = float(m["z"]) - dist > 4.0

func _archer_alive(id: String) -> bool:
	for a in _sim.get_archers():
		if str(a["id"]) == id:
			return bool(a["alive"])
	return false

func _update_lights(dist: float) -> void:
	var first := 0
	while first < _lantern_pos.size() and _lantern_pos[first].z < dist - 8.0:
		first += 1
	for i in _lights.size():
		var idx := first + i
		var l: OmniLight3D = _lights[i]
		if idx < _lantern_pos.size():
			var lp: Vector3 = _lantern_pos[idx]
			l.position = lp - Vector3(0.0, 0.2, 0.0)
			l.visible = true
		else:
			l.visible = false

func _update_camera(dist: float, delta: float) -> void:
	var rx: float = float(_sim.get_cart_x())
	var target := Vector3(rx * 0.6, 2.8, dist - 4.6)
	if _sim.is_ziplining():
		target.y = 4.1
	var k: float = clampf(delta * 6.0, 0.0, 1.0)
	var p: Vector3 = _camera.position
	p.x = lerpf(p.x, target.x, k)
	p.y = lerpf(p.y, target.y, k)
	p.z = target.z
	if _shake > 0.0:
		p += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * _shake * 0.25
		_shake = maxf(0.0, _shake - delta * 3.0)
	_camera.position = p
	var spd: float = float(_sim.get_speed()) if _sim.has_method("get_speed") else Sim.RUN_SPEED
	var fov_t: float = FOV_BASE + maxf(0.0, spd - 20.0) * FOV_PER_MS + (5.0 if _sim.is_ziplining() else 0.0)
	_camera.fov = lerpf(_camera.fov, fov_t, clampf(delta * 3.0, 0.0, 1.0))
	if _streaks:
		_streaks.emitting = _sim.is_running() and not debug_off.has("streaks")
		_streaks.speed_scale = spd / 20.0
	if _camera.is_inside_tree():
		_camera.look_at(Vector3(rx * 0.45, 1.75, dist + 10.0), Vector3.UP)

## Mouse ray from the camera: what the reticle is over, and where the gun aims
## (the archer it would hit, or AIM_FALLBACK metres along the ray).
func _update_aim() -> void:
	_aim_ok = false
	_aim_hit = ""
	if _camera == null or not _camera.is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var mp: Vector2 = vp.get_mouse_position()
	_aim_origin = _camera.project_ray_origin(mp)
	_aim_dir = _camera.project_ray_normal(mp)
	_aim_point = _aim_origin + _aim_dir * AIM_FALLBACK
	if _sim.has_method("ray_hits_archer"):
		_aim_hit = str(_sim.ray_hits_archer(_aim_origin, _aim_dir))
	if _aim_hit != "":
		for a in _sim.get_archers():
			if str(a["id"]) == _aim_hit:
				var ap: Vector3 = _sim.archer_world_pos(a)
				_aim_point = ap
				break
	_aim_ok = true

## Muzzle tracks the aim point; during reload the gun breaks open: tipped
## muzzle-up ~70° and spun about its barrel, then settles back.
func _update_gun(delta: float) -> void:
	if _gun_pivot == null or _rider == null:
		return
	_gun_pivot.visible = bool(_sim.can_shoot()) and not (_zip_model != null and bool(_sim.is_ziplining()))
	var k: float = clampf(delta * 20.0, 0.0, 1.0)
	var reloading: bool = bool(_sim.is_reloading())
	var target_q: Quaternion = Quaternion.IDENTITY
	if reloading:
		target_q = Quaternion(Vector3.RIGHT, BREAK_TILT)
	elif _aim_ok and _gun_pivot.is_inside_tree():
		var from: Vector3 = _gun_pivot.global_transform.origin
		var dir: Vector3 = _aim_point - from
		if dir.length_squared() > 0.0001:
			var pb: Basis = _rider.global_transform.basis.orthonormalized()
			var ld: Vector3 = (pb.inverse() * dir).normalized()
			if absf(ld.dot(Vector3.UP)) < 0.98:
				target_q = Quaternion(Basis.looking_at(ld, Vector3.UP))
			else:
				target_q = _gun_pivot.quaternion
	_gun_pivot.quaternion = _gun_pivot.quaternion.slerp(target_q, k)
	if reloading:
		_gun_spin += delta * 14.0
	else:
		_gun_spin = lerpf(_gun_spin, roundf(_gun_spin / TAU) * TAU, k)
	if _gun_spin_node:
		_gun_spin_node.basis = Basis(Vector3.BACK, _gun_spin)

func _update_axe(delta: float) -> void:
	if _axe_pivot == null:
		return
	_axe_t += delta
	var swinging: bool = _axe_t < AXE_SWING_TIME + 0.08
	# The pickaxe is always in his other hand (founder: revolver in one, axe in
	# the other); it only sweeps on a swipe.
	_axe_pivot.visible = _sim == null or not bool(_sim.is_ziplining())
	if swinging:
		var u: float = clampf(_axe_t / AXE_SWING_TIME, 0.0, 1.0)
		var e: float = 1.0 - (1.0 - u) * (1.0 - u)     # ease-out: fast strike
		_axe_pivot.rotation = Vector3(-0.4, 0.0, AXE_START - AXE_ARC * e)
	else:
		_axe_pivot.rotation = _axe_pivot.rotation.lerp(Vector3(0.35, 0.0, 0.55), clampf(delta * 8.0, 0.0, 1.0))

func _muzzle_pos() -> Vector3:
	if _gun_pivot and _gun_pivot.is_inside_tree():
		return _gun_pivot.global_transform * Vector3(0.0, 0.0, -GUN_LENGTH * 0.5)
	if _rider:
		return _rider.position + Vector3(-0.42, 1.0, 0.8)
	return Vector3.ZERO

func _update_fx(delta: float) -> void:
	if _tracer_t > 0.0:
		_tracer_t -= delta
		_tracer.visible = _tracer_t > 0.0
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 40.0)
	if _muzzle_flash:
		_muzzle_flash_t -= delta
		_muzzle_flash.visible = _muzzle_flash_t > 0.0

func _draw_tracer(from: Vector3, to: Vector3) -> void:
	if _tracer == null or not _tracer.is_inside_tree() or from.is_equal_approx(to):
		return
	_tracer.position = (from + to) * 0.5
	var d: Vector3 = (to - from).normalized()
	_tracer.look_at(to, Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
	_tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_tracer.scale = Vector3(1.0, from.distance_to(to), 1.0)
	_tracer_t = 0.09
	_tracer.visible = true

# ------------------------------------------------------------------------------
# Sim events
# ------------------------------------------------------------------------------

func _on_hit(_remaining: int) -> void:
	_shake = 1.0
	_t_hit = 0.0

func _on_shot() -> void:
	_play("shot")
	_t_shot = 0.0
	if _aim_mod:
		_aim_mod.kick = 0.32
	if _flash == null or _rider == null:
		return
	_flash.position = _muzzle_pos()
	_flash.light_energy = 5.0
	_muzzle_flash_t = 0.06
	_shake = maxf(_shake, 0.15)

func _on_shot_resolved(_hit_id: String, point: Vector3) -> void:
	_draw_tracer(_muzzle_pos(), point)

func _on_archer_down(id: String) -> void:
	_archer_fall[id] = 0.0
	_play("bear_hit")
	_t_cheer = 0.0

func _on_dry_fire() -> void:
	_play("empty")

func _on_reload_started() -> void:
	_play("reload")

func _on_boarder_repelled() -> void:
	_play("bear_hit")
	_shake = maxf(_shake, 0.4)

func _on_pickaxe_swing() -> void:
	_axe_t = 0.0
	_t_swipe = 0.0
	_play("swing")

func _on_cart_wrecked(lane: int, cause: String) -> void:
	if lane < 0 or lane >= _cart_fx.size():
		return
	var fx: Dictionary = _cart_fx[lane]
	fx["state"] = "wreck"
	fx["t"] = 0.0
	fx["z"] = float(_sim.get_distance())
	fx["spin"] = 1.0 if _rng.randf() < 0.5 else -1.0
	var lx: float = float(_lane_xs()[lane])
	_spawn_wreck_halves(lane, lx)
	if _debris:
		_debris.position = Vector3(lx, 0.4, float(_sim.get_distance()) + 0.5)
		_debris.restart()
		_debris.emitting = true
	var mine: bool = lane == int(_sim.get_lane())
	_shake = maxf(_shake, 1.3 if mine else 0.6)
	_popup("CART SMASHED" if cause == "boulder" else "RAIL ENDS", C_DANGER,
		Vector3(lx, 2.6, float(_sim.get_distance()) + 3.0))

## The founder's cart scene shipped two broken halves; a smashed cart becomes those
## halves flying apart (the whole-cart tumble stays as the fallback).
func _spawn_wreck_halves(lane: int, lx: float) -> void:
	if not ResourceLoader.exists(WRECK_A_MODEL) or lane >= _carts.size():
		return
	(_carts[lane] as Node3D).visible = false
	(_cart_fx[lane] as Dictionary)["state"] = "dead"
	var d: float = float(_sim.get_distance())
	var k: int = 0
	for path in [WRECK_A_MODEL, WRECK_B_MODEL]:
		var n: Node3D = _inst(path)
		if n == null:
			continue
		var holder := Node3D.new()
		holder.position = Vector3(lx, CART_Y, d)
		_world.add_child(holder)
		_fit_on_rail(n, LEAF_CART_LEN, CART_Y)
		holder.add_child(n)
		var side: float = -1.0 if k == 0 else 1.0
		_wreck_pieces.append({"node": holder, "t": 0.0,
			"vel": Vector3(side * _rng.randf_range(2.5, 4.5), _rng.randf_range(4.0, 6.5), _rng.randf_range(3.0, 7.0)),
			"spin": Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4), side * _rng.randf_range(4, 8))})
		k += 1

func _update_wrecks(delta: float) -> void:
	var keep: Array = []
	for w in _wreck_pieces:
		var wd: Dictionary = w
		var n: Node3D = wd["node"]
		if n == null or not is_instance_valid(n):
			continue
		var t: float = float(wd["t"]) + delta
		wd["t"] = t
		var v: Vector3 = wd["vel"]
		v.y -= 20.0 * delta
		wd["vel"] = v
		n.position += v * delta
		n.rotation += (wd["spin"] as Vector3) * delta
		if t > 2.2:
			n.queue_free()
		else:
			keep.append(wd)
	_wreck_pieces = keep

func _on_cart_spawned(lane: int) -> void:
	if lane < 0 or lane >= _cart_fx.size():
		return
	var fx: Dictionary = _cart_fx[lane]
	fx["state"] = "roll"
	_popup("NEW CART", Color(0.55, 1.0, 0.55), Vector3(float(_lane_xs()[lane]), 2.4, float(_sim.get_distance()) + 4.0))

func _on_hop_blocked(lane: int) -> void:
	_blocked_t = 0.0
	_blocked_lane = lane

func _on_rider_bailed(_from: int, _to: int) -> void:
	_t_hit = 0.0
	_shake = maxf(_shake, 1.4)

func _on_gold_collected(_total: int) -> void:
	_t_cheer = minf(_t_cheer, Motion.CHEER_HOLD * 0.6)

func _on_zip_caught(_i: int) -> void:
	_shake = maxf(_shake, 0.25)

func _on_zip_missed(_i: int) -> void:
	_shake = 1.2
