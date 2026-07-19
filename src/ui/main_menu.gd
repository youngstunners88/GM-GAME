extends Control

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var title: Label = $VBoxContainer/TitleLabel

const VERSION_TAG := "v1.0.0 — BLOCK 420"

var _wallet_btn: Button

func _ready() -> void:
    StateMachine.change_state(StateMachine.State.MENU)
    play_btn.pressed.connect(_on_play)
    continue_btn.pressed.connect(_on_continue)
    quit_btn.pressed.connect(_on_quit)
    title.text = "LIL BLUNT\nTHE SMOKE REALM"
    AudioManager.play_voice("menu_title")
    _setup_backdrop()
    _setup_ambience()
    for btn: Button in [play_btn, continue_btn, quit_btn]:
        _add_hover_glow(btn)
    # Show continue button only if save file exists
    if FileAccess.file_exists(GameManager.SAVE_PATH):
        continue_btn.show()
    else:
        continue_btn.hide()
    _setup_layer_shift_buttons()
    # Animate title
    var tween := create_tween().set_loops()
    tween.tween_property(title, "scale", Vector2(1.05, 1.05), 0.8)
    tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.8)

## Movie/Video-Game-Layer entry points on the hub (main menu): the Oracle,
## the on-chain leaderboard, community lore, and the community funnel. Each
## routes through Web3Bridge and degrades gracefully with no backend. Added in
## code so the base menu scene (Book Layer) stays untouched.
func _setup_layer_shift_buttons() -> void:
    var row := VBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    # Anchors stay at the default TOP-LEFT and we position absolutely.
    # (Bug fix: PRESET_BOTTOM_LEFT + a viewport-height offset double-counted
    # the bottom edge and pushed the whole column ~500px BELOW the screen —
    # every layer-shift button was invisible in shipped builds.)
    row.position = Vector2(24, get_viewport().get_visible_rect().size.y - 344)
    add_child(row)
    var defs := [
        ["CONNECT WALLET", _on_connect_wallet],
        ["NEW TO CRYPTO?", _on_crypto_onboarding],
        ["ASK THE ORACLE", _on_oracle],
        ["LEADERBOARD", _on_leaderboard],
        ["SUBMIT LORE", _on_submit_lore],
        ["JOIN THE SMOKERING", _on_join],
        ["INVITE A FRIEND", _on_invite_friend],
    ]
    for d in defs:
        var b := Button.new()
        b.text = d[0]
        b.custom_minimum_size = Vector2(240, 36)
        b.modulate = Color(0.85, 1.0, 0.9)
        b.pressed.connect(d[1])
        _add_hover_glow(b)
        row.add_child(b)
    _wallet_btn = row.get_child(0)
    # Offline mode: wallet connect needs the network — disable with a tooltip
    # rather than letting it fail mysteriously. Re-enables on reconnect.
    _apply_wallet_online_state(not GameManager.offline_mode)
    Web3Bridge.connectivity_changed.connect(func(online: bool) -> void:
        if is_instance_valid(_wallet_btn):
            _apply_wallet_online_state(online))

func _apply_wallet_online_state(online: bool) -> void:
    # Only meaningful when a backend is configured; pre-deploy the button
    # behaves exactly as before.
    if not Web3Bridge.has_backend():
        return
    _wallet_btn.disabled = not online
    _wallet_btn.tooltip_text = "" if online else "Wallet connect requires internet"

## Movie Layer: gentle, jargon-free crypto explainer for the non-crypto
## audience (crypto-onboarding skill). Tracks onboarding_viewed.
func _on_crypto_onboarding() -> void:
    Web3Bridge.report_metric("onboarding_viewed", {})
    Web3Bridge.track("menu_onboarding")
    var panel := preload("res://src/ui/crypto_onboarding.tscn").instantiate()
    add_child(panel)

## Connect the wallet from the hub BEFORE playing, so token-gated perks
## (Movie Layer) read real balances at level start. Refreshing here (awaited)
## populates Web3Bridge.token_balances so level_base._apply_token_perks() has
## data by the time L1 loads. Degrades gracefully: no wallet → the button just
## explains and the game plays perk-free.
func _on_connect_wallet() -> void:
    Web3Bridge.track("menu_connect_wallet")
    if not Web3Bridge.is_web3_available():
        _wallet_btn.text = "NO WALLET (play web build)"
        return
    _wallet_btn.text = "CONNECTING..."
    if Web3Bridge.wallet_address == "":
        await Web3Bridge.connect_wallet()
    else:
        await Web3Bridge.refresh_balances()
    if Web3Bridge.wallet_address != "":
        _wallet_btn.text = "WALLET: " + Web3Bridge.short_address()
        Web3Bridge.report_event("wallet_connect")
    else:
        _wallet_btn.text = "CONNECT WALLET"

func _on_oracle() -> void:
    Web3Bridge.track("menu_oracle")
    var panel := preload("res://src/ui/oracle_panel.tscn").instantiate()
    add_child(panel)
    panel.open()

func _on_leaderboard() -> void:
    Web3Bridge.track("menu_leaderboard")
    SceneRouter.load_scene("res://src/ui/leaderboard.tscn", SceneRouter.Transition.FADE)

func _on_submit_lore() -> void:
    Web3Bridge.track("menu_lore")
    var panel := preload("res://src/ui/lore_panel.tscn").instantiate()
    add_child(panel)
    panel.open()

