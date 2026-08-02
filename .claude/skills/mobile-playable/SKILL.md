---
name: mobile-playable
description: "Make Lil Blunt: The Smoke Realm playable on mobile devices (Godot 4.3 GDScript platformer). Use when asked to improve touch controls, responsive layout, mobile performance, viewport handling, orientation support, or the mobile web experience. Covers the MobileInputHandler virtual joystick, touch action buttons, screen adaptation, and mobile-specific optimization."
license: MIT
compatibility: "Godot 4.3+ with GDScript. Non-threaded HTML5 web export. Tested on itch.io mobile web and standalone mobile browsers. Android export security documented."
metadata:
  version: '1.0'
  author: Young Stunners
  game: "Lil Blunt: The Smoke Realm"
---

# Mobile Playable

## When to Use This Skill

Use when the user asks to:
- Fix or improve touch controls
- Make the game work on phones/tablets
- Improve mobile web performance
- Fix viewport or screen size issues on mobile
- Add orientation handling (portrait/landscape)
- Optimize for mobile GPUs and memory constraints
- Fix itch.io mobile web playback
- Add haptic feedback or mobile-specific UX
- Configure Android/iOS export settings

## Current Mobile State

### What's Implemented:
- `MobileInputHandler` autoload (`src/autoload/mobile_input_handler.gd`) — virtual joystick + action buttons
- `TouchControls` UI (`src/ui/touch_controls.gd`) — visual touch overlay
- `MobileControls` UI (`src/ui/mobile_controls.gd`) — alternate control scheme
- Mobile detection: `OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()`
- Player hooks: `MobileInputHandler.touch_jump` and `touch_dash` signals connected in `Player._ready()`
- Movement: `MobileInputHandler.get_movement_input()` returns -1/0/1 from virtual joystick
- Sprint: `MobileInputHandler.is_sprint_active()` returns button state
- Orientation setting: `window/handheld/orientation=6` (landscape) in project.godot

### What Needs Work:
- Touch controls need real-device testing (headless Chromium reports no touchscreen)
- Virtual joystick uses screen-relative zones, not a floating joystick
- No visual feedback for button presses (no press animation)
- No haptic feedback (vibration)
- Viewport may not handle notch/safe area insets
- Performance not optimized for mobile GPUs (forward_plus renderer)
- No PWA manifest for installable mobile web app

## MobileInputHandler Architecture

### Detection:
```gdscript
var is_mobile: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
```

**Critical**: On web export, `OS.get_name()` returns `"Web"` (never `"Android"` or `"iOS"`). A mobile browser only reveals itself through `DisplayServer.is_touchscreen_available()`. Without this check, itch.io/mobile-web players get no touch controls at all.

### Virtual Joystick:
- **Zone**: Left 40% of screen (`joystick_zone = Rect2(0, 0, screen_size.x * 0.4, screen_size.y)`)
- **Center**: Fixed at `Vector2(screen_size.x * 0.2, screen_size.y / 2)` — NOT a floating joystick
- **Deadzone**: 30px radius (`JOYSTICK_DEADZONE`)
- **Output**: `sign(delta.x)` — binary -1/0/1, no analog gradient

### Action Buttons:
- **Zone**: Right 60% of screen
- **Layout**: 4 buttons stacked vertically on the right edge:
  - Jump (top, y = screen_size.y / 4)
  - Sprint (middle, y = screen_size.y / 2)
  - Dash (lower, y = 3 * screen_size.y / 4)
  - Interact (bottom, y = screen_size.y - BUTTON_SIZE - 20)
- **Button size**: 80×80 px (`BUTTON_SIZE`)
- **Center X**: `screen_size.x - BUTTON_SIZE`

### Input Flow:
```
Touch event → _handle_touch() →
  if in joystick_zone → _update_joystick() → touch_move signal
  else → _handle_action_button() → emit signal (touch_jump/dash/sprint/interact)

Player._physics_process():
  movement_direction = MobileInputHandler.get_movement_input()  # overrides keyboard
  sprint_mult = input_handler.get_sprint_multiplier()  # checks MobileInputHandler.is_sprint_active()
```

## Mobile Improvements to Implement

