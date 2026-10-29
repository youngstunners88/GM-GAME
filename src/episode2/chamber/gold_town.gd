class_name GoldTownChamber
extends Ep2Interlude
## THE GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; skills ep2-surface-to-town,
## ep2-gold-rush-town, ep2-sheriff-jake, ep2-quickdraw-duel). Bull has dropped Lil Blunt in the main street and ridden off to see
## his blonde lady friend. The town chamber takes over in the same street (one invisible cut: Ep2GoldTown builds the town and the
## desert at the same coordinates in both rooms) and plays the rest of the slice in first person, the Winchester in his hands:
##
##   STREET    walk to the CERTIFICATES office
##   OFFICE    The Sheriff (the founder's own character: weathered, long duster, star, a wisp of smoke) and Minister Mike Dean (the certificate book) behind the counter: the certificate is made out in your
##             name, can't be sold on or traded, bring your share and he stamps it (whitepaper-faithful, no invented numbers)
##   TO_BAR    cross the street to the SALOON
##   BAR       a whiskey, a quarter of a Bitcoin on the bar, the bartender's jaw drops, a stranger at the end of the bar noticed -
##             "Give me a Bitcoin in exchange for the map to the auction, where you can get more gold and Bitcoin." Lil Blunt won't. the Sheriff walks
##             in: he is the witness
##   SQUARE_UP out in the street, face him; the Sheriff stands to the side
##   DRAW      the rifle stays down until the town bell rings (a seeded wait). Fire early = a foul, the Sheriff makes them redo it. Hit him first
##             = the map. Too slow = he shoots first: the screen drops, hearts restored, the Sheriff sets it up again (retry, never a death)
## POST-DRAW - THE LOCKED STORY ORDER (founder fix pack 2026-10-27 section 2, docs/founder-feedback/2026-10-27_fix_pack.md; it replaces the
## 2026-10-25 order and keeps its scenes):
##   WON       he wins: the stranger had drawn a Colt Single Action Army (the Peacemaker) from his hip; it falls by the body, which bleeds.
##             The street celebrates, then dances. Inferno does NOT arrive.
##   LOOT      E at the body takes the Peacemaker and the map to the auction (the map is never handed over without it)
##             ...then Minister Mike Dean runs out of his office, alarmed, asks what happened, and kneels to pray over the gentleman
##   JOB       Sheriff James, impressed with the draw, offers the job (who let the bears hold Fort Knox) and leads him to the jail
##   JAIL_TIP / JAIL  the Sheriff walks him out to the jailhouse; the prisoner talks; THEN the Sheriff sends him to Rich & Utah
##   TIP       the tip: RICH keeps an armory down the side lane off the left row (off Main Street, deliberately not obvious)
##   ARMORY    Rich the Claim Recorder and Utah: the trade (E at the counter: firearms, ammunition, river gear for Episode 1 crypto) and
##             the Colt Gatling in the yard (it hits the targets and sounds intense)
##   BULL_BACK after the Gatling: Inferno rides back in on his quad, parks outside Rich's; the first whiskey's on him
##   BODY      on the way: Mike Dean again, still praying by the body; Inferno greets him - "Must've been a bird ..."
##   DRINKS    the bar: they really drink (Inferno lifts his glass, Lil Blunt's comes up to the camera); Inferno has to help his cousin
##             Flux with his new kettle, and leaves him a gift for Mike Dean: THE GOLD PANNER
##   MINISTER2 the second visit: Lil Blunt brings Mike Dean the Gold Panner; Mike Dean stamps the certificate (the first visit refused)
##             and sends him to his friend Dude at the horse stables
##   STABLES   Dude: the Minister sent him; they agree a price in BTC for the horse; Dude offers his Chill Buds (Tabs health); then
##             "Logan's Lake first" - the horse needs to drink in this heat (the lake is on the map)
##   GEARED    on the way out of town (with the long rifle and the river gear: else first back to Rich's counter for them)
##   DONE      the ride to Logan's Lake (LakeTrailChamber: bandits on the way), then Logan. Fort Knox stays the climax - never opened here.
## Never in this room: the banned Episode 2 protocol (ep2-fort-knox-arc rule 4), a second health system, a wallet or contract address.
## The Armory never mints and is NOT the Treasury: the Treasury keeps no racks and no trade (lock section 7).

enum Beat { STREET, OFFICE, TO_BAR, BAR, SQUARE_UP, DRAW, WON, LOOT, JOB, JAIL_TIP, JAIL, TIP, ARMORY, BULL_BACK, BODY, DRINKS, MINISTER2,
	STABLES, GEARED, DONE }

## Explicit load as well as class_name: the headless gates do not rescan the global class cache for a newly added script.
const TOWN_BUMPS = preload("res://src/episode2/actors/ep2_town_bumps.gd")

## The post-draw lines (section 4). Timed captions: no voice key is configured on this box, so like the jailhouse's they are text, and a
## recording dropped into Ep2TownVoiceBank under the same speaker + text plays automatically. Lil Blunt's bird line is the founder's own.
const BLOOD_FX = preload("res://src/episode2/fx/ep2_blood_fx.gd")

const PANIC_LINES: Array = [
	["MIKE DEAN", "Lord have mercy! What in heaven's name happened out here?"],
	["SHERIFF", "A fair draw, Minister. The stranger called it. The little fella was faster."],
	["MIKE DEAN", "Then somebody had better pray for that poor soul. I'll see to him."],
]
const JOB_LINES: Array = [
	["SHERIFF", "That was some fine shooting, son. Haven't seen a draw that clean in years."],
	["SHERIFF", "I could use a hand like yours. Somebody let the bears hold Fort Knox."],
	["SHERIFF", "Find out who. My prisoner in the jailhouse knows more than he's telling."],
]
## Section 2 step 4: the Sheriff LEADS him to the jail (when the jailhouse is streamed in), and only after it sends him to Rich & Utah.
const JOB_TO_JAIL_LINES: Array = [
	["SHERIFF", "Come on. I'll walk you over, and you can hear it from him yourself."],
	["LIL BLUNT", "Lead the way, Sheriff."],
]
const ARMORY_SEND_LINES: Array = [
	["SHERIFF", "But get yourself properly armed first. Go see Rich and Utah, down the side lane."],
	["LIL BLUNT", "Rich and Utah. I'm on it, Sheriff."],
]
## The loot at the body (section 2 step 2): his Peacemaker and the map to the auction.
const LOOT_LINES: Array = [
	["LIL BLUNT", "A Colt Peacemaker. And the map to the auction - that's what he wanted a Bitcoin for."],
]
const BULL_BACK_LINES: Array = [
	["INFERNO", "Heard that Gatling clear across town. Figured it had to be you, little man."],
	["INFERNO", "Come on. First whiskey's on me."],
]
const BODY_LINES: Array = [
	["INFERNO", "Evening, Minister."],
	["MIKE DEAN", "Evening, Inferno. Just saying a few words for him."],
	["INFERNO", "So who put a hole in his head?"],
	["LIL BLUNT", "Must've been a bird that had to get rid of the heavy load."],
	["INFERNO", "A bird. Sure it was."],
]
const DRINK_LINES: Array = [
	["BARTENDER", "Two whiskeys, coming right up."],
	["INFERNO", "To the quickest little hand in GoldMine."],
	["LIL BLUNT", "Cheers."],
]
## ...they drink (section 2 step 7: visible drinking, not pantomime), then Flux's kettle, and Inferno's gift for Mike Dean (step 9).
const FLUX_LINES: Array = [
	["INFERNO", "Listen, my cousin Flux needs a hand with his new kettle."],
	["INFERNO", "We'll lie low a little while and meet up later. Stay out of trouble."],
]
const GIFT_LINES: Array = [
	["INFERNO", "Oh - and take this to Mike Dean for me. The Gold Panner. He's had his eye on it for years."],
	["LIL BLUNT", "The Gold Panner. I'll see he gets it."],
]
## The second visit to the certificate office (section 2 steps 9-10): the gift, the stamp, the referral to Dude.
const MINISTER2_LINES: Array = [
	["LIL BLUNT", "Minister. Inferno sent you this. The Gold Panner."],
	["MIKE DEAN", "The Gold Panner! Bless that big fella, he remembered."],
	["MIKE DEAN", "And your certificate, son. Made out in your name - stamped and sealed."],
	["LIL BLUNT", "Much obliged, Minister."],
	["MIKE DEAN", "You'll want a horse for the trail. Go see my friend Dude at the horse stables. Tell him I sent you."],
]
## The drink itself: Inferno's Stand_and_Drink (the hideout's clip) and Lil Blunt's glass up to the camera, then down.
const FP_DRINK_S := 2.4
const FP_GLASS_DOWN := Vector3(0.13, -0.30, -0.42)          # camera space: the glass held low at the bar
const FP_GLASS_LIP := Vector3(0.03, -0.12, -0.24)          # ...at his lips, tipped
const LOOT_R := 2.4                                         # how close to the body [E] takes the gun and the map
## The stranger's Peacemaker: in its holster on his gun-hand hip until the bell (his own frame, metres; the gun side is -x, as in
## COWBOY_HAND_DRAW), barrel down.
const OPP_HOLSTER := Vector3(-0.21, 0.93, 0.04)
## Inferno's ride back in: the road he left town on, reversed (woods_quad.gd _bull_ride_off), up the lane to Rich's. He parks east of the
## shop door, clear of the Gatling yard to the west (Ep2GoldTown.GATLING_POST) and of the lane walk.
const QUAD_RETURN: Array = [Vector3(70.0, 0.0, 1500.0), Vector3(16.0, 0.0, 1478.0), Vector3(2.0, 0.0, 1466.0), Vector3(0.0, 0.0, 1452.0),
	Vector3(-12.0, 0.0, 1452.0)]
const QUAD_PARK_LOCAL := Vector3(-5.2, 0.0, 4.2)           # in the Armory's frame (x along the front, +z out of the door)
const MINISTER_RUN := 3.1                                  # m/s: his panic run (the CMU run's own stride, 2.44 m/s, plays a little quick)
const MINISTER_RUN_STRIDE := 2.44
const MINISTER_WALK := 1.15
const KNEEL_AT := Vector3(0.95, 0.0, -0.45)                # where the Minister kneels, from the fallen stranger
const BODY_NEAR := 7.5                                     # how close Lil Blunt comes to the body before Inferno speaks
const GATLING_TESTED_HOLD := 1.4                           # seconds after he steps off the crank before Inferno is heard coming

# Founder 2026-10-28: restore the earlier Sheriff appearance, retaining his dialogue and voice.
# The previous model and textures are restored into streamed extras to preserve the main-pack budget.
const SHERIFF_MODEL := "res://src/episode2/extras/people/previous_sheriff/sheriff_walk.glb"
const SHERIFF_WALK_STRIDE := 0.81                         # m/s: his Walk clip's own ground speed (stride matching)
const MINISTER_MODEL := "res://src/episode2/assets/town/minister.glb"      # Minister Mike Dean: the founder's robot-headed minister (Drive 2026-10-14), baked for the pack
const COWBOY_MODEL := "res://src/episode2/assets/town/cowboy.glb"        # the stranger: a HUMAN cowboy (child meshes "Idle" and "Draw")
const BARTENDER_MODEL := "res://src/episode2/assets/town/bartender.glb"  # the barman: a human too - the town has no bears
const COWBOY_HEIGHT := 1.84
## His gun hand in the Draw pose, as a fraction of his height (x right, y up, z forward; measured in Blender by prep_founder_town_models.py).
const COWBOY_HAND_DRAW := Vector3(-0.18, 0.75, 0.10)
const BARTENDER_HEIGHT := 1.76
const WHISKEY_MODEL := "res://src/episode2/assets/whiskey_glass.glb"
const COIN_MODEL := "res://src/episode2/assets/btc_coin.glb"
const SHERIFF_HEIGHT := 1.78
const ACCOMPLICE_HEIGHT := 1.74
const MINISTER_HEIGHT := 1.65
const MINISTER_STEP := 0.5                               # the low wooden step he stands on behind the counter, so the counter does not hide him
## In each building's local frame (x along the front, -z inside).
## Where the smoke rises on the Sheriff, as a fraction of his height (x his left, y up, z forward): Sheriff James's pipe bowl, which
## hangs from the left corner of his mouth.
const SHERIFF_MOUTH := Vector3(0.03, 0.855, 0.095)
const MINISTER_DESK := Vector3(0.6, 0.0, -5.7)          # Minister Mike Dean behind the certificate counter, the certificate book open
const SHERIFF_OFFICE_AT := Vector3(-2.3, 0.0, -2.9)     # the Sheriff by the stove, where he greets whoever walks in
const OFFICE_SPOT := Vector3(0.6, 0.0, -3.4)          # where Lil Blunt stands at the counter
const BAR_SPOT := Vector3(-0.6, 0.0, -7.7)            # at the saloon bar
const BARTENDER_AT := Vector3(-0.8, 0.0, -10.0)
const OPP_AT_BAR := Vector3(2.5, 0.0, -7.6)
const SHERIFF_SALOON := Vector3(1.4, 0.0, -2.2)           # just inside the saloon door
## The duel in the street (world).
const DUEL_MARK := Vector3(0.0, 0.0, 1417.0)
const OPP_MARK := Vector3(0.0, 0.0, 1432.0)
const WITNESS_MARK := Vector3(-5.4, 0.0, 1424.5)
const DRAW_WAIT_MIN := 1.8
const DRAW_WAIT_MAX := 4.2
const OPP_REACTION := 1.45                            # seconds from the bell to his shot on the first try (the rifle must come up)
const OPP_REACTION_STEP := 0.3                        # ...a little more each time he wins (never a wall)
const OPP_HIT_R := 0.5
## The Armory (Rich & Utah, down the side lane). Bodies are on-box Blender figures (tools/ep2_blender/
## build_armory_folk.py); Rich is taller and broader in a long duster and wide-brim hat, Utah slimmer in a
## short open jacket with a flat brim and a bandana, so the two read apart at a glance (and at the river later).
const RICH_MODEL := "res://src/episode2/assets/town/rich_armory.glb"
const UTAH_MODEL := "res://src/episode2/assets/town/utah_armory.glb"
const RICH_HEIGHT := 1.86
const UTAH_HEIGHT := 1.74
## The two-storey Armory's Tripo Rich and Utah (heights incl. hat) and walk speeds matched to their Walk clip's stride (measured
## by tools/ep2_motion/retarget_bvh.py: Utah 0.86 m/s, Rich ~0.76 m/s at his scale) so their feet never skate.
const RICH2_HEIGHT := 1.80
const UTAH2_HEIGHT := 1.85
const RICH2_WALK := 0.76
const UTAH2_WALK := 0.86
## In the Armory's local frame (x along the front, -z inside). Rich behind the counter (the sales side), Utah
## working the crates and racks behind him.
const RICH_AT := Vector3(-0.7, 0.0, -5.7)
const UTAH_AT := Vector3(1.3, 0.0, -6.4)
const ARMORY_SPOT := Vector3(0.4, 0.0, -3.1)          # where Lil Blunt stands at the counter
const ARMORY_TRADE_R := 2.4                           # how close he must be for [E] to open the trade
## The lane he is pointed down (world) and the door mouth of the shop.
const LANE_MARK := Vector3(-12.0, 0.0, 1452.0)
## Feel-value prices in Episode 1 crypto coins (F - free to hunt/tune, never a protocol fact).
const PRICE_SNIPER := 3
const PRICE_RIVER_GEAR := 2
const SNIPER_BOX := 10
const RIFLE_BOX := 24
const REVOLVER_BOX := 18

