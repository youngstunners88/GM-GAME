class_name Stage1BossDefeatCutscene
extends CanvasLayer
## Stage 1 boss-defeat progress beat: Auditor down -> GOV VAULT looted ->
## mining gear claimed -> shaft jump toward Crystal Caverns (Stage 2).
## Plays after the Auditor's own death tween (see auditor.gd::die()) and
## before victory_screen.tscn — purely an interstitial, changes nothing
## about the Web3/leaderboard flow that follows it.
##
## Design brief + multi-model review (Grok 4.5 + gpt-6-astra-pro, both
## converged on the same failure-safety spine): see
## docs/model-responses/2026-09-05-*-stage1-defeat-cutscene.md.
##
## Deliberately screen-space only (a CanvasLayer overlay, same technique as
## the Smoke Lounge brand video in secret_realm.gd) rather than staging
## world-space actors: it never touches the live player node's transform or
## visibility, so it carries zero risk of leaving the player in a bad state
## for whatever loads next. The only real-object interaction is a single
## non-animated Player.set_outfit(MINER) call, which is the same call
## level_02_crystal_caverns.gd already makes on its own _ready() — this just
## makes it happen a few seconds earlier for narrative continuity.
##
## Every wait uses the project's hardened tree-owned timer idiom
## (get_tree().create_timer(t, true, false, true) — process-always, ignores
## pause/time-scale; same idiom as player.gd/auditor.gd/distributor.gd) and
## a hard deadline guarantees `finished` fires even if something upstream
## goes wrong — this project's freeze-bug history is entirely sequences that
## assumed some other node would still exist a frame later, so this one
## assumes nothing.

signal finished

const PICKAXE_TEX := "res://src/assets/sprites/sprite_item_pickaxe.png"
const MINER_TEX := "res://src/assets/sprites/sprite_lil-blunt_miner.png"
const TAX_VO_ID := "cutscene_s1_defeat_taxcollector"
const BLUNT_VO_ID := "cutscene_s1_defeat_lilblunt"
## Absolute ceiling on the whole sequence. If anything above hangs or a step
## takes longer than expected, this still reaches victory_screen.
const HARD_DEADLINE := 14.0
const CAVERN_TINT := Color(0.32, 0.22, 0.6, 0.6)

var _tint: ColorRect
var _pickaxe: Sprite2D
var _miner_portrait: Sprite2D
var _shaft: ColorRect
var _done := false

func play() -> void:
	layer = 5  # above HUD/gameplay, below the level-transition wipe (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_backdrop()
	get_tree().create_timer(HARD_DEADLINE, true, false, true).timeout.connect(_finish)
	_run()

func _run() -> void:
	# Beat 1 (0.0-1.0s): dark backdrop settles in. The finishing blow itself
	# already played out as the Auditor's own scale/spin/fade tween just
	# before this node was created (auditor.gd::die(), unchanged) — this
	# just gives that a beat to read before the vault reveal starts.
	var fade_in := create_tween()
	fade_in.tween_property(_tint, "color:a", 0.55, 0.5)
	await get_tree().create_timer(1.0, true, false, true).timeout

	# Beat 2 (~1.0-3.0s): GOV VAULT chest opens, Tax Collector reacts.
	var chest := _build_vault()
	AudioManager.play_voice(TAX_VO_ID)
	await get_tree().create_timer(0.5, true, false, true).timeout
	var lid: ColorRect = chest
	var open_tween := create_tween()
	open_tween.tween_property(lid, "rotation_degrees", -105.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_pickaxe()
	await get_tree().create_timer(1.5, true, false, true).timeout

	# Beat 3 (~3.0-6.5s): gear claimed. Pickaxe crosses to a Lil Blunt
	# portrait; the real player quietly gets the same MINER outfit
	# level_02 would give it anyway.
	_reveal_miner_portrait()
	if is_instance_valid(_pickaxe) and is_instance_valid(_miner_portrait):
		var claim := create_tween()
		claim.tween_property(_pickaxe, "global_position", _miner_portrait.global_position, 0.7)
		claim.parallel().tween_property(_pickaxe, "scale", Vector2(0.6, 0.6), 0.7)
		await claim.finished
	if is_instance_valid(_pickaxe):
		_pickaxe.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("set_outfit"):
		player.set_outfit(Player.Outfit.MINER)
	AudioManager.play_voice(BLUNT_VO_ID)
	await get_tree().create_timer(2.0, true, false, true).timeout

	# Beat 4 (~6.5-11.0s): mine shaft opens, Lil Blunt drops in, palette
	# shifts toward Crystal Caverns' cool blue-purple as the "moving on" cue.
	_build_shaft()
	await get_tree().create_timer(0.5, true, false, true).timeout
	if is_instance_valid(_miner_portrait) and is_instance_valid(_shaft):
		var drop := create_tween()
		drop.tween_property(_miner_portrait, "global_position", _shaft.global_position, 0.8)
		drop.parallel().tween_property(_miner_portrait, "scale", Vector2(0.25, 0.25), 0.8)
		drop.parallel().tween_property(_miner_portrait, "modulate:a", 0.0, 0.8)
		await drop.finished
	var wash := create_tween()
	wash.tween_property(_tint, "color", CAVERN_TINT, 1.0)
	await wash.finished
	await get_tree().create_timer(0.4, true, false, true).timeout
	_finish()

func _build_backdrop() -> void:
	_tint = ColorRect.new()
	_tint.color = Color(0.0, 0.0, 0.0, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

## Returns the lid ColorRect (the caller tweens its rotation to "open" it).
func _build_vault() -> ColorRect:
	var body := ColorRect.new()
	body.color = Color(0.32, 0.2, 0.08)
	body.size = Vector2(170, 90)
	body.position = Vector2(555, 430)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	var label := Label.new()
	label.text = "GOV VAULT"
	label.position = Vector2(555, 450)
	label.size = Vector2(170, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(label)

	var lid := ColorRect.new()
	lid.color = Color(0.42, 0.27, 0.1)
	lid.size = Vector2(170, 26)
	lid.position = Vector2(555, 430)
	lid.pivot_offset = Vector2(0, 26)
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lid)
	return lid

func _pop_pickaxe() -> void:
	if not ResourceLoader.exists(PICKAXE_TEX):
		return
	_pickaxe = Sprite2D.new()
	_pickaxe.texture = load(PICKAXE_TEX)
	_pickaxe.position = Vector2(640, 455)
	_pickaxe.scale = Vector2.ZERO
	add_child(_pickaxe)
	var pop := create_tween()
	pop.tween_property(_pickaxe, "scale", Vector2(1.3, 1.3), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reveal_miner_portrait() -> void:
	if not ResourceLoader.exists(MINER_TEX):
		return
	_miner_portrait = Sprite2D.new()
	_miner_portrait.texture = load(MINER_TEX)
	_miner_portrait.position = Vector2(950, 430)
	_miner_portrait.modulate.a = 0.0
	add_child(_miner_portrait)
	var reveal := create_tween()
	reveal.tween_property(_miner_portrait, "modulate:a", 1.0, 0.5)

func _build_shaft() -> void:
	_shaft = ColorRect.new()
	_shaft.color = Color(0.04, 0.04, 0.07)
	_shaft.position = Vector2(890, 590)
	_shaft.size = Vector2.ZERO
	_shaft.pivot_offset = Vector2(60, 0)
	_shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shaft)
	var grow := create_tween()
	grow.tween_property(_shaft, "size", Vector2(120, 55), 0.4)

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