### 1. Floating Virtual Joystick
**Problem**: Current joystick center is fixed at screen position. Players touching anywhere in the left 40% get binary direction based on offset from a fixed point — uncomfortable and imprecise.

**Solution**: Make the joystick float — the initial touch point becomes the joystick center, and dragging from there controls direction.

```gdscript
var _joystick_origin: Vector2 = Vector2.ZERO
var _joystick_active: bool = false

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed and joystick_zone.has_point(event.position):
        _joystick_origin = event.position
        _joystick_active = true
    elif not event.pressed and _joystick_active:
        _joystick_active = false
        current_movement = 0.0
        touch_move.emit(0.0)

func _handle_drag(event: InputEventScreenDrag) -> void:
    if _joystick_active:
        var delta := event.position - _joystick_origin
        if delta.length() < JOYSTICK_DEADZONE:
            current_movement = 0.0
        else:
            current_movement = clampf(delta.x / 80.0, -1.0, 1.0)  # analog
        touch_move.emit(current_movement)
```

### 2. Analog Movement
**Problem**: `sign(delta.x)` gives binary -1/0/1. No way to walk slowly.

**Solution**: Use `clampf(delta.x / threshold, -1.0, 1.0)` for analog input. Update `Player._physics_process()` to use the analog value:
```gdscript
var movement_direction: float = input_handler.get_movement_direction()
if MobileInputHandler and MobileInputHandler.is_mobile:
    movement_direction = MobileInputHandler.get_movement_input()
    # movement_direction is now -1.0 to 1.0, not just -1/0/1
```

### 3. Visual Touch Overlay
**Problem**: Current touch controls have no visual feedback. Players can't see where buttons are.

**Solution**: Draw a semi-transparent overlay in `_draw()` or via CanvasLayer:
- Joystick base circle + draggable thumb
- Button circles that highlight on press
- Use `CanvasItem` draw calls or TextureRect nodes

### 4. Button Layout Improvement
**Problem**: 4 buttons stacked vertically is not ergonomic. Thumb reach is limited.

**Solution**: Arrange buttons in an arc or diamond pattern:
```
     JUMP
  DASH   SPRINT
     INTERACT
```
Or use a configurable layout with drag-to-reposition.

### 5. Multi-Touch Handling
**Problem**: Current code tracks touches by `event.index` but doesn't properly handle simultaneous joystick + button presses.

**Solution**: Ensure each touch ID is tracked independently:
```gdscript
var _joystick_touch_id: int = -1  # which touch owns the joystick

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        if _joystick_touch_id == -1 and joystick_zone.has_point(event.position):
            _joystick_touch_id = event.index
            _joystick_origin = event.position
            _joystick_active = true
        else:
            _handle_action_button(event.position)
    else:
        if event.index == _joystick_touch_id:
            _joystick_touch_id = -1
            _joystick_active = false
            current_movement = 0.0
            touch_move.emit(0.0)
        else:
            _release_action_button(event.position)
```

### 6. Attack Button
**Problem**: No attack button on mobile. Keyboard uses J or Enter, but mobile has no equivalent.

**Solution**: Add an attack button to the action button layout. Connect to the player's combat handler.

### 7. Haptic Feedback
```gdscript
# On jump, hit, damage, pickup
if is_mobile:
    if OS.has_feature("android"):
        Input.vibrate_handheld(50)  # 50ms vibration
    # iOS uses a different API; check platform
```

### 8. Safe Area Handling
**Problem**: Notch/cutout and home indicator can overlap UI.

**Solution**:
```gdscript
func _ready() -> void:
    var safe_area := DisplayServer.get_display_safe_area()
    # Adjust UI positions to stay within safe_area
```

## Viewport and Screen Adaptation

### Current Config:
```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=6  # landscape
```

### Stretch Mode: `canvas_items`
- The viewport scales to fit the screen while maintaining 1280×720 design resolution
- UI elements scale proportionally
- `expand` aspect mode fills the screen (may crop edges on very different aspect ratios)

### Mobile Aspect Ratio Handling:
- **Landscape phones**: 16:9 or 19.5:9 — slight horizontal stretch, acceptable
- **Tablets**: 4:3 or 16:10 — more letterboxing, but `expand` fills the screen
- **Portrait**: orientation is locked to landscape (setting 6), but if portrait is desired, the entire UI needs redesign