## The Sharps 1874 and the Colt Gatling (founder 2026-10-20, skill ep2-armory-guns). The rifle Rich lifts out of the lit case is the long rifle he sells
## ("sniper" in Ep2ArmoryState.SHOP); the Gatling stands on its post in the yard OUTSIDE the shop and is never for sale.
const HOLD_RICH := "hand_l"                            # the bone each man carries the rifle on (Ep2TownFolk.attach_prop matches loosely)
const HOLD_UTAH := "RightHand"
const SHARPS_HOLD_POS := Vector3(0.0, 0.10, 0.02)      # in the hand bone's frame (tuned against the InspectRifle clip, see tools/ep2_shots/armory_guns_shot.gd)
const SHARPS_HOLD_ROT := Vector3(0.0, 0.0, 90.0)
const MOUNT_R := 2.6                                   # how close to the post's stand he must be to take the crank
const MOUNT_FOV := 66.0

var _town_col: Dictionary = {}
var _sheriff: Ep2TownFolk = null
var _minister: Ep2TownFolk = null
var _sheriff_delay: float = 0.0
var _sheriff_goes: Array = []                            # where the Sheriff walks once his delay has run out
var _sheriff_smoke: CPUParticles3D = null
var _bartender: Ep2TownFolk = null
var _opp: Ep2TownFolk = null
var _revolver: Node3D = null
var _glass: Node3D = null
var _coin: Node3D = null
var _rng := RandomNumberGenerator.new()
var _player_drawn: bool = false
var _draw_state: String = ""                          # "" | "wait" | "go" | "won" | "lost" | "foul"
var _opp_pool: Node3D = null                         # made only after the winning fall has finished
var _draw_t: float = 0.0
var _draw_wait: float = 0.0
var _losses: int = 0
var _fouls: int = 0
var _got_map: bool = false
var _bull_arrived: bool = false
var _end_t: float = -1.0
var _duel_ready: bool = false
var _flash_t: float = 0.0
var _flash: OmniLight3D = null
var _rich: Ep2TownFolk = null
var _utah: Ep2TownFolk = null
var _people: Ep2TownPeople = null                # the townsmen and townswomen on Main Street (streamed extras)
var _rich_brain: Ep2ArmoryBrain = null          # the two-storey Armory only
var _utah_brain: Ep2ArmoryBrain = null
var _shop: Ep2ArmoryShop = null
var _shop_layer: CanvasLayer = null
var _shop_open: bool = false
var _shop_bought: bool = false
var _town_audio: Ep2TownSoundscape = null
var _bumps: TOWN_BUMPS = null
var _law: Ep2TownLaw = null
var _fine_toast_t: float = 0.0
var _fine_toast_text: String = ""
var _stable_yard: Ep2StableYard = null
var _stable_prompt_shown: bool = false
signal stable_voice_requested(line_id: String, voice_id: String)
signal draw_bell_rung
## A post-draw caption was shown (speaker, text) - test evidence for the section 4 lines.
signal captioned(who: String, text: String)
var _geared: bool = false                             # rifle + river gear in hand
var _gear_t: float = -1.0
var _armory_visited: bool = false                     # he found the lane and walked in
## The jailhouse (founder lock 2026-10-20): the Sheriff's prisoner knows who brought the bears.
var _accomplice: Ep2TownFolk = null
var _jail_visited: bool = false
var _jail_done_t: float = -1.0
var _investigation_open: bool = false                 # the hunt is on: lake -> river -> trains -> Fort Knox
var _spent: int = 0                                   # crypto spent at the counter (test evidence)
## The two hero guns (ep2-armory-guns).
var _gatling: Ep2GatlingPost = null                   # the Colt on its post in the yard (streamed extras; null when they are not mounted)
var _mounted: bool = false                            # he is at the crank: the bore is his view and his mouse
var _sharps_case: Node3D = null                       # the Sharps in the lit case
var _sharps_hand: Node3D = null                       # ...and the same rifle once Rich has lifted it out
var _intro: Ep2ArmoryIntro = null                     # Rich and Utah introduce the two guns
var _intro_asked: bool = false
var _mount_bursts: int = 0                            # bursts fired from the post (test evidence)
var _mouse_before: int = Input.MOUSE_MODE_CAPTURED
## The post-draw (section 4).
var _minister_rigged: bool = false                    # the rigged Mike Dean (streamed): runs, kneels, prays; else the old statue
var _minister_task: String = ""                       # "" | "panic" (running out) | "asked" | "to_body" | "kneeling"
var _minister_t: float = 0.0
var _panic_done: bool = false
var _won_t: float = 0.0
var _job_said: bool = false
var _gat_tested_t: float = -1.0                       # >= 0 once he has fired the Gatling and stepped off: Inferno's cue
var _armory_t: float = 0.0
var _armory_return: bool = false                      # back at Rich's after the jail, only to gear up for the river
var _quad: Ep2TownQuad = null
var _bull_riding: bool = false
var _bull_task: String = ""                           # "" | "riding" | "to_lb" | "greeted" | "to_body" | "at_body" | "to_bar" | "at_bar" | "leaving"
var _body_said: bool = false
var _drinks_said: bool = false
var _glass2: Node3D = null
## The locked order's new steps (fix pack 2026-10-27 section 2).
var _got_peacemaker: bool = false                     # E at the body took the stranger's Colt
var _loot_prompt: bool = false
var _jail_sent: bool = false                          # the Sheriff has sent him on to Rich & Utah after the jail
var _fp_glass: Node3D = null                          # Lil Blunt's own glass, on the camera while he drinks
var _fp_drink_t: float = -1.0                         # >= 0 while that glass is up
var _bull_sip_t: float = -1.0                         # >= 0 while Inferno drinks
var _drinks_done: int = 0                             # drinks taken at the bar (test evidence)
var _gold_panner: bool = false                        # Inferno's gift, until it is handed to Mike Dean
var _panner_given: bool = false
var _stamped: bool = false                            # the certificate's stamp (the second visit)
var _minister2_said: bool = false
var _horse_bought: bool = false
var _depart_mounted: bool = false
var _depart_from := Vector3.ZERO
const DEPART_HORSE := Vector3(-13,0,1230)


func _init() -> void:
	title_card = "GOLDMINE"
	music_path = ""                                   # the ride's song carries on into the street (one motion)
	walk_speed = 3.0
	viewmodel_exposure = 0.8                          # desert daylight: the rifle's metal would read cream
	camera_min = Vector3(-300.0, 0.4, 1000.0)
	camera_max = Vector3(300.0, 80.0, 1800.0)


func _chamber_id() -> String:
	return "gold_town"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- the set ----------------------------------------------------------------------------------------------------------

func _build_room() -> void:
	for s in _build_steps():
		(s as Callable).call()


func _build_steps() -> Array:
	return [_step_light, _step_ground, _step_town, _step_desert, _step_people, _step_town_audio]


func _step_town_audio() -> void:
	_town_audio = Ep2TownSoundscape.new()
	_town_audio.name = "TownSoundscape"
	add_child(_town_audio)
	if _people != null:
		_people.greeted.connect(func(id: String, actor: Ep2TownFolk, count: int) -> void: _town_audio.greet(id, actor, count))
		_people.cold_greeted.connect(_on_person_cold)


func _town_speaker(who: String) -> String:
	return {"RICH": "rich", "UTAH": "utah", "SHERIFF": "sheriff", "ACCOMPLICE": "prisoner", "LIL BLUNT": "lil_blunt",
		"MIKE DEAN": "minister", "DUDE": "dude", "BAM": "bam"}.get(who, who.to_lower())


func _town_line(who: String, text: String) -> void:
	var id: String = Ep2TownVoiceBank.id_for(_town_speaker(who), text)
	if _hud != null:
		_hud.toast("%s: %s" % [who, text], Ep2TownVoiceBank.seconds(id))
	if id != "": _speak(id)


func _vo_len(id: String) -> float:
	if Ep2TownVoiceBank.LINES.has(id):
		return maxf(0.5, Ep2TownVoiceBank.seconds(id) - 0.25)
	return super._vo_len(id)


func _speak(id: String) -> void:
	if not Ep2TownVoiceBank.LINES.has(id):
		super._speak(id)
		return
	if _town_audio != null: _town_audio.silence_greeting()
	line_spoken.emit(id)
	var recording: AudioStream = Ep2TownVoiceBank.stream(id)
	if recording == null: return  # A missing new cast take must not play the retired sheriff instead.
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null: am.play_voice(id, recording)


func _warm_views() -> Array:
	var eye: Vector3 = Ep2GoldTown.DROP_POINT + Vector3(-2.0, 1.55, 0.0)
	return [{"eye": eye, "yaw": 0.0, "pitch": -0.03}, {"eye": eye, "yaw": -1.4, "pitch": -0.03}, {"eye": eye, "yaw": 1.4, "pitch": -0.03},
		{"eye": eye, "yaw": PI, "pitch": -0.03}, {"eye": Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 1.55, -2.0)), "yaw": -PI * 0.5, "pitch": 0.0},
		{"eye": Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.0, 1.55, -3.0)), "yaw": PI * 0.5, "pitch": 0.0}]


func _step_light() -> void:
	var env := Environment.new()
	_env_node.environment = env
	Ep2GoldTown.apply_desert_grade(env, _sun, 1.0)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _step_ground() -> void:
	var dg := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, 1300.0)
	dg.mesh = pm
	dg.material_override = Ep2GoldTown.desert_ground_mat()
	dg.position = Vector3(0.0, -0.012, 1450.0)
	dg.name = "DesertFloor"
	_visuals.add_child(dg)


func _step_town() -> void:
	_town_col = Ep2GoldTown.build(_visuals, true)
	# the counter and the bar are solid (Lil Blunt stands at them, the sheriff and the barman behind)
	var walls: Array = _town_col.get("walls", [])
	for seg in [["Bldg_Certificates", Vector3(-1.45, 0, -4.2), Vector3(2.65, 0, -4.2)], ["Bldg_Saloon", Vector3(-5.1, 0, -8.55), Vector3(3.1, 0, -8.55)]]:
		var a: Vector3 = Ep2GoldTown.local_to_world(str(seg[0]), seg[1])
		var b: Vector3 = Ep2GoldTown.local_to_world(str(seg[0]), seg[2])
		walls.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	_town_col["walls"] = walls


func _step_desert() -> void:
	var m: Array = Ep2GoldTown.desert_meshes()
	Ep2GoldTown.build_desert(_visuals, WoodsQuadChamber.RIDE_TRAIL, WoodsQuadChamber.FOREST_END_Z, WoodsQuadChamber.WORLD_END_Z, m[0], m[1],
		Ep2GoldTown.scrub_mat(), Ep2GoldTown.desert_rock_mat(), Ep2GoldTown.TOWN_Z - 260.0)


func _step_people() -> void:
	_build_sheriff()
	_bartender = Ep2TownFolk.new()
	_bartender.name = "Bartender"
	_visuals.add_child(_bartender)
	_bartender.setup(BARTENDER_MODEL, BARTENDER_HEIGHT, Color(0.85, 0.82, 0.74))
	_bartender.position = Ep2GoldTown.local_to_world("Bldg_Saloon", BARTENDER_AT)
	_face_folk(_bartender, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT))
	_opp = Ep2TownFolk.new()
	_opp.name = "Stranger"
	_visuals.add_child(_opp)
	_opp.setup(COWBOY_MODEL, COWBOY_HEIGHT, Color(0.2, 0.17, 0.15), false)
	_opp.position = Ep2GoldTown.local_to_world("Bldg_Saloon", OPP_AT_BAR)
	_face_folk(_opp, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT + Vector3(0.0, 0.0, -1.5)))
	# his Peacemaker (fix pack 2026-10-27 P0: "the opponent visibly draws a Colt Single Action Army"): the CAD kit's Colt SAA at real
	# size (the old primitive stands in until the streamed kit mounts), in its holster on his hip until the bell, then in his gun hand
	_revolver = Node3D.new()
	_revolver.name = "Revolver"
	_opp.add_child(_revolver)
	Ep2KitProps.place(_revolver, "Kit_Revolver", Transform3D.IDENTITY, Transform3D.IDENTITY, func(h: Node3D) -> void:
		var stand_in: Node3D = _make_revolver()
		stand_in.name = "PeacemakerStandIn"
		h.add_child(stand_in))
	_holster_revolver()
	_glass = _prop(WHISKEY_MODEL, 0.11)
	_whiskey_look(_glass)
	_coin = _prop(COIN_MODEL, 0.06)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.45)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_visuals.add_child(_flash)
	_build_armory_folk()
	_people = Ep2TownPeople.new()
	_people.configure_space(_town_col)
	_people.build(_visuals)
	_build_jail_folk()
	_build_shopkeepers()
	if _bull == null:
		_bull = _build_bull(Ep2GoldTown.door_world("Bldg_B", 0.8), PI * 0.5)
		_bull.visible = false
	_law = Ep2TownLaw.new()
	_law.name = "TownLaw"
	add_child(_law)
	_law.setup(self)


## The walk-in shops' keepers (founder fix pack 2026-10-27: "two more shopkeepers (women are fine) behind the counters"): the General
## Store's (Bldg_A, the apron) and the Hotel desk's (Bldg_B). Each stands behind her counter (the shop's "face" spot, where a customer
## looks) and turns to whoever walks in. Streamed models; the shops only open with the streamed kit, so without it there is no one.
const SHOPKEEPERS: Array = [["Bldg_A", Ep2Extras.SHOPKEEPER_GENERAL, 1.66], ["Bldg_B", Ep2Extras.SHOPKEEPER_HOTEL, 1.68]]
var _shopkeepers: Array = []                          # [piece, Ep2TownFolk]


func _build_shopkeepers() -> void:
	_shopkeepers.clear()
	for row in SHOPKEEPERS:
		var piece: String = str(row[0])
		var spots: Dictionary = Ep2GoldTown.shop_spots(piece)
		if spots.is_empty() or not Ep2Extras.has(str(row[1])):
			continue
		var k := Ep2TownFolk.new()
		k.name = "Shopkeeper_" + piece
		k.looping_clips.assign(["Idle"])
		k.clip_blend = 0.25
		_visuals.add_child(k)
		if not k.setup(str(row[1]), float(row[2]), Color(0.3, 0.25, 0.2)) or not k.has_clips():
			k.queue_free()
			continue
		k.procedural_bob = false
		k.use_height = true                            # the shop's plank floor
		var at: Vector3 = spots["face"]
		k.place(Vector3(at.x, Ep2GoldTown.shop_floor_y(piece, at), at.z))
		k.face_point(spots["counter"])
		k.rotation.y = k.facing
		k.hold_clip("Idle")
		_shopkeepers.append([piece, k])


