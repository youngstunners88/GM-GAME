extends Control

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var title: Label = $VBoxContainer/TitleLabel

const VERSION_TAG := "v1.0.0 — BLOCK 420"

## ── TITLE SCREEN: SMOKE THEME ───────────────────────────────────────────────
## Founder brief (2026-09-22): "the design beginning title section ... does not
## evoke the theme of marijuana or smoke". The old screen was a flat white
## label over the Level 1 forest plate with no music — it read as a generic
## platformer. Four things change together here, because any one alone still
## reads wrong: the backdrop art, the lettering, constant swirling smoke, and
## a menu track.

## Backdrop candidates, tried in order. The founder's GM key art (Lil Blunt at
## the trading counter) is first; if that file is not present the list falls
## through to the smoke-themed Blaze plate BEFORE it ever reaches the old
## forest one, so a missing art drop still lands on-theme instead of silently
## regressing the whole screen back to what he rejected.
const MENU_BACKDROPS: Array[String] = [
    "res://src/assets/backgrounds/bg_menu_gm_keyart.png",
    "res://src/assets/backgrounds/bg_menu_gm_keyart.jpg",
    "res://src/assets/backgrounds/bg_blaze_l1_smoke.jpg",
    "res://src/assets/backgrounds/bg_l1_forest.jpg",
]

## Founder-supplied menu track (MistMenu).
const MENU_MUSIC := "res://src/assets/music/menu_mist_theme.mp3"

## Smoke palette. Hot brand gold at the glyph core, cooling into pale
## smoke-green in the ghost behind it — the same hot-core/cool-edge read as
## the cigar smoke in the key art.
const SMOKE_TITLE_CORE := Color(1.0, 0.93, 0.72, 1.0)
const SMOKE_TITLE_GHOST := Color(0.62, 0.88, 0.68, 0.20)
const SMOKE_SUB_CORE := Color(0.80, 0.96, 0.82, 0.95)
const SMOKE_TITLE_EDGE := Color(0.04, 0.11, 0.07, 0.92)

var _wallet_btn: Button

func _ready() -> void:
    StateMachine.change_state(StateMachine.State.MENU)
    # S10 T6/T7 — TEST-ONLY boss warp entry. If the web page is loaded with
    # ?boss=N (N=2 or 3), route straight to that level so its in-level warp
    # (LevelBase._maybe_debug_boss_warp) can drop the player into the boss arena
    # for a Playwright capture — a blind driver cannot beat Level 1's boss, which
    # blocked every prior Distributor capture. No ?boss param => normal menu.
    if _boot_boss_warp():
        return
    # TEST-ONLY — ?lounge=1 routes straight into the Smoke Lounge so the founder's
    # brand video can be verified in a real browser (the lounge is a secret realm
    # a blind driver can't reach). No param => normal menu.
    if _boot_lounge():
        return
    # TEST-ONLY — ?stage=N routes to the START of level N so the founder's track
    # screenshots (props, carts, collectibles, HUD) can be reproduced exactly.
    if _boot_stage_warp():
        return
    if _boot_episode2():
        return
    play_btn.pressed.connect(_on_play)
    continue_btn.pressed.connect(_on_continue)
    _setup_backdrop()
    _setup_smoke_title()
    _setup_ambience()
    _setup_menu_music()
    AudioManager.play_voice("menu_title")
    for btn: Button in [play_btn, continue_btn]:
        _add_hover_glow(btn)
    # Show continue button only if save file exists
    if FileAccess.file_exists(GameManager.SAVE_PATH):
        continue_btn.show()
    else:
        continue_btn.hide()
    _setup_layer_shift_buttons()
    # NOTE: the old block-scale tween on `title` is gone. It pulsed the whole
    # label as one rigid sign, which is exactly the "not smoke" read the
    # founder called out. _setup_smoke_title() now owns title motion: a slow
    # lockup breath plus independent per-letter waver.

