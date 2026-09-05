class_name Stage2BossDefeatCutscene
extends CanvasLayer
## Stage 2 boss-defeat progress beat: Distributor (Crystalline Bureaucrat)
## shattered by the pickaxe -> Fort Knox vault door opens -> Gold Rush
## (Stage 3). Plays after the Distributor's own death tween (see
## distributor.gd::die()) and replaces its plain 3s "LEVEL COMPLETE!" Label
## wait — the queue_free() + SceneRouter.load_scene() that follows is
## untouched.
##
## Same architecture as src/level/stage1_boss_defeat_cutscene.gd (that one
## shipped in PR #63, gated, security-clean) — screen-space CanvasLayer
## overlay, no rendered video (Godot 4.3 web export only reliably plays
## MUTED Ogg Theora — see src/assets/video/README.md — which would cost the
## dialogue that's the point of the scene), built from assets already in the
## game. Design brief + multi-model review (Grok 4.5 + gpt-6-astra-pro):
## docs/model-responses/2026-09-05-*-stage2-defeat-cutscene.md.
##
## Failure-safety spine (identical to Stage 1, Kimi-audited there): every
## wait uses get_tree().create_timer(t, true, false, true) (process-always,
## ignores pause/time-scale); an independent hard-deadline SceneTreeTimer
## guarantees `finished` fires even if a step is interrupted; every node
## reference read across a beat boundary is is_instance_valid-guarded before
## use (Stage 1 shipped with exactly one gap here — an unguarded second
## reference in a two-node tween — caught in self-review and independently
## confirmed by Kimi K3; this file guards both sides of every such tween
## from the start).
##
## The Distributor's own "death" VO line (BossVoiceSystem, boss-voices.json
## voice_id VtsQlMLXxJPBwTtPTtoc) already fires at the top of die(), before
## this node exists — this cutscene does not retrigger or duplicate it.
## Lil Blunt's one-off line here is a separate beat, generated directly
## (not through BossVoiceData's randomized pools), same pattern as Stage 1.
##
## No outfit change: Lil Blunt is already in MINER outfit for all of Stage 2
## (set on that level's own _ready()) and Stage 3 never changes it either.

signal finished

const PICKAXE_TEX := "res://src/assets/sprites/sprite_item_pickaxe.png"
const VAULT_DOOR_TEX := "res://src/assets/art/vaults/fort_knox_vault_door.png"
const BLUNT_VO_ID := "cutscene_s2_defeat_lilblunt"
## Absolute ceiling on the whole sequence — see the class doc comment.
const HARD_DEADLINE := 12.0
const GOLD_TINT := Color(0.95, 0.8, 0.3, 0.55)

var _tint: ColorRect
var _pickaxe: Sprite2D
var _boss_body: ColorRect
var _boss_head: ColorRect
var _vault_door: Sprite2D

var _done := false

func play() -> void:
	layer = 5  # above HUD/gameplay, below the level-transition wipe (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_backdrop()
	get_tree().create_timer(HARD_DEADLINE, true, false, true).timeout.connect(_finish)
	_run()