## Behind the counter: she turns to Lil Blunt while he is in her shop, else back to the counter (a customer's place).
func _tick_shopkeepers(delta: float) -> void:
	for row in _shopkeepers:
		var piece: String = row[0]
		var k: Ep2TownFolk = row[1]
		k.face_point(_player_pos if _in_room(piece, -0.4) else Ep2GoldTown.shop_spots(piece).get("counter", k.position))
		k.step(delta)


func get_shopkeepers() -> Array:
	return _shopkeepers.map(func(r: Array) -> Ep2TownFolk: return r[1])


## Rich and Utah, the Armory's two shopkeepers, behind their counter from the first step into the lane
## (lock section 6: "both are present"). They are ordinary town folk - a stride bob, a turn to whoever
## comes in - not bears and not a menu.
func _build_armory_folk() -> void:
	if Ep2GoldTown.armory_v2 and Ep2Extras.has(Ep2Extras.RICH) and Ep2Extras.has(Ep2Extras.UTAH):
		_build_armory_folk_v2()
		return
	_rich = Ep2TownFolk.new()
	_rich.name = "Rich"
	_visuals.add_child(_rich)
	_rich.setup(RICH_MODEL, RICH_HEIGHT, Color(0.30, 0.20, 0.13))
	_rich.position = Ep2GoldTown.local_to_world("Bldg_Armory", RICH_AT)
	_face_folk(_rich, Ep2GoldTown.local_to_world("Bldg_Armory", ARMORY_SPOT))
	_utah = Ep2TownFolk.new()
	_utah.name = "Utah"
	_visuals.add_child(_utah)
	_utah.setup(UTAH_MODEL, UTAH_HEIGHT, Color(0.28, 0.33, 0.34))
	_utah.position = Ep2GoldTown.local_to_world("Bldg_Armory", UTAH_AT)
	_face_folk(_utah, Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(1.6, 0.0, -3.0)))
	# Rich works the claim book at the counter, Utah stands loose beside the racks (authored clips).
	_rich.hold_clip("Counter")
	_utah.hold_clip("Idle")
	_build_shop()


## The two-storey Armory's shopkeepers (founder 2026-10-19): the founder's Tripo Rich (miner, GM medallion, cigar) and Utah (gunman,
## bandoliers), rigged and moved by retargeted mocap (tools/ep2_motion/), each run by an Ep2ArmoryBrain that works both floors and
## reacts to Lil Blunt (skills ep2-tripo-folk-to-game, ep2-armory-npc-autonomy). Streamed with the building (Ep2Extras).
func _build_armory_folk_v2() -> void:
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	_rich = Ep2TownFolk.new()
	_rich.name = "Rich"
	_visuals.add_child(_rich)
	_rich.setup(Ep2Extras.RICH, RICH2_HEIGHT, Color(0.30, 0.20, 0.13))
	_utah = Ep2TownFolk.new()
	_utah.name = "Utah"
	_visuals.add_child(_utah)
	_utah.setup(Ep2Extras.UTAH, UTAH2_HEIGHT, Color(0.28, 0.33, 0.34))
	Ep2GroundedWalk.install(_utah)
	_rich_brain = Ep2ArmoryBrain.new()
	_rich_brain.walk_speed = RICH2_WALK
	_rich_brain.setup("rich", _rich, xf, _brain_spots(), "counter_rich", 7101)
	_utah_brain = Ep2ArmoryBrain.new()
	_utah_brain.walk_speed = UTAH2_WALK
	_utah_brain.setup("utah", _utah, xf, _brain_spots(), "bench", 7202)
	_build_shop()
	_build_guns()


## The trade counter itself: hidden until [E] at the counter (or a touch of BUY). Leather and brass,
## the same cabinet as the personal armory, and it only ever raises `buy_requested`.
func _build_shop() -> void:
	_shop = Ep2ArmoryShop.new()
	_shop.name = "ArmoryShop"
	_shop_layer = CanvasLayer.new()
	_shop_layer.name = "ArmoryShopLayer"
	_shop_layer.layer = 24
	add_child(_shop_layer)
	_shop_layer.add_child(_shop)
	_shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS       # the tree pauses while the trade is up
	_shop.process_mode = Node.PROCESS_MODE_ALWAYS
	_shop.buy_requested.connect(_on_buy_requested)
	_shop.closed.connect(_close_shop)
	_shop.hide()


# --- the two hero guns (Sharps 1874, Colt Gatling) --------------------------------------------------------------------------

## The spots the two men walk between: the building's own Spot_ empties plus the Gatling post in the yard (building-local frame).
func _brain_spots() -> Dictionary:
	var sp: Dictionary = Ep2GoldTown.armory_spots.duplicate()
	sp["gatling_stand"] = Ep2GoldTown.GATLING_POST + Vector3(-Ep2GoldTown.GATLING_STAND_BACK, 0.0, 0.0)
	sp["gatling_look"] = Ep2GoldTown.GATLING_POST + Vector3(-1.1, 0.0, -2.0)
	return sp


## The Sharps in the lit case (and a second instance for Rich's hand), the Gatling on its post in the yard with its plates, and the introduction that
## ties them to Rich and Utah. All of it is streamed art (Ep2Extras): where it is not mounted the Armory simply plays as before.
func _build_guns() -> void:
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	_sharps_case = _visuals.find_child("Arm2_Sharps_Bldg_Armory", true, false) as Node3D
	if Ep2Extras.has(Ep2Extras.GATLING):
		var post_w: Vector3 = xf * Ep2GoldTown.GATLING_POST
		var fwd: Vector3 = xf.basis * Vector3.RIGHT
		_gatling = Ep2GatlingPost.new()
		_gatling.name = "GatlingPost"
		_visuals.add_child(_gatling)
		_gatling.position = post_w
		if _gatling.build(Ep2Extras.GATLING, atan2(fwd.x, fwd.z)):
			_gatling.round_fired.connect(_on_gatling_round)
			_gatling.round_traced.connect(_on_gatling_trace)
			_gatling.hang_sign("NOT FOR SALE")
			var face: Vector3 = post_w + Vector3(0.0, 1.2, 0.0)
			for pl in Ep2GoldTown.GATLING_PLATES:
				_gatling.add_plate(xf * (pl as Vector3), face)
			for bl in Ep2GoldTown.GATLING_BALES:
				_gatling.add_bale(xf * (bl as Vector3), face)
			if _town_col.has("props"):
				(_town_col["props"] as Array).append([Vector2(post_w.x, post_w.z), 0.85])
		else:
			_visuals.remove_child(_gatling)
			_gatling.free()
			_gatling = null
	if _rich_brain == null or _utah_brain == null:
		return
	_intro = Ep2ArmoryIntro.new()
	_intro.rich = _rich_brain
	_intro.utah = _utah_brain
	_intro.gatling = _gatling
	_intro.sharps_price = int(Ep2ArmoryState.shop_item("sniper").get("price", PRICE_SNIPER))
	_intro.voice_seconds = func(who: String, text: String) -> float: return Ep2TownVoiceBank.seconds(Ep2TownVoiceBank.id_for(_town_speaker(who), text))
	if _gatling != null and _gatling.plate_count() > 0:
		var first: Dictionary = _gatling.targets[0]
		_intro.demo_target = (first["node"] as Node3D).position + _gatling.position + Vector3(0.0, 1.22, 0.0)
	_intro.said.connect(func(who: String, text: String, _secs: float) -> void: _town_line(who, text))
	_intro.objective_changed.connect(_on_intro_objective)
	_intro.sharps_lifted.connect(_on_sharps_lifted)
	_intro.finished.connect(_on_intro_finished)


func _on_intro_objective(text: String) -> void:
	if _hud != null and _beat == Beat.ARMORY:
		_hud.objective = text if text != "" else "Trade with Rich at the counter [E]."


func _on_intro_finished() -> void:
	_on_intro_objective("")


## Rich lifts the Sharps out of the lit case into his hand (the case rifle hides), or locks it back. Without a hand bone the rifle simply stays in the case.
func _on_sharps_lifted(in_hand: bool) -> void:
	if not in_hand:
		if _rich != null:
			_rich.drop_prop("Sharps")
		if _sharps_case != null:
			_sharps_case.visible = true
		return
	if not Ep2Extras.has(Ep2Extras.SHARPS) or _rich == null:
		return
	var ps: PackedScene = load(Ep2Extras.SHARPS) as PackedScene
	if ps == null:
		return
	var rifle: Node3D = ps.instantiate() as Node3D
	rifle.name = "Sharps"
	Ep2Pbr.dress(rifle)
	if _rich.attach_prop(rifle, HOLD_RICH, SHARPS_HOLD_POS, SHARPS_HOLD_ROT):
		if _sharps_case != null:
			_sharps_case.visible = false
	else:
		rifle.free()


## The introduction starts when he walks up to the counter, and ends (guns put away, both men back at work) if the beat moves on.
func _tick_armory_guns(delta: float) -> void:
	if _intro == null:
		return
	if _show_active: return
	# A completed purchase may skip the rest of the demonstration, after the current
	# recorded sentence finishes, rather than cutting a man off mid-word.
	if _gear_t >= 0.0 and _intro.is_busy() and _intro._line_t <= delta:
		_intro.cancel()
	if _hold > 0.0 and not _intro.is_busy(): return
	if not _intro_asked and _at_armory_counter() and _gear_t < 0.0:
		_intro_asked = true
		_intro.begin()
	_intro.mounted = _mounted
	_intro.player_bursts = _mount_bursts
	_intro.step(delta, _player_pos)


func skip_armory_intro() -> void:
	_intro_asked = true
	if _intro != null:
		_intro.skip()


## Step away from the crank and put the guns away (the beat moved on, or the room is being left).
func _end_guns() -> void:
	if _mounted:
		_dismount()
	if _intro != null:
		_intro.cancel()


func _can_mount() -> bool:
	if _gatling == null or _mounted or _beat != Beat.ARMORY or has_player_control() == false:
		return false
	if _intro != null and not _intro.mount_allowed():
		return false
	return _player_pos.distance_to(_gatling.stand_position()) < MOUNT_R


func _mount() -> void:
	_mounted = true
	_move_input = Vector2.ZERO
	_run_input = false
	_moving = false
	set_aim(false)
	var st: Vector3 = _gatling.stand_position()
	_player_pos = Vector3(st.x, _ground_y, st.z)
	_gatling.clear_sight_ray()
	_look_yaw = _gatling.aim_yaw                    # he takes the crank with the bore where it points (the arc is the gun's, not his old view)
	_look_pitch = _gatling.aim_pitch
	if _hud != null:
		_hud.set_search_prompt("")
		_hud.toast("THE COLT GATLING - click to fire, [E] to step away", 3.2)


func _dismount() -> void:
	_mounted = false
	if _gatling != null:
		_gatling.cease()
		_gatling.clear_sight_ray()
		_look_yaw = _gatling.aim_yaw
		_look_pitch = clampf(_gatling.aim_pitch, FPS_PITCH_MIN, FPS_PITCH_MAX)


func is_mounted() -> bool: return _mounted
func get_gatling() -> Ep2GatlingPost: return _gatling
func get_intro() -> Ep2ArmoryIntro: return _intro
func mount_bursts() -> int: return _mount_bursts


# --- mounted mode: the crank is his view, his mouse and his trigger; everything else about walking and the rifle waits -------------

func look(relative: Vector2) -> void:
	if _mounted and has_player_control() and _gatling != null:
		_gatling.aim_delta(relative)
		_look_yaw = _gatling.aim_yaw
		_look_pitch = _gatling.aim_pitch
		return
	super(relative)


func _move_player(delta: float) -> void:
	if _mounted or _depart_mounted:
		_moving = false
		return
	super(delta)


func _can_jump() -> bool:
	return not _mounted


func set_aim(on: bool) -> void:
	if _mounted:
		return
	super(on)


func reload() -> bool:
	if _mounted:
		if _hud != null:
			_hud.toast("THE DRUM IS ALL THERE IS", 1.4)
		return false
	return super()


func select_weapon(id: String) -> bool:
	if _mounted:
		return false
	return super(id)


func _fps_camera(delta: float) -> void:
	if _mounted and _gatling != null:
		_camera.position = _gatling.eye_position()
		# The Winchester's existing recoil hook gives each crank-fired round a short kick; it never moves the bore or its clamp.
		var kick: float = _vm.cam_kick if _vm != null else 0.0
		var pitch: float = clampf(_gatling.aim_pitch + kick, -1.4, 1.4)
		var cp: float = cos(pitch)
		var dir := Vector3(sin(_gatling.aim_yaw) * cp, sin(pitch), cos(_gatling.aim_yaw) * cp)
		_camera.look_at(_camera.position + dir, Vector3.UP)
		_camera.fov = MOUNT_FOV
		# Rounds converge on what this actual crosshair ray meets; the muzzle is not the eye and must not fire a parallel miss.
		_gatling.set_sight_ray(_camera.global_position, -_camera.global_transform.basis.z)
		return
	super(delta)


## One round left the Colt. Utah's demonstration has no camera kick; only the mounted player feels it.
func _on_gatling_round() -> void:
	if _mounted and _vm != null:
		_vm.cam_kick = maxf(_vm.cam_kick, 0.007)


func _on_gatling_trace(origin: Vector3, direction: Vector3, hit: Dictionary) -> void:
	if _law != null:
		_law.gatling_round(origin, direction, hit)


func _set_eye_view(on: bool) -> void:
	super(on)
	if (_mounted or (_beat == Beat.DRAW and not _player_drawn)) and _vm != null:
		_vm.set_shown(false)                                 # the Winchester stays out of the picture while his hands are on the crank


func _tick_viewmodel(delta: float) -> void:
	super(delta)
	if _mounted and _gatling != null and _hud != null:
		_hud.set_ammo(_gatling.rounds, 0, Ep2GatlingPost.DRUM)
		_hud.spread_deg = 1.4


## [E] at the counter opens Rich & Utah's trade. The personal armory keeps its own key: this is a
## trade with crypto, not a loadout swap (founder lock PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md).
func start_rig(_payment: String = "") -> bool:
	if can_mount_departure():
		_depart_mounted = true
		_depart_from = _player_pos
		_end_t = 1.2
		return true
	if _can_loot():
		_loot()
		return true
	if _mounted:
		_dismount()
		return true
	if _can_mount():
		_mount()
		return true
	if _stable_yard != null and _stable_interaction_allowed() and _stable_yard.try_talk(_player_pos):
		return true
	if (_beat != Beat.ARMORY and not _world_revisit) or _shop_open or _shop == null:
		return false
	if not _at_armory_counter():
		return false
	_open_shop()
	return true


## True when Lil Blunt is close enough to the counter to trade.
func _at_armory_counter() -> bool:
	if _beat != Beat.ARMORY and not _world_revisit:
		return false
	return _player_pos.distance_to(Ep2GoldTown.local_to_world("Bldg_Armory", ARMORY_SPOT)) < ARMORY_TRADE_R