## TEST-ONLY (S10 T6/T7). Reads ?boss=N on web; if N is a valid boss level
## (1-3), routes straight there and returns true so _ready stops setting up
## the menu. Returns false (no-op) on a normal load or any non-web build.
##
## Extended to include 1 (2026-08-18, PROMPT "Almost_Better" residual) so the
## Auditor's own mobility regression ("cant jump beyond this point anymore")
## can be captured directly, the same way ?boss=2/3 has always let a
## Playwright agent reach Distributor/Claim Jumper without playing the whole
## campaign first.
func _boot_boss_warp() -> bool:
    if not OS.has_feature("web"):
        return false
    var q: Variant = JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('boss') || ''", true)
    var s := str(q)
    if not s.is_valid_int():
        return false
    var n := int(s)
    if n < 1 or n > 3:
        return false
    # Mark the target unlocked so a fresh save can't bounce the load, then route.
    GameManager.highest_unlocked_level = maxi(GameManager.highest_unlocked_level, n)
    SceneRouter.load_scene(GameManager.level_scene(n), SceneRouter.Transition.FADE)
    return true

## TEST-ONLY. Reads ?stage=N (1-3) and routes to the START of that level.
## Distinct from ?boss=N, which loads the level AND warps to the boss arena —
## verifying the founder's TRACK screenshots (props, carts, collectibles, HUD)
## needs the level played from its opening, which ?boss= skips past.
func _boot_stage_warp() -> bool:
    if not OS.has_feature("web"):
        return false
    var q: Variant = JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('stage') || ''", true)
    var s := str(q)
    if not s.is_valid_int():
        return false
    var n := int(s)
    if n < 1 or n > 3:
        return false
    GameManager.highest_unlocked_level = maxi(GameManager.highest_unlocked_level, n)
    SceneRouter.load_scene(GameManager.level_scene(n), SceneRouter.Transition.FADE)
    return true

## TEST-ONLY. Reads ?ep2=1 on web and routes straight into Episode 2, so the
## runner/chamber loop can be opened with a URL instead of a full playthrough.
## Same shape as _boot_lounge below.
func _boot_episode2() -> bool:
    if not OS.has_feature("web"):
        return false
    var q: Variant = JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('ep2') || ''", true)
    if str(q) != "1":
        return false
    SceneRouter.load_scene(GameManager.EPISODE2_SCENE, SceneRouter.Transition.FADE)
    return true

## TEST-ONLY. Reads ?lounge=1 on web and routes into the Smoke Lounge so the
## founder's brand video can be captured in a browser. No-op otherwise.
func _boot_lounge() -> bool:
    if not OS.has_feature("web"):
        return false
    var q: Variant = JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('lounge') || ''", true)
    if str(q) != "1":
        return false
    SceneRouter.load_scene("res://src/level/secret_realm.tscn", SceneRouter.Transition.FADE)
    return true

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
    row.position = Vector2(24, get_viewport().get_visible_rect().size.y - 390)
    add_child(row)
    var defs := [
        # v1.2 preview. Sits in the layer-shift column (not the main PLAY
        # stack) so the v1.0 campaign flow is completely untouched — the
        # prototype is opt-in, and nothing in the platformer depends on it.
        # ASCII only — the pixel font has no ▶ glyph and renders it as tofu.
        ["NEW: EPISODE 2 (GOLD MINE)", _on_episode2],
        ["NEW: BLUNT FORCE (v1.2)", _on_shooter_prototype],
        ["CONNECT RABBY", _on_connect_wallet],
        ["NEW TO CRYPTO?", _on_crypto_onboarding],
        ["ASK THE ORACLE", _on_oracle],
        ["LEADERBOARD", _on_leaderboard],
        ["SUBMIT LORE", _on_submit_lore],
        ["JOIN THE SMOKERING", _on_join],
        ["FOLLOW ON X", _on_follow_x],
        ["INVITE A FRIEND", _on_invite_friend],
    ]
    for d in defs:
        var b := Button.new()
        b.text = d[0]
        # Brief correction B: readable at 720p base scaled into an itch iframe.
        # Bigger targets + font + a solid dark plate so labels read over the
        # forest art (was 240×36 / font 14, too small to read without zoom).
        b.custom_minimum_size = Vector2(300, 46)
        b.add_theme_font_size_override("font_size", 20)
        var plate := StyleBoxFlat.new()
        plate.bg_color = Color(0.05, 0.09, 0.06, 0.82)
        plate.set_corner_radius_all(6)
        plate.content_margin_left = 12
        plate.content_margin_right = 12
        b.add_theme_stylebox_override("normal", plate)
        var plate_hover := plate.duplicate()
        plate_hover.bg_color = Color(0.10, 0.18, 0.12, 0.92)
        b.add_theme_stylebox_override("hover", plate_hover)
        b.add_theme_stylebox_override("focus", plate_hover)
        b.modulate = Color(0.9, 1.0, 0.92)
        b.pressed.connect(d[1])
        _add_hover_glow(b)
        row.add_child(b)
        # Matched by label, not by index: adding entries above CONNECT RABBY
        # used to silently retarget the wallet button (get_child(0)).
        if d[0] == "CONNECT RABBY":
            _wallet_btn = b
    # Reposition to fit the taller button stack without clipping off-screen.
    row.position = Vector2(24, get_viewport().get_visible_rect().size.y - 8 - defs.size() * 54)
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
        _wallet_btn.text = "NO WALLET FOUND"
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
        _wallet_btn.text = "CONNECT RABBY"

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

