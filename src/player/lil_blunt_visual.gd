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
## Local-Y of the TOP and the FEET of the sprite's actual opaque pixels,
## measured from the real texture in set_outfit(). Everything that has to sit
## "on the character" (the held tool) is derived from these, never from an
## assumed sprite size. The cowboy art is 49x72 with its opaque box at
## y 9..58, so its visible feet are at local y=+2 while FEET_LOCAL_Y (the
## COLLISION floor) is +16 — a 14px gap. Hardcoding against the collision
## line is exactly what put the torch at the feet across several "fixes".
var _art_top_local: float = 0.0
var _art_feet_local: float = 0.0
## HOW FAR THE ART MUST DROP SO HIS VISIBLE FEET TOUCH THE GROUND.
##
## Founder, twice in one message: "Lil Blunt must not be standing above
## surfaces like he currently is, he must stand directly on the surface" and
## "the skateboard is so far from his feet... he wombles above the skateboard".
##
## Those are ONE bug. The sprite was anchored so the TEXTURE'S BOTTOM EDGE
## lands on the collision floor — but the character art has transparent
## padding under its feet (the cowboy sheet is 49x72 with opaque rows only
## 9..58), so the last PAINTED row sits ~14px higher. He therefore hovers a
## constant 14px above every floor, and anything anchored to the collision
## floor — the skateboard deck — appears that far BELOW his soles.
##
## Measured per outfit from the real texture, never hardcoded: different
## outfits have different padding.
var _art_offset_y: float = 0.0
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

## NOTE: the procedural leg ColorRects were REMOVED (2026-08-07). They were a
## leftover from when Lil Blunt was a drawn rectangle with no legs of his own.
## The shipped art already has legs, so these two dark rects rendered as a
## solid black block 6px BELOW the art's feet — the "shadow block beneath his
## feet" the founder screenshotted. Do not reintroduce them; if a walk cycle
## is wanted, it belongs in a SpriteFrames sheet (see OUTFIT_FRAMES).

func _ready() -> void:
	_spr = Sprite2D.new()
	add_child(_spr)
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
	var feet_y := FEET_LOCAL_Y - _spr.texture.get_height() / 2.0 + _art_offset_y
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
	else:
		if _bob_time != 0.0:
			_bob_time = 0.0
			_spr.rotation = 0.0
			_spr.position.y = feet_y
			if _tool:
				_tool.position.y = _tool_base_y
				_tool.rotation = 0.35 if facing_right else -0.35

## Show/hide the held tool. Pass "" to clear. Path is cached so calling
## every frame is free.
func set_tool(path: String, tool_scale: float = 1.0) -> void:
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
	_tool.scale = Vector2(tool_scale, tool_scale)
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
	# Hand height = 55% down the VISIBLE art, measured from the real texture
	# (see _art_top_local/_art_feet_local). The old code used a hardcoded
	# +2.0 that assumed a 32px sprite whose feet were at the collision line;
	# against the real 49x72 art that put the torch's lower half BELOW his
	# feet, which is the "torch at the feet" defect that survived two fixes.
	var hand_y := _art_top_local + (_art_feet_local - _art_top_local) * 0.55
	_tool_base_y = hand_y - (tex_height / 2.0 - grip_from_bottom)
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
	# _art_offset_y is applied by _measure_art_bounds() below, once the real
	# opaque bounds of THIS outfit are known.
	_spr.flip_h = not facing_right
	_spr.self_modulate = color
	_measure_art_bounds()
	# A tool equipped before an outfit swap must re-anchor to the new art.
	if _tool and _tool_path != "":
		var reapply := _tool_path
		_tool_path = ""
		set_tool(reapply)
	_setup_frames_for_outfit(outfit)

## Measure where the sprite's OPAQUE pixels actually start and end, in this
## node's local space. Run once per outfit swap (never per frame — it reads
## the image back from the GPU-side texture). Falls back to the full texture
## rect if the image can't be read, which is still better than a hardcoded
## guess.
func _measure_art_bounds() -> void:
	var tex := _spr.texture
	if tex == null:
		return
	var h := float(tex.get_height())
	var sprite_top := _spr.position.y - h / 2.0
	_art_top_local = sprite_top
	_art_feet_local = sprite_top + h
	var img := tex.get_image()
	if img == null:
		return
	var used := img.get_used_rect()
	if used.size.y <= 0:
		return
	_art_top_local = sprite_top + float(used.position.y)
	_art_feet_local = sprite_top + float(used.position.y + used.size.y)
	# Drop the art so its last opaque row lands exactly on the collision floor.
	_art_offset_y = FEET_LOCAL_Y - _art_feet_local
	_spr.position.y += _art_offset_y
	# Keep the cached bounds in the same local space as the re-seated sprite,
	# or the held-tool grip (derived from them) drifts by the same amount.
	_art_top_local += _art_offset_y
	_art_feet_local += _art_offset_y

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
