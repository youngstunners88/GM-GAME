class_name LilBluntVisual
extends Node2D
## Lil Blunt rendered from the client's real pixel-art sprites
## (src/assets/sprites/sprite_lil-blunt_*.png), replacing the old
## procedurally-drawn placeholder. Keeps the same API the rest of the
## code already uses:
##   color        — power-up tint (WHITE = normal art colors)
##   facing_right — mirrors the sprite toward travel direction
##   visible      — damage flicker (inherited)
##   set_outfit() — swaps cowboy / miner / crystal art per level theme

const OUTFIT_TEXTURES := {
	Player.Outfit.DEFAULT: "res://src/assets/sprites/sprite_lil-blunt_cowboy.png",
	Player.Outfit.MINER: "res://src/assets/sprites/sprite_lil-blunt_miner.png",
	Player.Outfit.CRYSTAL: "res://src/assets/sprites/sprite_lil-blunt_crystal.png",
}
## Collision box is 32×32 centred on this node; its floor line is +16 below.
const FEET_LOCAL_Y: float = 16.0

var _spr: Sprite2D

## Ambient pace scale (e.g. Smoke Lounge's chill walk cycle). Applies to the
## procedural leg-bob today (no AnimatedSprite2D frame sheet ships yet — see
## OUTFIT_FRAMES below) and to _anim.speed_scale once one does, so the effect
## isn't silently lost when real frame sheets land.
var _anim_speed_scale: float = 1.0

## Power-up tint applied over the art (cyan/green/red glows). WHITE = normal.
var color: Color = Color.WHITE:
	set(value):
		color = value
		if _spr:
			_spr.self_modulate = value

var facing_right: bool = true:
	set(value):
		facing_right = value
		if _spr:
			_spr.flip_h = not value
		if _anim:
			_anim.flip_h = not value
		if _tool:
			_tool.flip_h = not value
			_tool.position.x = TOOL_HAND_X if value else -TOOL_HAND_X
			_tool.rotation = 0.35 if value else -0.35

## Ground-movement flag driven by the player each physics frame; while true
## the sprite gets a light run-bob (rotation + hop) so walking reads as
## animation even with single-pose art.
var moving: bool = false

## Held tool (pickaxe/torch power-ups). Offset from node centre to the hand.
const TOOL_HAND_X: float = 14.0
var _tool: Sprite2D
var _tool_path: String = ""
## Grip-anchored Y computed once in set_tool(); _process() re-applies the
## same per-frame walk bob/lean to _tool from this base so the held tool
## doesn't drift relative to the hand while walking (_tool is a sibling of
## _spr, not a child, so it gets none of _spr's bob for free).
var _tool_base_y: float = 0.0
## Cosmetic flame glow, torch only. The project has no 2D lighting pipeline
## (no PointLight2D used anywhere) and Stage 2 has no darkness mechanic to
## illuminate — a raw light node here would render as an unconfigured bright
## circle over an already fully-lit painted background, doing nothing useful.
## A soft additive glow at the flame tip is the "simple light effect" the
## corrections brief allows as the minimum-viable option; it reads as "lit"
## without requiring gameplay that doesn't exist yet. Damage-to-enemies
## already works independently via Player._on_aura_body_entered — the torch
## was never mechanically inert, it just wasn't visibly telegraphed as lit.
var _glow: Sprite2D
var _glow_tween: Tween
var _bob_time: float = 0.0

## Frame-animation layer. When a SpriteFrames resource ships for an outfit
## (res://src/assets/sprites/frames_lil-blunt_<outfit>.tres — see
## ASSET_MANIFEST.md for exact sheet specs), it drives an AnimatedSprite2D and
## the static sprite hides. Until then, play_animation() records state and the
## existing procedural moves (run-bob, jump stretch, damage flicker) carry the
## read — so wiring is live today with zero art regression.
const OUTFIT_FRAMES := {
	Player.Outfit.DEFAULT: "res://src/assets/sprites/frames_lil-blunt_cowboy.tres",
	Player.Outfit.MINER: "res://src/assets/sprites/frames_lil-blunt_miner.tres",
	Player.Outfit.CRYSTAL: "res://src/assets/sprites/frames_lil-blunt_crystal.tres",
}
## One-shots hold until finished instead of being overwritten by state anims.
const ONESHOT_ANIMS := ["attack", "hurt", "death"]
var _anim: AnimatedSprite2D
var _current_anim: String = ""

