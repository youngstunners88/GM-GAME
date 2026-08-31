extends Node
## Global fullscreen control (autoload: FullscreenToggle).
##
## FOUNDER, THREE TIMES: "I want the game screen to cover more area space!
## ... we have all this unused real estate", "I'm so sick of playing this game
## on such a small payview screen. I told you expand the aspect ratio. This is
## not reasonable to have most of this space blank!!!"
##
## WHAT HIS SCREENSHOT ACTUALLY SHOWS, and why no code change had fixed it:
## the game itself renders correctly at 1280x720 with
## `stretch/mode="canvas_items"` + `stretch/aspect="expand"`, so it already
## fills whatever canvas it is given. The blank space is the itch.io PAGE
## around a small embed frame. Embed width/height is a setting on the itch.io
## project dashboard (Edit game -> Embed options), NOT anything this repository
## controls — butler only uploads build files, it cannot resize the page frame.
## So every previous pass that "looked at the viewport" found nothing to fix,
## and he kept asking.
##
## What the repo CAN do is make the embed size stop mattering: let him blow the
## game up to the whole monitor from inside the game. Browsers only honour the
## Fullscreen API from a real user gesture, so this is driven by input (a key,
## and the on-screen button in the HUD) rather than called automatically.
##
## F or F11 toggles. ESC is deliberately NOT bound: browsers reserve it to
## LEAVE fullscreen, and the browser exiting on its own is handled by polling
## the real window mode below rather than by tracking our own flag (which would
## desync the first time he pressed Escape).

## Actions are created at runtime so this needs no project.godot input-map edit
## and cannot collide with an existing binding.
const ACTION := "toggle_fullscreen"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		for key in [KEY_F, KEY_F11]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(ACTION, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		toggle()
		get_viewport().set_input_as_handled()

## True when the window is actually fullscreen RIGHT NOW.
##
## Read from DisplayServer every time rather than cached: the browser can drop
## out of fullscreen without telling the game (Escape, tab switch, the user
## clicking the browser's own exit affordance), and a cached bool would then be
## inverted — the next press would try to "exit" a fullscreen that had already
## ended, doing nothing and looking broken.
func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func toggle() -> void:
	set_fullscreen(not is_fullscreen())

func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
