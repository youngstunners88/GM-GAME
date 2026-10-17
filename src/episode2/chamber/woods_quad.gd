class_name WoodsQuadChamber
extends Ep2Interlude
## Interlude 2 - THE BEAR WOODS (founder 2026-10-09, reworked 2026-10-13). They step out of the mine lift into the wood. Inferno
## Bull is a master of disguise: nothing he owns can be found, least of all his FLAME-DESIGNER QUAD, hidden under a hand-built pile
## of leaves and branches in a thicket far from his door.
##
## Founder 2026-10-13: "the bears are not active ... not walking around, sleeping, reading magazines ... give them movements and
## awareness. They should all have personality and individual character ... they need to drive for a while before they get to the
## bear camp as they are shooting off bears on the road. Some bears fire back with their arrows ... I want the world to be much
## larger - bears being able to smell [the forge] and being so close to Inferno Bull's hideout makes no sense." So:
##   * THE NEAR WOOD (~230 m of trail): only the bears' SCOUTS roam here, each with a name, a routine and senses of his own
##     (Ep2BearBrain: Twitch walks a beat with fox ears, Professor Barnaby reads Bear Monthly on a stump, Old Moss snores by a
##     log, Mumbles roams and grumbles, Hattie keeps watch with her bow, Sniffer patrols by the quad). Inferno names each one as
##     they pass. Walk behind Inferno and nobody notices; run, shoot or stray into a bear's view and he hears / sees you, comes
##     to look, roars for help, charges or shoots. Inferno defends you (he fires on a charging bear). Three hearts.
##   * THE OLD LOGGING ROAD (~750 m on the quad, ~70 s): bear pickets along the road wake to the engine - brawlers run at the
##     bike and leap, archers draw and loose real arrows (a visible draw = the warning; arrows fly, miss or hit). Lil Blunt
##     shoots from the back seat while Inferno drives. Dead bears stay where they fell.
##   * OUT OF THE WOODS INTO GOLD-RUSH COUNTRY (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md): the pines thin,
##     the light warms, the desert opens, the bears stop coming; the town and Fort Knox grow on the horizon (Ep2GoldTown). Bull drops
##     Lil Blunt in the main street (his Blondie line), Lil Blunt hops off and Bull rides off on the quad. The town is the next room
##     (GoldTownChamber), built behind this one during the ride and swapped in with one invisible cut.
## Failing (out of hearts) restarts at the mine exit (checkpoint hideout_surface_exit, design/ep2/LIVING_WOODS_CONTRACT.md):
## bears, quad, ammo and hearts are restored together; Inferno says one line and they go again.
## Every hand-over inside the chamber is a move, never a blink: he climbs onto the quad (his view glides to the back seat while
## Inferno swings onto the saddle) and hops off at the ridge the same way (skill ep2-no-blackouts).
##
## Beats: SNEAK -> REVEAL (leaves off) -> MOUNT -> RIDE (on rails, the road fight, then the desert) -> DROPOFF (the street) -> DONE.
## Skills: ep2-interlude-chain, ep2-living-woods.

enum Beat { SNEAK, REVEAL, MOUNT, RIDE, DROPOFF, DONE }

const MUSIC := "res://src/assets/music/ep2_deep_mining3_quad.ogg"
const QUAD_LOOP := "res://src/assets/sounds/ep2_quad_loop.mp3"

# --- layout (metres; flat ground, +z is "deeper into the wood") ---
const SPAWN := Vector3(0.0, 0.0, 2.0)
const BULL_START := Vector3(1.6, 0.0, 4.0)
## The trail Inferno leads along while they sneak: ~230 m through the near wood, past the scouts.
const SNEAK_TRAIL: Array = [Vector2(0.0, 4.0), Vector2(1.0, 17.0), Vector2(-2.5, 30.0), Vector2(-1.5, 45.0), Vector2(4.0, 62.0),
	Vector2(8.0, 80.0), Vector2(5.0, 98.0), Vector2(-3.0, 114.0), Vector2(-8.0, 130.0), Vector2(-6.0, 146.0), Vector2(0.0, 162.0),
	Vector2(4.0, 178.0), Vector2(2.0, 194.0), Vector2(-4.0, 206.0), Vector2(-7.0, 214.0)]
const QUAD_POS := Vector3(-11.5, 0.0, 219.0)        # hidden in the thicket beside the end of the trail
const QUAD_YAW := 0.0                              # nose toward +z
## The ride (x, z): out of the thicket onto the old logging road and down it to the ridge over the bear camp (~750 m).
const RIDE_TRAIL: Array = [Vector2(-11.5, 219.0), Vector2(-6.0, 229.0), Vector2(2.0, 243.0), Vector2(10.0, 263.0), Vector2(14.0, 290.0),
	Vector2(8.0, 320.0), Vector2(-6.0, 348.0), Vector2(-16.0, 378.0), Vector2(-14.0, 410.0), Vector2(-2.0, 440.0), Vector2(12.0, 470.0),
	Vector2(20.0, 505.0), Vector2(14.0, 540.0), Vector2(0.0, 570.0), Vector2(-14.0, 600.0), Vector2(-20.0, 635.0), Vector2(-12.0, 668.0),
	Vector2(2.0, 698.0), Vector2(14.0, 730.0), Vector2(16.0, 765.0), Vector2(6.0, 798.0), Vector2(-8.0, 828.0), Vector2(-12.0, 860.0),
	Vector2(-5.0, 890.0), Vector2(3.0, 918.0), Vector2(2.0, 942.0), Vector2(1.0, 957.0),
	# out of the pines into gold-rush country (2026-10-14): a long easy road across the desert into the town's main street
	Vector2(-4.0, 990.0), Vector2(-10.0, 1040.0), Vector2(-7.0, 1100.0), Vector2(3.0, 1160.0), Vector2(9.0, 1220.0), Vector2(6.0, 1285.0),
	Vector2(1.0, 1345.0), Vector2(0.0, 1385.0), Vector2(0.0, 1403.0)]
const RIDE_SPEED := 12.5                            # the straights
const RIDE_BEND_SPEED := 7.5                        # Inferno brakes into the bends
## The modelled quad: Tripo H3.1 multi-view image-to-3D (Muapi) from the GPT-Image-2 stills of the founder's flame-designer quad, cleaned up by
## tools/ep2_forge/ai_vehicle_to_game.py: nose +Z, origin on the ground midway between the axles, tyre outer diameter 1.0 m, four Wheel_* nodes
## (hub-centred, axle = local X). Landmarks measured on the mesh: seat top 1.37-1.42, rack deck ~1.43 (z -1.84..-1.05), grips x +-0.5 y 1.72 z 0.5.
const QUAD_MODEL := "res://src/episode2/assets/vehicles/flame_quad_ai.glb"
const QUAD_WHEEL_R := 0.5
const SEAT_TOP := 1.43                              # the rack deck (Lil Blunt kneels on it)
const SEAT_TOP_DRIVER := 1.38                       # the bench Inferno sits on, at his hips
## Inferno rides SEATED (his Chair_Sit_Idle_M clip frozen at 4 s); Lil Blunt kneels on the rear of the seat / rack, eye just above
## Inferno's head, so he sees the road over him and the rack hoop is his rest (tools/ep2_shots/rider_probe.gd printed these numbers).
const BULL_SIT_CLIP := "Chair_Sit_Idle_M"
const BULL_SIT_AT := 4.0
const BULL_HIPS := Vector3(0.35, 1.10, -0.49)       # his hips in actor space in that pose
const BULL_SEAT_F := -0.50                          # his hips along the seat (+ = toward the nose)
const GRIP_F := 0.52
const GRIP_U := 1.74
const GRIP_X := 0.56
const BACK_F := -1.45                               # Lil Blunt's spot on the rear of the seat / rack
const BACK_SIDE := 0.30                             # ...a little to the right of the centreline: he looks past Inferno's shoulder, not into his back
const BACK_EYE := 1.40                              # his eye above the seat/rack there (kneeling)
const BULL_LEAN := 0.55                             # Inferno leans onto the grips (the seated clip alone sits him upright against a chair back)
const BULL_GRIPS_IK := false                      # Inferno's hands are NOT dragged to the grips: the skinned elbow cannot take the IK (tears / goes invisible)
const PICKET_ROAD_LEN := 775.0                    # the road pickets' `at` is a fraction of the WOODS road (the desert part has no bears)
const FOREST_END_Z := 960.0                        # the old growth thins out over the 100 m before this and stops
const DESERT_FULL_Z := 1080.0                      # the light is fully gold-rush country from here (graded by road distance)
const WORLD_END_Z := 1760.0
const HEARING := 19.0                              # a RUNNING Lil Blunt is heard inside this radius (x the bear's ears)
const WALK_NOISE := 4.0                            # ...a walking one only this close
const SHOT_HEARING := 46.0                         # a Winchester shot carries far further than boots on gravel
const ENGINE_HEARING := 70.0                       # the quad's engine: every bear inside this turns to it ...
const ENGINE_ALARM := 40.0                         # ... and inside this (with a clear line) knows it is the enemy
const SEAT_SIDE := 0.55                            # the back seat is wide: he sits to the right of Inferno's axis and sees the road past his shoulder
const CART_MODEL := "res://src/episode2/assets/town/donkey_cart.glb"
const CART_S0 := 868.0                              # where the farmer's donkey cart stands on the road (arc length; the desert, past the last pines)
const CART_SPEED := 2.4                             # ... and how fast it plods toward town (m/s)
const CART_LATERAL := 3.1                           # it keeps to the right of the road; the quad passes on the left
const CART_SCALE := 3.8                             # the Tripo model is ~1 m long, 0.59 m tall
const BULL_AHEAD := ["vo_bull_ahead1", "vo_bull_ahead2", "vo_bull_ahead3"]      # Lil Blunt is scouting on ahead
const BULL_WAIT := ["vo_bull_wait1", "vo_bull_wait2"]                           # Lil Blunt lags: a look back, a word
const BULL_EASY := ["vo_bull_woods_sneak", "vo_bull_sneak2", "vo_bull_sneak3"]  # the rare murmur while they walk
const BULL_QUIET := ["vo_bull_woods_quiet", "vo_bull_quiet2"]                   # he ran, a bear heard
const BULL_COVER := ["vo_bull_cover1", "vo_bull_cover2", "vo_bull_cover3"]      # Lil Blunt is in trouble: Inferno fires
const HEALTH_MAX := 3                              # the story's 3-heart cap (no second health system)
const BEAR_ACTIVE_R := 150.0                       # bears further than this sleep in the engine (hidden, not processed) - the fog hides them anyway
const ARROW_SPEED := 40.0
const ARCHERS_AT_ONCE := 2                         # the active-attack budget: at most this many bows drawn on him at a time
const VM_KEY_ENERGY := 4.7                         # measured: holds the held rifle at 0.34-0.38 mean in every direction (sun-only: 0.03-0.35)

## THE SCOUTS of the near wood (founder: "they should all have personality and individual character"). Positions keep a walker on
## Inferno's trail out of every bear's sight (sight x attention, field of view) - stealth is possible; straying, running and
## shooting are not free. `intro_at` = the trail point where Inferno names him.
const SCOUTS: Array = [
	{"name": "Twitch", "role": "brawler", "routine": "patrol", "pos": Vector2(33.0, 50.0),
		"route": [Vector2(33.0, 50.0), Vector2(34.0, 78.0), Vector2(30.0, 100.0)], "sight": 22.0, "fov": 120.0, "eyes": 1.0,
		"ears": 1.6, "react": 0.6, "walk": 1.25, "run": 4.4, "pause": 1.5, "hp": 2, "height": 2.0, "pitch": 1.15,
		"intro": "vo_bull_scout_twitch", "intro_at": 3},
	{"name": "Professor Barnaby", "role": "brawler", "routine": "read", "pos": Vector2(-16.0, 99.0), "face": -1.75,
		"sight": 18.0, "fov": 100.0, "eyes": 0.8, "ears": 0.9, "react": 1.6, "walk": 0.95, "run": 3.4, "hp": 2, "height": 2.3,
		"pitch": 0.9, "intro": "vo_bull_scout_barnaby", "intro_at": 5},
	{"name": "Old Moss", "role": "brawler", "routine": "sleep", "pos": Vector2(15.0, 131.0), "face": 1.2,
		"sight": 20.0, "fov": 110.0, "ears": 1.0, "react": 1.4, "walk": 0.9, "run": 3.2, "hp": 3, "height": 2.5, "pitch": 0.75,
		"intro": "vo_bull_scout_moss", "intro_at": 7},
	{"name": "Mumbles", "role": "brawler", "routine": "roam", "pos": Vector2(-31.0, 160.0), "roam_r": 7.0, "stomp": 0.4,
		"sight": 20.0, "fov": 110.0, "ears": 1.0, "react": 1.0, "walk": 0.85, "run": 3.8, "hp": 2, "height": 2.2, "pitch": 0.85,
		"intro": "vo_bull_scout_mumbles", "intro_at": 9},
	{"name": "Hattie", "role": "archer", "routine": "watch", "pos": Vector2(26.0, 197.0), "face": 0.6, "sweep": 0.6,
		"sight": 34.0, "fov": 100.0, "eyes": 1.4, "ears": 1.1, "react": 0.8, "hp": 1, "arrows": 8, "range": 40.0, "reload": 2.0,
		"height": 2.05, "pitch": 1.1, "intro": "vo_bull_scout_hattie", "intro_at": 11},
	{"name": "Sniffer", "role": "brawler", "routine": "patrol", "pos": Vector2(-31.0, 204.0),
		"route": [Vector2(-31.0, 204.0), Vector2(-35.0, 234.0)], "sight": 20.0, "fov": 110.0, "ears": 1.3, "react": 0.9,
		"walk": 1.0, "run": 4.0, "pause": 3.0, "hp": 2, "height": 2.15, "pitch": 1.0},
]
## THE ROAD PICKETS: `at` = fraction of the ride, `lat` = metres right (+) / left (-) of the road. They wake to the engine.
const ROAD_BEARS: Array = [
	{"name": "Brutus", "role": "brawler", "routine": "road", "at": 0.12, "lat": 7.0, "sight": 26.0, "react": 0.7, "run": 4.6, "hp": 2, "height": 2.4, "pitch": 0.8},
	{"name": "Pip", "role": "archer", "routine": "watch", "at": 0.15, "lat": -16.0, "sweep": 0.5, "sight": 32.0, "eyes": 1.2, "react": 0.9, "hp": 1, "arrows": 6, "range": 38.0, "reload": 2.4, "height": 1.95, "pitch": 1.2},
	{"name": "Fletch", "role": "archer", "routine": "watch", "at": 0.27, "lat": 17.0, "sweep": 0.4, "sight": 34.0, "react": 0.6, "hp": 1, "arrows": 8, "range": 40.0, "reload": 1.7, "height": 2.0, "pitch": 1.1},
	{"name": "Big Tess", "role": "archer", "routine": "road", "at": 0.30, "lat": -19.0, "sight": 34.0, "react": 1.1, "hp": 2, "arrows": 6, "range": 42.0, "reload": 2.8, "height": 2.45, "pitch": 0.85},
	{"name": "Rumble", "role": "brawler", "routine": "sleep", "at": 0.42, "lat": 10.0, "react": 1.2, "run": 4.2, "hp": 2, "height": 2.3, "pitch": 0.8},
	{"name": "Grizz", "role": "brawler", "routine": "read", "at": 0.44, "lat": 12.5, "react": 1.4, "run": 4.4, "hp": 3, "height": 2.4, "pitch": 0.7},
	{"name": "Sarge", "role": "archer", "routine": "watch", "at": 0.56, "lat": -15.0, "sweep": 0.5, "sight": 34.0, "react": 0.7, "hp": 2, "arrows": 8, "range": 40.0, "reload": 2.1, "height": 2.3, "pitch": 0.9},
	{"name": "Biscuit", "role": "brawler", "routine": "roam", "at": 0.58, "lat": 9.0, "roam_r": 5.0, "react": 0.9, "run": 4.8, "hp": 1, "height": 1.9, "pitch": 1.25},
	{"name": "Quill", "role": "archer", "routine": "watch", "at": 0.70, "lat": 16.0, "sweep": 0.6, "sight": 34.0, "react": 0.8, "hp": 1, "arrows": 6, "range": 40.0, "reload": 2.2, "height": 2.0, "pitch": 1.15},
	{"name": "Thorn", "role": "archer", "routine": "watch", "at": 0.72, "lat": -17.0, "sweep": 0.6, "sight": 34.0, "react": 0.8, "hp": 1, "arrows": 6, "range": 40.0, "reload": 2.2, "height": 2.05, "pitch": 1.05},
	{"name": "Moose", "role": "brawler", "routine": "road", "at": 0.74, "lat": 6.5, "react": 0.8, "run": 4.4, "hp": 3, "height": 2.65, "pitch": 0.65},
	{"name": "Gnasher", "role": "brawler", "routine": "road", "at": 0.85, "lat": -6.5, "react": 0.6, "run": 4.8, "hp": 2, "height": 2.3, "pitch": 0.85},
	{"name": "Wren", "role": "archer", "routine": "watch", "at": 0.87, "lat": 19.0, "sweep": 0.5, "sight": 36.0, "react": 0.7, "hp": 1, "arrows": 8, "range": 42.0, "reload": 1.9, "height": 1.95, "pitch": 1.2},
]