## The purse: the tokens Lil Blunt has collected all game (ETH, BTC, WBTC, SOL, TitanX; GameManager.purse_balance), one balance per
## tender. Never the score, never a soft currency.
func _purse(tender: String = "") -> int:
	if tender == "":
		tender = _shop.tender if _shop != null else "btc"
	return GameManager.purse_balance(tender)


func _open_shop() -> void:
	if _shop == null:
		return
	_shop.purse_of = func(t: String) -> int: return GameManager.purse_balance(t)
	_shop.open_shop(armory, _purse())
	_shop_open = true
	_shop_bought = false
	_move_input = Vector2.ZERO
	_run_input = false
	set_aim(false)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _close_shop() -> void:
	if not _shop_open:
		return
	_shop_open = false
	if _shop != null:
		_shop.hide()
	Input.mouse_mode = _mouse_before
	if not StateMachine.is_paused():
		get_tree().paused = false
	if not _shop_bought and _town_audio != null: _town_audio.queue_line("town_trade_10")


func _on_buy_requested(item_id: String, price: int, tender: String) -> void:
	buy(item_id, price, tender)


## The trade. The catalogue in `Ep2ArmoryState.SHOP` is the price, never the panel's label: debit the
## crypto first, then ask the state for the goods, and give the coin back if the state refuses. Rich
## does not hand over free iron and the room never invents a currency of its own.
func buy(item_id: String, _price: int, tender: String = "btc") -> bool:
	var item: Dictionary = Ep2ArmoryState.shop_item(item_id)
	if item.is_empty():
		_note(item_id, false)
		return false
	var cost: int = int(item["price"])
	if cost <= 0 or not Ep2ArmoryState.ARMORY_TENDER.has(tender):
		_note(item_id, false)
		return false
	if not _spend(cost, tender):
		_note(item_id, false)
		return false
	if not _deliver(item_id, int(item["rounds"]), tender):
		_refund(cost, tender)
		_note(item_id, false)
		return false
	_spent += cost
	_note(item_id, true)
	if _hud != null:
		_hud.toast(str(item["name"]), 1.4)
	_check_geared()
	return true


## Debit the tender's own balance (`GameManager.purse_spend`, which refuses to go negative).
func _spend(cost: int, tender: String) -> bool:
	if not GameManager.purse_spend(tender, cost):
		return false
	if _shop != null:
		_shop.set_purse(_purse(tender))
	return true


## Hand the faces back when the state refuses the sale (never a silent debit).
func _refund(cost: int, tender: String) -> void:
	GameManager.purse_add(tender, cost)
	if _shop != null:
		_shop.set_purse(_purse(tender))


func _deliver(item_id: String, rounds: int, tender: String) -> bool:
	match item_id:
		"sniper":
			return armory.purchase_sniper(tender)
		"sniper_ammo":
			return armory.purchase_sniper_ammo(rounds, tender)
		"river_gear":
			return armory.purchase_river_gear(tender)
		"rifle_ammo":
			return armory.purchase_ammo(Ep2ArmoryState.WIN, rounds, tender)
		"revolver_ammo":
			return armory.purchase_ammo(Ep2ArmoryState.REM, rounds, tender)
	return false


func _note(item_id: String, ok: bool) -> void:
	if _shop != null:
		_shop.purchase_result(item_id, ok)
	if _shop_open and _town_audio != null:
		if ok:
			_shop_bought = true
			_town_audio.queue_line("town_trade_07" if item_id == "river_gear" else ("town_trade_04" if item_id == "sniper" else "town_trade_06"))
		else:
			_town_audio.queue_line("town_trade_09")


## The long rifle and the river gear both in hand: the river shipment is on (the day-88 set-piece).
func _check_geared() -> void:
	if _geared or _gear_t >= 0.0:
		return
	# section 4: the first visit to Rich's goes on to the Gatling and Inferno's return; geared shows only once the story has been to
	# the bar (and the jail): already geared then -> straight on (_after_story), else this return visit is the one that gears him
	if armory.sniper_owned and armory.river_gear and _armory_return:
		_gear_t = 1.0


## The Sheriff: the founder's own model (Drive 2026-10-14), arms lowered out of the T-pose, grey beard, star, pipe - with a
## thin curl of smoke over his lip. Beside him stands Minister Mike Dean, the founder's robot-headed minister. Without the model a plain stand-in keeps the beats playable.
func _build_sheriff() -> void:
	_sheriff = Ep2TownFolk.new()
	_sheriff.name = "Sheriff"
	_sheriff.looping_clips.assign(["Idle", "Walk", "Talk", "Counter"])
	_sheriff.clip_blend = 0.2
	_visuals.add_child(_sheriff)
	_sheriff.setup(SHERIFF_MODEL, SHERIFF_HEIGHT, Color(0.42, 0.30, 0.18))
	Ep2GroundedWalk.install(_sheriff)
	if _sheriff.has_clips():
		_sheriff.procedural_bob = false                # mocap carries its own bob
		_sheriff.walk_clip_speed = float(Ep2GroundedWalk.config.reference_speed)
		_sheriff.hold_clip("Idle")
	_sheriff_smoke = _particles(18, 2.6, Color(0.86, 0.86, 0.84, 0.33), 0.06)
	_sheriff_smoke.name = "CigSmoke"
	_sheriff_smoke.position = SHERIFF_MOUTH * SHERIFF_HEIGHT
	_sheriff_smoke.direction = Vector3.UP
	_sheriff_smoke.spread = 12.0
	_sheriff_smoke.initial_velocity_min = 0.05
	_sheriff_smoke.initial_velocity_max = 0.12
	_sheriff_smoke.gravity = Vector3(0.02, 0.06, 0.0)
	_sheriff_smoke.scale_amount_min = 0.6
	_sheriff_smoke.scale_amount_max = 2.6
	_sheriff.add_child(_sheriff_smoke)
	_sheriff.position = Ep2GoldTown.local_to_world("Bldg_Certificates", SHERIFF_OFFICE_AT)
	_face_folk(_sheriff, Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT))
	_minister = Ep2TownFolk.new()
	_minister.name = "MinisterMikeDean"
	# The founder's Mike Dean rigged on the townfolk skeleton (tools/ep2_motion/rig_scan_character.py + clips_minister.json: a panic Run,
	# KneelDown and a praying Kneel - section 4 of the 2026-10-25 prompt) streams with the town people; without the pack the statue
	# stands in exactly as before.
	_minister.looping_clips.assign(["Idle", "Walk", "Run", "Kneel"])
	_minister.clip_blend = 0.2
	_visuals.add_child(_minister)
	_minister.setup(Ep2Extras.MINISTER if Ep2Extras.has(Ep2Extras.MINISTER) else MINISTER_MODEL, MINISTER_HEIGHT, Color(0.1, 0.1, 0.12))
	_minister_rigged = _minister.has_clips()
	if _minister_rigged:
		_minister.use_height = true                    # he stands on his step behind the counter, and steps down off it
		_minister.procedural_bob = false
		_minister.place(Ep2GoldTown.local_to_world("Bldg_Certificates", MINISTER_DESK) + Vector3(0.0, MINISTER_STEP, 0.0))
		_minister.hold_clip("Idle")
	else:
		_minister.position = Ep2GoldTown.local_to_world("Bldg_Certificates", MINISTER_DESK) + Vector3(0.0, MINISTER_STEP, 0.0)
	var step := MeshInstance3D.new()
	step.name = "MinisterStep"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, MINISTER_STEP, 0.9)
	step.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.11)
	wood.roughness = 0.9
	step.material_override = wood
	step.position = _minister.position - Vector3(0.0, MINISTER_STEP * 0.5, 0.0)
	_visuals.add_child(step)
	_face_folk(_minister, Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT))


## The founder's tumbler reads as WHISKEY (his hideout direction, skill ep2-bull-props-visible): clear glass with a rim light and an
## amber measure inside, instead of the raw GLB's baked cream - the same treatment as Inferno's glass in the hideout. `holder` is a
## _prop() holder (the tumbler's base on y = 0).
func _whiskey_look(holder: Node3D) -> void:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.86, 0.93, 1.0, 0.22)
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.9
	glass.rim_tint = 0.2
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = glass
	var bx: AABB = _aabb_of(holder)
	if bx.size.y <= 0.0:
		return
	var r: float = minf(bx.size.x, bx.size.z) * 0.5
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.84
	cyl.bottom_radius = r * 0.78
	cyl.height = bx.size.y * 0.5
	cyl.radial_segments = 20
	var amber := StandardMaterial3D.new()
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amber.albedo_color = Color(0.78, 0.40, 0.09, 0.86)
	amber.roughness = 0.12
	amber.emission_enabled = true
	amber.emission = Color(0.45, 0.20, 0.04)
	amber.emission_energy_multiplier = 0.5
	var liquid := MeshInstance3D.new()
	liquid.name = "Whiskey"
	liquid.mesh = cyl
	liquid.material_override = amber
	liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	liquid.position = Vector3(bx.get_center().x, bx.position.y + bx.size.y * 0.09 + cyl.height * 0.5, bx.get_center().z)
	holder.add_child(liquid)


static func _aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var bx: AABB = (n.global_transform.affine_inverse() * m.global_transform) * m.mesh.get_aabb() if n.is_inside_tree() else _local_xf(n, m) * m.mesh.get_aabb()
		out = bx if first else out.merge(bx)
		first = false
	return out


static func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t





func _make_revolver() -> Node3D:
	var g := Node3D.new()
	g.name = "Revolver"
	var steel := _plain(Color(0.22, 0.22, 0.24), 0.35, 0.85)
	var grip := _plain(Color(0.35, 0.22, 0.12), 0.7)
	_box(Vector3(0.03, 0.03, 0.2), Vector3(0.0, 0.0, 0.1), steel, g)
	_cyl(0.022, 0.022, 0.045, Vector3(0.0, -0.006, 0.0), steel, g).rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var gp := _box(Vector3(0.028, 0.1, 0.04), Vector3(0.0, -0.06, -0.04), grip, g)
	gp.rotation = Vector3(-0.35, 0.0, 0.0)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, 0.21)
	g.add_child(muzzle)
	return g


func _prop(path: String, size: float) -> Node3D:
	var n := Node3D.new()
	_visuals.add_child(n)
	n.visible = false
	if ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		n.add_child(m)
		var bx: AABB = _aabb_of(m)
		var s: float = size / maxf(maxf(bx.size.x, bx.size.y), maxf(bx.size.z, 0.001))
		m.scale = Vector3.ONE * s
		m.position = Vector3(-(bx.position.x + bx.size.x * 0.5) * s, -bx.position.y * s, -(bx.position.z + bx.size.z * 0.5) * s)
	else:
		_cyl(size * 0.4, size * 0.35, size, Vector3(0.0, size * 0.5, 0.0), _plain(Color(0.8, 0.55, 0.2), 0.2, 0.6), n)
	return n


static func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


func _face_folk(a: Ep2TownFolk, p: Vector3) -> void:
	a.face_point(p)
	a.rotation.y = a.facing


# --- setup + beats -----------------------------------------------------------------------------------------------------

