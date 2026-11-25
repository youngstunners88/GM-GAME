extends Node3D
## FIVE MORE PEOPLE IN THE AUCTION HALL (founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21): background extras of different age and
## build in their Sunday best (suits, vests, hats), made with MPFB2 from MakeHuman's CC0 assets (mpfb_folk.gd). Added by
## Ep2AuctionHouse as a child (one const + one load line there); streamed, loaded by path, no class_name.
##   - they stand on open floor: off the centre aisle, clear of the bidders, the band, the servers' walks, the porch and the road,
##   - they face the block; when the room swells at a call they clap (both hands by Ep2ArmIK, no clip needed) and the heavy man
##     lifts his hand to bid; when Jack Hammer is in the room they stop and turn to him,
##   - each is solid to Lil Blunt (the hall's own blocker rectangles).

const FOLK := preload("res://src/episode2/extras/folk_mpfb/mpfb_folk.gd")
const FLOOR_Y := 0.12
const BLOCK := Vector3(0.0, 0.0, 26.0)
const JACK := Vector3(-8.4, 0.0, 21.4)
## [id, height, house-local x, z, base clip, on a swell: "clap" | "bid" | ""]
const EXTRAS: Array = [
	["au_bidder", 1.76, 6.6, 16.8, "Idle", "bid"],
	["au_lady", 1.64, -6.8, 17.4, "Idle", "clap"],
	["au_youth", 1.80, 6.8, 9.8, "Idle", "clap"],
	["au_matron", 1.60, -7.2, 9.0, "Idle", "clap"],
	["au_elder", 1.66, -3.0, 7.0, "Idle", ""],
]

class Extra:
	var folk: Ep2TownFolk
	var clip: String = "Idle"
	var on_swell: String = ""
	var ik: Dictionary = {}
	var clap: float = 0.0          # 0..1 how much the hands are on the clap
	var phase: float = 0.0
	var bid_t: float = 0.0

var extras: Array = []
var _house: Node = null


func _ready() -> void:
	_house = get_parent()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1124
	for row in EXTRAS:
		var f: Ep2TownFolk = FOLK.make(self, str(row[0]), float(row[1]))
		if f == null:
			continue
		f.use_height = true
		f.clip_blend = 0.3
		f.place(Vector3(float(row[2]), FLOOR_Y, float(row[3])))
		f.face_point(BLOCK)
		f.rotation.y = f.facing
		var e := Extra.new()
		e.folk = f
		e.clip = str(row[4])
		e.on_swell = str(row[5])
		e.phase = rng.randf_range(0.0, TAU)
		f.hold_clip(e.clip)
		var ap: AnimationPlayer = f.anim_player()
		if ap != null and ap.current_animation != "":
			ap.seek(rng.randf_range(0.0, maxf(ap.current_animation_length - 0.1, 0.0)), true)
		if e.on_swell == "clap":
			e.ik = FOLK.arm_iks(f)
		if _house != null and _house.has_method("_solid"):
			_house.call("_solid", float(row[2]), float(row[3]), 0.3, 0.3)
		extras.append(e)


func _process(delta: float) -> void:
	var swell: float = float(_house.get("_swell")) if _house != null and "_swell" in _house else 0.0
	var phase: String = str(_house.get("phase")) if _house != null and "phase" in _house else ""
	var jack_here: bool = phase == "jack"
	for e in extras:
		if not is_instance_valid(e.folk):
			continue
		e.folk.face_point(JACK if jack_here else BLOCK)
		var want_clap: bool = e.on_swell == "clap" and swell > 0.35 and not jack_here
		e.clap = move_toward(e.clap, 1.0 if want_clap else 0.0, delta * 3.0)
		e.phase += delta * TAU * 2.3
		if not e.ik.is_empty():
			_clap(e)
		if e.on_swell == "bid":
			if swell > 0.9 and e.bid_t <= 0.0 and not jack_here and e.folk.play_clip("Bid"):
				e.bid_t = 2.4
			if e.bid_t > 0.0:
				e.bid_t -= delta
				if e.bid_t <= 0.0:
					e.folk.hold_clip(e.clip)
		e.folk.step(delta)


## Both hands meet and part in front of his chest, a little over twice a second. His sides and front come from his own shoulders in
## world space (2026-11-25: they came from his LOCAL rotation.y, but the hall is turned to the road, so each hand was sent to the other
## side and the forearms crossed - tools/ep2_shots/arm_fold_probe: 3 clappers folded in ~45% of frames).
func _clap(e: Extra) -> void:
	var f: Ep2TownFolk = e.folk
	var side: Vector3 = FOLK.across(f)                    # toward his left
	var fwd: Vector3 = side.cross(Vector3.UP)              # left x up = his front
	var centre: Vector3 = f.global_position + Vector3.UP * f.height_m * 0.70 + fwd * 0.30
	var gap: float = 0.025 + 0.09 * absf(sin(e.phase))
	for s in e.ik:
		var ik: Ep2ArmIK = e.ik[s]
		ik.reaching = e.clap > 0.01
		ik.influence = e.clap
		ik.target_world = centre + side * (gap if s == "Left" else -gap)