## Two small "feet" that shuffle in opposite phase while walking — a literal
## moving-legs read on top of the single-pose body sprite (real frame sheets
## replace all of this when they ship, per ASSET_MANIFEST.md).
var _leg_l: ColorRect
var _leg_r: ColorRect
const LEG_COLOR := Color(0.12, 0.10, 0.08, 1.0)

func _ready() -> void:
	_spr = Sprite2D.new()
	add_child(_spr)
	# Feet sit just below the body, behind it (drawn first).
	for i in 2:
		var leg := ColorRect.new()
		leg.color = LEG_COLOR
		leg.size = Vector2(7, 11)
		leg.pivot_offset = Vector2(3.5, 0)
		add_child(leg)
		move_child(leg, 0)
		if i == 0:
			_leg_l = leg
		else:
			_leg_r = leg
	set_outfit(Player.Outfit.DEFAULT)

## Ambient pace scale, driven by Player.set_movement_scale(). 1.0 = normal.
func set_speed_scale(scale: float) -> void:
	_anim_speed_scale = scale
	if _anim:
		_anim.speed_scale = scale

## Drive the named animation ("idle", "run", "jump_up", "jump_down", "attack",
## "hurt", "death"). Safe to call every frame; no-ops gracefully until a
## SpriteFrames resource exists for the current outfit.
func play_animation(anim: String) -> void:
	if _anim == null or _anim.sprite_frames == null:
		_current_anim = anim
		return
	if _current_anim in ONESHOT_ANIMS and _anim.is_playing() and not anim in ONESHOT_ANIMS:
		return
	if not _anim.sprite_frames.has_animation(anim):
		return
	if _current_anim != anim or anim in ONESHOT_ANIMS:
		_current_anim = anim
		_anim.play(anim)

func _process(delta: float) -> void:
	var feet_y := FEET_LOCAL_Y - _spr.texture.get_height() / 2.0
	var dir := 1.0 if facing_right else -1.0
	if moving:
		_bob_time += delta * _anim_speed_scale
		var stride := _bob_time * 16.0                 # step cadence
		var lift := absf(sin(stride)) * 4.0            # body rises between steps
		# Body: bounce + a small lean into the walk (reads as arm/shoulder swing).
		_spr.position.y = feet_y - lift
		_spr.rotation = sin(stride) * 0.05 + dir * 0.04
		# _tool is a sibling of _spr (not a child), so it gets none of the
		# bob above for free — apply the same lift here or the held item
		# visibly drifts from the hand while walking (see tool-hold-anchor).
		if _tool:
			_tool.position.y = _tool_base_y - lift
			_tool.rotation = (0.35 if facing_right else -0.35) + sin(stride) * 0.05 * dir
		# Feet swing forward/back in opposite phase, forward foot lifting — a
		# clear "legs moving" read. Offset toward the facing direction.
		var swing := sin(stride) * 7.0
		_leg_l.visible = true
		_leg_r.visible = true
		_leg_l.position = Vector2(-6 + swing * dir, feet_y + _spr.texture.get_height() / 2.0 - 8 - maxf(0.0, swing) * 0.6)
		_leg_r.position = Vector2(-1 - swing * dir, feet_y + _spr.texture.get_height() / 2.0 - 8 - maxf(0.0, -swing) * 0.6)
	else:
		if _bob_time != 0.0:
			_bob_time = 0.0
			_spr.rotation = 0.0
			_spr.position.y = feet_y
		# Feet planted together under the body while idle.
		if _leg_l:
			var by := feet_y + _spr.texture.get_height() / 2.0 - 8
			_leg_l.position = Vector2(-6, by)
			_leg_r.position = Vector2(-1, by)