func _on_setup() -> void:
	_player_pos = handoff.get("pos", Ep2GoldTown.DROP_POINT + Vector3(-2.2, 0.0, 0.6))
	_player_pos.y = 0.0
	_ground_y = 0.0
	_apply_handoff_gaze(0.0, -0.03, PI)
	_player_yaw = _look_yaw
	# the townsfolk carry on exactly where they were during the ride in (same people, same places, same errands)
	if _people != null and handoff.get("town_people") is Dictionary:
		_people.restore(handoff["town_people"], true)    # the ride crowd walked on lighter collision: replan a clipped path
	_stable_yard = _visuals.find_child("StableYard", true, false) as Ep2StableYard
	if _stable_yard != null:
		if handoff.get("stable_yard") is Dictionary:
			_stable_yard.restore(handoff["stable_yard"])
		_stable_yard.voice_line_requested.connect(func(id: String, voice: String) -> void:
			stable_voice_requested.emit(id, voice))
		_stable_yard.conversation_line.connect(_on_stable_line)
		_stable_yard.horse_bought.connect(_on_stable_horse_bought)
	if _law != null:
		_law.refresh_targets()
	_rng.seed = 1886
	if _hud:
		_hud.show_health = false
	if _vm != null:
		_vm.set_world_shadows(false)
		_vm.set_own_light(WoodsQuadChamber.VM_KEY_ENERGY, _sun)
	if _town_audio != null: _town_audio.start()
	var town_life: Ep2TownLife = _visuals.find_child("TownLife", true, false) as Ep2TownLife
	if town_life != null:
		town_life.town_ambient = true
	_bumps = TOWN_BUMPS.new()
	_bumps.build(_people, town_life, _town_audio)
	_advance_to(Beat.STREET)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.STREET:
			if _hud:
				_hud.objective = "Go to the CERTIFICATES office. Get the sheriff to sort you a certificate."
		Beat.OFFICE:
			if _hud:
				_hud.objective = ""
			look_toward(_sheriff.position + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.6)
			_sheriff_look_at_player()
			_start_show([
				FacilityShow._say("vo_sheriff_1", 0.35),
				FacilityShow._say("vo_lb_cert1", 0.25),
				FacilityShow._say("vo_sheriff_2", 0.3),
				{"do": "call", "fn": func() -> void: look_toward(_minister.position + Vector3(0.0, MINISTER_HEIGHT * 0.85, 0.0), 2.4)},
				FacilityShow._say("vo_minister_1", 0.3),
				{"do": "call", "fn": func() -> void: look_toward(_sheriff.position + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.4)},
				FacilityShow._say("vo_sheriff_3", 0.3),
				{"do": "call", "fn": release_look}], true)
		Beat.TO_BAR:
			if _hud:
				_hud.objective = "Cross the street to the SALOON."
			# the sheriff finishes his smoke at the counter, then strolls over behind you (he has a feeling about that saloon)
			_sheriff_delay = 6.0
			_sheriff_goes = [Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -2.0)), Ep2GoldTown.door_world("Bldg_Certificates", 1.6),
				Ep2GoldTown.door_world("Bldg_Saloon", 2.2)]
		Beat.BAR:
			if _hud:
				_hud.objective = ""
			var bar_top: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(-0.6, 1.2, -8.7))
			look_toward(_bartender.position + Vector3(0.0, 1.7, 0.0), 2.6)
			_start_show([
				FacilityShow._say("vo_bar_1", 0.3),
				FacilityShow._say("vo_lb_bar1", 0.2),
				{"do": "call", "fn": func() -> void: _place(_glass, bar_top)},
				{"do": "wait", "t": 0.6},
				FacilityShow._say("vo_lb_bar2", 0.2),
				{"do": "call", "fn": func() -> void: _place(_coin, bar_top + Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.35, 0, 0)) - Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3.ZERO))},
				FacilityShow._say("vo_bar_2", 0.3),
				{"do": "call", "fn": func() -> void: look_toward(_opp.position + Vector3(0.0, 1.9, 0.0), 2.4)},
				{"do": "call", "fn": func() -> void: _face_folk(_opp, _player_pos)},
				FacilityShow._say("vo_opp_1", 0.3),
				FacilityShow._say("vo_opp_2", 0.35),
				FacilityShow._say("vo_lb_draw1", 0.3),
				FacilityShow._say("vo_opp_3", 0.4),
				{"do": "call", "fn": _sheriff_enters_saloon},
				{"do": "call", "fn": func() -> void: look_toward(Ep2GoldTown.local_to_world("Bldg_Saloon", SHERIFF_SALOON) + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.0)},
				{"do": "wait", "t": 2.6},
				FacilityShow._say("vo_sheriff_witness", 0.3),
				{"do": "call", "fn": release_look}], true)
		Beat.SQUARE_UP:
			if _hud:
				_hud.objective = "Step out into the street and face him."
			var sd: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 1.5)
			_opp.walk_path([Ep2GoldTown.door_world("Bldg_Saloon", -1.0), sd, Vector3(3.0, 0.0, 1426.0), OPP_MARK], 1.5)
			_sheriff.walk_path([sd + Vector3(0.0, 0.0, 1.0), WITNESS_MARK], 1.4)
		Beat.DRAW:
			if _hud:
				_hud.objective = "Listen for the town bell. Keep your hands still until it rings."
				_hud.show_health = true
			_start_round()
		Beat.WON:
			Ep2DrawMusic.finish(self)
			_won_t = 0.0
			_minister_runs_out()
			if _hud:
				_hud.objective = ""
			# section 2 step 1: the street celebrates round Lil Blunt (clear of the fallen stranger), then pairs off and dances. Inferno does
			# NOT arrive at the draw. The map is NOT handed over: it is on the body with his Peacemaker (LOOT).
			if _people != null:
				_people.celebrate(_player_pos, _opp.position)
			if _town_audio != null:
				_town_audio.play_celebration()
			_start_show([
				FacilityShow._say("vo_sheriff_win", 0.4),
				{"do": "wait", "t": 0.4}], false)
		Beat.LOOT:
			# section 2 step 2: E at the body takes the Peacemaker and the map to the auction
			if _hud:
				_hud.objective = "Search the stranger: his PEACEMAKER and the map to the auction."
				_hud.toast("HE DROPPED HIS PEACEMAKER", 2.6)
		Beat.JOB:
			# section 2 step 4: Sheriff James walks over, impressed with the draw, and offers the job - who let the bears hold Fort Knox
			# (his prisoner knows more) - then leads him to the jail (Rich & Utah come after it)
			if _hud:
				_hud.objective = ""
			_job_said = false
			_sheriff.walk_to(_stand_off(_sheriff.position, _player_pos, 1.8), 1.4)
		Beat.JAIL_TIP:
			# the Sheriff walks him out to the jailhouse at the south edge of town (founder lock 2026-10-20) - he leads, Lil Blunt follows
			_investigation_open = false
			if _hud:
				_hud.objective = "Follow the Sheriff to the jailhouse, out the south road west of the street."
				_hud.toast("THE SHERIFF'S PRISONER KNOWS ABOUT THE BEARS", 3.8)
			if _sheriff != null:
				_sheriff.walk_path([Vector3(0.0, 0.0, _sheriff.position.z), Vector3(0.0, 0.0, 1399.0),
                    Ep2GoldTown.door_world("Bldg_Jail", 3.0), Ep2GoldTown.door_world("Bldg_Jail", -1.0),
                    _jail_spot("sheriff")], 1.6)
			look_toward(Ep2GoldTown.door_world("Bldg_Jail", 1.0) + Vector3(0.0, 1.5, 0.0), 2.0)
			_start_show([{"do": "wait", "t": 3.0}, {"do": "call", "fn": release_look}], false)
		Beat.JAIL:
			_jail_visited = true
			if _hud:
				_hud.objective = ""
			if _sheriff != null:
				_sheriff.face_point(_player_pos)
			if _accomplice != null:
				_accomplice.face_point(_player_pos)
			_start_show(_jail_show_steps(), false)
			_jail_done_t = -1.0
		Beat.TIP:
			# the tip off Main Street: Rich keeps an armory down the side lane (the lock's
			# "hard-won" find - no ARMORY sign on the main drag). Text only; the voice lines
			# for Rich and Utah are scripted in design/ep2/armory/RICH_UTAH_LINES.md and wait
			# on a voice key (none is configured on this box).
			if _hud:
				_hud.objective = "Rich keeps an armory down the side lane off the left row. Find it."
				_hud.toast("AN ARMORY DOWN THE SIDE LANE", 3.4)
			if _sheriff != null:
				_sheriff.face_point(Ep2GoldTown.door_world("Bldg_Armory", 1.0))
			look_toward(Ep2GoldTown.door_world("Bldg_Armory", 1.0) + Vector3(0.0, 1.4, 0.0), 2.0)
			_start_show([{"do": "wait", "t": 3.0}, {"do": "call", "fn": release_look}], false)
		Beat.ARMORY:
			_armory_t = 0.0
			if _armory_return:
				# back from the jail only to gear up for the river: no second welcome
				if _hud:
					_hud.objective = "Gear up for the river at Rich's counter [E]: the long rifle and the river gear."
				_check_geared()
			else:
				if _hud:
					_hud.objective = "Trade with Rich at the counter [E]."
				if _rich != null:
					_rich.face_point(_player_pos)
					look_toward(_rich.position + Vector3(0.0, RICH_HEIGHT * 0.85, 0.0), 2.2)
				_start_show([FacilityShow._say("town_trade_00"), FacilityShow._say("town_trade_01"),
					FacilityShow._say("town_trade_02"), FacilityShow._say("town_trade_03"),
					{"do": "call", "fn": release_look}], false)
		Beat.BULL_BACK:
			# section 4.3: after the Gatling, Inferno rides back in on his quad and parks outside Rich's
			_end_guns()
			if _hud:
				_hud.objective = ""
			_quad_comes_back()
		Beat.BODY:
			# section 4.4: on the way to the bar, the man Lil Blunt shot - and Mike Dean praying by him
			if _hud:
				_hud.objective = "Walk with Inferno to the saloon."
			_body_said = false
			_bull_task = "to_body"
			_bull_route([Ep2GoldTown.door_world("Bldg_Armory", 6.0), LANE_MARK, Vector3(-2.2, 0.0, 1450.0), _body_stand()], 1.5)
		Beat.DRINKS:
			# section 2 steps 7-9: whiskey at the bar - they really drink - then cousin Flux's new kettle, and Inferno's gift for Mike Dean
			if _hud:
				_hud.objective = "Inferno's buying. Into the saloon, up to the bar."
			_drinks_said = false
			_bull_task = "to_bar"
			_bull_route([Ep2GoldTown.door_world("Bldg_Saloon", 2.4), Ep2GoldTown.door_world("Bldg_Saloon", -1.0),
				Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT + Vector3(1.4, 0.0, -0.1))], 1.4)
		Beat.MINISTER2:
			# section 2 steps 9-10: the Gold Panner to Mike Dean; the stamp lands on this second visit; he sends him to Dude
			_minister2_said = false
			if _hud:
				_hud.objective = "Take the Gold Panner to Minister Mike Dean at the CERTIFICATES office."
		Beat.STABLES:
			prebuild_requested.emit("lake_trail")
			# section 2 steps 11-12: Dude - the Minister sent him; the horse for BTC; his Chill Buds; "Logan's Lake first"
			if _stable_yard != null:
				_stable_yard.set_referred(true)
			if _hud:
				_hud.objective = "Mike Dean's friend Dude keeps the horse stables. Tell him the Minister sent you."
		Beat.GEARED:
			_end_guns()
			_geared = true
			# the law's hook (Ep2TownLaw): irons held by the Sheriff come back as Lil Blunt leaves his town - never into the bandits' trail
			# with only the pickaxe
			if armory.firearms_confiscated:
				return_firearms()
				if _hud:
					_hud.toast("THE SHERIFF HANDS BACK YOUR IRONS AT THE TOWN LIMITS", 3.4)
			prebuild_requested.emit("lake_trail")
			if _hud:
				_hud.objective = "Mount your horse at Dude’s stables. Logan’s Lake is marked on your map."
				_hud.toast("TO LOGAN'S LAKE", 3.4)
			# Wait here for the player to mount at the actual stables.
		Beat.DONE:
			_resolve({"next_chamber": "lake_trail", "horse": _horse_bought, "got_map": _got_map, "peacemaker": _got_peacemaker,
				"stamped": _stamped, "draw_losses": _losses,
				"draw_fouls": _fouls, "armory_visited": _armory_visited, "sniper": armory.sniper_owned,
				"sniper_rounds": armory.sniper_rounds, "river_gear": armory.river_gear,
				"jail_visited": _jail_visited, "investigation": _investigation_open})


## The jailhouse exchange, as timed text (voice lines wait on a voice key like the Armory's): the Sheriff presents the caught
## helper, the accomplice bargains and gives a PARTIAL truth (bears were brought in to soften claims before the vault lockup, the
## pressure runs toward Fort Knox, look along the lake, the river and the trains), the Sheriff asks Lil Blunt to find who ordered it.
const JAIL_LINES: Array = [
	["SHERIFF", "Here he is. Caught him holding the gate open for the bears."],
	["ACCOMPLICE", "All I did was open a gate. Somebody paid me to bring them in."],
	["LIL BLUNT", "Who paid you?"],
	["ACCOMPLICE", "Never saw a face. Coin, and an order: soften the claims before the vault locks."],
	["ACCOMPLICE", "They want Fort Knox first. Watch the lake outflow, the river... the trains."],
	["SHERIFF", "Find who brought the bears, Lil Blunt. I'll keep this one where he is."],
]


func _jail_show_steps() -> Array:
	var steps: Array = []
	for ln in JAIL_LINES:
		var who: String = str(ln[0])
		var text: String = str(ln[1])
		steps.append({"do": "call", "fn": func() -> void: _jail_line(who, text)})
		steps.append(FacilityShow._say(Ep2TownVoiceBank.id_for(_town_speaker(who), text), 0.25))
	return steps


func _jail_line(who: String, text: String) -> void:
	if _hud != null:
		_hud.toast("%s: %s" % [who, text], Ep2TownVoiceBank.seconds(Ep2TownVoiceBank.id_for(_town_speaker(who), text)))
	if who == "ACCOMPLICE" and _accomplice != null:
		_accomplice.face_point(_player_pos)
		_accomplice.hold_clip("Greet")
	elif who == "SHERIFF" and _sheriff != null:
		_sheriff.face_point(_player_pos)


## Build the accomplice into cell A (jail extras only): hatless, rough, standing at the bars. Silent if the jail is not loaded.
func _build_jail_folk() -> void:
	if not Ep2GoldTown.jail_v1:
		return
	_accomplice = Ep2TownFolk.new()
	_accomplice.name = "Accomplice"
	_accomplice.looping_clips.assign(["Idle", "Observe", "Talk"])
	_accomplice.clip_blend = .18
	_visuals.add_child(_accomplice)
	_accomplice.setup(Ep2Extras.PRISONER, ACCOMPLICE_HEIGHT, Color(0.40, 0.30, 0.22))
	_accomplice.hold_clip("Observe")
	_accomplice.position = Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots.get("accomplice", Vector3(-1.85, 0.0, -5.7)))
	_face_folk(_accomplice, Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots.get("visit", Vector3(-1.85, 0.0, -4.05))))


func _jail_spot(name: String) -> Vector3:
	return Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots.get(name, Vector3.ZERO))


# --- the post-draw (founder 2026-10-25, PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE section 4) --------------------------------------------

## A spoken exchange as timed captions: each line is toasted with its speaker (and plays a recording when Ep2TownVoiceBank has one for that
## speaker + text), held for a reading time, the speaker turned to Lil Blunt.
func _caption_steps(lines: Array) -> Array:
	var steps: Array = []
	for ln in lines:
		var who: String = str(ln[0])
		var text: String = str(ln[1])
		steps.append({"do": "call", "fn": func() -> void: _caption_line(who, text)})
		steps.append({"do": "wait", "t": _caption_seconds(who, text)})
	return steps


static func _read_seconds(text: String) -> float:
	return clampf(1.3 + float(text.length()) * 0.052, 2.4, 6.2)


func _caption_seconds(who: String, text: String) -> float:
	var rec: float = Ep2TownVoiceBank.seconds(Ep2TownVoiceBank.id_for(_town_speaker(who), text))
	return maxf(_read_seconds(text), rec + 0.3)


func _caption_line(who: String, text: String) -> void:
	var id: String = Ep2TownVoiceBank.id_for(_town_speaker(who), text)
	if _hud != null:
		_hud.toast("%s: %s" % [who, text], _caption_seconds(who, text))
	if id != "":
		_speak(id)
	captioned.emit(who, text)
	match who:
		"SHERIFF":
			if _sheriff != null:
				_sheriff.face_point(_player_pos)
				_talk_clip(_sheriff, _caption_seconds(who, text))
		"MIKE DEAN":
			if _minister != null and _minister_task != "kneeling": _minister.face_point(_player_pos)
		"INFERNO":
			if _bull != null and _bull_task not in ["riding", "leaving"]: _bull.face_point(_player_pos)
		"BARTENDER":
			if _bartender != null: _bartender.face_point(_player_pos)
		"BAM":
			if _law != null and _law.get_bam() != null: _law.get_bam().face_point(_player_pos)


## A rigged speaker who is standing plays Talk for as long as his line lasts, then goes back to Idle - unless something else (a walk,
## another clip) took over in the meantime.
func _talk_clip(folk: Ep2TownFolk, seconds: float) -> void:
	if folk == null or not folk.has_clips() or folk.is_walking():
		return
	folk.hold_clip("Talk")
	get_tree().create_timer(maxf(seconds, 0.5)).timeout.connect(func() -> void:
		if is_instance_valid(folk) and folk._base_clip == "Talk":     # even if he set off walking meanwhile: he must not stop and keep talking
			folk.hold_clip("Idle"))


## `to`, moved `gap` metres toward `from` on the ground: where someone stops to talk to whoever stands at `to`.
static func _stand_off(from: Vector3, to: Vector3, gap: float) -> Vector3:
	var d := Vector3(from.x - to.x, 0.0, from.z - to.z)
	if d.length() < 0.01:
		d = Vector3(0.0, 0.0, 1.0)
	return Vector3(to.x, 0.0, to.z) + d.normalized() * gap


func _people_cheer_s() -> float:
	return Ep2TownPeople.CHEER_S if _people != null and not _people.people.is_empty() else 3.0


## Section 4.1: Mike Dean leaves his counter in a panic - round the end of it, out through the door - and runs to Lil Blunt (his rigged
## body on its Run clip; the statue simply hurries). _tick_minister carries on: his question, then the walk to the fallen stranger to pray.
func _minister_runs_out() -> void:
	if _minister == null:
		_panic_done = true
		return
	_minister_task = "panic"
	_minister_t = 0.0
	var stop: Vector3 = _stand_off(Ep2GoldTown.door_world("Bldg_Certificates", 2.0), _player_pos, 2.3)
	var pts: Array = [Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(3.2, 0.0, -5.4)),
		Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(3.2, 0.0, -3.4)), Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -2.0)),
		Ep2GoldTown.door_world("Bldg_Certificates", -0.6), Ep2GoldTown.door_world("Bldg_Certificates", 1.6), stop]
	if _minister_rigged:
		_minister.walk_clip = "Run"
		_minister.walk_clip_speed = MINISTER_RUN_STRIDE
	_minister.walk_path(pts, MINISTER_RUN)