# --- the old-growth wood (founder target artifacts/episode2-gold-mine/references/founder_2026-10-10/woods_exterior_target.jpg:
# "it looks like cartoon junk ... the realism edge as a standard ... birds flying randomly and trees moving with the wind";
# skill ep2-set-piece-forge). Kit from tools/ep2_blender/build_forest_kit.py, textures from Muapi stills (fort_knox_refs.json woods_kit).
const FOREST_KIT := "res://src/episode2/assets/woods/forest_kit.glb"
const BARK_TEX := "res://src/episode2/assets/woods/tex_woods_bark.jpg"
const BARK_NORMAL := "res://src/episode2/assets/woods/tex_woods_bark_n.png"     # derived from the bark still (tools: see skill ep2-set-piece-forge)
const FLOOR_TEX := "res://src/episode2/assets/woods/tex_woods_floor.jpg"
const BRANCH_TEX := "res://src/episode2/assets/woods/tex_woods_branch.png"
const FERN_TEX := "res://src/episode2/assets/woods/tex_woods_fern.png"
const ROCK_MODEL := "res://src/episode2/assets/woods/woods_rock.glb"
const BEAR_ARCHER_MODEL := "res://src/episode2/assets/mine_bear_archer.glb"   # founder's Tripo bear archer (static, bow drawn)
const EXIT_KIT_MODEL := "res://src/episode2/assets/mine_lift/mine_lift_kit.glb"
const EXIT_PLANK_TEX := "res://src/episode2/assets/mine_lift/tex_lift_planks.jpg"
const EXIT_IRON_TEX := "res://src/episode2/assets/mine_lift/tex_lift_rust_iron.jpg"
const FOLIAGE_SHADER := "res://src/episode2/art/ep2_foliage_wind.gdshader"
const GIANT_SPACING := 10.5                          # metres between the old-growth giants (the target's trunks are 1-3 m across)
## The wood is built in 60 m slices along the trail and the road (each slice its own MultiMeshes with a draw distance), so a
## 1 km world costs the web build what the old 300 m one did: only the slices near the camera are drawn.
const CHUNK_Z := 60.0
const FOREST_Z0 := -16.0
const FOREST_HALF_W := 70.0                          # the wood runs this far either side of the trail / road
const TREE_CELL := 8.0                               # spatial grid for trunk collision, sight lines and bullets

var _kit_meshes: Dictionary = {}                     # piece name -> Mesh (Trunk, Crown, Fern, Snag)
var _bark_mat: StandardMaterial3D = null
var _crown_mat: ShaderMaterial = null
var _fern_mat: ShaderMaterial = null
var _rock_mesh: Mesh = null
var _wildlife: Ep2Wildlife = null
var _exit_kit: Node3D = null                          # the mine-lift walkway kit, for the mine exit + bridge
## "golden" = golden hour (founder bear stills 2026-10-10b; Jev 0.54 / microsoft-decision-1 0.58 chose it on the closeness table),
## "" = the old-growth daylight of the earlier forest target. Set before setup().
var light_grade: String = "golden"
var _ground_mat: StandardMaterial3D = null
var _leaf_mats: Array = []
var _trees: Array = []                              # [Vector2 position, radius, height] for trunk collision
var _tree_grid: Dictionary = {}                     # Vector2i cell -> Array of the same entries
var _clearings: Array = []                          # [Vector2 a, Vector2 b, radius]: bears' beats (no trunk grows there)
var _quad: Node3D = null
var _quad_wheels: Array = []
var _quad_modelled: bool = false
var _quad_light: SpotLight3D = null
var _cover: Node3D = null
var _cover_bits: Array = []                         # [Node3D, Vector3 outward velocity, float spin, Transform3D rest]
var _reveal_t: float = -1.0
var _riding: bool = false
var _ride_pts: PackedVector3Array = PackedVector3Array()
var _ride_len: PackedFloat32Array = PackedFloat32Array()
var _ride_s: float = 0.0
var _ride_total: float = 0.0
var _ride_speed: float = 0.0
var _ride_done: bool = false
var _quad_yaw: float = 0.0
var _engine: AudioStreamPlayer = null
var _sneak_i: int = 0
var _bull_waiting: bool = false
var _bull_chat_cd: float = 14.0                      # seconds before Inferno may say another unprompted line (long + random: no nagging)
var _bull_wait_t: float = 0.0                        # how long he has stood looking back this time
var _bull_wait_lock: float = 0.0                     # after a wait he strolls on for a while before he will wait again
var _bull_pace: float = 0.0
var _line_idx: Dictionary = {}                       # pool key -> next line (rotates, never the same one twice running)
var _sneak_arc: PackedFloat32Array = PackedFloat32Array()
var _cart: Node3D = null                             # the farmer on his donkey cart (founder model), plodding down the desert road
var _cart_s: float = CART_S0
var _cart_warned: bool = false
var _cart_state: int = 0                             # 0 ahead, 1 approached (slowing), 2 greeted, 3 passed
var _bull_ride_cd: float = 0.0
var _bull_ride_shots: int = 0
var _warn_cd: float = 0.0
var _stay_cd: float = 0.0
var _bark_cd: float = 0.0
var _noise_hits: int = 0
var _quad_yaw_prev: float = 0.0
var _desert_k: float = -1.0                          # 0 woods light .. 1 gold-rush desert light (by the quad's z)
var _town_col: Dictionary = {}                        # Ep2GoldTown walls / props for walking in the street
var _rideoff: Dictionary = {}                         # Bull riding away down the street after the drop-off
var _dropoff_done: bool = false

# --- the living wood -----------------------------------------------------------------------------------------------
var _bears_root: Node3D = null
var _bears: Array = []                              # Ep2BearBrain (every bear: scouts, road pickets, camp)
var _specs: Array = []                              # resolved spawn specs (positions, faces, group)
var _spawned: int = 0
var _sense_acc: float = 0.0
var _engine_acc: float = 0.0
var _step_acc: float = 0.0
var _intro_done: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _health: int = HEALTH_MAX
var _invuln: float = 0.0
var _failing: bool = false
var _fail_t: float = 0.0
var _retry_line_pending: bool = false
var _attempt: int = 0
var _ammo_snapshot: Array = []
var _armory_snapshot: Dictionary = {}
var _player_vel: Vector3 = Vector3.ZERO
var _prev_player: Vector3 = Vector3.ZERO
var _player_arrows: Array = []
var _arrows: Array = []                             # Dictionary per arrow in flight / stuck
var _arrows_loosed: int = 0
var _arrow_hits: int = 0
var _kills: int = 0
var _alerts: int = 0
var _bull_alarm: bool = false
var _bull_calm_t: float = 0.0
var _bull_fire_cd: float = 0.0
var _bull_shots: int = 0
var _flashes: Array = []                            # [Node3D, seconds left]
var _glide: Dictionary = {}                          # the player's eye moving onto / off the quad
var _bull_swing: Dictionary = {}                     # Inferno swinging onto / off the saddle
var _road_lines: Dictionary = {}
var _sounds: Dictionary = {}
## Tests only: a run through the whole chamber that must not end on the way (the fight itself is tested separately).
var debug_invulnerable: bool = false


func _init() -> void:
	title_card = "THE BEAR WOODS"
	music_path = ""                                  # the lift's song carries on until the quad starts (Deep Mining 3 begins at MOUNT)
	walk_speed = 2.3                                 # a sneak: walking IS the stealth
	viewmodel_exposure = 0.82                        # open daylight: the rifle's metal would read cream
	camera_min = Vector3(-200.0, 0.4, -30.0)
	camera_max = Vector3(200.0, 60.0, 1120.0)


func _chamber_id() -> String:
	return "woods_quad"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- the set ----------------------------------------------------------------------------------------------------------

func _build_room() -> void:
	for step in _build_steps():
		(step as Callable).call()


## The wood in slices (each a few ms), so it can be built behind the mine lift while the cage is still rising (no blackout at
## the surface): the road first (the wood keeps clear of it), then 60 m slices of forest, the set pieces, and the bears a few at a time.
func _build_steps() -> Array:
	var steps: Array = [_step_light_mats, _load_forest_kit, _step_ground, _build_ride_path, _resolve_specs, _build_trails]
	for i in _forest_chunk_count():
		steps.append(Callable(self, "_build_forest_chunk").bind(i))
	steps.append_array([_build_sun_shafts, _build_mine_hut, _build_quad, _build_cover, _build_desert, _build_town, _build_cart])
	var n: int = SCOUTS.size() + ROAD_BEARS.size()
	for k in int(ceil(float(n) / 3.0)):
		steps.append(Callable(self, "_spawn_batch").bind(k, 3))
	steps.append(_step_bull)
	return steps


## The first views of the wood (the adit mouth, both sides, up into the canopy, down the trail, the first scout) for the GPU warm-up.
func _warm_views() -> Array:
	var eye: Vector3 = SPAWN + Vector3(0.0, 1.55, 0.0)
	var to_scout: Vector3 = Vector3(33.0, 1.2, 55.0) - (eye + Vector3(0.0, 0.0, 14.0))
	return [{"eye": eye, "yaw": 0.0, "pitch": -0.04}, {"eye": eye, "yaw": 0.8, "pitch": -0.05}, {"eye": eye, "yaw": -0.8, "pitch": -0.05},
		{"eye": eye, "yaw": 0.0, "pitch": 0.5}, {"eye": eye + Vector3(0.0, 0.0, 14.0), "yaw": 0.0, "pitch": -0.1},
		{"eye": eye + Vector3(0.0, 0.0, 14.0), "yaw": atan2(to_scout.x, to_scout.z), "pitch": -0.05}]


func _step_bull() -> void:
	if _bull == null:      # Inferno is built (and his shaders warmed) in the background too, not at the cut
		_bull = _build_bull(BULL_START, 0.0)


func _step_light_mats() -> void:
	_apply_light()
	_leaf_mats = [_plain(Color(0.13, 0.31, 0.12), 0.95), _plain(Color(0.19, 0.39, 0.14), 0.95), _plain(Color(0.10, 0.25, 0.10), 0.95),
		_plain(Color(0.27, 0.42, 0.12), 0.95)]


func _step_ground() -> void:
	# the forest floor: moss, needles and twigs (Muapi seamless still), world-tiled every 3.5 m - now under a 1 km wood
	_ground_mat = _tex(FLOOR_TEX, Color(0.82, 0.84, 0.76), 0.28) if ResourceLoader.exists(FLOOR_TEX) else _tex(GRAVEL_TEX, Color(0.38, 0.42, 0.25), 0.35)
	_ground_mat.uv1_world_triplanar = true
	_ground_mat.roughness = 0.95
	var z1: float = FOREST_END_Z + 30.0
	_box(Vector3(440.0, 0.5, z1 + 30.0), Vector3(0.0, -0.25, (z1 - 30.0) * 0.5), _ground_mat)
	# the desert floor from the last pines to beyond the town (a hair lower: the forest floor wins where they overlap)
	var dg := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, WORLD_END_Z - FOREST_END_Z + 520.0)
	dg.mesh = pm
	dg.material_override = Ep2GoldTown.desert_ground_mat()
	dg.position = Vector3(0.0, -0.012, (FOREST_END_Z - 80.0 + WORLD_END_Z + 440.0) * 0.5)
	dg.name = "DesertFloor"
	_visuals.add_child(dg)


## Old-growth daylight (founder target): a bright, pale sky glowing through the canopy, cool green-grey air between the trunks
## (fog = depth), a warm high sun breaking through in shafts and dapples, deep but readable shade on the floor.
func _apply_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.56, 0.68, 0.80)
	psm.sky_horizon_color = Color(0.62, 0.68, 0.60)
	psm.sky_energy_multiplier = 1.6
	psm.ground_horizon_color = Color(0.34, 0.38, 0.30)
	psm.ground_bottom_color = Color(0.14, 0.16, 0.12)
	psm.sun_angle_max = 18.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.54, 0.57, 0.50)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.56, 0.58, 0.54)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0095                     # a touch denser than the 300 m wood: the far slices fade before they are culled
	env.fog_sky_affect = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.18
	_env_node.environment = env
	_sun.rotation_degrees = Vector3(-58.0, -25.0, 0.0)
	_sun.light_color = Color(1.0, 0.90, 0.74)
	_sun.light_energy = 1.7
	if light_grade == "golden":
		# GOLDEN HOUR (founder bear stills founder_2026-10-10b/bear_scene_*.jpg): a low warm sun behind the trees, amber haze,
		# deep cool-green shade - the light the bears are seen in
		psm.sky_top_color = Color(0.46, 0.52, 0.62)
		psm.sky_horizon_color = Color(0.92, 0.80, 0.62)
		psm.ground_horizon_color = Color(0.40, 0.32, 0.22)
		env.fog_light_color = Color(0.60, 0.58, 0.48)
		env.fog_sun_scatter = 0.35
		env.ambient_light_color = Color(0.50, 0.52, 0.46)
		env.ambient_light_energy = 0.55
		env.adjustment_saturation = 1.0
		env.adjustment_contrast = 1.22
		_sun.rotation_degrees = Vector3(-14.0, 160.0, 0.0)          # low, from ahead of the player's walk (+z): backlight
		_sun.light_color = Color(1.0, 0.82, 0.62)
		_sun.light_energy = 2.0
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


## The trodden trail and the logging road as two smooth ribbons (one mesh each) - the same needle-and-moss floor, darker and
## browner (a grey gravel slab read as concrete in the old-growth wood). The road follows the quad's own curve exactly.
func _build_trails() -> void:
	var dirt: StandardMaterial3D = _tex(FLOOR_TEX, Color(0.58, 0.46, 0.36), 0.45) if ResourceLoader.exists(FLOOR_TEX) else _tex(GRAVEL_TEX, Color(0.34, 0.27, 0.20), 0.5)
	dirt.uv1_world_triplanar = true
	var road: StandardMaterial3D = _tex(FLOOR_TEX, Color(0.50, 0.40, 0.31), 0.4) if ResourceLoader.exists(FLOOR_TEX) else _tex(GRAVEL_TEX, Color(0.32, 0.26, 0.20), 0.5)
	road.uv1_world_triplanar = true
	var trail_mi := _ribbon(_smooth(SNEAK_TRAIL, 1.5), 2.2, dirt, 0.021)
	trail_mi.name = "SneakTrail"
	var road_mi := _ribbon(_ride_pts, 4.6, road, 0.02)
	road_mi.name = "LoggingRoad"
	var spawn_pad := _box(Vector3(6.0, 0.04, 6.0), Vector3(0.0, 0.02, 2.0), dirt)
	spawn_pad.name = "LiftPad"


