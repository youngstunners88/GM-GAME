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

## Ground-movement flag driven by the player each physics frame; while true
## the sprite gets a light run-bob (rotation + hop) so walking reads as
## animation even with single-pose art.
var moving: bool = false

## Held tool (pickaxe/torch power-ups). Offset from node centre to the hand.
const TOOL_HAND_X: float = 14.0
var _tool: Sprite2D
var _tool_path: String = ""
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
		_bob_time += delta
		var stride := _bob_time * 16.0                 # step cadence
		var lift := absf(sin(stride)) * 4.0            # body rises between steps
		# Body: bounce + a small lean into the walk (reads as arm/shoulder swing).
		_spr.position.y = feet_y - lift
		_spr.rotation = sin(stride) * 0.05 + dir * 0.04
		# Feet swing forward/back in opposite phase, forward foot lifting — a
		# clear "legs moving" read. Offset toward the facing direction.
		var swing := sin(stride) * 7.0
		_leg_l.visible = true
		_leg_r.visible = true
		_leg_l.position = Vector2(-6 + swing * dir, feet_y + _spr.texture.get_height() - 8 - maxf(0.0, swing) * 0.6)
		_leg_r.position = Vector2(-1 - swing * dir, feet_y + _spr.texture.get_height() - 8 - maxf(0.0, -swing) * 0.6)
	else:
		if _bob_time != 0.0:
			_bob_time = 0.0
			_spr.rotation = 0.0
			_spr.position.y = feet_y
		# Feet planted together under the body while idle.
		if _leg_l:
			var by := feet_y + _spr.texture.get_height() - 8
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
		return
	if _tool == null:
		_tool = Sprite2D.new()
		_tool.position = Vector2(TOOL_HAND_X if facing_right else -TOOL_HAND_X, 2.0)
		_tool.rotation = 0.35
		add_child(_tool)
	_tool.texture = load(path)
	_tool.flip_h = not facing_right

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
