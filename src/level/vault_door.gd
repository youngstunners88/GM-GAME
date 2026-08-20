extends Area2D
## VAULT DOOR — a walk-into entrance that loads a FULL SEPARATE vault
## environment, exactly like the Blaze Portal / Smoke Lounge secret door take
## the player to a different scene. Replaces the rejected in-level
## `protocol_vault` pit (session 4).
##
## Founder: "supposed to take us into the next element of the Diamond Vault /
## Fort Knox just as entering the Blaze Rush takes us to a different
## environment completely. Hole in the ground = unacceptable."
##
## Reuses the PROVEN Smoke-Lounge plumbing: on contact it records
## `GameManager.secret_return = {scene_path, position}` and
## `SceneRouter.load_scene(realm_path)`; the vault scene ends with a
## `return_portal` that loads `secret_return.scene_path`, and
## `level_base._spawn_player()` drops the player back at the door. No new
## resume code — the return-to-entry-position path is already shipped and
## tested for the secret realm.
##
## One visit per stage via the "vault" side-entrance kind (its own flag dict,
## distinct from "secret"/"blaze" so it can't collide with them).

## "diamonds" -> Diamond Vault. "gold" -> Fort Knox. Drives the visual only;
## the destination is `realm_path`.
@export var protocol: String = "diamonds"
@export var realm_path: String = "res://src/level/diamond_vault_realm.tscn"

var _used := false

func _ready() -> void:
	add_to_group("vault_door")
	if GameManager.is_side_entrance_used("vault", GameManager.current_level):
		queue_free()
		return
	# A generous, obvious trigger the player walks into at ground level.
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 150)
	cs.shape = rect
	cs.position = Vector2(0, -35)  # spans from ~ankle up to head height above the surface
	add_child(cs)
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)
	_build_visual()