## Catmull-Rom through `pts` (Vector2 x,z), resampled every ~`step` metres.
func _smooth(pts: Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n: int = pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		var steps: int = maxi(4, int(p1.distance_to(p2) / step))
		for k in steps:
			var t: float = float(k) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			out.append(Vector3(q.x, 0.0, q.y))
	var last: Vector2 = pts[n - 1]
	out.append(Vector3(last.x, 0.0, last.y))
	return out


## A flat strip `width` wide along `pts`, `y` above the ground: one ArrayMesh, world-triplanar material.
func _ribbon(pts: PackedVector3Array, width: float, mat: Material, y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = pts.size()
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var t: Vector3 = b - a
		t.y = 0.0
		t = t.normalized() if t.length() > 0.001 else Vector3.FORWARD
		var side := Vector3(t.z, 0.0, -t.x) * (width * 0.5)
		left.append(pts[i] - side + Vector3(0.0, y, 0.0))
		right.append(pts[i] + side + Vector3(0.0, y, 0.0))
	for i in n - 1:
		for v in [left[i], right[i], left[i + 1], right[i], right[i + 1], left[i + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(mi)
	return mi


func _distance_to_trails(p: Vector2) -> float:
	return _dist_segs(p, _segs_near(-1e9, 1e9, 0.0))


## The trail / road segments whose z-range comes within `margin` of [z0, z1] (a forest slice only tests its own few).
func _segs_near(z0: float, z1: float, margin: float) -> Array:
	var out: Array = []
	for tr in [SNEAK_TRAIL, RIDE_TRAIL]:
		for i in range(tr.size() - 1):
			var a: Vector2 = tr[i]
			var b: Vector2 = tr[i + 1]
			if maxf(a.y, b.y) >= z0 - margin and minf(a.y, b.y) <= z1 + margin:
				out.append([a, b])
	return out


func _dist_segs(p: Vector2, segs: Array) -> float:
	var best: float = 1e9
	for sg in segs:
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## The kit pieces as meshes, and the shared materials: world-triplanar bark (a 40 m trunk never stretches its bark), and the
## wind shader on the alpha-cut fir branch and fern cards.
func _load_forest_kit() -> void:
	if ResourceLoader.exists(FOREST_KIT):
		var root: Node = (load(FOREST_KIT) as PackedScene).instantiate()
		for piece in ["Trunk", "Crown", "Fern", "Snag"]:
			var mi: MeshInstance3D = root.find_child(piece, true, false) as MeshInstance3D
			if mi != null and mi.mesh != null:
				_kit_meshes[piece] = mi.mesh
		root.free()
	if ResourceLoader.exists(ROCK_MODEL):
		var rroot: Node = (load(ROCK_MODEL) as PackedScene).instantiate()
		for n in rroot.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).mesh != null:
				_rock_mesh = (n as MeshInstance3D).mesh
				break
		rroot.free()
	_bark_mat = StandardMaterial3D.new()
	_bark_mat.albedo_color = Color(0.78, 0.66, 0.60)
	_bark_mat.roughness = 0.95
	if ResourceLoader.exists(BARK_TEX):
		_bark_mat.albedo_texture = load(BARK_TEX)
		_bark_mat.uv1_triplanar = true
		_bark_mat.uv1_world_triplanar = true
		_bark_mat.uv1_scale = Vector3(0.42, 0.36, 0.42)          # ~2.4 m round, ~2.8 m tall per tile (0.22 stretched it into stripes - Astra pass 1)
	if ResourceLoader.exists(BARK_NORMAL):
		_bark_mat.normal_enabled = true
		_bark_mat.normal_texture = load(BARK_NORMAL)                 # bark relief (decision models' top pick, 2026-10-10: "trunks")
		_bark_mat.normal_scale = 1.4
	_crown_mat = _foliage_mat(BRANCH_TEX, Color(1.05, 1.15, 0.98), 0.55, 1.0, 40.0, 0.05)
	_fern_mat = _foliage_mat(FERN_TEX, Color(0.85, 0.95, 0.80), 0.06, 1.6, 1.0, 0.015)


func _foliage_mat(tex: String, tint: Color, sway: float, speed: float, bend_h: float, flutter: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(FOLIAGE_SHADER)
	if ResourceLoader.exists(tex):
		m.set_shader_parameter("albedo_tex", load(tex))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("bend_height", bend_h)
	m.set_shader_parameter("flutter", flutter)
	return m


## True when nothing may grow at p: the trails (with a margin), the spy sight-line, the bear camp, the quad's hiding place, the lift
## mouth, and (for trunks) the bears' beats - a bear on his patrol never walks through a tree.
func _forest_blocked(p: Vector2, margin: float, trees: bool = true, segs: Array = []) -> bool:
	var sg: Array = segs if not segs.is_empty() else _segs_near(p.y, p.y, margin + 40.0)
	if _dist_segs(p, sg) < margin:
		return true
	if p.distance_to(Vector2(QUAD_POS.x, QUAD_POS.z)) < 6.0 or p.y > FOREST_END_Z:
		return true
	if trees:
		if absf(p.x) < 7.0 and p.y < 8.0 and p.y > -14.0:
			return true
		for c in _clearings:
			var a: Vector2 = c[0]
			var ab: Vector2 = (c[1] as Vector2) - a
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(c[2]):
				return true
	return false


func _hash01(x: float, z: float, k: float) -> float:
	var h: float = sin(x * 12.9898 * k + z * 78.233) * 43758.5453
	return h - floor(h)


func _forest_chunk_count() -> int:
	return int(ceil((FOREST_END_Z + 10.0 - FOREST_Z0) / CHUNK_Z))


## The x-span of slice [z0, z1): FOREST_HALF_W either side of every trail / road point near it (the camp too at the far end).
func _chunk_x_span(z0: float, z1: float) -> Vector2:
	var lo: float = 1e9
	var hi: float = -1e9
	for tr in [SNEAK_TRAIL, RIDE_TRAIL]:
		for pt in tr:
			var v: Vector2 = pt
			if v.y >= z0 - 45.0 and v.y <= z1 + 45.0:
				lo = minf(lo, v.x)
				hi = maxf(hi, v.x)
	if lo > hi:
		lo = 0.0
		hi = 0.0
	return Vector2(lo - FOREST_HALF_W, hi + FOREST_HALF_W)


## THE OLD-GROWTH WOOD (founder target), one 60 m slice: giant conifers 34-48 m tall and 1.4-2.8 m across with root flares and real
## bark, their crowns of drooping fir-branch cards high overhead swaying in the wind; young firs between them; a fern understorey;
## fallen snags and mossy rocks on a needle-and-moss floor. Every layer of a slice is one MultiMesh with a draw distance.
## The grids are global (anchored at the old origins), so the wood by the mine is the one the founder approved.
func _build_forest_chunk(ci: int) -> void:
	if not _kit_meshes.has("Trunk") or not _kit_meshes.has("Crown"):
		if ci == 0:
			_build_forest_primitive()
		return
	var z0: float = FOREST_Z0 + float(ci) * CHUNK_Z
	var z1: float = z0 + CHUNK_Z
	var span: Vector2 = _chunk_x_span(z0, z1)
	var segs: Array = _segs_near(z0, z1, 40.0)
	var xf_trunk: Array = []
	var xf_crown: Array = []
	var xf_fern: Array = []
	var xf_snag: Array = []
	var rocks: Array = []
	# 1) the giants, on a jittered grid
	var gx: float = -72.0 + ceil((span.x + 72.0) / GIANT_SPACING) * GIANT_SPACING
	while gx <= span.y:
		var gz: float = -16.0 + ceil((z0 + 16.0) / GIANT_SPACING) * GIANT_SPACING
		while gz < z1:
			var r1: float = _hash01(gx, gz, 1.0)
			var r2: float = _hash01(gz, gx, 2.7)
			var p := Vector2(gx + (r1 - 0.5) * 7.0, gz + (r2 - 0.5) * 7.0)
			var rad: float = 0.7 + 0.7 * r2
			if not _forest_blocked(p, 3.4 + rad * 1.4, true, segs):
				var h: float = 34.0 + 14.0 * r1
				var yaw: float = r1 * TAU
				xf_trunk.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(rad, h, rad)), Vector3(p.x, -0.15, p.y)))
				var cs: float = h / 40.0
				xf_crown.append(Transform3D(Basis(Vector3.UP, yaw + 1.3) * Basis.from_scale(Vector3.ONE * cs), Vector3(p.x, 0.0, p.y)))
				_add_tree(p, rad * 1.25 + 0.25, h)
			gz += GIANT_SPACING
		gx += GIANT_SPACING
	# 2) young firs in the gaps (6-14 m: their crowns come down to eye level and give the mid-ground its green)
	gx = -66.0 + ceil((span.x + 66.0) / 7.0) * 7.0
	while gx <= span.y:
		var gz2: float = -10.0 + ceil((z0 + 10.0) / 7.0) * 7.0
		while gz2 < z1:
			var q1: float = _hash01(gx, gz2, 3.3)
			var q2: float = _hash01(gz2, gx, 5.1)
			var p2 := Vector2(gx + (q1 - 0.5) * 9.0, gz2 + (q2 - 0.5) * 9.0)
			if q1 < 0.30 and not _forest_blocked(p2, 7.0, true, segs):
				var h2: float = 6.0 + 8.0 * q2
				var rad2: float = 0.10 + 0.012 * h2
				xf_trunk.append(Transform3D(Basis.from_scale(Vector3(rad2, h2 * 0.97, rad2)), Vector3(p2.x, 0.0, p2.y)))
				# the crown model starts its branches at 15/40 of its height: sink it so the young tree's branches start ~1 m up
				var cs2: float = h2 / 40.0 * 1.55
				xf_crown.append(Transform3D(Basis(Vector3.UP, q2 * TAU) * Basis.from_scale(Vector3.ONE * cs2), Vector3(p2.x, h2 - 40.5 * cs2, p2.y)))
				_add_tree(p2, 0.45, h2)
			gz2 += 7.0
		gx += 7.0
	# 3) the fern understorey and the forest-floor clutter (snags, rocks) - thick along the trail, thinning into the deep wood
	var fx: float = -60.0 + ceil((span.x + 60.0) / 2.6) * 2.6
	while fx <= span.y:
		var fz: float = -12.0 + ceil((z0 + 12.0) / 2.6) * 2.6
		while fz < z1:
			var f1: float = _hash01(fx, fz, 7.7)
			var f2: float = _hash01(fz, fx, 9.1)
			var p3 := Vector2(fx + (f1 - 0.5) * 3.2, fz + (f2 - 0.5) * 3.2)
			var near_trail: float = _dist_segs(p3, segs)
			if near_trail < 58.0:
				var keep: float = (0.72 + 0.25 * clampf((near_trail - 2.0) / 6.0, 0.0, 1.0)) * (1.0 if near_trail < 30.0 else 0.5)
				if near_trail > 1.5 and f1 < keep and not _forest_blocked(p3, 1.5, false, segs) and p3.distance_to(Vector2(SPAWN.x, SPAWN.z)) > 2.5:
					var s: float = 0.7 + 0.9 * f2
					xf_fern.append(Transform3D(Basis(Vector3.UP, f1 * TAU) * Basis.from_scale(Vector3(s, s * (0.8 + 0.4 * f1), s)), Vector3(p3.x, -0.05, p3.y)))
				if f2 > 0.985 and near_trail > 4.0 and not _forest_blocked(p3, 4.0, true, segs):
					xf_snag.append(Transform3D(Basis(Vector3.UP, f1 * TAU) * Basis.from_scale(Vector3(0.8 + f1, 0.9 + 0.4 * f2, 0.9 + 0.4 * f2)), Vector3(p3.x, -0.12, p3.y)))
				elif f2 < 0.03 and near_trail > 2.4 and not _forest_blocked(p3, 2.4, true, segs):
					rocks.append(Transform3D(Basis(Vector3.UP, f1 * TAU) * Basis.from_scale(Vector3.ONE * (0.5 + 1.2 * f1)), Vector3(p3.x, -0.1, p3.y)))
			fz += 2.6
		fx += 2.6
	var mm_t := _multi(_kit_meshes["Trunk"], xf_trunk, _bark_mat, 240.0)
	var mm_c := _multi(_kit_meshes["Crown"], xf_crown, _crown_mat, 240.0)
	if _kit_meshes.has("Fern"):
		var mm_f := _multi(_kit_meshes["Fern"], xf_fern, _fern_mat, 120.0)
		if mm_f != null:
			mm_f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mm_f.name = "ForestFerns_%d" % ci
	if _kit_meshes.has("Snag"):
		_multi(_kit_meshes["Snag"], xf_snag, _bark_mat, 130.0)
	_scatter_rocks(rocks)
	if mm_t != null:
		mm_t.name = "ForestTrunks_%d" % ci
	if mm_c != null:
		mm_c.name = "ForestCrowns_%d" % ci


## One trunk for collision, sight lines and bullets (and its grid cell).
func _add_tree(p: Vector2, r: float, h: float) -> void:
	var e: Array = [p, r, h]
	_trees.append(e)
	var c := Vector2i(int(floor(p.x / TREE_CELL)), int(floor(p.y / TREE_CELL)))
	if not _tree_grid.has(c):
		_tree_grid[c] = []
	(_tree_grid[c] as Array).append(e)


## Trunks in the cells around p (radius in cells).
func _trees_near(p: Vector2, cells: int = 1) -> Array:
	var out: Array = []
	var c := Vector2i(int(floor(p.x / TREE_CELL)), int(floor(p.y / TREE_CELL)))
	for dx in range(-cells, cells + 1):
		for dz in range(-cells, cells + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _tree_grid.has(k):
				out.append_array(_tree_grid[k])
	return out


## Is the straight line a -> b (ground plane) through a trunk? Sight lines (a bear seeing Lil Blunt) and arrows use it.
func _los_blocked(a: Vector2, b: Vector2) -> bool:
	var d: float = a.distance_to(b)
	if d < 0.5:
		return false
	var seen: Dictionary = {}
	var n: int = int(ceil(d / (TREE_CELL * 0.5)))
	for i in n + 1:
		var q: Vector2 = a.lerp(b, float(i) / float(maxi(n, 1)))
		var c := Vector2i(int(floor(q.x / TREE_CELL)), int(floor(q.y / TREE_CELL)))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k := Vector2i(c.x + dx, c.y + dz)
				if seen.has(k) or not _tree_grid.has(k):
					continue
				seen[k] = true
				for e in _tree_grid[k]:
					var tp: Vector2 = e[0]
					var r: float = float(e[1]) * 0.75
					if tp.distance_to(a) < r + 0.3 or tp.distance_to(b) < r + 0.3:
						continue
					var ab: Vector2 = b - a
					var t: float = clampf((tp - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					if tp.distance_to(a + ab * t) < r:
						return true
	return false


## Mossy boulders: the Tripo rock when it is in the pack, else a squashed low sphere in the floor material.
func _scatter_rocks(xforms: Array) -> void:
	if xforms.is_empty():
		return
	if _rock_mesh != null:
		var mm := _multi(_rock_mesh, xforms, null, 130.0)
		if mm != null:
			mm.material_override = null
		return
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 0.9
	sm.radial_segments = 9
	sm.rings = 5
	var rock_mat: StandardMaterial3D = _tex(FLOOR_TEX, Color(0.62, 0.66, 0.55), 0.6)
	_multi(sm, xforms, rock_mat, 130.0)


## Light through the canopy: tall additive shafts, leaning with the sun, faded at both ends (the target's god rays), along the trail
## and the first stretch of the road. Unshaded, no depth write - in the Compatibility renderer there is no volumetric fog for this.
func _build_sun_shafts() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 1))
	grad.add_point(0.7, Color(1, 1, 1, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = gt
	m.albedo_color = Color(1.0, 0.93, 0.78, 0.045)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var qm := QuadMesh.new()
	qm.size = Vector2(2.6, 30.0)
	var xfs: Array = []
	var i: int = 0
	for tr in [_smooth(SNEAK_TRAIL, 4.5), _ride_pts]:
		var pts: PackedVector3Array = tr
		var stride: int = 1 if pts == _ride_pts else 1
		var acc: float = 0.0
		for k in range(1, pts.size(), stride):
			acc += pts[k].distance_to(pts[k - 1])
			if acc < 4.5:
				continue
			acc = 0.0
			i += 1
			var r: float = _hash01(float(i), pts[k].z, 4.4)
			var p := Vector2(pts[k].x + (r - 0.5) * 34.0, pts[k].z + r * 6.0)
			if p.y < FOREST_END_Z - 40.0:
				xfs.append(Transform3D(Basis.from_scale(Vector3(0.6 + 1.4 * r, 1.0, 1.0)), Vector3(p.x, 13.0, p.y)))
	var mm := _multi(qm, xfs, m, 0.0)
	if mm != null:
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm.name = "SunShafts"


## The old primitive wood (cylinders and cones): kept only as the fallback if the forest kit is missing.
func _build_forest_primitive() -> void:
	var bark: StandardMaterial3D = _plain(Color(0.26, 0.18, 0.12), 0.95)
	var xf_trunk: Array = []
	var xf_low: Array = []
	var gx: float = -70.0
	while gx <= 70.0:
		var gz: float = -14.0
		while gz <= 236.0:
			var r1: float = _hash01(gx, gz, 1.0)
			var r2: float = _hash01(gz, gx, 2.7)
			var p := Vector2(gx + (r1 - 0.5) * 6.0, gz + (r2 - 0.5) * 6.0)
			if not _forest_blocked(p, 4.2):
				var h: float = 8.0 + 6.0 * r1
				var rad: float = 0.34 + 0.2 * r2
				xf_trunk.append(Transform3D(Basis.from_scale(Vector3(rad, h, rad)), Vector3(p.x, h * 0.5, p.y)))
				var cr: float = 2.6 + 1.4 * r2
				xf_low.append(Transform3D(Basis.from_scale(Vector3(cr, 6.0, cr)), Vector3(p.x, h * 0.62 + 1.8, p.y)))
				_add_tree(p, rad + 0.25, h)
			gz += 7.5
		gx += 7.5
	_multi(_cyl_mesh(1.0, 1.0, 1.0, 6), xf_trunk, bark, 0.0)
	_multi(_cyl_mesh(0.0, 1.0, 1.0, 8), xf_low, _leaf_mats[0], 0.0)


func _cyl_mesh(rt: float, rb: float, h: float, sides: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = sides
	return cm


## One MultiMesh layer; `draw_dist` > 0 culls the whole slice beyond that distance (the fog has swallowed it by then).
func _multi(mesh: Mesh, xforms: Array, mat: Material, draw_dist: float = 0.0) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if draw_dist > 0.0:
		mmi.visibility_range_end = draw_dist
		mmi.visibility_range_end_margin = 12.0
	_visuals.add_child(mmi)
	return mmi


## The mine's surface mouth behind the spawn: a rocky mound with a plank door - the lift they just came up.
func _build_mine_hut() -> void:
	# THE MINE EXIT (founder reference founder_2026-10-10b/exiting_outside_mine_bull.jpg, "Head out into the woods"): Lil Blunt
	# starts INSIDE a timbered adit and looks out through its frame onto a plank bridge with rope rails that runs into the
	# old-growth wood, Inferno waiting on the boards. Built from the mine-lift walkway kit (tools/ep2_blender/build_lift_kit.py)
	# so the lift's top walkway and this exit are the same carpentry.
	var rock: StandardMaterial3D = _tex(ROCK_TEX, Color(0.40, 0.36, 0.31), 0.22)
	var timber: StandardMaterial3D = _tex(TIMBER_TEX, Color(0.56, 0.42, 0.30), 0.6)
	_box(Vector3(14.0, 7.0, 6.0), Vector3(0.0, 3.5, -9.0), rock)
	for sx in [-1.0, 1.0]:
		_box(Vector3(7.0, 6.0, 8.6), Vector3(sx * 5.6, 3.0, -1.7), rock)          # the hillside either side of the adit
	_box(Vector3(4.6, 3.0, 8.6), Vector3(0.0, 4.9, -1.7), rock)                    # over the adit roof
	if _kit_part("Deck2m") == null:
		_box(Vector3(3.4, 3.6, 0.5), Vector3(0.0, 1.8, -5.9), timber)
		_lantern(Vector3(-2.6, 3.0, -5.3), 2.6, 9.0)
		return
	# the adit: plank floor, timber-lined walls, sets of posts + cap beams every 2 m, the last set framing the mouth
	for i in 4:
		var z: float = -4.0 + float(i) * 2.0
		_kit_part("Deck2m", Vector3(0.0, 0.06, z + 1.0), Vector3.ZERO, Vector3(1.4, 1.0, 1.0))
		for sx in [-1.0, 1.0]:
			_box(Vector3(0.12, 3.3, 2.0), Vector3(sx * 1.78, 1.65, z + 1.0), timber)       # wall planking
			_kit_part("Beam4m", Vector3(sx * 1.62, 1.6, z + 2.0), Vector3(0.0, 0.0, PI * 0.5), Vector3(0.8, 1.15, 1.15))
		_kit_part("Beam4m", Vector3(0.0, 3.28, z + 2.0), Vector3.ZERO, Vector3(0.9, 1.2, 1.2))
	_box(Vector3(3.7, 0.14, 8.0), Vector3(0.0, 3.5, -1.0), timber)                     # lagging over the sets
	# the portal braces (the diagonal knee braces of the reference)
	for sx in [-1.0, 1.0]:
		_kit_part("Beam4m", Vector3(sx * 1.18, 2.95, 4.0), Vector3(0.0, 0.0, sx * 0.78), Vector3(0.24, 0.8, 0.8))
	_lantern(Vector3(-1.45, 2.5, 0.5), 2.2, 8.0)
	# the plank bridge out into the wood: 2 m sections with posts, a timber hand rail and a sagging rope rail each side
	for i in 6:
		var z2: float = 5.0 + float(i) * 2.0
		_kit_part("Deck2m", Vector3(0.0, 0.07, z2), Vector3.ZERO, Vector3(0.95, 1.0, 1.0))
		for sx in [-1.0, 1.0]:
			_kit_part("Post", Vector3(sx * 1.12, 0.0, z2 - 1.0))
			_kit_part("Rail2m", Vector3(sx * 1.12, 0.0, z2 - 1.0))
			_kit_part("Chain2m", Vector3(sx * 1.12, -0.42, z2 - 1.0))
	for sx in [-1.0, 1.0]:
		_kit_part("Post", Vector3(sx * 1.12, 0.0, 16.0))
	# the adit walls are solid (trunk-style collision circles along both sides)
	for zi in 11:
		for sx in [-1.0, 1.0]:
			_add_tree(Vector2(sx * 2.25, -4.0 + float(zi) * 0.8), 0.55, 3.5)


## One piece of the mine-lift walkway kit, with the lift's own triplanar plank / timber / rusted-iron materials (local scale).
func _kit_part(piece: String, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Node3D:
	if _exit_kit == null:
		if not ResourceLoader.exists(EXIT_KIT_MODEL):
			return null
		_exit_kit = (load(EXIT_KIT_MODEL) as PackedScene).instantiate() as Node3D
		var mats: Dictionary = {
			"Planks": _kit_tex(EXIT_PLANK_TEX, Color(0.90, 0.84, 0.76), 0.77),
			"Timber": _kit_tex(EXIT_PLANK_TEX, Color(0.60, 0.48, 0.38), 1.4),
			"RustIron": _kit_tex(EXIT_IRON_TEX, Color(0.95, 0.85, 0.80), 2.2),
		}
		(mats["RustIron"] as StandardMaterial3D).metallic = 0.35
		for mi in _exit_kit.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for si in m.mesh.get_surface_count():
				var src: Material = m.mesh.surface_get_material(si)
				var key: String = String(src.resource_name) if src != null else ""
				if mats.has(key):
					m.mesh.surface_set_material(si, mats[key])
	if pos == Vector3.ZERO and rot == Vector3.ZERO and scl == Vector3.ONE:
		return _exit_kit                                    # probe call: "is the kit there?"
	var src_node: Node3D = _exit_kit.find_child(piece, true, false) as Node3D
	if src_node == null:
		return null
	var n: Node3D = src_node.duplicate() as Node3D
	n.transform = Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)      # LOCAL scale (skill ep2-set-piece-forge)
	_visuals.add_child(n)
	return n


func _kit_tex(path: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = _tex(path, tint, uv_scale)
	m.roughness = 0.86
	return m


# --- Inferno's quad, and the leaves that hide it ---------------------------------------------------------------------------

func _build_quad() -> void:
	_quad = Node3D.new()
	_quad.name = "FlameQuad"
	_quad.position = QUAD_POS
	_quad.rotation.y = QUAD_YAW
	_quad_yaw = QUAD_YAW
	_visuals.add_child(_quad)
	var model: Node3D = null
	if ResourceLoader.exists(QUAD_MODEL):
		model = (load(QUAD_MODEL) as PackedScene).instantiate() as Node3D
	if model != null:
		model.name = "QuadModel"
		_quad.add_child(model)
		_quad_modelled = true
		for wn in model.find_children("Wheel_*", "Node3D", true, false):
			if String(wn.name).count("_") == 1:                     # Wheel_FL ... Wheel_RR, not their rims / nuts
				_quad_wheels.append(wn)
		_quad_light = SpotLight3D.new()
		_quad_light.light_color = Color(1.0, 0.92, 0.75)
		_quad_light.light_energy = 0.0
		_quad_light.spot_range = 28.0
		_quad_light.spot_angle = 30.0
		_quad_light.position = Vector3(0.0, 1.15, 1.62)
		_quad_light.rotation = Vector3(0.0, PI, 0.0)
		_quad.add_child(_quad_light)
		return
	_build_box_quad()


## Fallback when the model is missing from the build: the original boxes (candy red, flame tongues, chrome, headlight).
func _build_box_quad() -> void:
	var paint: StandardMaterial3D = _plain(Color(0.45, 0.04, 0.03), 0.25, 0.35)       # deep candy red
	var black: StandardMaterial3D = _plain(Color(0.05, 0.05, 0.06), 0.6, 0.2)
	var chrome: StandardMaterial3D = _plain(Color(0.72, 0.70, 0.66), 0.3, 0.6)
	var rubber: StandardMaterial3D = _plain(Color(0.05, 0.05, 0.055), 0.9)
	var flame_a: StandardMaterial3D = _glow(Color(1.0, 0.42, 0.04), 1.0)
	var flame_b: StandardMaterial3D = _glow(Color(1.0, 0.78, 0.12), 1.2)
	var flame_c: StandardMaterial3D = _glow(Color(1.0, 0.95, 0.55), 1.4)
	var s: float = 1.7                                # big enough to carry a 2.9 m bull
	_box(Vector3(1.0, 0.45, 2.0) * s, Vector3(0.0, 0.85 * s, 0.0), paint, _quad)                    # body
	_box(Vector3(0.9, 0.3, 0.9) * s, Vector3(0.0, 1.12 * s, 0.55 * s), paint, _quad)                 # tank / nose cover
	_box(Vector3(0.8, 0.14, 1.0) * s, Vector3(0.0, 1.17 * s, -0.5 * s), black, _quad)                # seat
	_box(Vector3(0.7, 0.1, 0.55) * s, Vector3(0.0, 1.14 * s, -1.0 * s), black, _quad)                # rear seat / rack
	_box(Vector3(1.7, 0.07, 0.07) * s, Vector3(0.0, 1.5 * s, 0.35 * s), chrome, _quad)               # handlebars
	_cyl(0.04 * s, 0.04 * s, 0.5 * s, Vector3(0.0, 1.27 * s, 0.35 * s), chrome, _quad, 8)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := _cyl(0.4 * s, 0.4 * s, 0.34 * s, Vector3(0.74 * s * sx, 0.4 * s, 0.72 * s * sz), rubber, _quad, 14)
			w.rotation = Vector3(0.0, 0.0, PI * 0.5)
			_quad_wheels.append(w)
			_cyl(0.2 * s, 0.2 * s, 0.36 * s, Vector3(0.74 * s * sx, 0.4 * s, 0.72 * s * sz), chrome, _quad, 10).rotation = Vector3(0.0, 0.0, PI * 0.5)   # rims
			_box(Vector3(0.42, 0.06, 0.95) * s, Vector3(0.74 * s * sx, 0.78 * s, 0.72 * s * sz), paint, _quad)   # fenders
		# THE FLAME DESIGN: layered tongues licking back from the nose along both flanks and over the front fenders
		for k in 7:
			var fl: float = 0.78 - 0.085 * float(k)                          # tongue length, long at the nose
			var tongue := _box(Vector3(0.05, 0.1 + 0.02 * float(k % 3), fl) * s, Vector3(0.515 * s * sx, (0.74 + 0.065 * float(k % 4)) * s, (0.78 - 0.33 * float(k)) * s), [flame_a, flame_b, flame_c][k % 3], _quad)
			tongue.rotation.x = -0.06 * float(k)
		_box(Vector3(0.04, 0.16, 0.8) * s, Vector3(0.45 * s * sx, 1.05 * s, 0.7 * s), flame_a, _quad)                # tank flame
		_box(Vector3(0.05, 0.08, 0.5) * s, Vector3(0.46 * s * sx, 1.12 * s, 0.75 * s), flame_c, _quad)
	var hl := _sphere(0.13 * s, Vector3(0.0, 1.02 * s, 1.02 * s), _glow(Color(1.0, 0.95, 0.75), 3.0), _quad, 0.8)
	hl.name = "Headlight"
	_quad_light = SpotLight3D.new()
	_quad_light.light_color = Color(1.0, 0.92, 0.75)
	_quad_light.light_energy = 0.0
	_quad_light.spot_range = 28.0
	_quad_light.spot_angle = 30.0
	_quad_light.position = Vector3(0.0, 1.1 * s, 1.1 * s)
	_quad_light.rotation = Vector3(0.0, PI, 0.0)
	_quad.add_child(_quad_light)


## The disguise: ~90 clumps of leaves, branches and a draped net of ferns, bigger than the quad, plus a ring of the same bushes
## around it, so from the trail it is simply the biggest bush in a thicket.
func _build_cover() -> void:
	_cover = Node3D.new()
	_cover.name = "LeafCover"
	_visuals.add_child(_cover)
	_cover.position = QUAD_POS
	var branch_mat: StandardMaterial3D = _bark_mat if _bark_mat != null else _plain(Color(0.30, 0.20, 0.12), 0.95)
	for i in 150:
		var a: float = float(i) * 2.399963                        # golden-angle scatter
		var rr: float = 0.25 + 1.75 * sqrt(fposmod(float(i) * 0.6180339, 1.0))
		var x: float = cos(a) * rr * 1.05
		var z: float = sin(a) * rr * 1.9 - 0.2
		var y: float = 0.4 + 2.2 * (1.0 - clampf(rr / 2.0, 0.0, 1.0)) + 0.25 * sin(float(i) * 1.7)
		var sz: float = 0.7 + 0.45 * absf(sin(float(i) * 2.3))
		var clump := _foliage_bit(i, sz, Vector3(x, y, z), _cover)
		clump.rotation = Vector3(0.3 * sin(float(i)), float(i), 0.2 * cos(float(i)))
		_cover_bits.append([clump, Vector3(x, 0.4, z).normalized() * (2.0 + 1.5 * absf(sin(float(i) * 3.1))) + Vector3(0.0, 3.0, 0.0), 2.5 * sin(float(i) * 1.3), clump.transform])
	for i in 16:
		var a2: float = float(i) * 0.7854
		var br := _cyl(0.035, 0.05, 2.0 + 0.5 * sin(float(i)), Vector3(cos(a2) * 0.9, 1.5, sin(a2) * 1.6), branch_mat, _cover, 5)
		br.rotation = Vector3(0.6 * sin(a2 * 2.0), a2, 0.5 * cos(a2))
		_cover_bits.append([br, Vector3(cos(a2), 1.0, sin(a2)) * 3.0, 3.0, br.transform])
	# the surrounding thicket (stays): the same leaf materials, so the pile belongs
	for i in 22:
		var a3: float = float(i) * 0.2856
		if absf(angle_difference(a3, -0.75)) < 0.75:
			continue                                               # the trail side stays open (where Inferno and the camera come in)
		var d: float = 3.0 + 1.0 * absf(sin(float(i) * 2.0))
		_foliage_bit(i, 1.5 + 0.7 * absf(sin(float(i))), QUAD_POS + Vector3(cos(a3) * d * 1.1, 0.0, sin(a3) * d * 1.7), _visuals, true)


func is_quad_modelled() -> bool: return _quad_modelled
func get_quad_wheel_count() -> int: return _quad_wheels.size()
func get_quad_node() -> Node3D:
	return _quad


func get_cover_node() -> Node3D:
	return _cover


func get_cover_bit_count() -> int:
	return _cover_bits.size()


## One piece of the quad's camouflage / the thicket round it: a fern clump (real alpha-cut fern cards) or a cut fir branch, in the same
## wind materials as the wood so the pile belongs. Falls back to a leaf ball if the forest kit is missing.
func _foliage_bit(i: int, sz: float, pos: Vector3, parent: Node3D, grounded: bool = false) -> Node3D:
	if _crown_mat == null or not _kit_meshes.has("Fern"):
		return _sphere(sz, pos + Vector3(0.0, 0.7 if grounded else 0.0, 0.0), _leaf_mats[i % _leaf_mats.size()], parent, 0.72)
	var mi := MeshInstance3D.new()
	if grounded or i % 3 != 0:
		mi.mesh = _kit_meshes["Fern"]
		mi.material_override = _fern_mat
		var k: float = sz * (1.5 if grounded else 1.25)
		mi.scale = Vector3(k, k * (1.2 if grounded else 1.0), k)
		mi.position = pos - Vector3(0.0, 0.0 if grounded else sz * 0.45, 0.0)
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2(sz * 1.8, sz * 2.2)
		mi.mesh = qm
		mi.material_override = _crown_mat
		mi.position = pos
	parent.add_child(mi)
	return mi


func is_quad_hidden() -> bool:
	return _cover != null and is_instance_valid(_cover) and _cover.visible and _reveal_t < 0.0


# --- the living bears -----------------------------------------------------------------------------------------------------

## The quad's road as a curve: Catmull-Rom through RIDE_TRAIL, resampled every ~1.5 m (built first: the wood keeps clear of it,
## and the road pickets stand along it).
func _build_ride_path() -> void:
	_ride_pts = _smooth(RIDE_TRAIL, 1.5)
	_ride_len = PackedFloat32Array()
	var acc: float = 0.0
	_ride_len.append(0.0)
	for i in range(1, _ride_pts.size()):
		acc += _ride_pts[i].distance_to(_ride_pts[i - 1])
		_ride_len.append(acc)
	_ride_total = acc


func _ride_sample(s: float) -> Array:
	s = clampf(s, 0.0, _ride_total)
	var i: int = 1
	while i < _ride_len.size() - 1 and _ride_len[i] < s:
		i += 1
	var a: Vector3 = _ride_pts[i - 1]
	var b: Vector3 = _ride_pts[i]
	var seg: float = maxf(_ride_len[i] - _ride_len[i - 1], 0.001)
	var t: float = clampf((s - _ride_len[i - 1]) / seg, 0.0, 1.0)
	return [a.lerp(b, t), atan2(b.x - a.x, b.z - a.z)]


## Every bear's spawn record: position, facing, group - and the clearing his beat needs (so no trunk stands in his way).
func _resolve_specs() -> void:
	_specs.clear()
	_clearings.clear()
	for sc in SCOUTS:
		var d: Dictionary = (sc as Dictionary).duplicate(true)
		d["group"] = "scout"
		_specs.append(d)
	for rb in ROAD_BEARS:
		var d2: Dictionary = (rb as Dictionary).duplicate(true)
		var smp: Array = _ride_sample(float(d2["at"]) * PICKET_ROAD_LEN)
		var at: Vector3 = smp[0]
		var yaw: float = float(smp[1])
		var right := Vector3(-cos(yaw), 0.0, sin(yaw))         # the rider's right (heading yaw: forward = (sin, 0, cos))
		var p: Vector3 = at + right * float(d2["lat"])
		d2["pos"] = Vector2(p.x, p.z)
		if not d2.has("face"):
			# sentries watch the road coming toward them (a little up-road); readers / sleepers face away into the trees
			var up_road: Array = _ride_sample(float(d2["at"]) * PICKET_ROAD_LEN - 25.0)
			var look: Vector3 = up_road[0]
			var face: float = atan2(look.x - p.x, look.z - p.z)
			if str(d2["routine"]) in ["read", "sleep"]:
				face += PI * 0.6
			d2["face"] = face
		d2["group"] = "road"
		_specs.append(d2)
	for d4 in _specs:
		var sp: Dictionary = d4
		var home: Vector2 = sp["pos"]
		var route: Array = sp.get("route", [])
		if route.size() >= 2:
			for i in route.size():
				_clearings.append([route[i], route[(i + 1) % route.size()], 3.2])
		else:
			_clearings.append([home, home, 3.5 + float(sp.get("roam_r", 0.0)) * (1.0 if str(sp["routine"]) == "roam" else 0.0)])


## Spawn `count` bears starting at batch `k` (the background build makes a few per frame).
func _spawn_batch(k: int, count: int) -> void:
	if _specs.is_empty():
		_resolve_specs()
	for i in range(k * count, mini((k + 1) * count, _specs.size())):
		if i >= _spawned:
			_spawn_bear(_specs[i], i)
			_spawned = i + 1


func _spawn_bear(spec: Dictionary, idx: int) -> Ep2BearBrain:
	if _bears_root == null:
		_bears_root = Node3D.new()
		_bears_root.name = "Bears"
		_visuals.add_child(_bears_root)
	var home: Vector2 = spec["pos"]
	var h: float = float(spec.get("height", 2.2))
	var a: Ep2Actor = Ep2BearKit.make_bear(_bears_root, Vector3(home.x, 0.0, home.y), h)
	a.name = "Bear_" + str(spec["name"]).replace(" ", "")
	if spec.has("face"):
		a.facing = float(spec["face"])
		a.rotation.y = a.facing
	if str(spec.get("role", "brawler")) == "archer":
		Ep2BearKit.add_bow(a)
	var brain := Ep2BearBrain.new(a, (spec as Dictionary).duplicate(true), 1886 + idx * 31 + _attempt * 7)
	brain.set_meta("group", str(spec["group"]))
	brain.set_meta("corpse_id", "woods:%d" % idx)
	if armory.corpses.has("woods:%d" % idx):
		brain.aware = Ep2BearBrain.Aware.DEAD
		brain.hp = 0
		brain.arrows = int(armory.corpses["woods:%d" % idx]["arrows"])
		a.stop()
		Ep2BearKit.pose(a, "dead")
	brain.roared.connect(_on_bear_roared)
	brain.arrow_loosed.connect(_on_arrow_loosed)
	brain.swiped.connect(_on_bear_swiped)
	brain.swing_started.connect(_on_bear_swing)
	brain.died.connect(_on_bear_died)
	brain.spotted.connect(_on_bear_spotted)
	_bears.append(brain)
	return brain


## The bears of one group ("scout", "road", "camp").
func get_bears(group: String = "") -> Array:
	if group == "":
		return _bears.duplicate()
	return _bears.filter(func(b: Ep2BearBrain) -> bool: return str(b.get_meta("group", "")) == group)


func get_bear(bear_name: String) -> Ep2BearBrain:
	for b in _bears:
		if (b as Ep2BearBrain).display_name() == bear_name:
			return b
	return null


func get_scouts() -> Array:
	return get_bears("scout")


# --- the story --------------------------------------------------------------------------------------------------------

func _on_setup() -> void:
	_armory_snapshot = armory.snapshot()  # before the first player event can spend a round or claim loot
	_ammo_snapshot = [armory.active_gun().rounds, armory.active_gun().reserve]
	_beat = Beat.SNEAK
	_player_pos = SPAWN
	_prev_player = SPAWN
	_ground_y = 0.0
	_apply_handoff_gaze(0.0, -0.04)           # first person, eyes level (keeps the gaze he had at the previous chamber's exit)
	_player_yaw = 0.0
	_rng.seed = 1886
	if _bull == null:
		_bull = _build_bull(BULL_START, 0.0)
	_engine = _loop_player(QUAD_LOOP, -7.0)
	# life in the wood: birds on random flights (some swooping between the trunks), flocks flushing, and the ElevenLabs
	# soundscape (ambience bed, canopy wind gusts, 3D bird calls) - founder 2026-10-10
	if _wildlife == null:
		_wildlife = Ep2Wildlife.new()
		_wildlife.name = "Wildlife"
		_visuals.add_child(_wildlife)
		_wildlife.setup(get_camera(), SPAWN, Vector2(45.0, 45.0), 34.0)
	if _hud:
		_hud.show_health = true
	if _vm != null:
		# the held Winchester reads the same daylight-bright in every direction (the low sun behind him turned it dark navy):
		# no tree-shadow patches on it, and its own key light fills what the sun leaves out (see Ep2Viewmodel.set_own_light)
		_vm.set_world_shadows(false)
		_vm.set_own_light(VM_KEY_ENERGY, _sun)
	_on_beat_entered(Beat.SNEAK)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.SNEAK:
			_sneak_i = 0
			if _hud:
				_hud.objective = "Stay close to Inferno. Walk soft - the bears' scouts hear a runner."
			_begin_carry_line("vo_bull_retry" if _retry_line_pending else "vo_bull_woods_sneak")
			_retry_line_pending = false
			_bull_chat_cd = _rng.randf_range(22.0, 34.0)
		Beat.REVEAL:
			_bull.stop()
			if _hud:
				_hud.objective = ""
			var bull_at := Vector3(QUAD_POS.x + 3.0, 0.0, QUAD_POS.z - 1.2)
			_start_show([
				{"do": "walk", "to": bull_at, "speed": 2.2},
				{"do": "face", "at": QUAD_POS},
				FacilityShow._say("vo_bull_quad_reveal", 0.2),
				{"do": "reach", "at": QUAD_POS + Vector3(0.0, 1.5, 0.0), "ramp": 0.5, "hold": 0.2, "lean": 0.35},
				{"do": "call", "fn": _reveal_quad},
				{"do": "wait", "t": 1.2},
				{"do": "release", "ramp": 0.5, "t": 0.4},
				FacilityShow._say("vo_lb_quad_ok", 0.2),
				{"do": "wait", "t": 0.5}], true)
			look_toward(QUAD_POS + Vector3(0.0, 1.3, 0.0), 2.2)
		Beat.MOUNT:
			# no blink (founder 2026-10-13 "the transitions are not smooth"): his eye climbs onto the back seat while Inferno
			# swings onto the saddle, in one continuous move
			_start_show([
				FacilityShow._say("vo_bull_quad_mount", 0.15),
				{"do": "call", "fn": _mount},
				{"do": "wait", "t": 1.05}], true)
		Beat.RIDE:
			_begin_ride()
		Beat.DROPOFF:
			_begin_dropoff()


func _show_finished() -> void:
	match _beat:
		Beat.REVEAL:
			_advance_to(Beat.MOUNT)
		Beat.MOUNT:
			_advance_to(Beat.RIDE)
		Beat.DROPOFF:
			_dropoff_done = true
			if _hud:
				_hud.objective = "Go to the CERTIFICATES office. Get the sheriff to sort you a certificate."



func _reveal_quad() -> void:
	_reveal_t = 0.0
	_sfx("ep2_leaves_pull")
	_noise(QUAD_POS, 10.0, "leaves")


func _mount() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_room_music"):
		am.play_room_music(MUSIC, 2.0)
	_sfx("ep2_quad_start")
	if _quad_light:
		_quad_light.light_energy = 6.0
	_bull_swing_on()
	_glide_to(_seat_position(), BACK_EYE, 1.0, 0.35)
	# while he climbs on his eye turns to the road ahead (a passenger looks where the quad will go)
	var f := Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw))
	look_toward(_seat_position() + f * 25.0 + Vector3(0.0, BACK_EYE, 0.0), 3.2)
	_noise(QUAD_POS, ENGINE_HEARING, "engine")          # the engine starts: the near wood hears it (Sniffer comes running)


func _fade(goal: float, seconds: float) -> void:
	if _hud:
		_hud.fade_to(goal, seconds)


func _begin_ride() -> void:
	release_look()
	release_camera()
	_riding = true
	_ride_done = false
	cam_distance = 7.5
	cam_height = 2.4
	_bull.stop()
	if _bull.current_clip() != BULL_SIT_CLIP:
		_bull_mount()
	_bull_swing = {}
	_glide = {}
	if _ride_pts.is_empty():
		_build_ride_path()
	_quad_yaw_prev = _quad_yaw
	_ride_s = 0.0
	_ride_speed = 0.0
	_road_lines.clear()
	if _engine:
		_engine.volume_db = -7.0
		_engine.play()
	_seat_riders()
	if _hud:
		_hud.objective = "Hold on and shoot back - bears on the road."
	_start_show([FacilityShow._say("vo_bull_road_start", 0.2), FacilityShow._say("vo_lb_road_go", 0.2)])
	prebuild_requested.emit("gold_town")          # the town builds behind the ride (one invisible cut at the drop-off)


## Where Lil Blunt kneels on the rack, for the quad's current pose.
func _seat_position() -> Vector3:
	var f := Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw))
	var r := Vector3(-f.z, 0.0, f.x)                 # the rider's right
	var base: Vector3 = _quad.position
	if _quad_modelled:
		return base + f * BACK_F + r * BACK_SIDE + Vector3(0.0, SEAT_TOP, 0.0)
	return base - f * 2.1 + r * SEAT_SIDE + Vector3(0.0, 1.1, 0.0)


## Inferno's actor origin when he sits on the saddle.
func _bull_seat_position() -> Vector3:
	var f := Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw))
	var base: Vector3 = _quad.position
	if _quad_modelled:
		var hips_at: Vector3 = base + f * BULL_SEAT_F + Vector3(0.0, SEAT_TOP_DRIVER + 0.10, 0.0)
		return hips_at - Basis(Vector3.UP, _quad_yaw) * BULL_HIPS
	return base + f * 0.55 + Vector3(0.0, 0.62, 0.0)