func _tick_minister(delta: float) -> void:
	if _minister == null or _minister_task == "":
		return
	_minister_t += delta
	match _minister_task:
		"panic":
			if not _minister.is_walking() and not _show_active and _beat != Beat.WON:
				_minister_task = "asking"
				if _minister_rigged:
					_minister.walk_clip = "Walk"
					_minister.walk_clip_speed = 0.0
				_minister.face_point(_player_pos)
				look_toward(_minister.position + Vector3(0.0, MINISTER_HEIGHT * 0.85, 0.0), 2.4)
				_start_show(_caption_steps(PANIC_LINES) + [{"do": "call", "fn": _after_panic}], false)
		"to_body":
			if not _minister.is_walking():
				_minister_task = "kneeling"
				_minister_t = 0.0
				_minister.face_point(_opp.position)
				if _minister_rigged:
					_minister.hold_clip("KneelDown")
		"kneeling":
			_minister.face_point(_opp.position)
			if _minister_rigged and _minister_t > 1.95 and _minister.current_clip() != "kneel":
				_minister.hold_clip("Kneel")
		"home":
			# back behind his counter for the second visit (DRINKS): facing the door, his book open
			if not _minister.is_walking():
				_minister_task = "at_desk"
				_minister.face_point(Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT))


func _after_panic() -> void:
	release_look()
	_panic_done = true
	_minister_task = "to_body"
	_minister.walk_path([_opp.position + KNEEL_AT], MINISTER_WALK)


## Section 4.3: the quad (the woods ride's model) rolls back up the road and the lane with Inferno in the saddle and parks outside Rich's.
func _quad_comes_back() -> void:
	if _quad == null:
		_quad = Ep2TownQuad.new()
		_quad.name = "InfernoQuad"
		_visuals.add_child(_quad)
		_quad.build()
	_quad.drive(QUAD_RETURN + [Ep2GoldTown.local_to_world("Bldg_Armory", QUAD_PARK_LOCAL)])
	_bull.visible = true
	if _bull.anim != null and not _bull.anim.has_animation(WoodsQuadChamber.BULL_SIT_CLIP):
		_bull.add_all_clips(SmeltingFacilityChamber.BULL_SIT_CLIPS)
	if _bull.anim != null and _bull.anim.has_animation(WoodsQuadChamber.BULL_SIT_CLIP):
		_bull.play(WoodsQuadChamber.BULL_SIT_CLIP, 0.0, 0.0)            # seated, frozen (the woods ride's pose)
		_bull.anim.seek(WoodsQuadChamber.BULL_SIT_AT, true)
	_bull.clear_face_goal()
	_bull_task = "riding"
	_seat_bull()


func _seat_bull() -> void:
	_bull.position = _quad.seat_position()
	_bull.facing = _quad.yaw
	_bull.rotation.y = _quad.yaw


func _tick_bull_back(delta: float) -> void:
	match _bull_task:
		"riding":
			_quad.step(delta)
			_seat_bull()
			# townspeople in the road step aside to the verge as he comes (the ride into town does the same)
			_make_way_t -= delta
			if _people != null and _make_way_t <= 0.0:
				_make_way_t = 0.25
				_people.make_way(_quad.position, Vector2(sin(_quad.yaw), cos(_quad.yaw)), 14.0, 2.0)
			if _quad.is_parked:
				# the parked quad is solid: nobody walks through it
				if _town_col.has("props"):
					(_town_col["props"] as Array).append([Vector2(_quad.position.x, _quad.position.z), 1.25])
				# he swings off beside the saddle and comes over (to the shop door if Lil Blunt is inside)
				_bull_task = "to_lb"
				_bull.position = _quad.dismount_spot()
				_bull.play(BULL_IDLE, 1.0, 0.25)
				var meet: Vector3 = Ep2GoldTown.door_world("Bldg_Armory", 1.2) if _in_room("Bldg_Armory", -0.5) else _player_pos
				_bull.walk_to(_stand_off(_bull.position, meet, 2.3), 1.5)
		"to_lb":
			if not _bull.is_walking() and not _show_active:
				if _player_pos.distance_to(_bull.position) > 6.5:
					_bull.face_point(_player_pos)
					if _hud != null:
						_hud.objective = "Inferno's back - he's outside Rich's."
					return
				_bull_task = "greeted"
				_bull.face_point(_player_pos)
				look_toward(_bull.head_world(), 2.4)
				_start_show(_caption_steps(BULL_BACK_LINES) + [{"do": "call", "fn": release_look}], false)
		"greeted":
			if not _show_active:
				_advance_to(Beat.BODY)


## Where Inferno stops by the fallen stranger: on the lane side of him, the Minister kneeling on the other.
func _body_stand() -> Vector3:
	return _opp.position + Vector3(-1.5, 0.0, 2.3)


var _bull_path: Array = []
var _bull_speed: float = 1.5
var _make_way_t: float = 0.0
var _duck: Ep2DuckModifier = null


## Inferno walks the points in order (Ep2Actor walks one point at a time).
func _bull_route(points: Array, speed: float) -> void:
	_bull_path = points.duplicate()
	_bull_speed = speed
	if not _bull_path.is_empty():
		_bull.walk_to(_bull_path.pop_front(), speed)


func _tick_bull_route() -> void:
	if _bull == null or _bull_task not in ["to_body", "to_bar", "leaving"]:
		return
	_duck_bull()
	if _bull.is_walking():
		return
	if not _bull_path.is_empty():
		_bull.walk_to(_bull_path.pop_front(), _bull_speed)
		return
	match _bull_task:
		"to_body":
			_bull_task = "at_body"
			_bull.face_point(_minister.position if _minister != null else _opp.position)
		"to_bar":
			_bull_task = "at_bar"
			_bull.face_point(_player_pos)
		"leaving":
			_bull_task = ""
			_bull.visible = false
			_set_duck(0.0)


## Section 4.5: a 2.9 m man through the saloon's 2.5 m batwing door - he stoops (Ep2DuckModifier) as he nears the door plane and straightens
## once through, and drops a hand's breadth, so the lintel never cuts his hat.
func _duck_bull() -> void:
	var lp: Vector3 = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Saloon")).affine_inverse() * _bull.position
	var near: float = 0.0
	if absf(lp.x) < 2.2:
		near = clampf((2.0 - absf(lp.z)) / 1.3, 0.0, 1.0)
	_set_duck(near)


func _set_duck(amount: float) -> void:
	if _duck == null:
		if amount <= 0.0 or _bull.skeleton == null:
			return
		_duck = Ep2DuckModifier.new()
		_duck.name = "DoorDuck"
		_bull.skeleton.add_child(_duck)
		_bull_model_y = _bull.model.position.y if _bull.model != null else 0.0
	_duck.amount = amount
	_max_duck = maxf(_max_duck, amount)
	_duck.forward = Vector3(sin(_bull.rotation.y), 0.0, cos(_bull.rotation.y))
	if _bull.model != null:
		_bull.model.position.y = _bull_model_y - 0.12 * amount


var _bull_model_y: float = 0.0
var _max_duck: float = 0.0                            # the deepest stoop so far (test evidence)


## Two whiskeys on the bar: the one from the draw's round and a second for Inferno beside it.
func _pour_two() -> void:
	var bar_top: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(-0.6, 1.2, -8.7))
	_place(_glass, bar_top)
	if _glass2 == null:
		_glass2 = _prop(WHISKEY_MODEL, 0.11)
		_whiskey_look(_glass2)
	_place(_glass2, bar_top + (Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(1.1, 0.0, 0.0)) - Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3.ZERO)))


## What follows Dude's horse (the town's last errand): the ride - straight on if he bought the long rifle and the river gear at Rich's,
## else back to Rich's counter for them first.
func _after_story() -> void:
	if armory.sniper_owned and armory.river_gear:
		_advance_to(Beat.GEARED)
	else:
		_armory_return = true
		_advance_to(Beat.ARMORY)


## Section 2 step 2: close enough to the fallen stranger (or the Colt by him) for E to search him.
func _can_loot() -> bool:
	if _beat != Beat.LOOT or _got_peacemaker or _show_active or _opp == null:
		return false
	var near: float = _player_pos.distance_to(_opp.position)
	if _revolver != null and _revolver.get_parent() == _visuals:
		near = minf(near, _player_pos.distance_to(_revolver.position))
	return near < LOOT_R


## E at the body: his Peacemaker and the map to the auction are Lil Blunt's. Then Minister Mike Dean comes running (step 3).
func _loot() -> void:
	_got_peacemaker = true
	_got_map = true
	GameManager.has_region_map = true
	GameManager.map_active_destination = "auction"
	GameManager.save_session()
	_town_sfx("gun_pickup")
	if _revolver != null:
		_revolver.visible = false
	if _hud != null:
		_hud.set_search_prompt("")
		_hud.objective = ""
		_hud.toast("YOU TOOK HIS PEACEMAKER AND THE MAP TO THE AUCTION", 3.4)
	look_toward(_opp.position + Vector3(0.0, 0.3, 0.0), 2.0)
	_start_show(_caption_steps(LOOT_LINES) + [{"do": "call", "fn": release_look}], false)


## After the body (BODY) Mike Dean walks back to his counter, so the second visit finds him there.
func _minister_goes_home() -> void:
	if _minister == null:
		return
	_minister_task = "home"
	if _minister_rigged:
		_minister.hold_clip("Idle")
	var desk: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", MINISTER_DESK) + Vector3(0.0, MINISTER_STEP if _minister_rigged else 0.0, 0.0)
	_minister.walk_path([Ep2GoldTown.door_world("Bldg_Certificates", 1.6), Ep2GoldTown.door_world("Bldg_Certificates", -0.6),
		Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -2.0)), Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(3.2, 0.0, -3.4)),
		Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(3.2, 0.0, -5.4)), desk], MINISTER_WALK)


## Section 2 step 7: they really drink. Inferno lifts his glass on his own Stand_and_Drink clip; Lil Blunt's glass comes up to the camera.
func _drink_together() -> void:
	_drinks_done += 1
	_fp_drink_t = 0.0
	_town_sfx("whiskey_gulp")
	if _glass != null:
		_glass.visible = false                         # it is in his hand now
	if _fp_glass == null and _camera != null:
		_fp_glass = _prop(WHISKEY_MODEL, 0.085)
		_whiskey_look(_fp_glass)
		_fp_glass.reparent(_camera, false)
		_fp_glass.name = "LilBluntGlass"
	if _fp_glass != null:
		_fp_glass.visible = true
		_fp_glass.position = FP_GLASS_DOWN
		_fp_glass.rotation = Vector3.ZERO
	if _bull != null and _bull.anim != null and _bull.anim.has_animation(SmeltingFacilityChamber.BULL_SIP):
		var hand: Node3D = _bull.holder("RightHand")
		if hand != null and _glass2 != null:
			_glass2.reparent(hand, false)
			_glass2.position = Ep2BullHero.RIGHT_PALM_M * (_bull.height_m / 2.4) + Vector3(0.0, -0.05, 0.0)
			_glass2.rotation = Vector3.ZERO
		_bull.play(SmeltingFacilityChamber.BULL_SIP, 1.0, 0.25)
		_bull_sip_t = 0.0


## Lil Blunt's glass: up to his lips, tipped, and back down to the bar (FP_DRINK_S); Inferno's sip runs its clip, then his glass goes
## back on the bar beside the first.
func _tick_drink(delta: float) -> void:
	if _fp_drink_t >= 0.0 and _fp_glass != null:
		_fp_drink_t += delta
		var k: float = clampf(_fp_drink_t / FP_DRINK_S, 0.0, 1.0)
		var lift: float = smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.72, 1.0, k))
		_fp_glass.position = FP_GLASS_DOWN.lerp(FP_GLASS_LIP, lift)
		_fp_glass.rotation = Vector3(-1.05 * lift, 0.0, 0.0)
		if k >= 1.0:
			_fp_drink_t = -1.0
			_fp_glass.visible = false
			if _glass != null:
				_glass.visible = true
	if _bull_sip_t >= 0.0 and _bull != null:
		_bull_sip_t += delta
		var length: float = 3.0
		if _bull.anim != null and _bull.anim.has_animation(SmeltingFacilityChamber.BULL_SIP):
			length = _bull.anim.get_animation(SmeltingFacilityChamber.BULL_SIP).length
		if _bull_sip_t >= minf(length, 4.5):
			_bull_sip_t = -1.0
			_bull.play(BULL_IDLE, 1.0, 0.3)
			_pour_two()                                # both glasses back on the bar (_pour_two puts the second one beside the first)


## True while either of them has the glass up (the rifle stays low then).
func is_drinking() -> bool:
	return _fp_drink_t >= 0.0 or _bull_sip_t >= 0.0


## A recorded town effect (Ep2TownSoundscape.ROOT, generated by scripts/generate-town-audio.mjs --sfx): the stamp, the Colt picked
## up off the street, the gulp of whiskey - all at Lil Blunt, so not spatial. Silent when the streamed pack lacks the file.
func _town_sfx(id: String) -> void:
	var path: String = Ep2TownSoundscape.ROOT + id + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = load(path)
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Inferno's gift for Mike Dean (step 9): Lil Blunt carries the Gold Panner to the certificate office.
func _take_gold_panner() -> void:
	_gold_panner = true
	if _hud != null:
		_hud.toast("INFERNO'S GIFT FOR MIKE DEAN: THE GOLD PANNER", 3.6)


func _give_gold_panner() -> void:
	_gold_panner = false
	_panner_given = true
	if _hud != null:
		_hud.toast("YOU GAVE MIKE DEAN THE GOLD PANNER", 2.6)


## The second visit's stamp (the certificate path: the first visit refused, the stamp lands now).
func _stamp_certificate() -> void:
	_stamped = true
	_town_sfx("stamp_thud")
	if _hud != null:
		_hud.toast("YOUR CERTIFICATE IS STAMPED", 3.0)


func _show_finished() -> void:
	match _beat:
		Beat.OFFICE:
			_advance_to(Beat.TO_BAR)
		Beat.BAR:
			_advance_to(Beat.SQUARE_UP)


func _place(n: Node3D, p: Vector3) -> void:
	n.position = p
	n.visible = true


## The sheriff pushes in through the saloon doors (if Lil Blunt outran him, he is already at the door) and walks up to the bar.
func _sheriff_enters_saloon() -> void:
	Ep2DrawMusic.begin(self)
	var outside: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 1.2)
	if _sheriff.position.distance_to(outside) > 4.0:
		_sheriff.position = outside
	_sheriff.walk_path([Ep2GoldTown.door_world("Bldg_Saloon", -0.6), Ep2GoldTown.local_to_world("Bldg_Saloon", SHERIFF_SALOON)], 1.4)


