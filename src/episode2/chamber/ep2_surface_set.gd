class_name Ep2SurfaceSet
extends Node3D
## THE SURFACE SET: the lake, the rail line with the GoldMine train, and the stable with its horses, on the desert approach to the
## town. Founder 2026-10-18 (PROMPT_EPISODE2_HORSES_STABLE_TRAIN_LAKE_WRONG_STAGE.md): "after Lil Blunt and Inferno leave the forest ...
## the world opens: lake/river, stable, horses, train as the approach layer toward town". This is Episode 2, NOT the Episode 1 Level 3
## backdrop (src/level/stable_horses.gd, distant_train.gd, distant_lake.gd), which stays as it was and gets nothing new.
##
## Built by Ep2GoldTown.build(), which BOTH the bear woods (the quad rides past it: z 960 -> 1400) and the town chamber call at the
## same coordinates, so the set is there for the whole ride and one invisible cut keeps it. Pure scenery: no collision, no pickups.
##
## Assets are the ones that already ship, so the pck does not grow: the Runpod/AssetFurnace horse's 15 sprite frames
## (src/assets/sprites/horse_*.png), the Blender barn + corral sprite and the photoreal GoldMine locomotive sprite. The rigged 3D horse
## stays out of the pack (size gate, design/ep2 notes). All colour comes from the sprites; the water is one small shader.
##
## Layout, metres, same frame as Ep2GoldTown (the road runs +z toward the town; the town starts at z 1400):
##   * the rail line runs along the road on one side (x = +RAIL_X), the lake lies beyond it, the stable stands on the other side.
##   * the train shunts slowly up and down the line (stops at each end, then goes back), smoke drifting off its stack.

const HORSE_DIR := "res://src/assets/sprites/horse_%s_%02d.png"
const STABLE_TEX := "res://src/assets/sprites/sprite_prop_stable.png"
const TRAIN_TEX := "res://src/assets/sprites/sprite_prop_train-goldmine_512.png"
const PUFF_TEX := "res://src/assets/sprites/fx_dot.png"
const WATER_SHADER := "res://src/episode2/art/lake_water.gdshader"

const RAIL_X := 34.0                                   # the line runs beside the road, ~27 m off it
const RAIL_Z0 := 1030.0
const RAIL_Z1 := 1385.0
const LAKE_RECT := Rect2(42.0, 1030.0, 142.0, 350.0)   # x, z, width, depth: the water, just beyond the rails
const STABLE_POS := Vector3(-16.0, 0.0, 1222.0)        # centre of the barn + corral facade (it faces the road, +x)
const STABLE_WIDTH_M := 20.0
const PADDOCK := Rect2(-24.0, 1204.0, 20.0, 36.0)      # where the horses stand and walk (x, z, width, depth)

## Sprite measurements (px). Horses: 340x320 canvases, hooves on the bottom edge, 259 px standing height.
const HORSE_CANVAS := Vector2(340.0, 320.0)
const HORSE_HEIGHT_M := 2.2
const HORSE_STAND_PX := 259.0
const STABLE_SIZE := Vector2(1400.0, 600.0)
const STABLE_USED_W := 1348.0                          # opaque width
const STABLE_BASE_PX := 431.0                          # y of the ground line
const TRAIN_SIZE := Vector2(512.0, 266.0)
const TRAIN_LENGTH_M := 13.0
const TRAIN_STACK := Vector2(-116.0, 251.0)            # chimney, px from the sprite centre (x) and above the rails (y), nose at -x

const TRAIN_SPEED := 5.5                               # m/s along the line
const TRAIN_PAUSE_S := 14.0
const PUFFS := 6
const PUFF_LIFE_S := 6.5

var _roamer: AnimatedSprite3D
var _roam_dir: float = 1.0
var _train: Sprite3D
var _train_z: float = 1090.0
var _train_dir: float = 1.0
var _train_wait: float = 0.0
var _puffs: Array = []
var _clock: float = 0.0


## True where the surface set stands, so the desert scrub and boulders leave it clear (Ep2GoldTown.build_desert).
static func blocks(p: Vector2) -> bool:
	if LAKE_RECT.grow(10.0).has_point(p):
		return true
	if absf(p.x - RAIL_X) < 6.0 and p.y > RAIL_Z0 - 10.0 and p.y < RAIL_Z1 + 10.0:
		return true
	return PADDOCK.grow(5.0).has_point(p) or Rect2(STABLE_POS.x - 6.0, STABLE_POS.z - STABLE_WIDTH_M * 0.5 - 6.0, 12.0, STABLE_WIDTH_M + 12.0).has_point(p)


static func build(parent: Node3D) -> Ep2SurfaceSet:
	var s := Ep2SurfaceSet.new()
	s.name = "SurfaceSet"
	parent.add_child(s)
	s._build_lake()
	s._build_rails()
	s._build_train()
	s._build_stable()
	return s