func _seat_riders() -> void:
	var f := Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw))
	var r := Vector3(-f.z, 0.0, f.x)
	var base: Vector3 = _quad.position
	_bull.position = _bull_seat_position()
	_bull.clear_face_goal()
	_bull.facing = _quad_yaw
	_bull.rotation.y = _quad_yaw
	if _quad_modelled:
		if BULL_GRIPS_IK:      # off: arm IK + spine lean tore his sculpted elbow and torso (founder 2026-10-11: "elbow partially invisible"); the seated clip keeps his arms
			_bull.reach("Left", base + f * GRIP_F - r * GRIP_X + Vector3(0.0, GRIP_U, 0.0), 0.5, BULL_LEAN)
			_bull.reach("Right", base + f * GRIP_F + r * GRIP_X + Vector3(0.0, GRIP_U, 0.0), 0.5, BULL_LEAN)
		eye_height = BACK_EYE
	_player_pos = _seat_position()
	_player_yaw = _quad_yaw
	_ground_y = _player_pos.y
	_vel_y = 0.0


## Inferno sits on the quad (the seated clip, frozen).
func _bull_mount() -> void:
	if not _quad_modelled or _bull == null:
		return
	_bull.add_all_clips(SmeltingFacilityChamber.BULL_SIT_CLIPS)
	if _bull.anim != null and _bull.anim.has_animation(BULL_SIT_CLIP):
		_bull.play(BULL_SIT_CLIP, 0.0, 0.0)
		_bull.anim.seek(BULL_SIT_AT, true)