func _sheriff_look_at_player() -> void:
	_sheriff.face_point(_player_pos)


func _tick(delta: float) -> void:
	if _fine_toast_t > 0.0:
		_fine_toast_t = maxf(0.0, _fine_toast_t - delta)
		if _fine_toast_t == 0.0 and _hud != null:
			_hud.toast(_fine_toast_text, 3.4)
	if _law != null:
		_law.step(delta)
		if _law.suspends_story():
			_tick_people(delta)
			return
	var intro_busy: bool = _intro != null and _intro.is_busy()
	var duel: bool = _beat in [Beat.BAR, Beat.SQUARE_UP, Beat.DRAW]
	if _stable_yard != null:
		_stable_yard.step(delta, _player_pos, duel or _hold > 0.0 or _show_active or intro_busy or _shop_open)
	if _town_audio != null:
		_town_audio.step(delta, _people, _player_pos, _hold > 0.0 or _show_active or intro_busy or _shop_open, duel)
		if not _show_active and _hold <= 0.0 and not intro_busy and not duel and not _shop_open and _town_audio.has_queued():
			_begin_carry_line(_town_audio.take_line())
	if _bumps != null:
		var shove: Vector3 = _bumps.step(delta, _player_pos)
		if shove.length_squared() > 0.0001:
			# Several ordinary collision moves, never a teleport through a wall. The town has no damage/hearts.
			var parts: int = maxi(1, ceili(shove.length() / 0.15))
			for i in parts:
				var next: Vector3 = _collide(_player_pos + shove / float(parts))
				_player_pos.x = next.x
				_player_pos.z = next.z
			if _vm != null:
				_vm.cam_kick = maxf(_vm.cam_kick, 0.045)
	_tick_people(delta)
	_tick_minister(delta)
	_tick_bull_route()
	if _gatling != null:
		_gatling.step(delta)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		_flash.light_energy = 6.0 * _flash_t / 0.08
	match _beat:
		Beat.STREET:
			if _in_room("Bldg_Certificates", -1.4):
				_advance_to(Beat.OFFICE)
		Beat.TO_BAR:
			if _in_room("Bldg_Saloon", -5.5):
				_advance_to(Beat.BAR)
		Beat.SQUARE_UP:
			_duel_ready = _player_pos.distance_to(DUEL_MARK) < 2.0 and not _opp.is_walking() and not _sheriff.is_walking()
			if _duel_ready and (_people == null or _people.duel_lane_clear()):
				_advance_to(Beat.DRAW)
		Beat.DRAW:
			_tick_draw(delta)
		Beat.WON:
			Ep2DrawMusic.finish(self)
			_won_t += delta
			# the Sheriff has called it; the body is there to be searched (the street cheers and dances meanwhile)
			if not _show_active and _won_t > 0.8:
				_advance_to(Beat.LOOT)
		Beat.LOOT:
			_won_t += delta
			var can: bool = _can_loot()
			if _hud != null and can != _loot_prompt:
				_hud.set_search_prompt(("Search him [E]" if TouchUi.keys_shown() else "Search him") if can else "")
			_loot_prompt = can
			# the Minister's panic and his prayer play out after the loot; the job follows once the street has had its cheer
			if _got_peacemaker and _panic_done and not _show_active and _won_t > _people_cheer_s():
				_advance_to(Beat.JOB)
		Beat.JOB:
			if not _job_said and not _sheriff.is_walking() and not _show_active:
				_job_said = true
				_sheriff.face_point(_player_pos)
				look_toward(_sheriff.position + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.4)
				# with the jailhouse streamed in he leads the way there; without it he sends him straight to Rich & Utah
				var lines: Array = JOB_LINES + (JOB_TO_JAIL_LINES if Ep2GoldTown.jail_v1 else ARMORY_SEND_LINES)
				_start_show(_caption_steps(lines) + [{"do": "call", "fn": release_look}], false)
			elif _job_said and not _show_active:
				_advance_to(Beat.JAIL_TIP if Ep2GoldTown.jail_v1 else Beat.TIP)
		Beat.JAIL_TIP:
			# the Sheriff leads: if Lil Blunt outruns him, the prisoner talks once the Sheriff is in too
			if _in_room("Bldg_Jail", -1.2) and (_sheriff == null or not _sheriff.is_walking()):
				_advance_to(Beat.JAIL)
		Beat.JAIL:
			# the exchange over, the hunt (lake -> river -> trains -> Fort Knox) is on; THEN the Sheriff sends him to Rich & Utah (step 4)
			if not _show_active:
				if _jail_done_t < 0.0:
					_jail_done_t = 0.0
					_investigation_open = true
					if _hud:
						_hud.toast("THE HUNT IS ON: WHO BROUGHT THE BEARS?", 3.8)
					if _sheriff != null:
						_sheriff.face_point(_player_pos)
					look_toward(_sheriff.position + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.4)
					_jail_sent = true
					_start_show(_caption_steps(ARMORY_SEND_LINES) + [{"do": "call", "fn": release_look}], false)
				else:
					_jail_done_t += delta
					if _jail_done_t > 0.6:
						_advance_to(Beat.TIP)
		Beat.TIP:
			if _in_room("Bldg_Armory", -1.4):
				_armory_visited = true
				_advance_to(Beat.ARMORY)
		Beat.ARMORY:
			_armory_visited = true
			_tick_armory_guns(delta)
			if _hud != null:
				if _mounted:
					_hud.set_search_prompt("")
				elif _can_mount():
					_hud.set_search_prompt("Take the crank [E]")
				else:
					_hud.set_search_prompt("Trade with Rich [E]" if _at_armory_counter() else "")
			_check_geared()
			_armory_t += delta
			if _gear_t >= 0.0 and not _show_active and not _mounted and _hold <= 0.0 and (_town_audio == null or not _town_audio.has_queued()) and not (_intro != null and _intro.is_busy()):
				_gear_t -= delta
				if _gear_t < 0.0:
					_advance_to(Beat.GEARED)
			elif not _armory_return:
				# section 4.3: the Gatling tested (a burst fired from the crank, then stepped off, Utah's intro wound up) is Inferno's cue.
				# With no Gatling streamed in (the pack is not mounted), he still comes once the visit has had its time.
				if _gat_tested_t < 0.0 and _mount_bursts > 0 and not _mounted:
					_gat_tested_t = 0.0
				var free: bool = not _show_active and not _shop_open and not _mounted and not (_intro != null and _intro.is_busy())
				if _gat_tested_t >= 0.0 and free:
					_gat_tested_t += delta
					if _gat_tested_t >= GATLING_TESTED_HOLD:
						_advance_to(Beat.BULL_BACK)
				elif _gatling == null and free and _armory_t > 25.0:
					_advance_to(Beat.BULL_BACK)
		Beat.BULL_BACK:
			_tick_bull_back(delta)
		Beat.BODY:
			if not _body_said and _bull_task == "at_body" and not _show_active and _player_pos.distance_to(_opp.position) < BODY_NEAR:
				_body_said = true
				_bull.face_point(_minister.position if _minister != null else _opp.position)
				look_toward(_opp.position + Vector3(0.0, 0.5, 0.0), 2.2)
				_start_show(_caption_steps(BODY_LINES) + [{"do": "call", "fn": release_look}], false)
			elif _body_said and not _show_active:
				_advance_to(Beat.DRINKS)
		Beat.DRINKS:
			_tick_drink(delta)
			if not _drinks_said and _bull_task == "at_bar" and not _show_active and _in_room("Bldg_Saloon", -5.5):
				_drinks_said = true
				_minister_goes_home()                 # while they drink, Mike Dean gets up and goes back behind his counter
				_pour_two()
				_bull.face_point(_player_pos)
				look_toward(_bull.head_world(), 2.0)
				# the toast, then they really drink (step 7), then Flux's kettle (step 8) and the gift for Mike Dean (step 9)
				_start_show(_caption_steps(DRINK_LINES) + [{"do": "call", "fn": _drink_together}, {"do": "wait", "t": FP_DRINK_S + 0.2}]
					+ _caption_steps(FLUX_LINES) + _caption_steps(GIFT_LINES) + [{"do": "call", "fn": _take_gold_panner},
					{"do": "call", "fn": release_look}], false)
			elif _drinks_said and not _show_active and not is_drinking():
				# Inferno heads off to his cousin's; the story's next thread is the gift for Mike Dean
				_bull_task = "leaving"
				_bull_route([Ep2GoldTown.door_world("Bldg_Saloon", -1.0), Ep2GoldTown.door_world("Bldg_Saloon", 3.0), Vector3(1.5, 0.0, 1470.0),
					Vector3(16.0, 0.0, 1480.0)], 1.6)
				_advance_to(Beat.MINISTER2)
		Beat.MINISTER2:
			# the second visit: in at the counter with the Gold Panner - the stamp, then the referral to Dude (steps 9-10)
			if not _minister2_said and not _show_active and _in_room("Bldg_Certificates", -1.4) \
					and (_minister == null or not _minister.is_walking()):
				_minister2_said = true
				if _minister != null:
					_minister.face_point(_player_pos)
					look_toward(_minister.position + Vector3(0.0, MINISTER_HEIGHT * 0.85, 0.0), 2.4)
				_start_show(_caption_steps(MINISTER2_LINES.slice(0, 2)) + [{"do": "call", "fn": _give_gold_panner}]
					+ _caption_steps(MINISTER2_LINES.slice(2, 3)) + [{"do": "call", "fn": _stamp_certificate}]
					+ _caption_steps(MINISTER2_LINES.slice(3)) + [{"do": "call", "fn": release_look}], false)
			elif _minister2_said and not _show_active:
				_advance_to(Beat.STABLES)
		Beat.STABLES:
			# Dude's conversation runs in Ep2StableYard (talk [E]); the horse bought, his "Logan's Lake first" said -> the ride
			if _horse_bought and not _show_active and (_stable_yard == null or not _stable_yard.conversation_active()):
				_after_story()
		Beat.GEARED:
			if _hud != null:
				_hud.set_search_prompt(("Mount horse [E]" if TouchUi.keys_shown() else "Mount horse") if can_mount_departure() else "")
			if _depart_mounted:
				_end_t = maxf(0.0,_end_t-delta)
				var mount_k: float = smoothstep(0.0,1.0,1.0-_end_t/1.2)
				_player_pos = _depart_from.lerp(DEPART_HORSE,mount_k)
				eye_height = lerpf(1.55,2.18,mount_k)
				_look_yaw = lerp_angle(_look_yaw,atan2(10.0,-9.0),mount_k)
				if _end_t == 0.0 and _handoff_ok(): _advance_to(Beat.DONE)

	if _stable_yard != null and _hud != null:
		var show_prompt: bool = _stable_interaction_allowed() and _stable_yard.can_talk(_player_pos)
		if show_prompt:
			_hud.set_search_prompt("Talk to Dude [E]" if TouchUi.keys_shown() else "Talk to Dude")
		elif _stable_prompt_shown and _beat != Beat.ARMORY:
			_hud.set_search_prompt("")
		_stable_prompt_shown = show_prompt


func _stable_interaction_allowed() -> bool:
	return (_world_revisit or _beat not in [Beat.BAR, Beat.SQUARE_UP, Beat.DRAW, Beat.GEARED, Beat.DONE]) and _hold <= 0.0 and not _show_active and not _shop_open and not (_intro != null and _intro.is_busy())


func _on_stable_line(who: String, text: String, id: String, _voice: String) -> void:
	var seconds: float = _read_seconds(text)
	if id != "" and Ep2TownVoiceBank.LINES.has(id):
		seconds = maxf(seconds, Ep2TownVoiceBank.seconds(id) + 0.3)
	if _hud != null:
		_hud.toast("%s: %s" % [who, text], seconds)
	if id != "":
		line_spoken.emit(id)
		if Ep2TownVoiceBank.LINES.has(id):
			if _town_audio != null: _town_audio.silence_greeting()
			var recording: AudioStream = Ep2TownVoiceBank.stream(id)
			if recording != null:
				var am: Node = get_node_or_null("/root/AudioManager")
				if am != null: am.play_voice(id, recording)
	captioned.emit(who, text)


func _on_stable_horse_bought(_paid: int, _credit: int) -> void:
	_horse_bought = true
	GameManager.map_active_destination = "logans_lake"
	GameManager.save_session()
	if _hud != null:
		_hud.objective = "Take your horse to Logan's Lake first so she can drink and cool down. It's on the map."


func can_mount_departure() -> bool:
	return _beat == Beat.GEARED and _horse_bought and not _mounted_transport and not _depart_mounted and not _show_active and _player_pos.distance_to(DEPART_HORSE) < 3.0

func _wants_handoff() -> bool:
	return _beat == Beat.GEARED and _depart_mounted and not _show_active


## True when Lil Blunt is inside `piece` deeper than `depth` (local z, negative = inside).
func _in_room(piece: String, depth: float) -> bool:
	var e: Array = Ep2GoldTown.entry(piece)
	var lp: Vector3 = Ep2GoldTown.building_xform(e).affine_inverse() * _player_pos
	var fp: Array = Ep2GoldTown.FOOTPRINT["Bldg_Armory2" if piece == "Bldg_Armory" and Ep2GoldTown.armory_v2 else piece]
	return lp.z < depth and absf(lp.x) < float(fp[0]) * 0.5


## The cast: the Sheriff strolls where he is sent (after his delay) and turns to whoever he is talking to; the stranger walks and squares up.
func _tick_people(delta: float) -> void:
	_tick_shopkeepers(delta)
	if _sheriff_delay > 0.0:
		_sheriff_delay -= delta
		if _sheriff_delay <= 0.0 and not _sheriff_goes.is_empty():
			_sheriff.walk_path(_sheriff_goes, 1.35)
			_sheriff_goes = []
	if not _sheriff.is_walking():
		if _beat == Beat.DRAW:
			_sheriff.face_point((DUEL_MARK + OPP_MARK) * 0.5)
		elif _beat in [Beat.OFFICE, Beat.BAR, Beat.WON, Beat.JOB]:
			_sheriff_look_at_player()
	if _beat == Beat.SQUARE_UP and not _opp.is_walking():
		_opp.face_point(DUEL_MARK)
	# the Armory's two turn to whoever comes in the door of the shop
	if _people != null:
		_people.set_context("duel" if _beat in [Beat.BAR, Beat.SQUARE_UP, Beat.DRAW] else ("quiet" if _beat in [Beat.OFFICE, Beat.WON, Beat.JOB, Beat.BODY, Beat.JAIL] else "normal"))
		_people.step(delta, _player_pos)
	if _accomplice != null:
		_accomplice.step(delta)
	if _rich_brain != null:
		_rich_brain.step(delta, _player_pos)
		_utah_brain.step(delta, _player_pos)
	elif _rich != null and _beat in [Beat.TIP, Beat.ARMORY, Beat.GEARED] and _in_room("Bldg_Armory", -2.0):
		_rich.face_point(_player_pos)
		if _utah != null:
			_utah.face_point(_player_pos)
	_sheriff.step(delta)
	_minister.step(delta)
	_opp.step(delta)
	_bartender.step(delta)