# --- the lake ---------------------------------------------------------------------------------------------------------------

func _build_lake() -> void:
	var lake := Node3D.new()
	lake.name = "Lake"
	add_child(lake)
	var c := Vector3(LAKE_RECT.position.x + LAKE_RECT.size.x * 0.5, 0.0, LAKE_RECT.position.y + LAKE_RECT.size.y * 0.5)
	var sand := MeshInstance3D.new()
	var sm := PlaneMesh.new()
	sm.size = LAKE_RECT.size + Vector2(16.0, 16.0)
	sand.mesh = sm
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.66, 0.55, 0.39)
	sand_mat.roughness = 1.0
	sand.material_override = sand_mat
	sand.position = c + Vector3(0.0, 0.04, 0.0)
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sand.name = "Shore"
	lake.add_child(sand)
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = LAKE_RECT.size
	water.mesh = wm
	if ResourceLoader.exists(WATER_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(WATER_SHADER) as Shader
		water.material_override = mat
	else:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.16, 0.30, 0.38)
		water.material_override = fallback
	water.position = c + Vector3(0.0, 0.10, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.name = "Water"
	lake.add_child(water)


# --- the rail line ----------------------------------------------------------------------------------------------------------

func _build_rails() -> void:
	var rails := Node3D.new()
	rails.name = "Rails"
	add_child(rails)
	var length: float = RAIL_Z1 - RAIL_Z0
	var mid: float = (RAIL_Z0 + RAIL_Z1) * 0.5
	_box(rails, Vector3(3.6, 0.30, length), Vector3(RAIL_X, 0.12, mid), Color(0.30, 0.26, 0.23), "Bed")
	for side in [-1.0, 1.0]:
		_box(rails, Vector3(0.14, 0.18, length), Vector3(RAIL_X + side * 0.72, 0.36, mid), Color(0.42, 0.38, 0.36), "Rail")
	var ties := MultiMesh.new()
	ties.transform_format = MultiMesh.TRANSFORM_3D
	var tm := BoxMesh.new()
	tm.size = Vector3(2.5, 0.14, 0.28)
	ties.mesh = tm
	var n: int = int(length / 0.8)
	ties.instance_count = n
	for i in n:
		ties.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(RAIL_X, 0.30, RAIL_Z0 + 0.4 + float(i) * 0.8)))
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = ties
	var tie_mat := StandardMaterial3D.new()
	tie_mat.albedo_color = Color(0.30, 0.20, 0.12)
	tie_mat.roughness = 1.0
	tmi.material_override = tie_mat
	tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tmi.name = "Ties"
	rails.add_child(tmi)


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, nm: String) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = nm
	parent.add_child(mi)


# --- the train --------------------------------------------------------------------------------------------------------------

## A fixed plane facing the road (a side-on locomotive seen from the road, foreshortened like the real thing at an angle), nose
## toward +z when it runs toward the town. The sprite's nose is at its left edge, so it is mirrored when running +z.
func _build_train() -> void:
	var holder := Node3D.new()
	holder.name = "TrainHolder"
	add_child(holder)
	_train = _flat_sprite(TRAIN_TEX, TRAIN_LENGTH_M / TRAIN_SIZE.x, TRAIN_SIZE.y * 0.5, -PI * 0.5)
	_train.name = "Train"
	holder.add_child(_train)
	_train.flip_h = true
	_place_train()
	var puff_tex: Texture2D = load(PUFF_TEX) as Texture2D if ResourceLoader.exists(PUFF_TEX) else null
	for i in PUFFS:
		var p := Sprite3D.new()
		p.name = "Smoke%d" % i
		p.texture = puff_tex
		p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.shaded = false
		p.transparent = true
		p.pixel_size = 0.02
		p.modulate = Color(0.86, 0.83, 0.80, 0.0)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(p)
		_puffs.append(p)


func _place_train() -> void:
	if _train == null:
		return
	var ps: float = TRAIN_LENGTH_M / TRAIN_SIZE.x
	_train.position = Vector3(RAIL_X, TRAIN_SIZE.y * 0.5 * ps + 0.45, _train_z)
	_train.flip_h = _train_dir > 0.0


# --- the stable and its horses ------------------------------------------------------------------------------------------------

