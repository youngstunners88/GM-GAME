class_name Stage3BossDefeatCutscene
extends CanvasLayer
## Stage 3 FINAL boss-defeat cutscene — Episode 1 close. Claim Jumper
## (dynamite bandit on the skull minecart) resists, gets outthought at the
## rail switch, then Bitcoin tokens detonate his own dynamite load; Lil
## Blunt boards a separate cart deeper into the mine. Plays after the
## Claim Jumper's own death tween (see bandit_boss.gd::die()) and replaces
## its plain "GAME COMPLETE!" Label + 3s wait — the queue_free() +
## SceneRouter.load_scene(main_menu) that follows is untouched. There is no
## Stage 4 today; this closes the episode and correctly returns to the menu.
##
## Third in the series (src/level/stage1_boss_defeat_cutscene.gd,
## stage2_boss_defeat_cutscene.gd — both shipped in PR #63, gated,
## security-clean, Kimi-audited with zero open findings on the second one).
## Same architecture: screen-space CanvasLayer overlay, no rendered video
## (Godot 4.3 web export only reliably plays MUTED Ogg Theora — see
## src/assets/video/README.md — which would cost the dialogue), built from
## assets already in the game. Design brief + multi-model review:
## docs/model-responses/2026-09-05-*-stage3-defeat-cutscene.md (the Grok
## dispatch produced an unusable stub this round — narrated intent, no beat
## sheet — so this design leans on the gpt-6-astra-pro response alone,
## verified against the real asset paths and boss-voices.json before use).
##
## Failure-safety spine (identical to Stage 1/2): every wait uses
## get_tree().create_timer(t, true, false, true); an independent
## hard-deadline SceneTreeTimer guarantees `finished` fires regardless; every
## node reference read across a beat boundary is is_instance_valid-guarded
## on BOTH sides of any two-node interaction (the exact gap Stage 1 shipped
## with and Stage 2 closed).
##
## The Claim Jumper's own "death" VO (boss-voices.json, voice_id
## LEQxdWqt02nZ8lXoPL0Y) already fires at the top of die(), before this node
## exists — not retriggered. The four one-off lines here
## (cutscene_s3_resist_bandit / cutscene_s3_defeat_lilblunt /
## cutscene_s3_defeat_bandit / cutscene_s3_exit_lilblunt) are new, separate
## from that randomized pool, same pattern as Stage 1/2's one-off VO.

signal finished

const PICKAXE_TEX := "res://src/assets/sprites/sprite_item_pickaxe.png"
const CART_TEX := "res://src/assets/sprites/sprite_boss_bandit-cart.png"
const BTC_TEX := "res://src/assets/sprites/sprite_item_coin-btc.png"
const EXIT_CART_TEX := "res://src/assets/sprites/sprite_prop_minecart-slow.png"
const MINER_TEX := "res://src/assets/sprites/sprite_lil-blunt_miner.png"

const RESIST_VO_ID := "cutscene_s3_resist_bandit"
const BLUNT_DEFEAT_VO_ID := "cutscene_s3_defeat_lilblunt"
const BANDIT_DEFEAT_VO_ID := "cutscene_s3_defeat_bandit"
const EXIT_VO_ID := "cutscene_s3_exit_lilblunt"

## Absolute ceiling on the whole sequence — see the class doc comment.
const HARD_DEADLINE := 15.0

var _tint: ColorRect
var _cart: Sprite2D
var _fuse: ColorRect
var _pickaxe: Sprite2D
var _lever: ColorRect
var _miner_portrait: Sprite2D
var _exit_cart: Sprite2D
var _shaft: ColorRect

var _done := false

func play() -> void:
	layer = 5  # above HUD/gameplay, below the level-transition wipe (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_backdrop()
	get_tree().create_timer(HARD_DEADLINE, true, false, true).timeout.connect(_finish)
	_run()