## Show/hide the held tool. Pass "" to clear. Path is cached so calling
## every frame is free.
func set_tool(path: String) -> void:
	if path == _tool_path:
		return
	_tool_path = path
	if path == "":
		if _tool:
			_tool.queue_free()
			_tool = null
		_clear_glow()
		return
	if _tool == null:
		_tool = Sprite2D.new()
		add_child(_tool)
	_tool.rotation = 0.35 if facing_right else -0.35
	_tool.texture = load(path)
	_tool.flip_h = not facing_right
	# Tool sprites (pickaxe, torch) are tall thin poles (~34-36px) drawn
	# CENTERED on this node's position by default. Anchoring the geometric
	# CENTER at hand height put ~18px of sprite BELOW the hand — on a 32px-tall
	# player whose feet sit at local y=+16, that dragged the far end of the
	# torch (and its flame-topped silhouette) right down onto the ground,
	# reading as "carried at the feet" instead of held up. Anchor the GRIP
	# instead: about a quarter of the way up from the sprite's bottom edge,
	# which puts most of a held pole above the hand (flame above the head)
	# and only a short handle stub below it — how you'd actually grip one.
	var tex_height := float(_tool.texture.get_height()) if _tool.texture else 0.0
	var grip_from_bottom := tex_height * 0.25
	_tool_base_y = 2.0 - (tex_height / 2.0 - grip_from_bottom)
	_tool.position = Vector2(
		TOOL_HAND_X if facing_right else -TOOL_HAND_X,
		_tool_base_y)
	if path.contains("torch"):
		_show_glow(tex_height)
	else:
		_clear_glow()

## Soft additive glow at the flame tip, gently pulsing. Purely cosmetic — no
## light/shadow rendering, so it costs nothing and needs no scene setup.
func _show_glow(tool_tex_height: float) -> void:
	if _glow == null:
		_glow = Sprite2D.new()
		_glow.texture = _make_glow_texture()
		_glow.modulate = Color(1.0, 0.75, 0.35, 0.55)
		_glow.material = CanvasItemMaterial.new()
		_glow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_tool.add_child(_glow)
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_glow, "scale", Vector2(1.15, 1.15), 0.5) \
			.set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(_glow, "scale", Vector2(0.9, 0.9), 0.5) \
			.set_trans(Tween.TRANS_SINE)
	# Flame sits at the sprite's TOP edge (grip is near the bottom quarter,
	# per _tool's anchor above), so the glow parents onto _tool at local
	# (0, -tex_height/2) — the top of the torch texture, whichever way it
	# ends up flipped, since _glow is a child of _tool and inherits flip_h.
	_glow.position = Vector2(0, -tool_tex_height / 2.0 + 4.0)

func _clear_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	if _glow:
		_glow.queue_free()
		_glow = null

## 16x16 radial-falloff dot, generated once and cached — no art dependency
## for a one-off cosmetic effect.
var _glow_tex: ImageTexture
func _make_glow_texture() -> ImageTexture:
	if _glow_tex:
		return _glow_tex
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var d := Vector2(x, y).distance_to(center) / (size / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

## Swap outfit art (cowboy for Forest/Gold Rush, miner/crystal for Caves).
func set_outfit(outfit: int) -> void:
	if _spr == null:
		return
	var path: String = OUTFIT_TEXTURES.get(outfit, OUTFIT_TEXTURES[Player.Outfit.DEFAULT])
	_spr.texture = load(path)
	# Anchor feet to the collision floor so he stands ON platforms.
	_spr.position = Vector2(0.0, FEET_LOCAL_Y - _spr.texture.get_height() / 2.0)
	_spr.flip_h = not facing_right
	_spr.self_modulate = color
	_setup_frames_for_outfit(outfit)

## If a frame-sheet resource exists for this outfit, switch to animated mode.
func _setup_frames_for_outfit(outfit: int) -> void:
	var frames_path: String = OUTFIT_FRAMES.get(outfit, "")
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		if _anim:
			_anim.visible = false
		_spr.visible = true
		return
	if _anim == null:
		_anim = AnimatedSprite2D.new()
		add_child(_anim)
	_anim.sprite_frames = load(frames_path)
	# Feet-anchor using the 64×64 frame spec from ASSET_MANIFEST.md.
	_anim.position = Vector2(0.0, FEET_LOCAL_Y - 32.0)
	_anim.visible = true
	_spr.visible = false
	if _current_anim != "":
		play_animation(_current_anim)