## ...and gets off (standing idle, hands free) at the ridge.
func _bull_dismount() -> void:
	if _bull == null:
		return
	_bull.release("Left", 0.2)
	_bull.release("Right", 0.2)
	if _bull.anim != null:
		_bull.anim.speed_scale = 1.0
	_bull.play(BULL_IDLE, 1.0, 0.25)


## He swings a leg over: from where he stands beside the quad up onto the saddle in one arc, sitting down on the way.
func _bull_swing_on() -> void:
	_bull.stop()
	_bull.clear_face_goal()
	_bull_swing = {"from": _bull.position, "to": _bull_seat_position(), "t": 0.0, "dur": 0.85, "yaw0": _bull.facing, "yaw1": _quad_yaw,
		"on": true, "switched": false, "arc": 0.45}


## ...and off again at the ridge: down beside the front wheel, standing, then up to the ferns.
func _bull_swing_off(walk_to_p: Vector3) -> void:
	var f := Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw))
	var r := Vector3(-f.z, 0.0, f.x)
	var down: Vector3 = _quad.position - r * 1.5 + f * 0.3
	down.y = 0.0
	_bull_swing = {"from": _bull.position, "to": down, "t": 0.0, "dur": 0.7, "yaw0": _bull.facing, "yaw1": _quad_yaw - 0.6,
		"on": false, "switched": false, "arc": 0.25, "then": walk_to_p}


func _tick_bull_swing(delta: float) -> void:
	if _bull_swing.is_empty() or _bull == null:
		return
	var t: float = float(_bull_swing["t"]) + delta
	_bull_swing["t"] = t
	var k: float = clampf(t / float(_bull_swing["dur"]), 0.0, 1.0)
	var e: float = k * k * (3.0 - 2.0 * k)
	var from: Vector3 = _bull_swing["from"]
	var to: Vector3 = _bull_swing["to"]
	_bull.position = from.lerp(to, e) + Vector3(0.0, float(_bull_swing["arc"]) * sin(PI * e), 0.0)
	_bull.facing = lerp_angle(float(_bull_swing["yaw0"]), float(_bull_swing["yaw1"]), e)
	_bull.rotation.y = _bull.facing
	if not bool(_bull_swing["switched"]):
		if bool(_bull_swing["on"]) and k >= 0.55:
			_bull_swing["switched"] = true
			_bull_mount()
		elif not bool(_bull_swing["on"]) and k >= 0.3:
			_bull_swing["switched"] = true
			_bull_dismount()
	if k >= 1.0:
		var then: Variant = _bull_swing.get("then", null)
		_bull_swing = {}
		if then is Vector3:
			_bull.walk_to(then, 1.4)


## The player's eye moves (no cut, no blink) from where he is to `to` with eye height `eye1`: onto the quad, off it at the ridge.
func _glide_to(to: Vector3, eye1: float, dur: float, arc: float = 0.0) -> void:
	_glide = {"from": _player_pos, "to": to, "eye0": eye_height, "eye1": eye1, "t": 0.0, "dur": maxf(dur, 0.05), "arc": arc}


func _tick_glide(delta: float) -> void:
	if _glide.is_empty():
		return
	var t: float = float(_glide["t"]) + delta
	_glide["t"] = t
	var k: float = clampf(t / float(_glide["dur"]), 0.0, 1.0)
	var e: float = k * k * (3.0 - 2.0 * k)
	var from: Vector3 = _glide["from"]
	var to: Vector3 = _glide["to"]
	_player_pos = from.lerp(to, e) + Vector3(0.0, float(_glide["arc"]) * sin(PI * e), 0.0)
	eye_height = lerpf(float(_glide["eye0"]), float(_glide["eye1"]), e)
	_ground_y = _player_pos.y
	_vel_y = 0.0
	if k >= 1.0:
		_glide = {}


func is_gliding() -> bool:
	return not _glide.is_empty()