func _run() -> void:
	# Beat 1 (~0.0-2.2s): dynamite resistance. The boss still looks dangerous.
	var fade_in := create_tween()
	fade_in.tween_property(_tint, "color:a", 0.45, 0.3)
	_pop_cart(Vector2(760, 340))
	_pop_fuse_warning()
	AudioManager.play_voice(RESIST_VO_ID)
	await get_tree().create_timer(2.2, true, false, true).timeout

	# Beat 2 (~2.2-4.5s): outthink the environment, not more brawling. Lil
	# Blunt hooks the pickaxe under a rail switch instead of striking the
	# boss; the cart gets diverted onto a siding.
	_build_switch()
	_pop_pickaxe(Vector2(520, 420))
	if is_instance_valid(_pickaxe) and is_instance_valid(_lever):
		var hook := create_tween()
		hook.tween_property(_pickaxe, "rotation_degrees", -60.0, 0.3)
		hook.tween_property(_lever, "rotation_degrees", 35.0, 0.25)
	await get_tree().create_timer(0.7, true, false, true).timeout
	if is_instance_valid(_cart):
		var divert := create_tween()
		divert.tween_property(_cart, "position", Vector2(900, 300), 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.6, true, false, true).timeout

	# Beat 3 (~4.5-7.7s): Bitcoin-token leverage detonates the dynamite load.
	var tokens := _throw_btc_tokens()
	AudioManager.play_voice(BLUNT_DEFEAT_VO_ID)
	await get_tree().create_timer(0.9, true, false, true).timeout
	for t in tokens:
		if is_instance_valid(t):
			t.queue_free()
	_flash_impact()
	AudioManager.play_voice(BANDIT_DEFEAT_VO_ID)
	_wreck_cart()
	await get_tree().create_timer(2.2, true, false, true).timeout

	# Beat 4 (~7.7-11.0s): a separate cart, deeper into the mine. Ends on
	# motion, not a static pose.
	_pop_exit_cart(Vector2(300, 420))
	_reveal_miner_portrait(Vector2(340, 400))
	await get_tree().create_timer(0.5, true, false, true).timeout
	AudioManager.play_voice(EXIT_VO_ID)
	_build_shaft()
	if is_instance_valid(_exit_cart) and is_instance_valid(_shaft):
		var descend_cart := create_tween()
		descend_cart.tween_property(_exit_cart, "global_position", _shaft.global_position, 1.2)
		descend_cart.parallel().tween_property(_exit_cart, "scale", Vector2(0.4, 0.4), 1.2)
		descend_cart.parallel().tween_property(_exit_cart, "modulate:a", 0.0, 1.2)
	if is_instance_valid(_miner_portrait) and is_instance_valid(_shaft):
		var descend_rider := create_tween()
		descend_rider.tween_property(_miner_portrait, "global_position", _shaft.global_position, 1.2)
		descend_rider.parallel().tween_property(_miner_portrait, "scale", Vector2(0.3, 0.3), 1.2)
		descend_rider.parallel().tween_property(_miner_portrait, "modulate:a", 0.0, 1.2)
	_show_episode_complete()
	await get_tree().create_timer(1.6, true, false, true).timeout
	_finish()

func _build_backdrop() -> void:
	_tint = ColorRect.new()
	_tint.color = Color(0.0, 0.0, 0.0, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

func _pop_cart(pos: Vector2) -> void:
	if not ResourceLoader.exists(CART_TEX):
		return
	_cart = Sprite2D.new()
	_cart.texture = load(CART_TEX)
	_cart.position = pos
	_cart.scale = Vector2.ZERO
	add_child(_cart)
	var pop := create_tween()
	pop.tween_property(_cart, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A pulsing warning dot near the cart, selling "still armed" without
## depending on the cart texture existing.
func _pop_fuse_warning() -> void:
	_fuse = ColorRect.new()
	_fuse.color = Color(1.0, 0.5, 0.05, 0.85)
	_fuse.size = Vector2(16, 16)
	_fuse.position = Vector2(820, 300)
	_fuse.pivot_offset = _fuse.size / 2.0
	_fuse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fuse)
	var pulse := create_tween()
	pulse.set_loops(4)
	pulse.tween_property(_fuse, "scale", Vector2(1.6, 1.6), 0.2)
	pulse.tween_property(_fuse, "scale", Vector2(1.0, 1.0), 0.2)

func _build_switch() -> void:
	var rail_a := ColorRect.new()
	rail_a.color = Color(0.3, 0.22, 0.12, 0.9)
	rail_a.size = Vector2(220, 8)
	rail_a.position = Vector2(460, 470)
	rail_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rail_a)

	var rail_b := ColorRect.new()
	rail_b.color = Color(0.3, 0.22, 0.12, 0.9)
	rail_b.size = Vector2(160, 8)
	rail_b.position = Vector2(500, 500)
	rail_b.rotation_degrees = 20.0
	rail_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rail_b)

	_lever = ColorRect.new()
	_lever.color = Color(0.55, 0.5, 0.45, 0.95)
	_lever.size = Vector2(6, 40)
	_lever.position = Vector2(560, 465)
	_lever.pivot_offset = Vector2(3, 40)
	_lever.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lever)