## Follow @smokering25 — reads config.social.x (SOCIAL_LINKS.md is the record).
func _on_follow_x() -> void:
    Web3Bridge.track("menu_follow_x")
    var url: String = Web3Bridge.config.get("social", {}).get("x", "")
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

## Key art behind the menu; the flat ColorRect from the .tscn becomes a
## translucent green-black haze so the title and buttons stay readable over a
## busy painting without flattening it to grey.
func _setup_backdrop() -> void:
    var chosen := ""
    for path: String in MENU_BACKDROPS:
        if ResourceLoader.exists(path):
            chosen = path
            break
    if chosen == "":
        push_warning("MainMenu: no backdrop found, keeping flat colour plate.")
        return
    var bg := TextureRect.new()
    bg.name = "Backdrop"
    bg.texture = load(chosen)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    move_child(bg, 0)
    var overlay := get_node_or_null("ColorRect") as ColorRect
    if overlay:
        # Green-black, not pure black: a neutral darkener drains the plate to
        # grey and loses the realm colour the founder wants the menu to carry.
        overlay.color = Color(0.02, 0.08, 0.05, 0.52)
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        move_child(overlay, 1)


## The founder's menu track. Routed through AudioManager.play_music rather than
## a bare AudioStreamPlayer so it uses the Music bus, the duck-in fade, and the
## same stop/override path every other track uses — a local player here would
## ignore volume settings and keep playing over Level 1.
func _setup_menu_music() -> void:
    if not ResourceLoader.exists(MENU_MUSIC):
        push_warning("MainMenu: menu music missing at %s" % MENU_MUSIC)
        return
    AudioManager.play_music(MENU_MUSIC)


## Smoke lettering. The .tscn still owns TitleLabel/SubtitleLabel so anything
## that looks those nodes up keeps working; both become invisible anchors and
## the real lockup is built here.
func _setup_smoke_title() -> void:
    var vbox := get_node_or_null("VBoxContainer") as VBoxContainer
    if vbox == null:
        return
    var subtitle := get_node_or_null("VBoxContainer/SubtitleLabel") as Label
    title.visible = false
    if subtitle:
        subtitle.visible = false

    var stack := VBoxContainer.new()
    stack.name = "SmokeTitle"
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 2)
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(stack)
    vbox.move_child(stack, 0)

    # Distinct names matter: two nodes added under one parent with the same
    # name make Godot silently rename the second ("SmokeLine" -> "@SmokeLine@2"),
    # so anything looking the pair up by name finds only one of them.
    var line_main := _make_smoke_line("LIL BLUNT", 78, SMOKE_TITLE_CORE, 0.0)
    line_main.name = "SmokeLineTitle"
    stack.add_child(line_main)
    var line_sub := _make_smoke_line("THE SMOKE REALM", 34, SMOKE_SUB_CORE, 0.6)
    line_sub.name = "SmokeLineSub"
    stack.add_child(line_sub)

    # Slow lockup breath. Deliberately a different period from the per-letter
    # waver below (2.9s vs 1.7-2.6s) so the two motions never phase-lock into
    # a single visible pulse.
    stack.pivot_offset = Vector2(260, 70)
    var tw := stack.create_tween().set_loops()
    tw.tween_property(stack, "scale", Vector2(1.025, 1.025), 2.9) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_property(stack, "scale", Vector2(1.0, 1.0), 2.9) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One title line, laid out ONE GLYPH AT A TIME.