func _build_stable() -> void:
	var stable := Node3D.new()
	stable.name = "Stable"
	add_child(stable)
	var ps: float = STABLE_WIDTH_M / STABLE_USED_W
	var barn := _flat_sprite(STABLE_TEX, ps, STABLE_BASE_PX - STABLE_SIZE.y * 0.5, PI * 0.5)
	barn.name = "Barn"
	barn.position = Vector3(STABLE_POS.x, (STABLE_BASE_PX - STABLE_SIZE.y * 0.5) * ps, STABLE_POS.z)
	stable.add_child(barn)
	var grazer := _horse(stable, "Grazer", Vector3(STABLE_POS.x + 3.6, 0.0, STABLE_POS.z + 5.0), "graze", 5.0, false)
	var sentry := _horse(stable, "Sentry", Vector3(STABLE_POS.x + 3.0, 0.0, STABLE_POS.z - 4.0), "stand", 1.0, true)
	_roamer = _horse(stable, "Roamer", Vector3(STABLE_POS.x + 6.4, 0.0, STABLE_POS.z - 12.0), "walk", 10.0, false)
	_roamer.set_meta("z_from", STABLE_POS.z - 12.0)
	_roamer.set_meta("z_to", STABLE_POS.z + 12.0)
	grazer.modulate = Color(1.0, 0.97, 0.92)
	sentry.modulate = Color(0.95, 0.90, 0.86)


func _horse(parent: Node3D, nm: String, pos: Vector3, anim: String, fps: float, flip: bool) -> AnimatedSprite3D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var counts := {"walk": 8, "graze": 6, "stand": 1}
	for a in counts:
		frames.add_animation(a)
		frames.set_animation_loop(a, true)
		frames.set_animation_speed(a, fps if a == anim else 10.0)
		if a == "stand":
			var st: String = "res://src/assets/sprites/horse_stand.png"
			if ResourceLoader.exists(st):
				frames.add_frame(a, load(st))
			continue
		for i in int(counts[a]):
			var path: String = HORSE_DIR % [a, i]
			if ResourceLoader.exists(path):
				frames.add_frame(a, load(path))
	var h := AnimatedSprite3D.new()
	h.name = nm
	h.sprite_frames = frames
	h.animation = anim
	var ps: float = HORSE_HEIGHT_M / HORSE_STAND_PX
	h.pixel_size = ps
	h.position = pos + Vector3(0.0, HORSE_CANVAS.y * 0.5 * ps, 0.0)       # hooves on the bottom edge of the canvas
	h.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	h.shaded = false
	h.transparent = true
	h.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	h.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	h.flip_h = flip
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(h)
	h.play(anim)
	return h


## A sprite standing on the ground on a vertical plane (not a billboard) turned to `yaw`. `up_px` is how far the sprite centre sits above
## its ground line, in pixels (the caller sets the position).
func _flat_sprite(path: String, pixel_size: float, _up_px: float, yaw: float) -> Sprite3D:
	var s := Sprite3D.new()
	if ResourceLoader.exists(path):
		s.texture = load(path) as Texture2D
	s.pixel_size = pixel_size
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.rotation.y = yaw
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


# --- motion -------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_roamer):
		var z: float = _roamer.position.z + _roam_dir * (92.0 * (HORSE_HEIGHT_M / HORSE_STAND_PX) / 0.8) * delta
		var z0: float = float(_roamer.get_meta("z_from"))
		var z1: float = float(_roamer.get_meta("z_to"))
		if z > z1:
			_roam_dir = -1.0
		elif z < z0:
			_roam_dir = 1.0
		_roamer.position.z = clampf(z, z0 - 0.5, z1 + 0.5)
		_roamer.flip_h = _roam_dir > 0.0                     # a horse walking +z is seen going to screen-left from the road
	if _train != null:
		if _train_wait > 0.0:
			_train_wait -= delta
		else:
			_train_z += _train_dir * TRAIN_SPEED * delta
			if _train_z > RAIL_Z1 - 10.0 or _train_z < RAIL_Z0 + 10.0:
				_train_z = clampf(_train_z, RAIL_Z0 + 10.0, RAIL_Z1 - 10.0)
				_train_dir = -_train_dir
				_train_wait = TRAIN_PAUSE_S
		_place_train()
		_animate_smoke()


## The stack's smoke: puffs rise, swell and fade, drifting away from the road. A pure function of the clock (no randomness).
func _animate_smoke() -> void:
	var ps: float = TRAIN_LENGTH_M / TRAIN_SIZE.x
	var nose: float = _train_dir                                  # the nose faces the way it runs (+z when dir > 0)
	var stack := Vector3(RAIL_X, TRAIN_STACK.y * ps + 0.45, _train_z + nose * absf(TRAIN_STACK.x) * ps)
	for i in _puffs.size():
		var p: Sprite3D = _puffs[i]
		var t: float = fmod(_clock / PUFF_LIFE_S + float(i) / float(_puffs.size()), 1.0)
		p.position = stack + Vector3(t * 9.0, t * 11.0, -nose * t * 4.0)
		var s: float = lerpf(0.7, 3.2, t)
		p.scale = Vector3(s, s, s)
		var a: float = sin(t * PI) * 0.55
		p.modulate = Color(0.86, 0.83, 0.80, a)