func _pop_pickaxe(pos: Vector2) -> void:
	if not ResourceLoader.exists(PICKAXE_TEX):
		return
	_pickaxe = Sprite2D.new()
	_pickaxe.texture = load(PICKAXE_TEX)
	_pickaxe.position = pos
	_pickaxe.scale = Vector2.ZERO
	add_child(_pickaxe)
	var pop := create_tween()
	pop.tween_property(_pickaxe, "scale", Vector2(0.9, 0.9), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Returns the token nodes so the caller can free them once they land.
func _throw_btc_tokens() -> Array:
	if not ResourceLoader.exists(BTC_TEX):
		return []
	var tex := load(BTC_TEX)
	var tokens := []
	var origin := Vector2(520, 420)
	var target := Vector2(880, 300)
	for i in range(2):
		var token := Sprite2D.new()
		token.texture = tex
		token.position = origin
		token.scale = Vector2.ZERO
		add_child(token)
		var arc := create_tween()
		arc.tween_property(token, "scale", Vector2(0.8, 0.8), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		arc.tween_property(token, "position", target + Vector2(i * 20, -i * 10), 0.5) \
			.set_trans(Tween.TRANS_SINE)
		tokens.append(token)
	return tokens

func _flash_impact() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.85, 0.4, 0.8)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.2)
	fade.tween_callback(flash.queue_free)

func _wreck_cart() -> void:
	if is_instance_valid(_fuse):
		_fuse.queue_free()
	if is_instance_valid(_cart):
		var collapse := create_tween()
		collapse.tween_property(_cart, "rotation_degrees", 25.0, 0.5)
		collapse.parallel().tween_property(_cart, "modulate:a", 0.0, 0.6)
		collapse.parallel().tween_property(_cart, "position:y", _cart.position.y + 40.0, 0.5)

	var debris_colors := [
		Color(0.55, 0.35, 0.15, 0.9), Color(0.9, 0.5, 0.1, 0.9), Color(0.35, 0.35, 0.35, 0.9),
	]
	var origin := Vector2(880, 300)
	for i in range(10):
		var piece := ColorRect.new()
		piece.color = debris_colors[i % debris_colors.size()]
		piece.size = Vector2(12, 12)
		piece.rotation_degrees = randf_range(0.0, 360.0)
		piece.pivot_offset = piece.size / 2.0
		piece.position = origin
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(piece)
		var angle := deg_to_rad(randf_range(0.0, 360.0))
		var dist := randf_range(100.0, 240.0)
		var dest := origin + Vector2(cos(angle), sin(angle)) * dist
		var burst := create_tween()
		burst.tween_property(piece, "position", dest, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_property(piece, "modulate:a", 0.0, 0.7)
		burst.tween_callback(piece.queue_free)

func _pop_exit_cart(pos: Vector2) -> void:
	if not ResourceLoader.exists(EXIT_CART_TEX):
		return
	_exit_cart = Sprite2D.new()
	_exit_cart.texture = load(EXIT_CART_TEX)
	_exit_cart.position = pos
	_exit_cart.scale = Vector2.ZERO
	add_child(_exit_cart)
	var pop := create_tween()
	pop.tween_property(_exit_cart, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reveal_miner_portrait(pos: Vector2) -> void:
	if not ResourceLoader.exists(MINER_TEX):
		return
	_miner_portrait = Sprite2D.new()
	_miner_portrait.texture = load(MINER_TEX)
	_miner_portrait.position = pos
	_miner_portrait.modulate.a = 0.0
	add_child(_miner_portrait)
	var reveal := create_tween()
	reveal.tween_property(_miner_portrait, "modulate:a", 1.0, 0.3)

func _build_shaft() -> void:
	_shaft = ColorRect.new()
	_shaft.color = Color(0.03, 0.03, 0.05)
	_shaft.position = Vector2(300, 560)
	_shaft.size = Vector2.ZERO
	_shaft.pivot_offset = Vector2(60, 0)
	_shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shaft)
	var grow := create_tween()
	grow.tween_property(_shaft, "size", Vector2(120, 60), 0.4)

func _show_episode_complete() -> void:
	var label := Label.new()
	label.text = "EPISODE 1 COMPLETE\nDeeper..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(label)
	var reveal := create_tween()
	reveal.tween_property(label, "modulate:a", 1.0, 0.6)

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
