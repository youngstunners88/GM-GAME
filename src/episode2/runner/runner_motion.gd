class_name RunnerMotion
extends RefCounted
## Episode 2 runner — MOTION + EMOTION layer (layer 5 of the ep2-layered-production
## workflow). Pure logic: given what the sim says is happening, which skeletal clip
## a character should be in, at what speed, from what offset. No nodes are created
## here, so every choice is headless-testable (tests/ep2_runner_motion_test.gd).
##
## The view owns the AnimationPlayers and calls pick_rider()/pick_archer() each
## frame, then Anim.want() cross-fades to the answer.
##
## Clip timings were MEASURED from the Meshy rigs (bone-speed peaks), not guessed:
##   Side_Shot trigger 0.86 s · Charged_Axe_Chop impact 2.02 s · Regular_Jump apex
##   0.80 s · CrouchLookAroundBow head at 65 % height · Archery_Shot release 1.16 s.
## Re-measure with the probe in .claude/skills/ep2-motion-emotion/SKILL.md after any re-rig.

const RIDER_RIG := "res://src/episode2/assets/lil_blunt_rigged.glb"
const BEAR_RIG := "res://src/episode2/assets/bear_rigged.glb"

## Loop these; everything else is a one-shot that returns to the base clip.
const LOOPING := ["Combat_Stance", "CrouchLookAroundBow", "Rope_Hang_Idle", "Idle",
	"Archery_Aim_with_Lateral_Scan"]

## clip -> [start offset s, playback speed]. Offsets skip wind-up so the key
## moment lands right after the sim event (shot 0.08 s, chop 0.19 s, apex ~0.33 s).
const RIDER_CLIPS := {
	"idle": ["Combat_Stance", 0.0, 1.0],
	"zip": ["Rope_Hang_Idle", 0.0, 1.0],
	"duck": ["CrouchLookAroundBow", 0.4, 1.0],
	"jump": ["Regular_Jump", 0.35, 1.35],
	"hop": ["Regular_Jump", 0.45, 2.0],
	"hit": ["Hit_Reaction", 0.0, 1.6],
	"reload": ["Standing_Reload", 0.0, 2.55],
	"swipe": ["Charged_Axe_Chop", 1.6, 2.2],
	"cheer": ["Victory_Fist_Pump", 0.0, 1.2],
}
const BEAR_CLIPS := {
	"idle": ["Idle", 0.0, 1.0],
	"aim": ["Archery_Aim_with_Lateral_Scan", 0.0, 1.0],
	"loose": ["Archery_Shot", 0.6, 1.25],
	"die": ["Shot_and_Fall_Backward", 0.2, 1.5],
	"leap": ["Leap_and_Punch", 0.0, 1.4],
	"stomp": ["Angry_Ground_Stomp", 0.0, 1.2],
	"flinch": ["Hit_Reaction_with_Bow", 0.0, 1.5],
}

## How long an event keeps its emotion on screen (s).
const HIT_HOLD := 0.7
const SHOOT_HOLD := 0.32
const CHEER_HOLD := 0.9
const SWIPE_HOLD := 0.45
const HOP_HOLD := 0.28
## A boulder/rail-end on the rider's own rail inside this many seconds = alarm.
const DANGER_SECS := 1.6

## Rider mood from sim state + event timers (seconds since each event; big = long ago).
## Priority: the most urgent physical state wins, then reactions, then attitude.
## `t_shot` is kept for API stability; shooting is the aim modifier's job.
static func pick_rider(zipping: bool, ducking: bool, airborne: bool, reloading: bool,
		t_hit: float, t_shot: float, t_swipe: float, t_hop: float, t_cheer: float) -> String:
	if zipping:
		return "zip"
	if t_hit < HIT_HOLD:
		return "hit"
	if t_swipe < SWIPE_HOLD:
		return "swipe"
	if ducking:
		return "duck"
	if airborne:
		return "jump"
	if t_hop < HOP_HOLD:
		return "hop"
	# No full-body "shoot" clip: RunnerAimModifier points the gun arm at the
	# reticle on top of the idle, so the body stays square in the cart with the
	# revolver in one hand and the pickaxe in the other (founder 2026-09-27).
	if reloading:
		return "reload"
	if t_cheer < CHEER_HOLD:
		return "cheer"
	return "idle"

## Archer mood: dead > loosing (arrow about to fly) > aiming (in range) > idle.
static func pick_archer(alive: bool, to_release: float, ahead: float) -> String:
	if not alive:
		return "die"
	if to_release >= 0.0 and to_release < 0.5:
		return "loose"
	if ahead > -4.0 and ahead < 70.0:
		return "aim"
	return "idle"

## Seconds until a hazard that would destroy the rider's own cart, or INF.
static func danger_eta(sim: Object, lane: int, dist: float, speed: float) -> float:
	var best: float = INF
	if speed <= 0.0:
		return best
	for o in sim.get_obstacles():
		if str(o.get("type", "")) == "boulder" and int(o["lane"]) == lane and not bool(o.get("smashed", false)):
			var dz: float = float(o["z"]) - dist
			if dz >= 0.0:
				best = minf(best, dz / speed)
	if sim.has_method("get_rail_events"):
		for e in sim.get_rail_events():
			if str(e["type"]) == "end" and int(e["lane"]) == lane and not bool(e["done"]):
				var dz2: float = float(e["z"]) - dist
				if dz2 >= 0.0:
					best = minf(best, dz2 / speed)
	return best


## Thin cross-fading driver around one AnimationPlayer.
class Anim:
	var player: AnimationPlayer = null
	var table: Dictionary = {}
	var current: String = ""

	func _init(model: Node, clips: Dictionary) -> void:
		table = clips
		if model == null:
			return
		var found: Array = model.find_children("*", "AnimationPlayer", true, false)
		if found.is_empty():
			return
		player = found[0]
		for name in player.get_animation_list():
			var a: Animation = player.get_animation(name)
			if a and LOOPING.has(str(name)):
				a.loop_mode = Animation.LOOP_LINEAR

	func ok() -> bool:
		return player != null

	## Switch to `mood` (a key in the clip table). One-shots restart from their
	## offset every time the mood is entered; loops keep playing.
	func want(mood: String, blend: float = 0.12) -> void:
		if player == null or mood == current or not table.has(mood):
			return
		var spec: Array = table[mood]
		var clip: String = str(spec[0])
		if not player.has_animation(clip):
			return
		current = mood
		player.play(clip, blend, float(spec[2]))
		var off: float = float(spec[1])
		if off > 0.0:
			player.seek(off, true)