### Improvement: Adaptive Layout
```gdscript
func _ready() -> void:
    var screen := get_viewport().get_visible_rect().size
    var aspect := screen.x / screen.y
    if aspect > 2.0:
        # Ultra-wide: spread UI elements more
        _layout_ultrawide()
    elif aspect < 1.5:
        #接近正方形: compact layout
        _layout_compact()
    else:
        _layout_standard()
```

## Performance Optimization

### Critical: Switch Renderer
```ini
# In project.godot — change from forward_plus to gl_compatibility
[rendering]
renderer/rendering_method="gl_compatibility"
```
`forward_plus` can cause rendering issues on mobile GPUs and older browsers. `gl_compatibility` is the correct renderer for a 2D HTML5 game that needs to run on mobile.

### Mobile Performance Guidelines:
1. **Use CPUParticles2D, not GPUParticles2D** — CPUParticles2D works everywhere; GPUParticles2D may not work on mobile web
2. **Limit particle counts** — keep under 50 active particles on screen at once
3. **Avoid per-pixel shaders** — the transition wipe shader is fine, but avoid screen-space effects
4. **Texture sizes** — keep background images under 2048×2048 for mobile GPU limits
5. **Audio format** — OGG for music (smaller, streams), MP3 for SFX (short, loaded in memory)
6. **Lazy loading** — don't load all level resources at boot; load per-level
7. **Physics tick rate** — keep at 60fps; don't increase for mobile

### Memory Management:
1. **Self-freeing effects** — all one-shot effects use `tween.finished.connect(queue_free)` or timers
2. **No leaked instances** — check with `get_tree().get_node_count()` before and after scenes
3. **Scene switching** — `SceneRouter` should free the old scene before loading the new one

## PWA (Progressive Web App)

### Current Web Assets (`web/`):
- `manifest.json` — basic PWA manifest
- `service-worker.js` — service worker for offline caching
- `icon.svg` — app icon
- `_headers` — HTTP headers (CORS, caching)
- `launcher.js` — web launcher script

### PWA Improvements:
1. **Add install prompt** — "Add to Home Screen" for mobile users
2. **Offline play** — service worker should cache the game for offline play
3. **Splash screen** — themed splash screen while loading
4. **App icon variants** — multiple sizes for different devices
5. **Theme color** — match the boot splash color `Color(0.101961, 0.301961, 0.2, 1)`

## Android Export

### Security (`ANDROID_EXPORT_SECURITY.md`):
- Review the security checklist before attempting Android export
- Keystore management: never commit signing keys
- Permissions: minimal — only what the game needs (no unnecessary network/location access)

### Android-Specific:
1. **Back button** — map to pause menu (currently no handling)
2. **App lifecycle** — handle pause/resume when app goes to background
3. **Screen sleep** — prevent screen from sleeping during gameplay
4. **Touch precision** — Android touch precision varies by device; use generous button sizes

## itch.io Mobile Web

### itch.io Mobile Considerations:
1. **iframe sandbox** — itch.io embeds games in iframes; SharedArrayBuffer is unavailable (hence non-threaded export)
2. **Fullscreen** — itch.io provides a fullscreen button; ensure the game handles it correctly
3. **Orientation lock** — itch.io may not respect orientation settings; add an in-game "rotate device" prompt if portrait
4. **Touch detection** — `DisplayServer.is_touchscreen_available()` is the only reliable check on itch.io mobile web

### Mobile Testing Checklist:
- [ ] Touch controls appear on mobile browsers
- [ ] Virtual joystick responds correctly (left/right)
- [ ] All action buttons are reachable by thumb
- [ ] Multi-touch works (move + jump simultaneously)
- [ ] No input lag or missed jumps
- [ ] Game renders correctly at mobile screen sizes
- [ ] No performance drops below 30fps during gameplay
- [ ] Audio plays correctly (mobile browsers require user interaction first)
- [ ] Screen doesn't sleep during gameplay
- [ ] Back button (Android) opens pause menu
- [ ] Game works in itch.io iframe on mobile
- [ ] PWA install prompt works (if enabled)
- [ ] Safe area respected (notch/home indicator)