# --- the draw ---------------------------------------------------------------------------------------------------------

func _start_round() -> void:
	_player_drawn = false
	_draw_state = "wait"
	_draw_t = 0.0
	_opp_pool = null
	_draw_wait = _rng.randf_range(DRAW_WAIT_MIN, DRAW_WAIT_MAX)
	_opp.position = OPP_MARK
	_face_folk(_opp, DUEL_MARK)
	_opp.set_pose("idle")
	_opp.dead = false
	_opp.rotation = Vector3(0.0, _opp.rotation.y, 0.0)
	_holster_revolver()
	_sheriff.position = WITNESS_MARK
	look_toward(OPP_MARK + Vector3(0.0, 1.6, 0.0), 3.0)


## Seconds the stranger takes from the bell to his shot this round.
func opp_reaction() -> float:
	return OPP_REACTION + OPP_REACTION_STEP * float(mini(_losses, 3))


func _tick_draw(delta: float) -> void:
	_draw_t += delta
	match _draw_state:
		"wait":
			if _draw_t > 0.6:
				release_look()
			if _draw_t >= _draw_wait and _hold <= 0.0:
				if _town_audio == null or not _town_audio.ring_bell(): return
				_draw_state = "go"
				_draw_t = 0.0
				draw_bell_rung.emit()
				_opp_draws()
				if _hud:
					_hud.objective = "Enter to draw, then shoot!" if TouchUi.keys_shown() else "DRAW!"
		"go":
			if _draw_t >= opp_reaction():
				_opp_fires()
		"won":
			if _opp_pool == null and _draw_t > 0.55:
				var back: Vector3 = -Vector3(sin(_opp.rotation.y), 0.0, cos(_opp.rotation.y))
				var at: Vector3 = _opp.position + back * 0.75
				at.y = 0.0
				_opp_pool = BLOOD_FX.pool(_visuals, at, 0.55)
			if _draw_t > 0.8 and not _show_active:
				_advance_to(Beat.WON)
		"lost":
			if _hud:
				_hud.fade = clampf(_draw_t / 0.5, 0.0, 1.0) if _draw_t < 1.6 else clampf(1.0 - (_draw_t - 1.6) / 0.7, 0.0, 1.0)
			if _draw_t > 1.6 and _draw_state == "lost" and not _show_active and _hold <= 0.0:
				_restage()
				_begin_carry_line("vo_sheriff_lose")
				_draw_state = "relost"
		"relost", "foul":
			if _hud and _draw_state == "relost":
				_hud.fade = clampf(1.0 - (_draw_t - 1.6) / 0.7, 0.0, 1.0)
			if _hold <= 0.0 and _draw_t > 2.4:
				if _hud:
					_hud.fade = 0.0
					_hud.objective = "Listen for the bell. Hands still until it rings."
				_start_round()


func _restage() -> void:
	_player_pos = DUEL_MARK
	_look_yaw = _yaw_to(DUEL_MARK, OPP_MARK)
	_look_pitch = -0.02


## The weapon stays completely out of frame until the player draws after the bell.
func _viewmodel_lowered() -> bool:
	return (_beat == Beat.DRAW and not _player_drawn) or _fp_drink_t >= 0.0   # the glass is up


## Feet stay planted in the duel: he may look and aim, not walk.
func _current_speed() -> float:
	return 0.0 if _beat == Beat.DRAW else super._current_speed()


## A shot before the word is a FOUL (the round is redone); after it, the round is real.
func draw_weapon() -> bool:
	if _beat != Beat.DRAW or _draw_state != "go" or _player_drawn or not has_player_control():
		return false
	_player_drawn = true
	return true

func shoot() -> bool:
	if _beat == Beat.DRAW and _draw_state == "go" and not _player_drawn:
		if TouchUi.is_touch(): draw_weapon()
		return false
	if _mounted:
		if not has_player_control() or _gatling == null:
			return false
		if _gatling.fire_burst(0.7):
			_mount_bursts += 1
			if _people != null: _people.notify_danger(_player_pos, 32.0)
			return true
		if _hud != null:
			_hud.toast("THE DRUM IS EMPTY", 1.4)
		return false
	if _beat == Beat.DRAW and _draw_state == "wait" and has_player_control():
		_fouls += 1
		_draw_state = "foul"
		_draw_t = 0.0
		_begin_carry_line("vo_sheriff_foul")
		if _hud:
			_hud.objective = "FOUL - wait for the word."
		return false
	if _beat == Beat.DRAW and _draw_state != "go":
		return false
	return super.shoot()


func _on_player_shot() -> void:
	if _people != null: _people.notify_danger(_player_pos)
	var eye: Vector3 = _camera.global_position if _camera != null else _player_pos + Vector3(0.0, eye_height, 0.0)
	var dir: Vector3 = -_camera.global_transform.basis.z if _camera != null else Vector3(sin(_look_yaw), 0.0, cos(_look_yaw))
	var in_draw: bool = _beat == Beat.DRAW and _draw_state == "go"
	if in_draw and aim_hits_opponent(eye, dir):
		_draw_state = "won"
		_draw_t = 0.0
		var axis_hit: Vector3 = opponent_hit_point(eye, dir)
		var outward: Vector3 = eye - axis_hit
		if outward.length_squared() < 0.0001:
			outward = -dir
		outward = outward.normalized()
		var wound: Vector3 = axis_hit + outward * 0.18
		BLOOD_FX.spurt(_visuals, wound, dir)
		var body: Node3D = _opp.model if _opp.model != null else _opp
		BLOOD_FX.stain(body, wound, outward)
		_opp.fall_dead()
		_drop_revolver()
		if _hud:
			_hud.objective = ""
		return
	if _law != null:
		_law.player_shot(eye, dir, in_draw)


## True when a ray from `eye` along `dir` passes within OPP_HIT_R of the stranger's body (feet to hat).
func aim_hits_opponent(eye: Vector3, dir: Vector3) -> bool:
	var points: Array = _opp_ray_points(eye, dir)
	return (points[0] as Vector3).distance_to(points[1] as Vector3) < OPP_HIT_R


## The point on the stranger's body axis closest to this aim ray (the winning wound).
func opponent_hit_point(eye: Vector3, dir: Vector3) -> Vector3:
	return _opp_ray_points(eye, dir)[1]


func _opp_ray_points(eye: Vector3, dir: Vector3) -> Array:
	var a: Vector3 = _opp.position + Vector3(0.0, 0.3, 0.0)
	var b: Vector3 = _opp.position + Vector3(0.0, _opp.height_m, 0.0)
	var d: Vector3 = dir.normalized()
	# closest points between the ray and the body's axis
	var u: Vector3 = b - a
	var w0: Vector3 = eye - a
	var aa: float = d.dot(d)
	var bb: float = d.dot(u)
	var cc: float = u.dot(u)
	var dd: float = d.dot(w0)
	var ee: float = u.dot(w0)
	var den: float = aa * cc - bb * bb
	var sc: float = 0.0
	var tc: float = 0.0
	if den > 1e-6:
		sc = (bb * ee - cc * dd) / den
		tc = clampf((aa * ee - bb * dd) / den, 0.0, 1.0)
	sc = maxf(sc, 0.0)
	return [eye + d * sc, a + u * tc]


## The stranger's gun hand comes up with the revolver in it (the baked "Draw" arm pose + the prop at his hand).
func _opp_draws() -> void:
	_opp.set_pose("draw")
	if _revolver.get_parent() != _opp:
		_revolver.reparent(_opp, false)
	_revolver.visible = true
	_revolver.position = COWBOY_HAND_DRAW * COWBOY_HEIGHT
	_revolver.rotation = Vector3(0.0, 0.0, 0.0)
	_opp.kick()


## The Peacemaker back in its holster on his hip, barrel down (a new round, a restage).
func _holster_revolver() -> void:
	if _revolver == null:
		return
	if _revolver.get_parent() != _opp:
		_revolver.reparent(_opp, false)
	_revolver.visible = true
	_revolver.position = OPP_HOLSTER
	_revolver.rotation = Vector3(PI * 0.5 - 0.12, 0.0, 0.0)


## He falls: the Colt leaves his hand and lies in the dirt by him, on its side - E there takes it (and the map) in Beat.LOOT.
func _drop_revolver() -> void:
	if _revolver == null:
		return
	var at: Vector3 = _opp.to_global(Vector3(-0.42, 0.0, 0.38)) if _opp.is_inside_tree() else _opp.position + Vector3(-0.42, 0.0, 0.38)
	_revolver.reparent(_visuals, false)
	_revolver.position = Vector3(at.x, 0.045, at.z)
	_revolver.rotation = Vector3(0.0, _opp.rotation.y + 0.9, PI * 0.5)
	_revolver.visible = true


## Where the round leaves the Colt's barrel (the kit's origin is the bore at the cylinder's front face; the barrel runs +z).
func _opp_muzzle() -> Vector3:
	if _revolver != null and _revolver.is_inside_tree():
		return _revolver.to_global(Vector3(0.0, 0.0, 0.19))
	return _opp.position + Vector3(0.3, 1.2, 0.4)


func _opp_fires() -> void:
	_opp.kick()
	_losses += 1
	_draw_state = "lost"
	_draw_t = 0.0
	_sfx("ep2_revolver_blast_1")
	_sfx("damage")
	_flash.position = _opp_muzzle()
	_flash_t = 0.08
	if _hud:
		_hud.objective = ""


# --- state the tests read ----------------------------------------------------------------------------------------------

## The town's law owns control only while the Sheriff is escorting Lil Blunt.
## Inside the cell the eye remains free; its collision keeps him behind bars.
func has_player_control() -> bool:
	return super.has_player_control() and (_law == null or not _law.blocks_control())


func _law_arrest_started() -> void:
	_sheriff_delay = 0.0
	_sheriff_goes = []
	_move_input = Vector2.ZERO
	_run_input = false
	_end_guns()
	set_aim(false)
	release_look()
	if _hud != null:
		_hud.set_search_prompt("")


func _law_line(who: String, text: String) -> void:
	_caption_line(who, text)


func _law_fine(amount: int, debt: int) -> void:
	_caption_line("SHERIFF", Ep2TownLaw.FINE_LINE)
	_fine_toast_text = "SHERIFF'S FINE: %d BTC" % amount
	if debt > 0:
		_fine_toast_text += " - %d BTC ON THE BOOKS" % debt
	_fine_toast_t = 2.0


func _law_cold_cast(who: String, lines: Array) -> void:
	if not _show_active:
		_start_show(_caption_steps(lines), false)


func _on_person_cold(id: String, _actor: Ep2TownFolk) -> void:
	if _law != null and _law.suspends_story():
		return
	var line: Array = Ep2TownLaw.cold_line_for(id)
	if not line.is_empty():
		_caption_line(str(line[0]), str(line[1]))


## The chamber exposes the law for evidence and for the later story hand-off.
func get_town_law() -> Ep2TownLaw: return _law


## Called by the story when Lil Blunt leaves town; ownership was never erased.
func return_firearms() -> void:
	armory.return_firearms()


func get_draw_state() -> String: return _draw_state
func get_draw_wait() -> float: return _draw_wait
func get_losses() -> int: return _losses
func get_fouls() -> int: return _fouls
func has_map() -> bool: return _got_map
func has_peacemaker() -> bool: return _got_peacemaker
func can_loot() -> bool: return _can_loot()
func get_revolver() -> Node3D: return _revolver
func has_gold_panner() -> bool: return _gold_panner
func gold_panner_given() -> bool: return _panner_given
func is_stamped() -> bool: return _stamped
func drinks_done() -> int: return _drinks_done
func horse_bought() -> bool: return _horse_bought
func jail_sent_to_armory() -> bool: return _jail_sent
func get_sheriff() -> Ep2TownFolk: return _sheriff
func get_minister() -> Ep2TownFolk: return _minister
func get_opponent() -> Ep2TownFolk: return _opp
func get_bartender() -> Ep2TownFolk: return _bartender
func get_people() -> Ep2TownPeople: return _people
func get_accomplice() -> Ep2TownFolk: return _accomplice
func is_investigation_open() -> bool: return _investigation_open
func jail_visited() -> bool: return _jail_visited
func get_rich() -> Ep2TownFolk: return _rich
func get_utah() -> Ep2TownFolk: return _utah
func get_shop() -> Ep2ArmoryShop: return _shop
func is_shop_open() -> bool: return _shop_open
func armory_visited() -> bool: return _armory_visited
func has_sniper() -> bool: return armory.sniper_owned
func has_river_gear() -> bool: return armory.river_gear
func coins_spent() -> int: return _spent
## The personal armory's key stays out of the trade: while Rich has the counter up, the loadout
## selector (and the trade's own E) must not fight over the same key.
func toggle_armory() -> void:
	if _shop_open or _mounted or not _running or _resolved or _show_blocks_control:
		return
	super()
func armory_open() -> bool:
	return _shop_open or super()
func is_bull_here() -> bool: return _bull != null and _bull.visible
## Section 4 (post-draw) evidence.
func get_bull() -> Ep2Actor: return _bull
func get_quad() -> Ep2TownQuad: return _quad
func bull_task() -> String: return _bull_task
func minister_rigged() -> bool: return _minister_rigged
func minister_task() -> String: return _minister_task
func is_armory_return() -> bool: return _armory_return
func max_duck() -> float: return _max_duck
func is_second_glass_on_bar() -> bool: return _glass2 != null and _glass2.visible
func is_coin_on_bar() -> bool: return _coin != null and _coin.visible
func is_glass_on_bar() -> bool: return _glass != null and _glass.visible


## Hearts are restored after a lost draw (a retry, never a death); the duel is the only place the HUD shows them.
func _shows_health() -> bool:
	return _beat == Beat.DRAW


## The street and the two rooms: the building walls (door gaps open into the office and the saloon), the counter, the bar, the props.
func _collide(p: Vector3) -> Vector3:
	if _law != null and _law.cell_locked():
		return _law.confine_cell(p)
	var c: Vector2 = Ep2GoldTown.collide(Vector2(p.x, p.z), 0.3, _town_col.get("walls", []), _town_col.get("props", []))
	if _people != null and p.y < 2.0:
		for person in _people.people:
			if absf(person.folk.position.y - p.y) > 1.5:
				continue                     # the saloon's balcony drinkers are 4 m up: they do not stand in the street under them
			var dv: Vector2 = c - Vector2(person.folk.position.x, person.folk.position.z)
			if dv.length() < 0.64:
				c = Vector2(person.folk.position.x, person.folk.position.z) + (dv.normalized() if dv.length() > 0.001 else Vector2.RIGHT) * 0.64
				c = Ep2GoldTown.collide(c, 0.3, _town_col.get("walls", []), _town_col.get("props", []))
	# Restore access to the original approach yard without opening the woods or any story gate.
	return Vector3(clampf(c.x, -40.0, 40.0), p.y, clampf(c.y, Ep2StableYard.PADDOCK.position.y - 2.0, Ep2GoldTown.TOWN_Z + 95.0))