## A distinct standing doorway/arch so it reads as "a way IN", never a pit.
func _build_visual() -> void:
	var diamonds := protocol == "diamonds"
	var frame := Node2D.new()
	frame.name = "DoorFrame"
	frame.z_index = 2
	add_child(frame)

	if diamonds:
		# Crystal geode arch — cyan/violet, from Grok's identity spec.
		var glow := ColorRect.new()
		glow.size = Vector2(120, 150)
		glow.position = Vector2(-60, -150)
		glow.color = Color(0.35, 0.85, 1.0, 0.16)
		frame.add_child(glow)
		# The backdrop art, cropped small, previewed inside the arch mouth —
		# a slice of the place beyond the door.
		_build_tunnel(frame, Color(0.45, 0.85, 1.0))
		var peek := _make_peek("res://src/assets/art/vaults/diamond_vault_backdrop.png")
		if peek:
			frame.add_child(peek)
		for sx: float in [-1.0, 1.0]:
			var pillar := ColorRect.new()
			pillar.size = Vector2(16, 150)
			pillar.position = Vector2(sx * 52 - 8, -150)
			pillar.color = Color(0.5, 0.9, 1.0, 0.9)
			frame.add_child(pillar)
	else:
		# Fort Knox blast door — the founder's own vault-door art as the
		# centerpiece of the entrance.
		_build_tunnel(frame, Color(1.0, 0.78, 0.35))
		var door := Sprite2D.new()
		if ResourceLoader.exists("res://src/assets/art/vaults/fort_knox_vault_door.png"):
			door.texture = load("res://src/assets/art/vaults/fort_knox_vault_door.png")
			door.scale = Vector2(0.32, 0.32)
		door.position = Vector2(0, -70)
		frame.add_child(door)
		var glow := ColorRect.new()
		glow.size = Vector2(130, 150)
		glow.position = Vector2(-65, -150)
		glow.color = Color(1.0, 0.7, 0.25, 0.12)
		frame.add_child(glow)

	# "Enter" beckon chevron pointing INTO the door, bobbing — reads as a
	# doorway to walk into, opposite of the old downward drop chevron.
	var label := Label.new()
	label.text = "ENTER VAULT"
	label.position = Vector2(-54, -186)
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.7, 1.0, 1.0, 1.0) if diamonds else Color(1.0, 0.85, 0.4, 1.0)
	frame.add_child(label)
	var tw := create_tween().set_loops()
	tw.tween_property(frame, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(frame, "modulate", Color(0.85, 0.85, 0.85, 1.0), 0.9).set_trans(Tween.TRANS_SINE)

## The aperture the doorway actually has, in local px. Everything that draws
## "the place beyond the door" is cropped to this — see _make_peek.
const MOUTH := Vector2(104.0, 130.0)
const MOUTH_CENTRE := Vector2(0.0, -75.0)

func _make_peek(path: String) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var spr := Sprite2D.new()
	var tex: Texture2D = load(path)
	spr.texture = tex
	# CROP TO THE MOUTH — do not scale the whole painting down and let it spill.
	#
	# Founder (shot_3): the vault entrance "looks messy". Measured cause: this
	# fitted the backdrop by HEIGHT only — 130 / 576 = 0.226, which renders the
	# 1024px-wide painting at ~231px across a doorway whose mouth is ~104px.
	# More than half the image hung outside the arch on both sides, behind the
	# pillars, as an unframed rectangle of unrelated art. That reads as a
	# stray panel pasted behind the door, which is exactly what he circled.
	#
	# region_rect takes the CENTRE slice of the source at the mouth's own aspect,
	# so what shows through the doorway is a correctly-proportioned window into
	# the vault rather than a squashed whole-painting thumbnail.
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var aspect: float = MOUTH.x / MOUTH.y
	var src_h: float = th
	var src_w: float = minf(tw, th * aspect)
	spr.region_enabled = true
	spr.region_rect = Rect2((tw - src_w) * 0.5, (th - src_h) * 0.5, src_w, src_h)
	spr.scale = Vector2(MOUTH.x / src_w, MOUTH.y / src_h)
	spr.position = MOUTH_CENTRE
	spr.z_index = -1
	return spr

## Receding rings inside the mouth so the doorway reads as a TUNNEL going
## down/in, not a flat panel on a wall.
##
## Founder (shot_3): "lets make it have like a chamber like effect that goes
## downward like a tunnel chamber". Four nested frames, each smaller, darker and
## nudged DOWNWARD, give a forced-perspective throat: the eye reads successive
## edges as distance, and the downward drift sells "it goes down" rather than
## "it goes back". Drawn behind the peek slice (z -2) so the view through the
## door still sits at the far end of the throat.
func _build_tunnel(frame: Node2D, tint: Color) -> void:
	var rings := 4
	for i in range(rings):
		var t: float = float(i) / float(rings)          # 0 = mouth, 1 = deepest
		var ring := ColorRect.new()
		var w: float = MOUTH.x * (1.0 - 0.16 * float(i))
		var h: float = MOUTH.y * (1.0 - 0.14 * float(i))
		ring.size = Vector2(w, h)
		# Each ring sits a little lower than the last: the throat descends.
		ring.position = Vector2(-w * 0.5, MOUTH_CENTRE.y - h * 0.5 + 10.0 * float(i))
		# Darken with depth; keep a touch of the protocol colour so it still
		# reads as crystal/gold rather than a black hole.
		var k: float = 1.0 - 0.72 * t
		ring.color = Color(tint.r * k * 0.5, tint.g * k * 0.5, tint.b * k * 0.5,
			0.30 + 0.16 * float(i))
		ring.z_index = -2
		frame.add_child(ring)

func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	GameManager.mark_side_entrance_used("vault", GameManager.current_level)
	# Where to come back to — consumed by level_base._spawn_player() on return.
	GameManager.secret_return = {
		"scene_path": get_tree().current_scene.scene_file_path,
		"position": global_position,
	}
	AudioManager.play_sfx("powerup")
	ScreenShake.shake(0.2, 4.0)
	SceneRouter.load_scene(realm_path, SceneRouter.Transition.SMOKE)
