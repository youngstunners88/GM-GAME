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

## Current Mobile State (rewritten 2026-10-13)

**Touch controls are owned by skill `gm-game-mobile-touch-experience`** — read it first for anything about the
joystick, thumb buttons, layouts, safe areas, orientation or haptics. Mobile skills added 2026-10-23 (founder: "players use finger movements", no keys written on screen):
`gm-game-blaze-rush-mobile` (Blaze Rush, all 3 stages), `ep2-mobile-touch` (Episode 2 runner + hideout), `gm-game-mobile-seamless-transitions` (Episode 1 -> 2 hand-off and the other cuts),
`gm-game-touch-flow-verification` (how to prove a touch flow; what needs a real phone). Plain-words device checklist for the founder: `docs/MOBILE_TEST_STEPS_2026-10-23.md`. Summary:
- `src/input/mobile/` holds the analog `VirtualJoystick`, `VirtualButton`s, per-device layout scenes and the
  `MobileLayoutManager` autoload. Controls press ordinary InputMap actions (`TouchActions`); gameplay never knows.
- `MobileInputHandler` (`src/autoload/mobile_input_handler.gd`) is only a thin shim (`is_mobile`,
  `get_movement_input()` = `Input.get_axis`, `is_sprint_active()`); its `touch_*` signals are never emitted.
- The old `src/ui/mobile_controls.gd` / `touch_controls.tscn` (TouchScreenButtons) are deleted.
- Detection: `OS.get_name() in ["Android","iOS"] or DisplayServer.is_touchscreen_available()` (Web always reports
  `"Web"`, so `has_feature("mobile")` is always false). Phone vs tablet is by smallest side in dp (< 600 = phone).
- Orientation setting: `window/handheld/orientation=6` (landscape) in project.godot; stretch `canvas_items` + `expand`.
- Gates: `tests/mobile_touch_controls_test.tscn`; real-browser multi-touch `scripts/touch-playtest.mjs`.

### Still open (not touch controls)
- Real-device confirmation on a phone and a tablet (founder hard-refresh) — nothing here is claimed FIXED without it.
- No PWA manifest; performance not tuned for mobile GPUs (forward_plus renderer in project settings).
- Native Android/iOS export paths are untested on hardware.

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
- **Portrait**: `window/handheld/orientation=6` is the sensor setting and the web shell allows BOTH orientations, so portrait is real. Blaze Rush frames itself for portrait (`BlazeFraming`); the 3D Episode 2 runner/hideout cannot, so it pauses behind a drawn "turn your phone" cue (`ep2_rotate`).

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