func _on_join() -> void:
    Web3Bridge.track("menu_join")
    var url: String = Web3Bridge.config.get("social", {}).get("telegram", "")
    if url != "":
        OS.shell_open(url)

## TASK 5 (AgentMail): invite a friend by email. A tiny in-code dialog — the
## backend sends the branded referral email and tracks click/conversion.
func _on_invite_friend() -> void:
    Web3Bridge.track("menu_invite")
    var dlg := AcceptDialog.new()
    dlg.title = "Invite a friend to the Smoke Realm"
    dlg.ok_button_text = "SEND INVITE"
    var box := VBoxContainer.new()
    var lbl := Label.new()
    lbl.text = "Your friend gets ONE invite email with a play link.\nNo spam, one-click unsubscribe."
    var input := LineEdit.new()
    input.placeholder_text = "friend@example.com"
    input.custom_minimum_size = Vector2(320, 36)
    box.add_child(lbl)
    box.add_child(input)
    dlg.add_child(box)
    add_child(dlg)
    dlg.confirmed.connect(func():
        var email := input.text.strip_edges()
        if email != "" and "@" in email:
            Web3Bridge.invite_friend(email, func(res: Variant):
                var ok: bool = typeof(res) == TYPE_DICTIONARY and (res as Dictionary).get("ok", false)
                var note := AcceptDialog.new()
                note.dialog_text = "Invite sent!" if ok else "Couldn't send right now (server offline?)."
                add_child(note)
                note.popup_centered())
        dlg.queue_free())
    dlg.popup_centered()

## GM Forest key art behind the menu; the existing flat ColorRect becomes a
## translucent darkener so buttons and title stay readable over the painting.
func _setup_backdrop() -> void:
    var bg := TextureRect.new()
    bg.texture = load("res://src/assets/backgrounds/bg_l1_forest.jpg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    move_child(bg, 0)
    var overlay := get_node_or_null("ColorRect") as ColorRect
    if overlay:
        overlay.color = Color(0, 0, 0, 0.6)
        move_child(overlay, 1)

## Drifting smoke + floating ETH rings — the menu breathes instead of sitting.
func _setup_ambience() -> void:
    var smoke := CPUParticles2D.new()
    smoke.texture = load("res://src/assets/sprites/fx_dot.png")
    smoke.amount = 14
    smoke.lifetime = 6.0
    smoke.preprocess = 6.0
    smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    smoke.emission_rect_extents = Vector2(700, 40)
    smoke.position = Vector2(640, 760)
    smoke.direction = Vector2(0, -1)
    smoke.spread = 20.0
    smoke.gravity = Vector2(6, -14)
    smoke.initial_velocity_min = 18.0
    smoke.initial_velocity_max = 42.0
    smoke.scale_amount_min = 24.0
    smoke.scale_amount_max = 60.0
    smoke.color = Color(0.75, 0.9, 0.78, 0.06)
    add_child(smoke)

    var ring_tex: Texture2D = load("res://src/assets/sprites/sprite_item_eth-ring.png")
    for i in range(3):
        var ring := Sprite2D.new()
        ring.texture = ring_tex
        ring.modulate = Color(1, 1, 1, 0.55)
        ring.position = Vector2(200 + i * 420, 160 + (i % 2) * 320)
        add_child(ring)
        var tw := ring.create_tween().set_loops()
        tw.tween_property(ring, "position:y", ring.position.y - 26.0, 2.2 + i * 0.4) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tw.tween_property(ring, "position:y", ring.position.y, 2.2 + i * 0.4) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    var version := Label.new()
    version.text = VERSION_TAG
    version.modulate = Color(1, 1, 1, 0.5)
    # Default top-left anchors + absolute position (same off-screen bug fix as
    # the layer-shift button column — bottom anchors double-counted the edge).
    version.position = Vector2(get_viewport().get_visible_rect().size.x - 210,
            get_viewport().get_visible_rect().size.y - 34)
    add_child(version)

## Buttons brighten on hover/focus (keyboard AND mouse per UI rules).
func _add_hover_glow(btn: Button) -> void:
    var glow := func() -> void:
        var tw := btn.create_tween()
        tw.tween_property(btn, "modulate", Color(1.25, 1.2, 0.9), 0.12)
    var unglow := func() -> void:
        var tw := btn.create_tween()
        tw.tween_property(btn, "modulate", Color.WHITE, 0.15)
    btn.mouse_entered.connect(glow)
    btn.mouse_exited.connect(unglow)
    btn.focus_entered.connect(glow)
    btn.focus_exited.connect(unglow)

func _on_play() -> void:
    AudioManager.play_sfx("powerup")
    # TASK 1 (AgentMail): one-time OPTIONAL email prompt before the first run.
    # Skipping is one click and it never asks again; the game itself never
    # requires an email. See src/ui/email_signup_panel.gd.
    var esp_script := load("res://src/ui/email_signup_panel.gd")
    if not esp_script.already_shown():
        var panel := preload("res://src/ui/email_signup_panel.tscn").instantiate()
        add_child(panel)
        await panel.closed
    Web3Bridge.report_event("play_start")
    GameManager.reset_session()
    SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)

func _on_continue() -> void:
    AudioManager.play_sfx("powerup")
    Web3Bridge.report_event("play_start")
    GameManager.load_session()
    SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)

func _on_quit() -> void:
    get_tree().quit()