##
## Why not a Label and a tween: a single Label can only move as a block, which
## is what made the old title read as a bouncing sign. Smoke needs each letter
## drifting on its own clock.
##
## Why not an HBoxContainer of per-letter Labels: a container OWNS its
## children's position and rewrites it on every re-layout, so a position tween
## on a container child fights the container and snaps on the first resize.
## Measuring the font and placing glyphs in a plain Control keeps position
## ours to animate, at the cost of doing the layout maths here.
func _make_smoke_line(text: String, size: int, core: Color, phase_bias: float) -> Control:
    var line := Control.new()
    line.name = "SmokeLine"  # overridden by the caller to a unique name
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

    # Measure with the font these Labels will ACTUALLY render with, not with
    # ThemeDB.fallback_font unconditionally. The project ships no custom theme
    # today so the two are the same — but the glyph positions here are computed
    # from this measurement, so the day someone adds a pixel font to the theme,
    # a hardcoded fallback would silently space every title letter wrong.
    var font: Font = title.get_theme_font("font")
    if font == null:
        font = ThemeDB.fallback_font
    var tracking := float(size) * 0.06
    var widths: Array[float] = []
    var total := 0.0
    for i in text.length():
        var w := font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
        widths.append(w)
        total += w + tracking
    total -= tracking

    line.custom_minimum_size = Vector2(total, float(size) * 1.55)

    var x := 0.0
    for i in text.length():
        var ch: String = text[i]
        var w: float = widths[i]
        # A space still advances the pen, but must not spawn a glyph, a ghost
        # or a tween — animating an empty rect is pure cost for zero pixels.
        if ch == " ":
            x += w + tracking
            continue

        var glyph := Label.new()
        glyph.text = ch
        glyph.add_theme_font_size_override("font_size", size)
        glyph.add_theme_color_override("font_color", core)
        glyph.add_theme_color_override("font_outline_color", SMOKE_TITLE_EDGE)
        glyph.add_theme_constant_override("outline_size", maxi(4, int(float(size) * 0.10)))
        glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
        glyph.position = Vector2(x, float(size) * 0.2)
        line.add_child(glyph)

        # The ghost: the same glyph, bigger, barely there, sitting behind and
        # slightly above — the smear of smoke the letter is condensing out of.
        # show_behind_parent keeps it under the crisp glyph without needing a
        # second pass over the line to fix draw order.
        var ghost := Label.new()
        ghost.text = ch
        ghost.add_theme_font_size_override("font_size", size)
        ghost.add_theme_color_override("font_color", SMOKE_TITLE_GHOST)
        ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ghost.show_behind_parent = true
        ghost.pivot_offset = Vector2(w * 0.5, float(size) * 0.55)
        ghost.scale = Vector2(1.32, 1.46)
        ghost.position = Vector2(0, -float(size) * 0.06)
        glyph.add_child(ghost)

        # Per-letter waver. Durations are derived from the index so adjacent
        # letters are never in step; phase_bias offsets the whole second line
        # from the first.
        var drift := 3.0 + float(i % 4) * 1.7
        var dur := 1.7 + float(i % 5) * 0.23 + phase_bias * 0.1
        var base_y := glyph.position.y
        var tw := glyph.create_tween().set_loops()
        tw.tween_property(glyph, "position:y", base_y - drift, dur) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tw.tween_property(glyph, "position:y", base_y, dur) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

        # The ghost curls and fades on its own, slower clock — that mismatch
        # between crisp glyph and smear is what sells it as smoke rather than
        # as a drop shadow.
        var gtw := ghost.create_tween().set_loops()
        var lean := 0.05 + float(i % 3) * 0.02
        gtw.tween_property(ghost, "rotation", lean, dur * 1.6) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        gtw.tween_property(ghost, "rotation", -lean, dur * 1.6) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

        x += w + tracking

    return line


## Drifting smoke + floating ETH rings — the menu breathes instead of sitting.
func _setup_ambience() -> void:
    _setup_smoke_layers()

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