# --- per-frame --------------------------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_warn_cd = maxf(0.0, _warn_cd - delta)
	_stay_cd = maxf(0.0, _stay_cd - delta)
	_bark_cd = maxf(0.0, _bark_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if _ammo_snapshot.is_empty() and _vm != null:
		_ammo_snapshot = [_vm.gun.rounds, _vm.gun.reserve]
		_armory_snapshot = armory.snapshot()
	_player_vel = (_player_pos - _prev_player) / maxf(delta, 0.0001)
	_prev_player = _player_pos
	_tick_flashes(delta)
	if _hud != null:
		if not _hud.search_requested.is_connected(_search_nearby):
			_hud.search_requested.connect(_search_nearby)
		var body: Ep2BearBrain = _nearby_corpse()
		_hud.set_search_prompt("Search %s [E]" % body.display_name() if body != null else "")
	if _failing:
		_tick_fail(delta)
		return
	_tick_glide(delta)
	_tick_bull_swing(delta)
	_tick_cover(delta)
	_tick_bears(delta)
	_tick_arrows(delta)
	_tick_player_arrows(delta)
	_tick_footsteps(delta)
	_tick_riders(delta)
	if _wildlife != null:
		_wildlife._centre = Vector3(_player_pos.x, 0.0, _player_pos.z)      # the birds keep to the stretch of wood he is in
		_wildlife.step(delta)
	match _beat:
		Beat.SNEAK:
			_tick_bull_defence(delta)
			_tick_sneak(delta)
		Beat.RIDE:
			_tick_bull_ride_cover(delta)
			_tick_ride(delta)
		Beat.DROPOFF:
			_tick_dropoff(delta)


## Inferno the grown-up (founder 2026-10-14: "mechanical ... repeats walk soft and follow me ... if Lil Blunt goes on ahead he should acknowledge it
## as an adult and not wait for him to come back"). He walks the trail at his own pace. Lil Blunt scouting AHEAD: one easy word now and then and he
## carries on. Lil Blunt LAGGING: he stops, looks back, waits a few seconds, then strolls on slowly (never rigid). Unprompted lines are rare, random
## and rotate through a pool (skill ep2-bull-companion-pacing).
func _tick_sneak(delta: float) -> void:
	_bull_chat_cd = maxf(0.0, _bull_chat_cd - delta)
	_bull_wait_lock = maxf(0.0, _bull_wait_lock - delta)
	if _bull_alarm or not _bull_swing.is_empty():
		return
	var trail: Array = SNEAK_TRAIL
	var target2: Vector2 = trail[_sneak_i]
	var bt := Vector3(target2.x, 0.0, target2.y)
	var bull2 := Vector2(_bull.position.x, _bull.position.z)
	var gap: float = _trail_s(Vector2(_player_pos.x, _player_pos.z)) - _trail_s(bull2)      # > 0: Lil Blunt is AHEAD of him on the trail
	var dist_player: float = Vector2(_bull.position.x - _player_pos.x, _bull.position.z - _player_pos.z).length()
	var at_end: bool = _sneak_i >= trail.size() - 1 and bull2.distance_to(Vector2((trail[trail.size() - 1] as Vector2).x, (trail[trail.size() - 1] as Vector2).y)) < 1.6
	var want_pace: float = 1.9
	if _show_active:
		pass
	elif at_end:
		# at the thicket he does wait for him - the reveal is theirs together
		if dist_player > 8.0:
			if _bull.is_walking():
				_bull.stop()
			_bull.face_point(_player_pos)
			_bull_chat(BULL_WAIT, 12.0, 20.0)
	elif gap > 3.5 and dist_player > 4.0:
		# he is out in front: Inferno lets him scout, says so once in a while, and keeps his own pace
		_bull_wait_t = 0.0
		_bull_waiting = false
		if gap > 6.0:
			_bull_chat(BULL_AHEAD, 18.0, 34.0)
		want_pace = 2.3
		_bull_walk_pace(bt, want_pace)
	elif dist_player > 8.0 and gap < -2.0:
		if _bull_wait_lock <= 0.0:
			# a look back and a short wait ...
			_bull_wait_t += delta
			_bull_waiting = true
			if _bull.is_walking():
				_bull.stop()
			_bull.face_point(_player_pos)
			if _bull_wait_t > 0.8:
				_bull_chat(BULL_WAIT, 22.0, 38.0)
			if _bull_wait_t > 3.8:
				# ... then he gets on with it: he is a grown man, he strolls on and Lil Blunt catches up
				_bull_wait_lock = 16.0
				_bull_wait_t = 0.0
				_bull_waiting = false
		else:
			_bull_walk_pace(bt, 1.25)
	else:
		_bull_wait_t = 0.0
		_bull_waiting = false
		_bull_walk_pace(bt, want_pace)
		_bull_chat(BULL_EASY, 40.0, 75.0)
	if bull2.distance_to(target2) < 0.35:
		_sneak_i += 1
		_intro_scout_at(_sneak_i)
		if _sneak_i >= trail.size():
			_sneak_i = trail.size() - 1
			if dist_player < 8.0:
				_advance_to(Beat.REVEAL)
			return


## Walk toward `bt` at `pace` (re-issued when the pace changes, so a stroll turns into a stride and back without a stop).
func _bull_walk_pace(bt: Vector3, pace: float) -> void:
	if not _bull.is_walking() or absf(_bull_pace - pace) > 0.05:
		_bull_pace = pace
		_bull.walk_to(bt, pace)


## One unprompted line from `pool`, rotating (never the same line twice running), then silence for a random `cd_min`..`cd_max` seconds.
func _bull_chat(pool: Array, cd_min: float, cd_max: float) -> bool:
	if _bull_chat_cd > 0.0 or _hold > 0.0 or _show_active:
		return false
	var key: String = str(pool[0])
	var i: int = int(_line_idx.get(key, _rng.randi() % pool.size()))
	_line_idx[key] = (i + 1) % pool.size()
	_bull_chat_cd = _rng.randf_range(cd_min, cd_max)
	_begin_carry_line(str(pool[i % pool.size()]))
	return true


## Arc length along the sneak trail of the point nearest `p` (how far along the trail someone is, whatever side of it he wandered to).
func _trail_s(p: Vector2) -> float:
	var tr: Array = SNEAK_TRAIL
	if _sneak_arc.is_empty():
		_sneak_arc.append(0.0)
		for i in range(1, tr.size()):
			_sneak_arc.append(_sneak_arc[i - 1] + (tr[i] as Vector2).distance_to(tr[i - 1] as Vector2))
	var best_d: float = 1e9
	var best_s: float = 0.0
	for i in range(tr.size() - 1):
		var a: Vector2 = tr[i]
		var ab: Vector2 = (tr[i + 1] as Vector2) - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_s = _sneak_arc[i] + ab.length() * t
	return best_s


## Inferno names the scout they are passing (a quiet aside, only if that bear is alive and has not noticed them).
func _intro_scout_at(i: int) -> void:
	for b in _bears:
		var br: Ep2BearBrain = b
		if int(br.p.get("intro_at", -1)) != i or _intro_done.has(br.display_name()):
			continue
		_intro_done[br.display_name()] = true
		if br.is_unaware() and _hold <= 0.0:
			_begin_carry_line(str(br.p["intro"]))


## The bears live: dormant far away (hidden, not processed), awake near Lil Blunt - routine, senses (sight 5x a second with the trees
## in the way, hearing from the world's noise events), combat. Their snores and page turns are 3D sounds.
func _tick_bears(delta: float) -> void:
	_sense_acc += delta
	var sense: bool = _sense_acc >= 0.2
	if sense:
		_sense_acc = 0.0
	var pl: Vector3 = _player_pos
	var exposure: float = _exposure()
	_assign_attack_budget()
	for b in _bears:
		var br: Ep2BearBrain = b
		var a: Ep2Actor = br.actor
		if a == null or not is_instance_valid(a):
			continue
		var d: float = Vector2(a.position.x - pl.x, a.position.z - pl.z).length()
		var on: bool = d < BEAR_ACTIVE_R
		if on != a.visible:
			a.visible = on
			a.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		if not on:
			continue
		br.lead = Vector3(_player_vel.x, 0.0, _player_vel.z) * 0.7 if _riding else Vector3.ZERO
		if sense and not br.is_dead():
			var blocked: bool = d > 3.0 and _los_blocked(Vector2(a.position.x, a.position.z), Vector2(pl.x, pl.z))
			br.has_los = not blocked
			br.look(pl, exposure, blocked, 0.2)
		br.step(delta, pl)
		if not br.is_dead() and a.is_walking():
			_push_out_of_trees(a)
		_bear_ambience(br, d)


## How visible Lil Blunt is right now (sight meter rate): still / walking / running, on a roaring quad, belly-down on the ridge.
func _exposure() -> float:
	if _riding:
		return 1.0
	if _moving:
		return 1.0 if _run_input else 0.55
	return 0.3


## The active-attack budget: only the nearest few archers may draw on him at once (contract: no overlapping attack spam).
func _assign_attack_budget() -> void:
	var archers: Array = []
	for b in _bears:
		var br: Ep2BearBrain = b
		if br.role() == "archer" and br.is_alert():
			archers.append(br)
	archers.sort_custom(func(x: Ep2BearBrain, y: Ep2BearBrain) -> bool:
		return x.actor.position.distance_squared_to(_player_pos) < y.actor.position.distance_squared_to(_player_pos))
	for i in archers.size():
		(archers[i] as Ep2BearBrain).may_attack = i < ARCHERS_AT_ONCE


func _bear_ambience(br: Ep2BearBrain, d: float) -> void:
	var a: Ep2Actor = br.actor
	var st: String = Ep2BearKit.pose_name(a)
	var snore: AudioStreamPlayer3D = a.get_meta("snore") if a.has_meta("snore") else null
	if st == "sleep" and d < 40.0:
		if snore == null:
			var s: AudioStream = _sound("ep2_bear_snore")
			if s != null:
				snore = AudioStreamPlayer3D.new()
				snore.name = "Snore"
				if s is AudioStreamMP3:
					(s as AudioStreamMP3).loop = true
				snore.stream = s
				snore.bus = "SFX"
				snore.volume_db = -4.0
				snore.unit_size = 5.0
				snore.max_distance = 40.0
				snore.pitch_scale = float(br.p.get("pitch", 1.0))
				a.add_child(snore)
				snore.position = Vector3(0.0, 0.6, 0.0)
				a.set_meta("snore", snore)
		if snore != null and not snore.playing:
			snore.play()
	elif snore != null and snore.playing:
		snore.stop()
	if st == "sit_read" and d < 25.0:
		var page: int = int(float(a.get_meta("pose_t", 0.0)) / 7.0)
		if page != int(a.get_meta("page", 0)):
			a.set_meta("page", page)
			_sfx3d("ep2_page_flip", a.global_position + Vector3(0.0, 1.0, 0.0), -8.0, 1.0, 25.0)


## A bear on the move slides round a trunk instead of walking through it.
func _push_out_of_trees(a: Ep2Actor) -> void:
	var q := Vector2(a.position.x, a.position.z)
	for t in _trees_near(q, 1):
		var tp: Vector2 = t[0]
		var r: float = float(t[1]) + 0.45
		var dv: Vector2 = q - tp
		if dv.length() < r:
			q = tp + (dv.normalized() if dv.length_squared() > 1e-6 else Vector2(1.0, 0.0)) * r
	a.position.x = q.x
	a.position.z = q.y


## Footsteps are world noise: a walker is heard only right beside a bear, a runner across a clearing.
func _tick_footsteps(delta: float) -> void:
	if _riding or not _moving or not has_player_control():
		_step_acc = 0.0
		return
	_step_acc += delta
	var every: float = 0.32 if _run_input else 0.55
	if _step_acc >= every:
		_step_acc = 0.0
		_noise(_player_pos, HEARING if _run_input else WALK_NOISE, "run" if _run_input else "step")


## A sound at `at` carrying `radius` metres. Returns how many bears it newly put on guard. In the stealth beats that is a NOISE HIT
## (Inferno shushes / hisses); on the road it is just the fight.
func _noise(at: Vector3, radius: float, kind: String) -> int:
	var n: int = 0
	for b in _bears:
		var br: Ep2BearBrain = b
		if br.is_dead() or not br.actor.visible:
			continue
		var was: int = br.aware
		br.hear(at, radius, kind)
		if (was == Ep2BearBrain.Aware.UNAWARE or was == Ep2BearBrain.Aware.SEARCH) and br.aware != was:
			n += 1
			_sfx3d("ep2_bear_growl_%d" % (1 + (br.actor.get_instance_id() % 3)), br.actor.global_position + Vector3(0.0, 1.6, 0.0),
				-2.0, float(br.p.get("pitch", 1.0)), 45.0)
	if n > 0 and kind != "engine" and kind != "leaves" and (_beat == Beat.SNEAK or _beat == Beat.REVEAL):
		_noise_hits += 1
		if _warn_cd <= 0.0:
			_warn_cd = 14.0
			var shot: bool = kind == "shot"
			if _hud:
				_hud.toast("A SHOT CARRIES!" if shot else "SHH! WALK SOFT", 2.0)
			# a hiss is urgent: it cuts whatever he was saying
			var qi: int = int(_line_idx.get("quiet", 0))
			_line_idx["quiet"] = qi + 1
			_bull_chat_cd = maxf(_bull_chat_cd, 12.0)
			_begin_carry_line("vo_bull_woods_shot" if shot else str(BULL_QUIET[qi % BULL_QUIET.size()]))
	return n


## Inferno defends him: a bear that has seen them and comes on, he levels his rifle and fires (no arm IK - the rifle pivots in his
## fist, his arm stays as sculpted). His shots are world noise too. When the threat is gone he takes up the trail again.
func _tick_bull_defence(delta: float) -> void:
	if _bull == null:
		return
	_bull_fire_cd = maxf(0.0, _bull_fire_cd - delta)
	# "if he sees Lil Blunt struggling" (founder 2026-10-14): hurt, or a hostile bear closing on HIM - then Inferno does not wait for a bear to be
	# coming at himself: he covers Lil Blunt, fires faster and straighter, and steps in for a clear line.
	var threat: Ep2BearBrain = null
	var best: float = 40.0
	var near_player: bool = false
	for b in _bears:
		var br: Ep2BearBrain = b
		if not br.is_alert() or br.is_dead():
			continue
		var d: float = br.actor.position.distance_to(_bull.position)
		var dp: float = br.actor.position.distance_to(_player_pos)
		var pressing: bool = dp < 13.0
		near_player = near_player or pressing
		var score: float = d - (14.0 if pressing else 0.0)
		if score < best and d < 40.0 and not _los_blocked(Vector2(_bull.position.x, _bull.position.z), Vector2(br.actor.position.x, br.actor.position.z)):
			best = score
			threat = br
	var struggling: bool = _health < HEALTH_MAX or near_player
	if threat == null:
		if near_player and _health < HEALTH_MAX:
			# no clear line from where he stands: he steps toward Lil Blunt to get one
			var toward: Vector3 = (_player_pos - _bull.position)
			toward.y = 0.0
			if toward.length() > 5.0:
				_bull.walk_to(_bull.position + toward.normalized() * minf(toward.length() - 3.5, 6.0), 3.4)
		if _bull_alarm:
			_bull_calm_t += delta
			if _bull_calm_t > 2.5:
				_bull_alarm = false
				_bull_waiting = false
		return
	_bull_calm_t = 0.0
	if not _bull_alarm:
		_bull_alarm = true
		_bull.stop()
		_bull_fire_cd = 0.5 if struggling else 0.9
		if _bark_cd <= 0.0:
			_bark_cd = 8.0
			if _health <= 1:
				var ci0: int = int(_line_idx.get("cover", 0))
				_line_idx["cover"] = ci0 + 1
				_begin_carry_line(str(BULL_COVER[ci0 % BULL_COVER.size()]))      # Lil Blunt is on his last heart: not "he's seen us", "I've got you"
			else:
				_begin_carry_line("vo_bull_spotted")
	elif struggling and _health <= 1 and _bark_cd <= 0.0 and _hold <= 0.0:
		_bark_cd = 10.0
		var ci: int = int(_line_idx.get("cover", 0))
		_line_idx["cover"] = ci + 1
		_begin_carry_line(str(BULL_COVER[ci % BULL_COVER.size()]))
	_bull.face_point(threat.actor.position)
	var hero: Ep2BullHero = _bull.get_node_or_null("BullHero")
	if hero:
		hero.aim_at(threat.actor.global_position + Vector3.UP * threat.actor.height_m * 0.6)
	if _bull_fire_cd <= 0.0 and _bull.is_facing(threat.actor.position, 0.35):
		_bull_fire_cd = (1.0 + _rng.randf() * 0.4) if struggling else (1.6 + _rng.randf() * 0.6)
		_bull_fire_at(threat, 0.72 if struggling else 0.55)


## Inferno on the quad covers Lil Blunt too (the road fight): when a bear is on the quad, or he is hurt, he lets off a round over his shoulder
## from the saddle (no reach, the rifle pivots in his fist). Not a turret - one round every couple of seconds, and only when it matters.
func _tick_bull_ride_cover(delta: float) -> void:
	_bull_ride_cd = maxf(0.0, _bull_ride_cd - delta)
	if _bull_ride_cd > 0.0 or _bull == null or _player_pos.z > FOREST_END_Z:
		return
	var best: Ep2BearBrain = null
	var best_d: float = 1e9
	var hurt: bool = _health < HEALTH_MAX
	for b in _bears:
		var br: Ep2BearBrain = b
		if br.is_dead() or not br.is_alert() or not br.actor.visible:
			continue
		var d: float = br.actor.position.distance_to(_player_pos)
		var reach: float = 26.0 if hurt else 11.0
		if br.role() == "archer" and not hurt:
			continue                                                       # an archer at range is for Lil Blunt to answer unless he is hurt
		if d < reach and d < best_d:
			best_d = d
			best = br
	if best == null:
		return
	_bull_ride_cd = (1.7 if hurt else 2.6) + _rng.randf() * 0.7
	_bull_ride_shots += 1
	_bull_fire_at(best, 0.72 if hurt else 0.5)
	if _health <= 1 and _bark_cd <= 0.0 and _hold <= 0.0:
		_bark_cd = 12.0
		var ci: int = int(_line_idx.get("cover", 0))
		_line_idx["cover"] = ci + 1
		_begin_carry_line(str(BULL_COVER[ci % BULL_COVER.size()]))


func _bull_fire_at(br: Ep2BearBrain, hit_chance: float = 0.55) -> void:
	_bull_shots += 1
	var target: Vector3 = br.actor.position + Vector3(0.0, br.actor.height_m * 0.6, 0.0)
	var hero: Ep2BullHero = _bull.get_node_or_null("BullHero")
	var muzzle: Vector3 = hero.fire_at(target) if hero else _bull.position + Vector3.UP * 1.5
	_flash(muzzle)
	_sfx3d("ep2_winchester_shot_%d" % (1 + _bull_shots % 3), muzzle, -1.0, 0.92, 90.0)
	if _rng.randf() < hit_chance:
		br.set_meta("killed_by", "bull")   # Bull's kill is Bull's: Lil Blunt must not take the credit
		br.take_hit(_bull.position)
	_noise(_bull.position, SHOT_HEARING, "bull_shot")


func _tick_flashes(delta: float) -> void:
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Array = _flashes[i]
		f[1] = float(f[1]) - delta
		if float(f[1]) <= 0.0:
			if is_instance_valid(f[0]):
				(f[0] as Node).queue_free()
			_flashes.remove_at(i)


func _flash(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 5.0
	l.omni_range = 6.0
	_visuals.add_child(l)
	l.global_position = at
	var s := _sphere(0.12, at, _glow(Color(1.0, 0.85, 0.5), 6.0), null, 1.0)
	_flashes.append([l, 0.07])
	_flashes.append([s, 0.05])


func _tick_cover(delta: float) -> void:
	if _reveal_t < 0.0 or _cover == null or not is_instance_valid(_cover):
		return
	if _reveal_t >= 1.5:
		return
	_reveal_t += delta
	var k: float = clampf(_reveal_t / 1.5, 0.0, 1.0)
	for bit in _cover_bits:
		var n: Node3D = bit[0]
		var vel: Vector3 = bit[1]
		n.position += vel * delta * (1.0 - k * 0.6)
		n.rotation.y += float(bit[2]) * delta
		n.scale = Vector3.ONE * maxf(0.0, 1.0 - k * k)
	if k >= 1.0:
		_cover.visible = false
		_reveal_t = 1.5


func _tick_ride(delta: float) -> void:
	if _ride_done:
		return
	var remaining: float = _ride_total - _ride_s
	# Inferno brakes into the bends and opens up on the straights; he eases to a stop behind the ridge
	var h0: float = float(_ride_sample(_ride_s)[1])
	var h1: float = float(_ride_sample(_ride_s + 14.0)[1])
	var bend: float = clampf(absf(angle_difference(h0, h1)) / 0.55, 0.0, 1.0)
	var target_speed: float = lerpf(RIDE_SPEED, RIDE_BEND_SPEED, bend)
	target_speed = minf(target_speed, _tick_cart(delta))
	if remaining < 60.0:
		target_speed = minf(target_speed, 3.0 + 6.0 * remaining / 60.0)        # rolling into town at a walking pace
	if remaining < 16.0:
		target_speed = maxf(1.5, target_speed * remaining / 16.0)
	_ride_speed = move_toward(_ride_speed, target_speed, 4.5 * delta)
	_ride_s = minf(_ride_s + _ride_speed * delta, _ride_total)
	var smp: Array = _ride_sample(_ride_s)
	var pos: Vector3 = smp[0]
	_quad_yaw = lerp_angle(_quad_yaw, float(smp[1]), clampf(8.0 * delta, 0.0, 1.0))
	var bob: float = 0.05 * sin(_anim_t * 17.0) * clampf(_ride_speed / RIDE_SPEED, 0.0, 1.0)
	_quad.position = pos + Vector3(0.0, bob, 0.0)
	_quad.rotation = Vector3(0.02 * sin(_anim_t * 9.0), _quad_yaw, 0.03 * sin(_anim_t * 7.0))
	for w in _quad_wheels:
		(w as Node3D).rotation.x += _ride_speed * delta / (QUAD_WHEEL_R if _quad_modelled else 0.68)
	_seat_riders()
	# a passenger's view rides the quad: when it turns, the view turns with it (and the mouse still looks around freely)
	_look_yaw += angle_difference(_quad_yaw_prev, _quad_yaw)
	_quad_yaw_prev = _quad_yaw
	if _engine:
		_engine.pitch_scale = 0.85 + 0.35 * clampf(_ride_speed / RIDE_SPEED, 0.0, 1.0)
	# out of the pines the light warms into gold-rush country (graded by distance, never a cut)
	_grade_desert(_quad.position.z)
	# the engine is the loudest thing in the wood: bears near the road turn to it, the close ones know it is the enemy
	_engine_acc += delta
	if _engine_acc >= 0.25:
		_engine_acc = 0.0
		_engine_noise()
	_road_barks()
	if _ride_s >= _ride_total - 0.01:
		_ride_done = true
		_advance_to(Beat.DROPOFF)


func _engine_noise() -> void:
	var q2 := Vector2(_quad.position.x, _quad.position.z)
	for b in _bears:
		var br: Ep2BearBrain = b
		if br.is_dead() or br.is_alert() or not br.actor.visible:
			continue
		var bp := Vector2(br.actor.position.x, br.actor.position.z)
		var d: float = bp.distance_to(q2)
		if d < ENGINE_ALARM and not _los_blocked(bp, q2):
			br.alarm(_quad.position)
		elif d < ENGINE_HEARING:
			br.hear(_quad.position, ENGINE_HEARING, "engine")


## Inferno calls the road: bows in the trees, a charger, the last picket behind them.
func _road_barks() -> void:
	if _hold > 0.0:
		return
	var archer_drawing: bool = false
	var charger: bool = false
	for b in _bears:
		var br: Ep2BearBrain = b
		if not br.is_alert() or br.is_dead() or str(br.get_meta("group", "")) != "road":
			continue
		var d: float = br.actor.position.distance_to(_player_pos)
		if br.role() == "archer" and d < 42.0 and Ep2BearKit.pose_name(br.actor) == "aim":
			archer_drawing = true
		elif br.role() == "brawler" and d < 30.0:
			charger = true
	if archer_drawing and float(_road_lines.get("bows", -100.0)) < _elapsed - 16.0:
		_road_lines["bows"] = _elapsed
		_begin_carry_line("vo_bull_road_bows")
	elif charger and float(_road_lines.get("charge", -100.0)) < _elapsed - 16.0:
		_road_lines["charge"] = _elapsed
		_begin_carry_line("vo_bull_road_charge")
	elif not _road_lines.has("clear") and _ride_s > (float(ROAD_BEARS[ROAD_BEARS.size() - 1]["at"]) * _ride_total + 70.0):
		_road_lines["clear"] = _elapsed
		_begin_carry_line("vo_bull_road_clear")


func get_noise_hits() -> int:
	return _noise_hits


func is_riding() -> bool:
	return _riding


func get_ride_progress() -> float:
	return _ride_s / maxf(_ride_total, 0.001)


func get_ride_length() -> float:
	return _ride_total


func get_live_bear_count() -> int:
	return _bears.filter(func(b: Ep2BearBrain) -> bool: return not b.is_dead()).size()


func get_kills() -> int: return _kills
func get_alert_count() -> int: return _alerts
func get_arrows_loosed() -> int: return _arrows_loosed
func get_arrow_hits() -> int: return _arrow_hits
func get_bull_shots() -> int: return _bull_shots
func get_bull_ride_shots() -> int: return _bull_ride_shots
func get_attempt() -> int: return _attempt
func is_failing() -> bool: return _failing


## While riding the player does not steer: the quad is on rails and the mouse only looks around.
func _move_player(delta: float) -> void:
	if _riding or not _glide.is_empty():
		_moving = false
		return
	super._move_player(delta)


func _update_vertical(delta: float) -> void:
	if _riding or not _glide.is_empty():
		return
	super._update_vertical(delta)


func _can_jump() -> bool:
	return not _riding and _glide.is_empty()


func has_player_control() -> bool:
	return _running and not _resolved and not _show_blocks_control and _beat != Beat.DONE and not _failing and not armory_open()


## The woods have no spyglass any more (the ride ends in town): the rifle never drops to low ready here.
func _viewmodel_lowered() -> bool:
	return false


# --- the fight -----------------------------------------------------------------------------------------------------------

## THE RIFLE IS IN HIS HANDS, so a shot is a fact of the wood (skill ep2-interlude-chain): the round flies down his aim (with the
## Winchester's spread) and hits the first bear on the line unless a trunk is in the way; and the bang is heard far and wide.
func _on_player_shot() -> void:
	if armory.equipped == Ep2ArmoryState.BOW:
		var eye: Vector3 = _player_pos + Vector3(0.0, eye_height, 0.0)
		var origin: Vector3 = _vm.rifle.get_node("Nock").global_position
		var direction: Vector3 = (eye + _fire_dir() * 50.0 - origin).normalized()
		var arrow := _arrow_mesh()
		_visuals.add_child(arrow)
		arrow.global_position = origin
		_player_arrows.append({"node": arrow, "pos": origin, "v": direction * 38.0, "t": 0.0})
		_noise(_player_pos, 14.0, "bow")
		return
	var eye: Vector3 = _player_pos + Vector3(0.0, eye_height, 0.0)
	var dir: Vector3 = _fire_dir()
	var hit: Ep2BearBrain = _bear_on_ray(eye, dir)
	if hit != null:
		hit.set_meta("killed_by", "player")   # only HIS shots earn his "bear down" line (founder 2026-10-15)
		var killed: bool = hit.take_hit(eye)
		if _hud:
			_hud.hit_marker(killed)
		_sfx3d("ep2_bear_hit", hit.actor.global_position + Vector3(0.0, 1.4, 0.0), 0.0, float(hit.p.get("pitch", 1.0)), 60.0)
	_noise(_player_pos, SHOT_HEARING, "shot")


## The camera's aim with the Winchester's current spread (a gaussian cone: wide from the hip, tight down the sights).
func _fire_dir() -> Vector3:
	var sigma: float = _vm.gun.spread_deg(_moving, false) if _vm != null else 0.0
	var yaw: float = _look_yaw + (deg_to_rad(_rng.randfn(0.0, sigma)) if sigma > 0.0 else 0.0)
	var pitch: float = _look_pitch + (deg_to_rad(_rng.randfn(0.0, sigma)) if sigma > 0.0 else 0.0)
	var cp: float = cos(pitch)
	return Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp)


## The nearest living bear the ray passes through (his body as one or two capsules for the pose he is in), unless a trunk is first.
func _bear_on_ray(eye: Vector3, dir: Vector3, max_distance: float = 170.0) -> Ep2BearBrain:
	var best: Ep2BearBrain = null
	var best_t: float = 1e9
	for b in _bears:
		var br: Ep2BearBrain = b
		if br.is_dead() or not br.actor.visible:
			continue
		var to: Vector3 = br.actor.position - eye
		var tc: float = to.dot(dir)
		if tc < -2.0 or tc > max_distance + 2.0:
			continue
		for sh in _bear_shapes(br):
			var t: float = _ray_capsule(eye, dir, sh[0], sh[1], float(sh[2]))
			if t >= 0.0 and t <= max_distance and t < best_t:
				best_t = t
				best = br
	if best != null and _ray_tree_blocked(eye, dir, best_t, 0.0, 0.0):
		return null
	return best


## Where a bear's body is for a bullet: [a, b, radius] capsules (standing, seated on his stump, or lying down).
func _bear_shapes(br: Ep2BearBrain) -> Array:
	var a: Ep2Actor = br.actor
	var k: float = a.height_m / 2.2
	var up := Vector3.UP
	var fwd := Vector3(sin(a.facing), 0.0, cos(a.facing))
	var p: Vector3 = a.position
	match Ep2BearKit.pose_name(a):
		"sleep", "wake", "dead":
			return [[p + fwd * 0.2 + up * 0.32 * k, p - fwd * 1.55 * k + up * 0.32 * k, 0.5 * k]]
		"sit_read":
			return [[p + up * 0.45 * k, p + up * 1.25 * k, 0.55 * k]]
	return [[p + up * 0.45 * k, p + up * 1.85 * k, 0.52 * k]]


## Ray (origin o, unit dir d) against a capsule a-b of radius r: the ray parameter of the hit, or -1.
static func _ray_capsule(o: Vector3, d: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var ab: Vector3 = b - a
	var ao: Vector3 = o - a
	var abd: float = ab.dot(d)
	var aba: float = ab.dot(ab)
	var denom: float = aba - abd * abd
	var t: float
	var s: float
	if absf(denom) < 1e-6:
		s = 0.0
		t = (a - o).dot(d)
	else:
		t = (ab.dot(ao) * abd - aba * d.dot(ao)) / denom
		s = (ab.dot(ao) + t * abd) / aba
	s = clampf(s, 0.0, 1.0)
	var on_seg: Vector3 = a + ab * s
	t = maxf((on_seg - o).dot(d), 0.0)
	if (o + d * t).distance_to(on_seg) <= r:
		return t
	return -1.0


## Does a trunk stop the round before `t_max`? (Horizontal ray vs trunk circles, along the grid.)
func _ray_tree_blocked(eye: Vector3, dir: Vector3, t_max: float, near_clearance: float = 0.4, far_clearance: float = 0.3) -> bool:
	var d2 := Vector2(dir.x, dir.z)
	var l: float = d2.length()
	if l < 1e-4:
		return false
	var e2 := Vector2(eye.x, eye.z)
	var seen: Dictionary = {}
	var t: float = 0.0
	while t <= t_max + TREE_CELL:
		var q: Vector2 = e2 + d2 * t
		var c := Vector2i(int(floor(q.x / TREE_CELL)), int(floor(q.y / TREE_CELL)))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k := Vector2i(c.x + dx, c.y + dz)
				if seen.has(k) or not _tree_grid.has(k):
					continue
				seen[k] = true
				for e in _tree_grid[k]:
					var tp: Vector2 = e[0]
					var r: float = float(e[1]) * 0.8
					# solve |e2 + d2*s - tp| = r for the ray parameter s (3D parameter: d2 already carries the horizontal share)
					var f: Vector2 = e2 - tp
					var aa: float = d2.dot(d2)
					var bb: float = 2.0 * f.dot(d2)
					var cc: float = f.dot(f) - r * r
					var disc: float = bb * bb - 4.0 * aa * cc
					if disc < 0.0:
						continue
					var s: float = (-bb - sqrt(disc)) / (2.0 * aa)
					if s >= near_clearance and s <= t_max - far_clearance and eye.y + dir.y * s < float(e[2]):
						return true
		t += TREE_CELL * 0.5 / l
	return false


func _on_bear_roared(br: Ep2BearBrain, at: Vector3) -> void:
	_sfx3d("ep2_bear_roar", at + Vector3(0.0, 1.8, 0.0), 2.0, float(br.p.get("pitch", 1.0)), 90.0)
	for b in _bears:
		var o: Ep2BearBrain = b
		if o != br and not o.is_dead() and o.actor.visible:
			o.ally_roar(at)


func _on_bear_spotted(br: Ep2BearBrain) -> void:
	_alerts += 1
	if (_beat == Beat.SNEAK or _beat == Beat.REVEAL) and str(br.get_meta("group", "")) != "road" and _bark_cd <= 0.0 and _hold <= 0.0:
		_bark_cd = 8.0
		_begin_carry_line("vo_bull_spotted")


func _on_bear_swing(br: Ep2BearBrain) -> void:
	_sfx3d("ep2_bear_attack_%d" % (1 + (br.actor.get_instance_id() % 3)), br.actor.global_position + Vector3(0.0, 1.6, 0.0), 0.0,
		float(br.p.get("pitch", 1.0)), 50.0)


func _on_bear_swiped(br: Ep2BearBrain) -> void:
	var d: float = Vector2(br.actor.position.x - _player_pos.x, br.actor.position.z - _player_pos.z).length()
	if d < 2.9:
		_hurt("claw")


func _on_bear_died(br: Ep2BearBrain) -> void:
	armory.record_corpse(str(br.get_meta("corpse_id", "")), br.arrows, br.actor.has_meta("bow"))
	_kills += 1
	_sfx3d("ep2_bear_death_%d" % (1 + _kills % 3), br.actor.global_position + Vector3(0.0, 1.2, 0.0), 0.0, float(br.p.get("pitch", 1.0)), 70.0)
	var snore: AudioStreamPlayer3D = br.actor.get_meta("snore") if br.actor.has_meta("snore") else null
	if snore != null:
		snore.stop()
	# Lil Blunt only brags about a bear HE shot. A bear Bull dropped (or anything else) gets no line from him.
	if str(br.get_meta("killed_by", "")) == "player" and _hold <= 0.0 and _bark_cd <= 4.0:
		_bark_cd = 6.0
		_begin_carry_line("ep2_vo_bear_down_%d" % (1 + (_kills * 5) % 12))


## An archer let fly: a real arrow, aimed where Lil Blunt will be when it arrives (the quad moves), that hits or whistles past.
func _on_arrow_loosed(br: Ep2BearBrain, from: Vector3, _to: Vector3) -> void:
	_arrows_loosed += 1
	_sfx3d("ep2_bow_loose", from, 0.0, 1.0, 60.0)
	var chest: Vector3 = _player_pos + Vector3(0.0, maxf(eye_height - 0.3, 0.6), 0.0)
	var d: float = from.distance_to(chest)
	var flight: float = d / ARROW_SPEED
	var lead: Vector3 = chest + _player_vel * flight
	var p_hit: float = clampf(0.30 - d * 0.0045, 0.10, 0.28)
	if not _riding and _moving and _run_input:
		p_hit *= 0.5                                     # a sprinting target is hard to lead
	var hit: bool = _rng.randf() < p_hit
	var aim: Vector3 = lead
	if not hit:
		var to_t: Vector3 = (lead - from).normalized()
		var side := Vector3(-to_t.z, 0.0, to_t.x)
		aim = lead + side * (1.0 if _rng.randf() < 0.5 else -1.0) * (1.1 + 1.6 * _rng.randf()) + Vector3(0.0, _rng.randf() * 0.9 - 0.3, 0.0)
	var g: float = 3.4
	var v: Vector3 = (aim - from) / maxf(flight, 0.05) + Vector3(0.0, 0.5 * g * flight, 0.0)
	var node := _arrow_mesh()
	_visuals.add_child(node)
	node.global_position = from
	_arrows.append({"node": node, "pos": from, "v": v, "g": g, "t": 0.0, "flight": flight, "hit": hit, "stuck": false,
		"life": 0.0, "whizz": false, "from": br})


## Swept flight hits the first bear or trunk once; it never spends ammunition a second time.
func _tick_player_arrows(delta: float) -> void:
	for i in range(_player_arrows.size() - 1, -1, -1):
		var item: Dictionary = _player_arrows[i]
		var before: Vector3 = item["pos"]
		var velocity: Vector3 = item["v"]
		velocity.y -= 9.8 * delta
		var travel: Vector3 = velocity * delta
		var hit: Ep2BearBrain = _bear_on_ray(before, travel.normalized(), travel.length())
		var stopped: bool = hit != null or _ray_tree_blocked(before, travel.normalized(), travel.length(), 0.0, 0.0)
		if hit != null:
			hit.set_meta("killed_by", "player")
			var killed: bool = hit.take_hit(before)
			if _hud != null:
				_hud.hit_marker(killed)
		item["t"] = float(item["t"]) + delta
		item["pos"] = before + travel
		item["v"] = velocity
		var node: Node3D = item["node"]
		node.global_position = item["pos"]
		node.basis = Basis.looking_at(-velocity.normalized(), Vector3.UP)
		if stopped or float(item["t"]) > 4.0 or node.position.y < _ground_y:
			node.queue_free()
			_player_arrows.remove_at(i)


func _arrow_mesh() -> Node3D:
	return Ep2BowView.arrow()


func _tick_arrows(delta: float) -> void:
	var chest: Vector3 = _player_pos + Vector3(0.0, maxf(eye_height - 0.3, 0.6), 0.0)
	for i in range(_arrows.size() - 1, -1, -1):
		var ar: Dictionary = _arrows[i]
		var node: Node3D = ar["node"]
		if not is_instance_valid(node):
			_arrows.remove_at(i)
			continue
		ar["life"] = float(ar["life"]) + delta
		if bool(ar["stuck"]):
			if float(ar["life"]) > 40.0 or _arrows.size() > 40:
				node.queue_free()
				_arrows.remove_at(i)
			continue
		var t0: float = float(ar["t"])
		var t1: float = t0 + delta
		ar["t"] = t1
		var v: Vector3 = ar["v"]
		var p: Vector3 = ar["pos"]
		v.y -= float(ar["g"]) * delta
		p += v * delta
		ar["v"] = v
		ar["pos"] = p
		node.global_position = p
		if v.length() > 0.1:
			node.look_at(p + v, Vector3.UP, true)
		if not bool(ar["whizz"]) and p.distance_to(chest) < 4.0:
			ar["whizz"] = true
			_sfx3d("ep2_runner_arrow_flyby_0%d" % (1 + i % 2), p, 2.0, 1.0, 20.0)
		var flight: float = float(ar["flight"])
		if bool(ar["hit"]) and t0 < flight and t1 >= flight:
			if p.distance_to(chest) < 1.1:
				_arrow_hits += 1
				_hurt("arrow")
				node.queue_free()
				_arrows.remove_at(i)
				continue
			ar["hit"] = false                       # he moved: it flies on past
		if p.y <= 0.05 or t1 > 4.0:
			ar["stuck"] = true                       # into the ground, where it stays
			ar["life"] = 0.0
			p.y = maxf(p.y, 0.05)
			node.global_position = p
			if p.distance_to(chest) < 12.0:
				_sfx3d("ep2_arrow_thunk", p, -4.0, 1.0, 25.0)


## One heart less (claw or arrow), with a moment of grace; the last one ends the attempt.
func _hurt(cause: String) -> void:
	if _invuln > 0.0 or _failing or debug_invulnerable or _resolved:
		return
	_health -= 1
	_invuln = 1.3
	if _hud:
		_hud.hurt()
	_sfx("damage")
	if _hold <= 0.0:
		_speak("vo_hurt")
	if _health <= 0:
		_fail(cause)
	elif _riding and float(_road_lines.get("hurt", -100.0)) < _elapsed - 20.0:
		_road_lines["hurt"] = _elapsed
		_begin_carry_line("vo_bull_road_hurt")


func get_health() -> int:
	return _health


func _shows_health() -> bool:
	return true


## Out of hearts: the attempt ends (input, damage and the bears stop), the screen goes down, and the wood is restored at the mine exit.
func _fail(cause: String) -> void:
	if _failing:
		return
	_failing = true
	_fail_t = 0.0
	if _vm != null:
		_vm.set_aim(false)
	_fade(1.0, 0.55)
	if _hud:
		_hud.toast("MAULED!" if cause == "claw" else "STRUCK BY AN ARROW!", 1.8)


func _tick_fail(delta: float) -> void:
	_fail_t += delta
	if _fail_t >= 0.9:
		_retry_from_surface()


## CHECKPOINT hideout_surface_exit (design/ep2/LIVING_WOODS_CONTRACT.md): everything of this attempt rolls back together - bears
## (alive, in their routines), arrows, the quad under its leaves, Inferno at the bridge, hearts, ammunition - and play resumes at
## the mine exit with one line from Inferno. Nothing before the checkpoint (the lesson, the lava, the lift) is replayed.
func _retry_from_surface() -> void:
	if not _armory_snapshot.is_empty():
		armory.restore(_armory_snapshot)
	_attempt += 1
	for ar in _arrows:
		if is_instance_valid(ar["node"]):
			(ar["node"] as Node).queue_free()
	_arrows.clear()
	for item in _player_arrows:
		(item["node"] as Node3D).queue_free()
	_player_arrows.clear()
	for f in _flashes:
		if is_instance_valid(f[0]):
			(f[0] as Node).queue_free()
	_flashes.clear()
	if _bears_root != null and is_instance_valid(_bears_root):
		_bears_root.queue_free()
	_bears_root = null
	_bears.clear()
	_spawned = 0
	_intro_done.clear()
	for i in _specs.size():
		_spawn_bear(_specs[i], i)
	_spawned = _specs.size()
	# the quad back under its leaves
	_quad.position = QUAD_POS
	_quad.rotation = Vector3(0.0, QUAD_YAW, 0.0)
	_quad_yaw = QUAD_YAW
	_reveal_t = -1.0
	if _cover != null:
		_cover.visible = true
		for bit in _cover_bits:
			(bit[0] as Node3D).transform = bit[3]
	_riding = false
	_ride_done = false
	_ride_s = 0.0
	_ride_speed = 0.0
	if _engine:
		_engine.stop()
	if _quad_light:
		_quad_light.light_energy = 0.0
	# Inferno at the bridge, standing
	_bull_swing = {}
	_glide = {}
	_bull.stop()
	_bull.release("Left", 0.05)
	_bull.release("Right", 0.05)
	_bull.position = BULL_START
	_bull.facing = 0.0
	_bull.rotation.y = 0.0
	_bull_dismount()
	_bull_alarm = false
	_bull_waiting = false
	# Lil Blunt at the mine mouth, whole again, with the rounds he had there
	_player_pos = SPAWN
	_prev_player = SPAWN
	_player_vel = Vector3.ZERO
	_player_yaw = 0.0
	_look_yaw = 0.0
	_look_pitch = -0.04
	eye_height = FPS_EYE_HEIGHT
	_ground_y = 0.0
	_vel_y = 0.0
	_health = HEALTH_MAX
	_invuln = 1.5
	if _armory_snapshot.is_empty() and _vm != null and _ammo_snapshot.size() == 2:
		_vm.gun.rounds = int(_ammo_snapshot[0])
		_vm.gun.reserve = int(_ammo_snapshot[1])
	_scope_k = 0.0
	_rideoff = {}
	_dropoff_done = false
	_cart_s = CART_S0
	_cart_state = 0
	_cart_warned = false
	_bull_chat_cd = 20.0
	_bull_wait_t = 0.0
	_bull_wait_lock = 0.0
	_bull_ride_cd = 0.0
	if _cart != null:
		_place_cart(0.0)
	_road_lines.clear()
	_show_active = false
	_show_blocks_control = false
	if _show != null:
		_show.running = false
	release_look()
	_failing = false
	_retry_line_pending = true
	_advance_to(Beat.SNEAK)
	_fade(0.0, 0.8)
	if _hud:
		_hud.toast("BACK AT THE MINE EXIT", 2.0)


## Trunks are solid; the wood is the limit of the world until the drop-off; in the town street the buildings are.
func _collide(p: Vector3) -> Vector3:
	var q := p
	if _beat == Beat.DROPOFF:
		var c: Vector2 = Ep2GoldTown.collide(Vector2(q.x, q.z), 0.3, _town_col.get("walls", []), _town_col.get("props", []))
		q.x = clampf(c.x, -30.0, 30.0)
		q.z = clampf(c.y, Ep2GoldTown.TOWN_Z - 30.0, Ep2GoldTown.TOWN_Z + 90.0)
		return q
	q.x = clampf(q.x, -110.0, 110.0)
	q.z = clampf(q.z, -5.0, QUAD_POS.z + 40.0)
	for t in _trees_near(Vector2(q.x, q.z), 1):
		var tp: Vector2 = t[0]
		var d := Vector2(q.x - tp.x, q.z - tp.y)
		var r: float = float(t[1])
		if d.length() < r:
			var out: Vector2 = (d.normalized() if d.length_squared() > 1e-6 else Vector2(1.0, 0.0)) * r
			q.x = tp.x + out.x
			q.z = tp.y + out.y
	return q


# --- the farmer and his donkey (founder 2026-10-14: "on the road they should drive past the man on the cart with the donkey - slow down, pass him and wave") ---

func _build_cart() -> void:
	if not ResourceLoader.exists(CART_MODEL):
		return
	var holder := Node3D.new()
	holder.name = "DonkeyCart"
	var model: Node3D = (load(CART_MODEL) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * CART_SCALE
	model.rotation.y = -PI * 0.5                      # the model's nose is +X; the holder's +Z is the way it travels
	holder.add_child(model)
	_visuals.add_child(holder)
	_cart = holder
	_place_cart(0.0)


## Put the cart on its place on the road (right of the centre line), nose down the road, with a plodding bob.
func _place_cart(t: float) -> void:
	if _cart == null:
		return
	var smp: Array = _ride_sample(_cart_s)
	var yaw: float = float(smp[1])
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	var pos: Vector3 = (smp[0] as Vector3) + right * CART_LATERAL
	pos.y = 0.012 + 0.02 * absf(sin(t * 4.2))
	_cart.position = pos
	_cart.rotation = Vector3(0.012 * sin(t * 2.1), yaw, 0.01 * sin(t * 4.2))


## The cart plods on; the quad eases down behind it (so it does not spook the donkey), draws level, Inferno greets the farmer, Lil Blunt answers,
## and they open up again past him. Returns the speed this allows the quad.
func _tick_cart(delta: float) -> float:
	if _cart == null or _cart_state >= 3:
		return 99.0
	_cart_s += CART_SPEED * delta
	_place_cart(_elapsed)
	var gap: float = _cart_s - _ride_s                  # > 0: the cart is still ahead of them on the road
	var allow: float = 99.0
	if gap < 70.0 and gap > -10.0:
		allow = maxf(CART_SPEED + 2.7, CART_SPEED + 2.7 + (gap - 8.0) * 0.16)     # eases from the straight-road speed down to a stroll past him
		if _cart_state == 0:
			_cart_state = 1
		if not _cart_warned and gap > 16.0 and _hold <= 0.0 and not _show_active:
			_cart_warned = true
			_begin_carry_line("vo_bull_cart1")
	if _cart_state == 1 and gap < 13.0:
		_cart_state = 2
		_start_show([FacilityShow._say("vo_bull_cart2", 0.15), FacilityShow._say("vo_cart_man", 0.15), FacilityShow._say("vo_lb_cart", 0.1)])
	if gap < -24.0:
		_cart_state = 3                                  # behind them now: the road opens up again
	return allow


func get_cart_state() -> int: return _cart_state
func get_cart_node() -> Node3D: return _cart


# --- out of the woods: the desert, the town, the drop-off (founder lock 2026-10-14) ------------------------------------------

## The town and Fort Knox (Ep2GoldTown - the SAME build the town chamber makes, at the same coordinates).
func _build_town() -> void:
	_town_col = Ep2GoldTown.build(_visuals, false)


## Gold-rush country between the last pines and the town (Ep2GoldTown.build_desert - the same scrub, rocks and mesas the town chamber
## builds, so the drop-off cut is invisible), then the distant riders.
func _build_desert() -> void:
	Ep2GoldTown.build_desert(_visuals, RIDE_TRAIL, FOREST_END_Z, WORLD_END_Z, _kit_meshes.get("Fern", null), _rock_mesh, _dry_scrub_mat(), _desert_rock_mat())
	_build_riders()


func _dry_scrub_mat() -> ShaderMaterial:
	return Ep2GoldTown.scrub_mat()


func _desert_rock_mat() -> StandardMaterial3D:
	return Ep2GoldTown.desert_rock_mat()


var _riders: Array = []                               # [Node3D, Vector3 a, Vector3 b, float t, float period]


## One or two distant riders on the hills: they ride slowly to and fro far off the road and never come near (spec beat 1).
func _build_riders() -> void:
	const RIDER := "res://src/episode2/assets/town/distant_rider.glb"
	if not ResourceLoader.exists(RIDER):
		return
	for spec in [[Vector3(-120.0, 0.0, 1120.0), Vector3(-160.0, 0.0, 1240.0), 70.0], [Vector3(150.0, 0.0, 1290.0), Vector3(110.0, 0.0, 1380.0), 90.0]]:
		var r: Node3D = (load(RIDER) as PackedScene).instantiate() as Node3D
		r.name = "DistantRider"
		_visuals.add_child(r)
		r.position = spec[0]
		_riders.append([r, spec[0], spec[1], 0.0, float(spec[2])])


func _tick_riders(delta: float) -> void:
	for rd in _riders:
		rd[3] = float(rd[3]) + delta
		var k: float = 0.5 - 0.5 * cos(TAU * float(rd[3]) / float(rd[4]))
		var a: Vector3 = rd[1]
		var b: Vector3 = rd[2]
		var n: Node3D = rd[0]
		var prev: Vector3 = n.position
		n.position = a.lerp(b, k)
		var mv: Vector3 = n.position - prev
		if mv.length() > 1e-4:
			n.rotation.y = atan2(mv.x, mv.z)


## The woods' golden hour warms into gold-rush desert light over the road between the last pines and DESERT_FULL_Z.
func _grade_desert(z: float) -> void:
	if light_grade != "golden" or _env_node == null or _env_node.environment == null:
		return
	var k: float = clampf((z - (FOREST_END_Z - 120.0)) / (DESERT_FULL_Z - (FOREST_END_Z - 120.0)), 0.0, 1.0)
	if absf(k - _desert_k) < 0.01:
		return
	_desert_k = k
	Ep2GoldTown.apply_desert_grade(_env_node.environment, _sun, k)


## THE DROP-OFF (founder 2026-10-14): in the main street Bull tells him about his blonde lady friend (a grin, nothing shown), sends him to
## the certificate office and says he'll meet him at the bar; Lil Blunt hops off (his eye glides down, no cut) and Bull rides off on
## the quad down the street and away. Then the town chamber takes over in one invisible cut.
func _begin_dropoff() -> void:
	_riding = false
	_grade_desert(Ep2GoldTown.TOWN_Z)
	if _hud:
		_hud.objective = ""
	var r := Vector3(-cos(_quad_yaw), 0.0, sin(_quad_yaw)) * -1.0
	var off: Vector3 = _quad.position + r * 2.2 + Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw)) * -0.8
	off.y = 0.0
	_start_show([
		FacilityShow._say("vo_bull_drop1", 0.25),
		{"do": "call", "fn": func() -> void: _glide_to(off, FPS_EYE_HEIGHT, 1.0, 0.15)},
		{"do": "wait", "t": 1.05},
		{"do": "call", "fn": func() -> void: look_toward(_bull.position + Vector3(0.0, 2.2, 0.0), 3.0)},
		FacilityShow._say("vo_bull_drop2", 0.2),
		FacilityShow._say("vo_lb_drop", 0.2),
		{"do": "call", "fn": _bull_ride_off},
		{"do": "wait", "t": 1.2},
		{"do": "call", "fn": release_look}], true)


## Bull opens the throttle and rides away up the street, round the church and off - the engine fading with the distance.
func _bull_ride_off() -> void:
	var start: Vector3 = _quad.position
	_rideoff = {"pts": [start, Vector3(0.0, 0.0, 1440.0), Vector3(2.0, 0.0, 1466.0), Vector3(16.0, 0.0, 1478.0), Vector3(70.0, 0.0, 1500.0),
		Vector3(160.0, 0.0, 1520.0)], "s": 0.0, "v": 0.0}
	_sfx("ep2_quad_start")


func _tick_dropoff(delta: float) -> void:
	if not _rideoff.is_empty():
		var pts: Array = _rideoff["pts"]
		_rideoff["v"] = minf(float(_rideoff["v"]) + 4.0 * delta, 11.0)
		_rideoff["s"] = float(_rideoff["s"]) + float(_rideoff["v"]) * delta
		var s: float = float(_rideoff["s"])
		var i: int = 0
		var acc: float = 0.0
		while i < pts.size() - 1 and acc + (pts[i + 1] as Vector3).distance_to(pts[i]) < s:
			acc += (pts[i + 1] as Vector3).distance_to(pts[i])
			i += 1
		if i < pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var t: float = clampf((s - acc) / maxf(a.distance_to(b), 0.01), 0.0, 1.0)
			_quad.position = a.lerp(b, t)
			_quad_yaw = lerp_angle(_quad_yaw, atan2(b.x - a.x, b.z - a.z), clampf(5.0 * delta, 0.0, 1.0))
			_quad.rotation = Vector3(0.0, _quad_yaw, 0.0)
			for w in _quad_wheels:
				(w as Node3D).rotation.x += float(_rideoff["v"]) * delta / (QUAD_WHEEL_R if _quad_modelled else 0.68)
			_bull.position = _bull_seat_position()
			_bull.facing = _quad_yaw
			_bull.rotation.y = _quad_yaw
		var far: float = _quad.position.distance_to(_player_pos)
		if _engine:
			_engine.pitch_scale = 0.9 + 0.3 * clampf(float(_rideoff["v"]) / 11.0, 0.0, 1.0)
			_engine.volume_db = -7.0 - 26.0 * clampf(far / 120.0, 0.0, 1.0)
		if far > 110.0 or i >= pts.size() - 1:
			if _quad.visible:
				_quad.visible = false
				_bull.visible = false
				if _engine:
					_engine.stop()
	# he is out of sight and the town is built: hand over to the town chamber (one cut, same street)
	if _dropoff_done and (_quad == null or not _quad.visible) and _handoff_ok() and not _resolved:
		_resolve({"next_chamber": "gold_town"})


func get_handoff() -> Dictionary:
	var h: Dictionary = super.get_handoff()
	h["pos"] = _player_pos
	return h


func _wants_handoff() -> bool:
	return _beat == Beat.DROPOFF and _dropoff_done and is_bull_gone()


func is_bull_gone() -> bool:
	return _quad != null and not _quad.visible


# --- sound -----------------------------------------------------------------------------------------------------------------

## A committed sound by id (src/assets/sounds/<id>.ogg|.mp3|.wav, or the Episode 2 audio folder), cached.
func _sound(id: String) -> AudioStream:
	if _sounds.has(id):
		return _sounds[id]
	var st: AudioStream = null
	for p in ["res://src/assets/sounds/%s.ogg", "res://src/assets/sounds/%s.mp3", "res://src/assets/sounds/%s.wav",
			"res://src/episode2/assets/audio/%s.wav", "res://src/episode2/assets/audio/%s.mp3", "res://src/episode2/assets/audio/%s.ogg"]:
		var path: String = (p as String) % id
		if ResourceLoader.exists(path):
			st = load(path)
			break
	_sounds[id] = st
	return st


## A one-shot positional sound in the wood (growls, roars, bowstrings, arrows, Inferno's rifle).
func _sfx3d(id: String, at: Vector3, db: float = 0.0, pitch: float = 1.0, max_d: float = 60.0) -> void:
	var st: AudioStream = _sound(id)
	if st == null or _visuals == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = db
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.max_distance = max_d
	p.unit_size = 8.0
	_visuals.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


## Bodies stay until this encounter is disposed or retried. Search is a once-only resource transaction.
func _nearby_corpse() -> Ep2BearBrain:
	if not has_player_control() or _riding or not _glide.is_empty():
		return null
	var nearest: Ep2BearBrain = null
	var best: float = 2.8
	var eye := Vector2(_player_pos.x, _player_pos.z)
	var forward := Vector2(sin(_look_yaw), cos(_look_yaw))
	for bear in _bears:
		var br: Ep2BearBrain = bear
		var id: String = str(br.get_meta("corpse_id", ""))
		if not br.is_dead() or not armory.corpses.has(id) or bool(armory.corpses[id]["searched"]):
			continue
		var pos := Vector2(br.actor.position.x, br.actor.position.z)
		var offset: Vector2 = pos - eye
		var distance: float = offset.length()
		if distance < best and (distance < 0.5 or offset.normalized().dot(forward) > 0.5) and not _los_blocked(eye, pos):
			nearest = br
			best = distance
	return nearest


func _search_nearby() -> void:
	start_rig()


func start_rig(_mode: String = "eth") -> bool:
	var body: Ep2BearBrain = _nearby_corpse()
	if body == null:
		return false
	var count: int = armory.claim_corpse(str(body.get_meta("corpse_id")))
	if count < 0:
		return false
	if _hud != null:
		_hud.toast("Recovered bear bow · %d arrows" % count if bool(armory.corpses[str(body.get_meta("corpse_id"))].get("bow", false)) else "Recovered %d bear arrows" % count if count > 0 else "No arrows recovered", 1.8)
	return true