func _run() -> void:
	# Beat 1 (0.0-1.6s): crystal barrage vs. pickaxe defense.
	var fade_in := create_tween()
	fade_in.tween_property(_tint, "color:a", 0.5, 0.4)
	_pop_pickaxe(Vector2(560, 420), Vector2(0.9, 0.9))
	for i in range(3):
		_spawn_shard(Vector2(300 + i * 40, 120 + i * 30))
		if is_instance_valid(_pickaxe):
			var swing := create_tween()
			swing.tween_property(_pickaxe, "rotation_degrees", -35.0, 0.18)
			swing.tween_property(_pickaxe, "rotation_degrees", 10.0, 0.18)
		await get_tree().create_timer(0.5, true, false, true).timeout

	# Beat 2 (~1.6-3.2s): close-range smash, boss cracks, Lil Blunt VO.
	_build_boss()
	if is_instance_valid(_pickaxe):
		var smash := create_tween()
		smash.tween_property(_pickaxe, "scale", Vector2(1.4, 1.4), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		smash.tween_property(_pickaxe, "position", Vector2(720, 400), 0.25)
	_flash_impact()
	AudioManager.play_voice(BLUNT_VO_ID)
	await get_tree().create_timer(1.6, true, false, true).timeout

	# Beat 3 (~3.2-5.2s): finishing blow + shatter collapse. The boss's own
	# defeat VO already fired in distributor.gd::die() before this node
	# existed — no new boss line here.
	_flash_impact()
	if is_instance_valid(_pickaxe):
		var final_hit := create_tween()
		final_hit.tween_property(_pickaxe, "scale", Vector2(1.7, 1.7), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shatter_boss()
	await get_tree().create_timer(2.0, true, false, true).timeout

	# Beat 4 (~5.2-8.0s): Fort Knox vault door reveal + gold wash into
	# Gold Rush (Stage 3).
	_reveal_vault_door()
	await get_tree().create_timer(0.6, true, false, true).timeout
	if is_instance_valid(_vault_door):
		var open := create_tween()
		open.tween_property(_vault_door, "rotation_degrees", 12.0, 0.15)
		open.tween_property(_vault_door, "rotation_degrees", -8.0, 0.15)
		open.tween_property(_vault_door, "modulate:a", 0.0, 0.6)
	var wash := create_tween()
	wash.tween_property(_tint, "color", GOLD_TINT, 1.0)
	await wash.finished
	await get_tree().create_timer(0.5, true, false, true).timeout
	_finish()

func _build_backdrop() -> void:
	_tint = ColorRect.new()
	_tint.color = Color(0.0, 0.0, 0.0, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

func _pop_pickaxe(pos: Vector2, initial_scale: Vector2) -> void:
	if not ResourceLoader.exists(PICKAXE_TEX):
		return
	_pickaxe = Sprite2D.new()
	_pickaxe.texture = load(PICKAXE_TEX)
	_pickaxe.position = pos
	_pickaxe.scale = Vector2.ZERO
	add_child(_pickaxe)
	var pop := create_tween()
	pop.tween_property(_pickaxe, "scale", initial_scale, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## One incoming crystal shard that arcs to roughly the pickaxe and breaks.
func _spawn_shard(from: Vector2) -> void:
	var shard := ColorRect.new()
	shard.color = Color(0.55, 0.75, 1.0, 0.9)
	shard.size = Vector2(22, 22)
	shard.rotation_degrees = 45.0
	shard.pivot_offset = shard.size / 2.0
	shard.position = from
	shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shard)
	var target := Vector2(560, 420)
	var arc := create_tween()
	arc.tween_property(shard, "position", target, 0.45)
	arc.parallel().tween_property(shard, "rotation_degrees", 45.0 + 180.0, 0.45)
	arc.tween_property(shard, "modulate:a", 0.0, 0.15)
	arc.tween_callback(shard.queue_free)

func _build_boss() -> void:
	_boss_body = ColorRect.new()
	_boss_body.color = Color(0.35, 0.3, 0.75, 0.9)
	_boss_body.size = Vector2(150, 170)
	_boss_body.position = Vector2(760, 300)
	_boss_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_body)

	_boss_head = ColorRect.new()
	_boss_head.color = Color(0.85, 0.7, 0.25, 0.9)
	_boss_head.size = Vector2(60, 60)
	_boss_head.position = Vector2(800, 260)
	_boss_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_head)

func _flash_impact() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.15)
	fade.tween_callback(flash.queue_free)

func _shatter_boss() -> void:
	if is_instance_valid(_boss_body):
		var collapse := create_tween()
		collapse.tween_property(_boss_body, "scale", Vector2.ZERO, 0.5)
		collapse.parallel().tween_property(_boss_body, "modulate:a", 0.0, 0.5)
	if is_instance_valid(_boss_head):
		var collapse_head := create_tween()
		collapse_head.tween_property(_boss_head, "scale", Vector2.ZERO, 0.5)
		collapse_head.parallel().tween_property(_boss_head, "modulate:a", 0.0, 0.5)

	var shard_colors := [
		Color(0.4, 0.6, 1.0, 0.9), Color(0.6, 0.4, 0.9, 0.9), Color(0.95, 0.8, 0.3, 0.9),
	]
	var origin := Vector2(800, 340)
	for i in range(10):
		var piece := ColorRect.new()
		piece.color = shard_colors[i % shard_colors.size()]
		piece.size = Vector2(14, 14)
		piece.rotation_degrees = randf_range(0.0, 360.0)
		piece.pivot_offset = piece.size / 2.0
		piece.position = origin
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(piece)
		var angle := deg_to_rad(randf_range(0.0, 360.0))
		var dist := randf_range(120.0, 260.0)
		var dest := origin + Vector2(cos(angle), sin(angle)) * dist
		var burst := create_tween()
		burst.tween_property(piece, "position", dest, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_property(piece, "modulate:a", 0.0, 0.7)
		burst.tween_callback(piece.queue_free)

func _reveal_vault_door() -> void:
	if not ResourceLoader.exists(VAULT_DOOR_TEX):
		return
	_vault_door = Sprite2D.new()
	_vault_door.texture = load(VAULT_DOOR_TEX)
	_vault_door.position = Vector2(640, 360)
	_vault_door.modulate.a = 0.0
	add_child(_vault_door)
	var reveal := create_tween()
	reveal.tween_property(_vault_door, "modulate:a", 1.0, 0.4)

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