## Constant, never-idle smoke behind the whole menu.
##
## THREE layers, not one. A single emitter reads as one puff from one spot;
## depth is what makes it read as a room full of smoke. A low bank rolls along
## the floor, a mid layer does the visible SWIRLING, and a high thin wisp
## crosses the title.
##
## Every layer is preprocessed by a full lifetime, so the screen is ALREADY
## full of smoke on frame one. Without that the menu opens empty and fills in
## over ~9 seconds, which reads as "the smoke starts late" rather than as
## atmosphere that was always there.
func _setup_smoke_layers() -> void:
    var vp := get_viewport().get_visible_rect().size
    # y,        half_w,     amount, life, v_min, v_max, s_min, s_max, alpha, swirl
    _add_smoke_layer(vp.y - 30.0, vp.x * 0.62, 20, 9.0, 8.0, 22.0, 54.0, 120.0, 0.055, 14.0)
    _add_smoke_layer(vp.y * 0.72, vp.x * 0.55, 16, 11.0, 12.0, 30.0, 38.0, 88.0, 0.045, 34.0)
    _add_smoke_layer(vp.y * 0.38, vp.x * 0.48, 10, 13.0, 6.0, 18.0, 26.0, 62.0, 0.030, 22.0)


## One smoke band.
##
## `swirl` maps to tangential_accel, and it is the property that matters: with
## gravity alone particles rise in straight parallel lines, which looks like
## steam off a vent. Tangential acceleration curls each particle around its own
## emission point, which is what the founder asked for — smoke that is
## constantly swirling rather than merely drifting upward.
##
## Alphas are deliberately tiny (0.03-0.06). These layers stack, and they sit
## UNDER the title; anything heavier turns the lockup muddy and costs
## readability, which is the trap this screen was already in.
func _add_smoke_layer(y: float, half_w: float, amount: int, lifetime: float,
        vel_min: float, vel_max: float, scale_min: float, scale_max: float,
        alpha: float, swirl: float) -> void:
    var smoke := CPUParticles2D.new()
    smoke.texture = load("res://src/assets/sprites/fx_dot.png")
    smoke.amount = amount
    smoke.lifetime = lifetime
    smoke.preprocess = lifetime
    smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    smoke.emission_rect_extents = Vector2(half_w, 30.0)
    smoke.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, y)
    smoke.direction = Vector2(0, -1)
    smoke.spread = 26.0
    smoke.gravity = Vector2(5, -10)
    smoke.initial_velocity_min = vel_min
    smoke.initial_velocity_max = vel_max
    smoke.tangential_accel_min = -swirl
    smoke.tangential_accel_max = swirl
    smoke.damping_min = 2.0
    smoke.damping_max = 6.0
    smoke.angular_velocity_min = -18.0
    smoke.angular_velocity_max = 18.0
    smoke.scale_amount_min = scale_min
    smoke.scale_amount_max = scale_max
    smoke.color = Color(0.74, 0.90, 0.77, alpha)
    smoke.z_index = -1
    add_child(smoke)


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

## Brief correction G: Continue resumes at the highest realm the player has
## reached (was hardcoded to Level 1, so progress never carried).
func _on_continue() -> void:
    AudioManager.play_sfx("powerup")
    Web3Bridge.report_event("play_start")
    GameManager.load_session()
    var scene := GameManager.level_scene(GameManager.highest_unlocked_level)
    SceneRouter.load_scene(scene, SceneRouter.Transition.FADE)

## v1.2 "Blunt Force" prototype room. Opt-in preview only — it does not touch
## campaign save state, and it is NOT the shipping unlock path (per the GDD,
## shooter levels unlock from campaign completion via
## GameManager.highest_unlocked_level, never from a menu shortcut).
## Episode 2 (3D Gold Mine runner + Protocol Chambers) — direct entry.
##
## Episode 2 is also reached organically after boss 3
## (GameManager.next_level_scene -> EPISODE2_SCENE), but requiring a full
## three-level, three-boss playthrough to reach it makes it effectively
## untestable: that is exactly why it sat unplayable and unnoticed. This button
## is the same opt-in prototype entry the v1.2 shooter already uses.
func _on_episode2() -> void:
    AudioManager.play_sfx("powerup")
    Web3Bridge.track("episode2_open")
    SceneRouter.load_scene(GameManager.EPISODE2_SCENE, SceneRouter.Transition.FADE)

func _on_shooter_prototype() -> void:
    AudioManager.play_sfx("powerup")
    Web3Bridge.track("shooter_prototype_open")
    SceneRouter.load_scene("res://src/shooter/prototype_room.tscn", SceneRouter.Transition.FADE)

# Quit button removed — get_tree().quit() is a no-op in browser and
# confusing on web. Players close the tab themselves.
