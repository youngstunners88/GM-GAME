class_name GoldTownChamber
extends Ep2Interlude
## THE GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; skills ep2-surface-to-town,
## ep2-gold-rush-town, ep2-sheriff-jake, ep2-quickdraw-duel). Bull has dropped Lil Blunt in the main street and ridden off to see
## his blonde lady friend. The town chamber takes over in the same street (one invisible cut: Ep2GoldTown builds the town and the
## desert at the same coordinates in both rooms) and plays the rest of the slice in first person, the Winchester in his hands:
##
##   STREET    walk to the CERTIFICATES office
##   OFFICE    The Sheriff (the founder's own character: weathered, long duster, star, a wisp of smoke) and Minister Mike Dean behind the
##             counter, facing the door. On his left wall hang the four Miner's License certificates (Prospector's, Miner's, Foreman's, Mine
##             Owner's). First visit = a soft gate: the four licenses + Flip / Builder bonds explained, no free paper (Phase 2 reframe
##             2026-11-03, docs/founder-feedback/2026-11-03_phase2_license_reframe.md section 3.1)
##   TO_BAR    cross the street to the SALOON
##   BAR       a whiskey, a quarter of a Bitcoin on the bar, the bartender's jaw drops, a stranger at the end of the bar noticed -
##             "Give me a Bitcoin in exchange for the map to the auction, where you can get more gold and Bitcoin." Lil Blunt won't. the Sheriff walks
##             in: he is the witness
##   SQUARE_UP out in the street, face him; the Sheriff stands to the side
##   DRAW      the rifle stays down until the town bell rings (a seeded wait). Fire early = a foul, the Sheriff makes them redo it. Hit him first
##             = the map. Too slow = he shoots first: the screen drops, hearts restored, the Sheriff sets it up again (retry, never a death)
## POST-DRAW - THE LOCKED STORY ORDER (founder fix pack 2026-10-27 section 2, docs/founder-feedback/2026-10-27_fix_pack.md; it replaces the
## 2026-10-25 order and keeps its scenes):
##   WON       he wins: the stranger had drawn a Borchardt C93 from his hip (founder 2026-11-02); it falls by the body, which bleeds.
##             The street celebrates, then dances. Inferno does NOT arrive.
##   LOOT      E at the body takes the Borchardt and the map to the auction (the map is never handed over without it)
##             ...then Minister Mike Dean runs out of his office, alarmed, asks what happened, and kneels to pray over the gentleman
##   JOB       Sheriff James, impressed with the draw, offers the job (who let the bears hold Fort Knox) and leads him to the jail
##   JAIL_TIP / JAIL  the Sheriff walks him out to the jailhouse; the prisoner talks; THEN the Sheriff sends him to Rich & Utah
##   TIP       the tip: RICH keeps an armory down the side lane off the left row (off Main Street, deliberately not obvious)
##   ARMORY    Rich the Claim Recorder and Utah: the trade (E at the counter: firearms, ammunition, river gear for Episode 1 crypto) and
##             the Colt Gatling in the yard (it hits the targets and sounds intense)
##   BULL_BACK after the Gatling: Inferno rides back in on his quad, parks outside Rich's; the first whiskey's on him
##   BODY      on the way: Mike Dean again, still praying by the body; Inferno greets him - "Must've been a bird ..."
##   DRINKS    the bar: they really drink (Inferno lifts his glass, Lil Blunt's comes up to the camera); Inferno has to help his cousin
##             Flux with his new kettle; before he goes he points Lil Blunt back to Mike Dean for a real Miner's License or a bond
##             (Phase 2 reframe 2026-11-03: Inferno gifts NO paper - there is no Gold Panner and no stamp anywhere)
##   MINISTER2 the second visit: Mike Dean's license / bond close (the four licenses on his left wall), then the referral to his
##             friend Dude at the horse stables
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
## The loot at the body (section 2 step 2): his Borchardt and the map to the auction.
const LOOT_LINES: Array = [
	["LIL BLUNT", "A Borchardt pistol. And the map to the auction - that's what he wanted a Bitcoin for."],
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
## ...they drink (section 2 step 7: visible drinking, not pantomime), then Inferno's pointer back to Mike Dean (no gift), and Flux's kettle.
const FLUX_LINES: Array = [
	["INFERNO", "Listen, my cousin Flux needs a hand with his new kettle."],
	["INFERNO", "We'll lie low a little while and meet up later. Stay out of trouble."],
]
## Phase 2 reframe (2026-11-03) section 3.2: post-drink, before Flux - Inferno gifts nothing, he points back to Mike Dean.
const INFERNO_LICENSE_LINES: Array = [
	["INFERNO", "You already got the map off that fool. That'll get you in the door at the auction."],
	["INFERNO", "If you want real weight - lower fees, Builder share, something that actually sits on the vault - go back to Mike Dean. Get a proper Miner's License. Or bond if you've got the ETH. I ain't carrying paper for you."],
]
## Section 3.1: the first visit (pre-draw, Bull sent him) - the four licenses on the left wall and the bonds; a soft gate, no free paper.
## Index 1 is the line where Mike Dean turns Lil Blunt's eye to the wall (`MINISTER_WALL_LINE`).
const MINISTER1_LINES: Array = [
	["MIKE DEAN", "Bull sent you. Looking for a claim."],
	["MIKE DEAN", "We don't hand out paper for free. What you're looking at on the wall are the four licenses that actually sit on the wBTC vault."],
	["MIKE DEAN", "Prospector's is the floor. Then Miner's, Foreman's, Mine Owner's. Each one carries a bigger floor claim and better perks - pre-order queue, lower trade tax, Builder pool weight."],
	["MIKE DEAN", "You can start with a Prospector's when you're ready, or go the bond route if you want the discount and a real share of the gold. Flip bond gets you NOTE cheaper. Builder bond puts you in the longer pool."],
	["MIKE DEAN", "Sheriff's the one who can walk you through the process once you've got skin in it. Right now you're just a man who walked in with Bull's name. That's not enough for a license."],
]
const MINISTER_WALL_LINE := 1
## Section 3.3: the second visit (post-Flux) - the license / bond close, then the referral to Dude (steps 9-10). Index 1 turns to the wall.
const MINISTER2_LINES: Array = [
	["MIKE DEAN", "You're back. And you walked out of a street draw with a map and a dead man behind you."],
	["MIKE DEAN", "The map is useful. The license is weight."],
	["MIKE DEAN", "Prospector's gets you on the board. Higher licenses unlock the pre-order queue, cut the trade tax, and put real Builder pool weight behind your name. Everything is backed by the same wBTC vault - floor is real."],
	["MIKE DEAN", "If you've got ETH and want the bigger share, look at a Builder bond. If you just want NOTE at a discount, the Flip bond is open when the round is live."],
	["MIKE DEAN", "Decide what you actually want. Then we can talk numbers. In the meantime, if you need a horse that won't die in the heat, talk to my good friend Dude at the stables. Tell him I sent you."],
	["LIL BLUNT", "Much obliged, Minister."],
]
## The four Miner's License tiers on the office's left wall, low to high (the same ladder as the Auctions - Miner's License UI).
## Each tier's printed certificate (GPT Image 2 via Muapi, 2026-11-03: engraved parchment, its title, "GOLDMINE TERRITORY", "BACKED BY
## THE wBTC VAULT", a copper / silver / gold / platinum seal, "TIER n OF 4"). Streamed in the Episode 2 extras pack (the main pack has
## no room for four textures); until it mounts each frame shows a plain placard with the tier name.
const LICENSE_TIERS: Array = [
	["PROSPECTOR'S LICENSE", Color(0.72, 0.45, 0.25), "res://src/episode2/extras/town/licenses/tex_license_prospector.jpg"],
	["MINER'S LICENSE", Color(0.75, 0.76, 0.78), "res://src/episode2/extras/town/licenses/tex_license_miner.jpg"],
	["FOREMAN'S LICENSE", Color(0.93, 0.74, 0.25), "res://src/episode2/extras/town/licenses/tex_license_foreman.jpg"],
	["MINE OWNER'S LICENSE", Color(0.86, 0.90, 0.95), "res://src/episode2/extras/town/licenses/tex_license_mine-owner.jpg"],
]
## The drink itself: Inferno's Stand_and_Drink (the hideout's clip) and Lil Blunt's glass up to the camera, then down.
const FP_DRINK_S := 2.4
const FP_GLASS_DOWN := Vector3(0.13, -0.30, -0.42)          # camera space: the glass held low at the bar
const FP_GLASS_LIP := Vector3(0.03, -0.12, -0.24)          # ...at his lips, tipped
const LOOT_R := 2.4                                         # how close to the body [E] takes the gun and the map
## The stranger's Borchardt: in its holster on his gun-hand hip until the bell (his own frame, metres; the gun side is -x, as in
## COWBOY_HAND_DRAW), barrel down.
const OPP_HOLSTER := Vector3(-0.21, 0.93, 0.04)
const OPP_HOLSTER_ROT := Vector3(PI * 0.5 - 0.12, 0.0, 0.0)
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
const COWBOY_HAND_DRAW := Vector3(-0.122, 0.734, 0.315)     # his fist in the baked Draw mesh, measured (x -0.22, y 1.35, z 0.58 m at 1.84 m)
const OPP_GUN_GRIP := Vector3(0.0, -0.095, -0.012)          # where that fist closes on the Borchardt, in the gun's own frame (measured)
const OPP_DRAW_S := 0.14                                   # the pistol's travel from the hip to the aimed hand
const BARTENDER_HEIGHT := 1.76
const WHISKEY_MODEL := "res://src/episode2/assets/whiskey_glass.glb"
const COIN_MODEL := "res://src/episode2/assets/btc_coin.glb"
const SHERIFF_HEIGHT := 1.78
const DUDE_TREATS_WITHIN := 7.0
const ACCOMPLICE_HEIGHT := 1.74
const MINISTER_HEIGHT := 1.65
const MINISTER_STEP := 0.5                               # the low wooden step he stands on behind the counter, so the counter does not hide him
## In each building's local frame (x along the front, -z inside).
## Where the smoke rises on the Sheriff, as a fraction of his height (x his left, y up, z forward): Sheriff James's pipe bowl, which
## hangs from the left corner of his mouth.
const SHERIFF_MOUTH := Vector3(0.03, 0.855, 0.095)
## The license wall (office-local). Founder 2026-11-03 (follow-up): on the side OPPOSITE Minister Mike Dean's desk - the right wall's
## inner face (x +3.86; his desk and chair stand on the left, x -2.3), on the clear stretch between the side window (z ~ -5.3..-6.5,
## measured in tools/ep2_shots/license_wall_shot) and the back wall, above the safe. Seen from the counter it reads left to right
## Prospector's -> Mine Owner's, rising slightly - the ladder.
const LICENSE_WALL_AT := Vector3(3.86, 1.55, -6.9)       # the FRONT-most frame (the top tier); lower tiers step towards the back
const LICENSE_WALL_STEP := 0.58                           # along the wall
const LICENSE_WALL_RISE := 0.08                           # the slight diagonal, rising to the top tier
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
var _retaliation_entry: Dictionary = {}
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
var _patch_shop: Ep2BudPatchShop = null
var _shop_open: bool = false
var _shop_bought: bool = false
var _town_audio: Ep2TownSoundscape = null
var _bumps: TOWN_BUMPS = null
var _law: Ep2TownLaw = null
var _miners: Ep2BackLotMiners = null          # the local gold miners in the back lots behind the fronts (PROMPT_BACK_MINERS_2026-11-08)
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
var _case: Ep2SharpsCase = null                        # the case's lid, its rifle and Rich's hands at it (the take-out, founder 2026-11-07)
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
var _got_peacemaker: bool = false                     # E at the body took the stranger's Borchardt (the name stays: saves and hand-over results carry it)
var _opp_gun_real: bool = false                        # the streamed Borchardt is in his holder (not the stand-in)
var _opp_draw_k: float = -1.0                          # the draw's progress, hip to hand; below 0 when not drawing
var _loot_prompt: bool = false
var _jail_sent: bool = false                          # the Sheriff has sent him on to Rich & Utah after the jail
var _fp_glass: Node3D = null                          # Lil Blunt's own glass, on the camera while he drinks
var _fp_drink_t: float = -1.0                         # >= 0 while that glass is up
var _bull_sip_t: float = -1.0                         # >= 0 while Inferno drinks
var _drinks_done: int = 0                             # drinks taken at the bar (test evidence)
var _license_talk: bool = false                       # the second visit's license / bond close has been heard (no paper changes hands)
var _minister2_said: bool = false
var _horse_bought: bool = false
var _depart_mounted: bool = false
var _depart_from := Vector3.ZERO
const DEPART_HORSE := Ep2LakeRoad.ORIGIN
const PLAYTEST_AT_DUDE := Vector3(2.0, 0.0, 1.5)     # beside his 3 m walk, within talk range of both ends


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
	# The cast is five steps, not one (founder 2026-11-01, "a glitch delay by the quad bike"): this room is prebuilt behind the woods
	# from the quad's reveal on, and every step runs inside one frame - the old single people step was the frozen frame at the quad.
	return [_step_light, _step_ground, _step_town, _step_desert, _step_people_core, _step_people_armory, _step_people_space,
		_step_people_crowd, _step_people_after, _build_back_lot_miners, _step_town_audio]


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
		_hud.speech("%s: %s" % [who, text], Ep2Speech.pace(id, text), Ep2Speech.voiced(id))
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


## The whole cast in one call (the old single step; the prebuild runs the five parts on separate frames).
func _step_people() -> void:
	_step_people_core()
	_step_people_armory()
	_step_people_space()
	_step_people_crowd()
	_step_people_after()
	_build_back_lot_miners()


## The draw's cast: the Sheriff, the barman, the stranger with his Borchardt, the glass, the coin and the muzzle light.
func _step_people_core() -> void:
	_build_sheriff()
	_build_license_wall()
	_bartender = Ep2TownFolk.new()
	_bartender.name = "Bartender"
	_visuals.add_child(_bartender)
	_bartender.setup(BARTENDER_MODEL, BARTENDER_HEIGHT, Color(0.85, 0.82, 0.74))
	_bartender.position = Ep2GoldTown.local_to_world("Bldg_Saloon", BARTENDER_AT)
	_face_folk(_bartender, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT))
	_opp = Ep2TownFolk.new()
	_opp.name = "Stranger"
	_visuals.add_child(_opp)
	_opp.ground_fn = Ep2GoldTown.ground_y
	_opp.setup(COWBOY_MODEL, COWBOY_HEIGHT, Color(0.2, 0.17, 0.15), false)
	_opp.position = Ep2GoldTown.local_to_world("Bldg_Saloon", OPP_AT_BAR)
	_face_folk(_opp, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT + Vector3(0.0, 0.0, -1.5)))
	# his Borchardt C93 (founder 2026-11-02: "holds and drops a Borchardt, not a Colt"): the gun-only model at real size (the old primitive
	# stands in until the streamed pack mounts), in its holster on his hip until the bell, then in his fist
	_revolver = Node3D.new()
	_revolver.name = "Revolver"
	_opp.add_child(_revolver)
	_arm_stranger()
	_holster_revolver()
	_glass = _prop(WHISKEY_MODEL, 0.11)
	_whiskey_look(_glass)
	_coin = _prop(COIN_MODEL, 0.06)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.45)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_visuals.add_child(_flash)


func _step_people_armory() -> void:
	_build_armory_folk()


## The townspeople's street graph (Ep2TownNavigation, now bucketed: ~0.3 s instead of ~9 s).
func _step_people_space() -> void:
	_people = Ep2TownPeople.new()
	_people.configure_space(_town_col)


func _step_people_crowd() -> void:
	_people.build(_visuals)


## The jail, the shopkeepers, Inferno (hidden until he rides back) and the town law.
func _step_people_after() -> void:
	_build_jail_folk()
	_build_shopkeepers()
	if _bull == null:
		_bull = _build_bull(Ep2GoldTown.door_world("Bldg_B", 0.8), PI * 0.5)
		_bull.visible = false
	_law = Ep2TownLaw.new()
	_law.name = "TownLaw"
	add_child(_law)
	_law.setup(self)


## The back-lot miners (founder 2026-11-08): digging, resting on a pitchfork, talking gold, sat on a crate - behind the fronts, off Main
## Street. Their bodies are solid to Lil Blunt (the same props list the counter, the Gatling post and the quad join).
func _build_back_lot_miners() -> void:
	if _miners != null and is_instance_valid(_miners): _miners.queue_free()
	_miners = Ep2BackLotMiners.new()
	_miners.name = "BackLotMiners"
	_visuals.add_child(_miners)
	_miners.build()
	if _town_col.has("props"):
		(_town_col["props"] as Array).append_array(_miners.circles)


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
	preload("res://src/episode2/actors/ep2_armory_pose.gd").install(_rich)
	preload("res://src/episode2/actors/ep2_armory_pose.gd").install(_utah)
	Ep2GroundedWalk.install(_rich)
	Ep2GroundedWalk.install(_utah)
	preload("res://src/episode2/actors/ep2_armory_pose.gd").install_rifle(_rich)
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
	sp["case_reach"] = Ep2SharpsCase.REACH_SPOT                     # beside the lit case, where his arm reaches the rifle's grip
	return sp


## The Sharps in the lit case (and a second instance for Rich's hand), the Gatling on its post in the yard with its plates, and the introduction that
## ties them to Rich and Utah. All of it is streamed art (Ep2Extras): where it is not mounted the Armory simply plays as before.
func _build_guns() -> void:
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	_sharps_case = _visuals.find_child("Arm2_Sharps_Bldg_Armory", true, false) as Node3D
	# the rifle he lifts IS the case rifle (the scoped showcase Sharps), under a glass lid that opens; without the stream the kit rifle stays
	_case = Ep2SharpsCase.new()
	_case.name = "SharpsCase"
	_visuals.add_child(_case)
	if _case.setup(xf, _rich, _visuals.find_child("Arm2_CaseLid_Bldg_Armory", true, false) as Node3D, _sharps_case):
		_sharps_case = _case.rifle
	else:
		_case.queue_free()
		_case = null
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
	if _case != null:
		_intro.case_point = _case.rest_point()
		_intro.reach_spot = "case_reach"
	_intro.voice_seconds = func(who: String, text: String) -> float: return Ep2Speech.pace(Ep2TownVoiceBank.id_for(_town_speaker(who), text), text)
	if _gatling != null and _gatling.plate_count() > 0:
		var first: Dictionary = _gatling.targets[0]
		_intro.demo_target = (first["node"] as Node3D).position + _gatling.position + Vector3(0.0, 1.22, 0.0)
	_intro.said.connect(func(who: String, text: String, _secs: float) -> void: _town_line(who, text))
	_intro.objective_changed.connect(_on_intro_objective)
	_intro.sharps_lifted.connect(_on_sharps_lifted)
	_intro.finished.connect(_on_intro_finished)


func _on_intro_objective(text: String) -> void:
	if _hud != null and _beat == Beat.ARMORY:
		var fallback: String = "Trade with Rich at the counter [E]." if TouchUi.keys_shown() else "Trade with Rich at the counter."
		_hud.objective = text if text != "" else fallback


func _on_intro_finished() -> void:
	_on_intro_objective("")


## Rich lifts the Sharps out of the lit case into his hand (the case rifle hides), or locks it back. Without a hand bone the rifle simply stays in the case.
func _on_sharps_lifted(in_hand: bool) -> void:
	if _case != null:
		if in_hand:
			_case.give_to_hand()
		else:
			_case.take_from_hand()                    # Ep2SharpsCase lowers it home on the intro's clock (or settles it, if the beat was cut short)
		return
	if not in_hand:
		if _rich != null:
			_rich.drop_prop("Sharps")
		if _sharps_case != null:
			_sharps_case.visible = true
		return
	if _rich == null:
		return
	var rifle: Node3D = preload("res://src/episode2/actors/ep2_armory_pose.gd").attach_rifle(_rich)
	if rifle != null:
		if _sharps_case != null:
			_sharps_case.visible = false


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
	if _case != null:
		_case.update(_intro.stage, _intro.stage_time())


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
	if can_use_bud_patch():
		_open_patch()
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


# --- Dude's Chill Bud patch (founder 2026-11-01) --------------------------------------------------------------------------------

## True beside the patch outside Dude's fence whenever he has control and no trade panel is up - including GEARED, the moment he is
## at the ranch about to ride for the lake (the stable yard's own talk rule is closed then).
func can_use_bud_patch() -> bool:
	return _stable_yard != null and not _shop_open and not _mounted and not _depart_mounted and not _show_active \
		and has_player_control() and Ep2BudPatch.in_reach(_player_pos)


func _open_patch() -> void:
	if _patch_shop == null:
		_patch_shop = Ep2BudPatchShop.new()
		_patch_shop.name = "BudPatchShop"
		_patch_shop.process_mode = Node.PROCESS_MODE_ALWAYS
		_patch_shop.buy_requested.connect(func(item_id: String, _price: int, tender: String) -> void: buy_buds_at_patch(item_id, tender))
		_patch_shop.closed.connect(_close_patch)
		if _shop_layer == null:
			_build_shop()
		_shop_layer.add_child(_patch_shop)
	_patch_shop.purse_of = func(t: String) -> int: return GameManager.purse_balance(t)
	_patch_shop.open_patch(GameManager.purse_balance(_patch_shop.tender))
	_shop_open = true
	_move_input = Vector2.ZERO
	_run_input = false
	set_aim(false)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _close_patch() -> void:
	if _patch_shop == null or not _patch_shop.visible:
		return
	_patch_shop.hide()
	_shop_open = false
	Input.mouse_mode = _mouse_before
	if not StateMachine.is_paused():
		get_tree().paused = false


## The patch sale: debit the tender first, then store the buds in Tabs (the same Chill Bud Dude sells). Never free, never twice for one
## payment. True when the buds were stored.
func buy_buds_at_patch(item_id: String, tender: String = "btc") -> bool:
	var row: Dictionary = Ep2BudPatch.item(item_id)
	var ok: bool = false
	if not row.is_empty() and Ep2ArmoryState.ARMORY_TENDER.has(tender) and GameManager.purse_spend(tender, int(row["price"])):
		GameManager.add_chill_buds(int(row["buds"]))
		ok = true
	if _patch_shop != null:
		_patch_shop.set_purse(GameManager.purse_balance(tender))
		_patch_shop.purchase_result(item_id, ok)
	if ok and _hud != null:
		_hud.toast("CHILL BUDS +%d  ·  IN YOUR TABS" % int(row["buds"]), 1.6)
	return ok


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
	if not Ep2ArmoryState.unlocks_stock(armory, item_id):
		_note(item_id, false)                              # the Shipment, then the Sharps, open the counter (founder 2026-11-03)
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
	# the new stock (founder 2026-11-01): the coach gun, the MP18, the golden Thompson and their ammunition
	if Ep2ArmoryState.SHOP_GUNS.has(item_id):
		return armory.purchase_firearm(item_id, tender)
	if Ep2ArmoryState.SHOP_AMMO.has(item_id):
		return armory.purchase_ammo(str(Ep2ArmoryState.SHOP_AMMO[item_id]), rounds, tender)
	return false


func _note(item_id: String, ok: bool) -> void:
	if _shop != null:
		_shop.purchase_result(item_id, ok)
	if _shop_open and _town_audio != null:
		if ok:
			_shop_bought = true
			_town_audio.queue_line("town_trade_07" if item_id == "river_gear" else ("town_trade_04" if item_id == "sniper" or Ep2ArmoryState.SHOP_GUNS.has(item_id) else "town_trade_06"))
		else:
			_town_audio.queue_line("town_trade_09")


## The long rifle and the river gear both in hand: the river shipment is on (the day-88 set-piece).
func _check_geared() -> void:
	if _geared or _gear_t >= 0.0:
		return
	# section 4: the first visit to Rich's goes on to the Gatling and Inferno's return; geared shows only once the story has been to
	# the bar (and the jail): already geared then -> straight on (_after_story), else this return visit is the one that gears him
	if armory.river_gear and _armory_return:
		_gear_t = 1.0


## The Sheriff: the founder's own model (Drive 2026-10-14), arms lowered out of the T-pose, grey beard, star, pipe - with a
## thin curl of smoke over his lip. Beside him stands Minister Mike Dean, the founder's robot-headed minister. Without the model a plain stand-in keeps the beats playable.
func _build_sheriff() -> void:
	_sheriff = Ep2TownFolk.new()
	_sheriff.name = "Sheriff"
	_sheriff.looping_clips.assign(["Idle", "Walk", "Talk", "Counter"])
	_sheriff.clip_blend = 0.2
	_visuals.add_child(_sheriff)
	_sheriff.ground_fn = Ep2GoldTown.ground_y          # his boots on the porch boards and the steps, not through them
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


## The Sheriff and Mike Dean as the street sees them through the open door, for a copy of the town that is not the running story (the woods'
## drop-off): the same models, at the same marks, facing the same spot, so the hand-over to this room changes nothing he can see.
static func build_office_stand_ins(parent: Node3D) -> Array:
	var out: Array = []
	if Ep2GoldTown.entry("Bldg_Certificates").is_empty():
		return out
	var spot: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT)
	var sheriff := Ep2TownFolk.new()
	sheriff.name = "OfficeSheriff"
	parent.add_child(sheriff)
	sheriff.setup(SHERIFF_MODEL, SHERIFF_HEIGHT, Color(0.42, 0.30, 0.18))
	sheriff.place(Ep2GoldTown.local_to_world("Bldg_Certificates", SHERIFF_OFFICE_AT))
	sheriff.hold_clip("Idle")
	out.append(sheriff)
	var minister := Ep2TownFolk.new()
	minister.name = "OfficeMikeDean"
	minister.use_height = true
	parent.add_child(minister)
	minister.setup(Ep2Extras.MINISTER if Ep2Extras.has(Ep2Extras.MINISTER) else MINISTER_MODEL, MINISTER_HEIGHT, Color(0.1, 0.1, 0.12))
	minister.place(Ep2GoldTown.local_to_world("Bldg_Certificates", MINISTER_DESK) + Vector3(0.0, MINISTER_STEP, 0.0))
	minister.hold_clip("Idle")
	out.append(minister)
	var box := BoxMesh.new()
	box.size = Vector3(1.1, MINISTER_STEP, 0.9)
	var step := MeshInstance3D.new()
	step.name = "OfficeMinisterStep"
	step.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.11)
	wood.roughness = 0.9
	step.material_override = wood
	step.position = minister.position - Vector3(0.0, MINISTER_STEP * 0.5, 0.0)
	parent.add_child(step)
	for folk in out:
		(folk as Ep2TownFolk).face_point(spot)
		(folk as Ep2TownFolk).rotation.y = (folk as Ep2TownFolk).facing
	return out


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
	Ep2DrawMusic.begin_town(self)
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
	if handoff.has("playtest"):
		# founder playtest preset (Ep2Playtest): standing at Dude's, facing him, on the Minister's referral. His route start, not his
		# node: on the web his model can still be streaming when the town sets up.
		_player_pos = Ep2StableYard.DUDE_PATH[0] + PLAYTEST_AT_DUDE
		_look_yaw = atan2(-PLAYTEST_AT_DUDE.x, -PLAYTEST_AT_DUDE.z)
		_player_yaw = _look_yaw
	_advance_to(Beat.STABLES if handoff.has("playtest") else Beat.STREET)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.STREET:
			if _hud:
				_hud.objective = "Go to the CERTIFICATES office. Ask about a Miner's License."
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
			] + _minister_steps(MINISTER1_LINES, MINISTER_WALL_LINE) + [
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
			# NOT arrive at the draw. The map is NOT handed over: it is on the body with his Borchardt (LOOT).
			if _people != null:
				_people.celebrate(_player_pos, _opp.position)
			if _town_audio != null:
				_town_audio.play_celebration()
			_start_show([
				FacilityShow._say("vo_sheriff_win", 0.4),
				{"do": "wait", "t": 0.4}], false)
		Beat.LOOT:
			# section 2 step 2: E at the body takes the Borchardt and the map to the auction
			if _hud:
				_hud.objective = "Search the stranger: his BORCHARDT and the map to the auction."
				_hud.toast("HE DROPPED HIS BORCHARDT", 2.6)
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
					_hud.objective = ("Buy the water & river gear at Rich's counter [E] - it is the top row."
						if TouchUi.keys_shown() else "Buy the water & river gear at Rich's counter - it is the top row.")
				_check_geared()
			else:
				if _hud:
					_hud.objective = "Trade with Rich at the counter [E]." if TouchUi.keys_shown() else "Trade with Rich at the counter."
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
			if _body_at_meet:
				# the body talk already happened where they met: straight on to the bar
				_body_said = true
				_bull_task = "at_body"
			else:
				_body_said = false
				_bull_task = "to_body"
				_bull_route(_bull_way_to(_body_stand()), 1.5)
		Beat.DRINKS:
			# section 2 steps 7-9: whiskey at the bar - they really drink - Inferno's pointer to Mike Dean for a real license, then cousin Flux's new kettle
			if _hud:
				_hud.objective = "Inferno's buying. Into the saloon, up to the bar."
			_drinks_said = false
			_bull_task = "to_bar"
			_bull_route([Ep2GoldTown.door_world("Bldg_Saloon", 2.4), Ep2GoldTown.door_world("Bldg_Saloon", -1.0),
				Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT + Vector3(1.4, 0.0, -0.1))], 1.4)
		Beat.MINISTER2:
			# section 2 steps 9-10: back to Mike Dean for the Miner's License / bond talk; he sends him to Dude
			_minister2_said = false
			if _hud:
				_hud.objective = "Go back to Minister Mike Dean at the CERTIFICATES office: ask about a Miner's License."
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
			if _stable_yard != null:
				_stable_yard.announce_patch()
			if _hud:
				_hud.objective = "Mount your horse at Dude’s stables. Logan’s Lake is marked on your map."
				_hud.toast("TO LOGAN'S LAKE", 3.4)
			# Wait here for the player to mount at the actual stables.
		Beat.DONE:
			_resolve({"next_chamber": "lake_trail", "horse": _horse_bought, "got_map": _got_map, "peacemaker": _got_peacemaker,
				"license_talk": _license_talk, "draw_losses": _losses,
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
		steps.append(FacilityShow._say(Ep2TownVoiceBank.id_for(_town_speaker(who), text), Ep2Speech.GAP))
	return steps


func _jail_line(who: String, text: String) -> void:
	if _hud != null:
		var jail_id: String = Ep2TownVoiceBank.id_for(_town_speaker(who), text)
		_hud.speech("%s: %s" % [who, text], Ep2Speech.pace(jail_id, text), Ep2Speech.voiced(jail_id))
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
	return Ep2Speech.read_seconds(text)


## How long a spoken line holds the exchange: its take + a breath when voiced (no reading time - there are no subtitles to read,
## founder 2026-11-01), a reading time only for a line whose take is missing.
func _caption_seconds(who: String, text: String) -> float:
	return Ep2Speech.pace(Ep2TownVoiceBank.id_for(_town_speaker(who), text), text)


func _caption_line(who: String, text: String) -> void:
	var id: String = Ep2TownVoiceBank.id_for(_town_speaker(who), text)
	if _hud != null:
		_hud.speech("%s: %s" % [who, text], _caption_seconds(who, text), Ep2Speech.voiced(id))
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


## The story cast as bodies the crowd keeps clear of (ep2-world-common-sense, founder 2026-11-05: "people walk through Minister Mike Dean
## while he prays"). Mike Dean kneeling by the fallen stranger gets a praying man's room; anyone the story has standing and talking to
## Lil Blunt gets room too, and so does the gap between them (nobody walks between two men in conversation). The fallen stranger, the
## parked quad and the Gatling post are solid. Refreshed every tick, so the circles move with the walkers.
func _update_keep_clear() -> void:
	var talking: bool = _show_active
	for entry in [["minister", _minister], ["sheriff", _sheriff], ["inferno", _bull]]:
		var id: String = entry[0]
		var who: Node3D = entry[1]
		if who == null or not who.visible or (id == "inferno" and _bull_task in ["riding", "riding_off"]):
			_people.clear_keep_clear(id)
			_people.clear_keep_clear(id + "_talk")
			continue
		var busy: bool = id == "minister" and _minister_task in ["kneeling", "asking"]
		var walking: bool = bool(who.call("is_walking"))
		var near_lb: bool = Vector2(who.position.x - _player_pos.x, who.position.z - _player_pos.z).length() < 4.0
		var in_talk: bool = talking and near_lb and not walking
		_people.set_keep_clear(id, who.position, Ep2TownPeople.KEEP_BUSY if busy or in_talk else Ep2TownPeople.KEEP_BODY)
		if in_talk:
			var mid: Vector3 = (who.position + _player_pos) * 0.5
			_people.set_keep_clear(id + "_talk", mid, Vector2(who.position.x - mid.x, who.position.z - mid.z).length())
		else:
			_people.clear_keep_clear(id + "_talk")
	if _opp != null and _opp.dead:
		# he fell backwards from where he stood: his body lies along the line behind him
		var back: Vector3 = Vector3(-sin(_opp.rotation.y), 0.0, -cos(_opp.rotation.y))
		_people.set_keep_clear("fallen", _opp.position + back * 0.85, 1.0)
	else:
		_people.clear_keep_clear("fallen")
	if _quad != null and _quad.visible and _quad.is_parked:
		_people.set_keep_clear("quad", _quad.position, 1.25)
	else:
		_people.clear_keep_clear("quad")
	if _gatling != null:
		_people.set_keep_clear("gatling", _gatling.position, 0.85)


## The town's swinging doors (Ep2SwingDoor: the saloon's batwings) pushed by everyone who goes through: Lil Blunt, the townspeople and
## the story cast alike.
func _step_doors(delta: float) -> void:
	if _town_col.get("doors", []).is_empty():
		return
	var bodies: Array = [_player_pos]
	if _people != null:
		for q in _people.people:
			bodies.append(q.folk.position)
	for who in [_minister, _sheriff, _bull, _bartender, _accomplice, _opp, _rich, _utah]:
		if who != null and who.visible:
			bodies.append(who.position)
	Ep2GoldTown.step_doors(_town_col, delta, bodies)


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
			_quad_step_minding(delta)
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
				# he swings off beside the saddle and comes over: to the shop door if Lil Blunt is inside; to the lane side of the fallen
				# stranger if he has already walked down to Mike Dean (ep2-world-common-sense: he goes where Lil Blunt is, once, and the
				# talk happens there); else to wherever he stands. Out of the side lane he walks the lane, never through the row's walls.
				_bull_task = "to_lb"
				_bull.position = _quad.dismount_spot()
				_bull.play(BULL_IDLE, 1.0, 0.25)
				var meet: Vector3
				if _in_room("Bldg_Armory", -0.5):
					meet = Ep2GoldTown.door_world("Bldg_Armory", 1.2)
				elif _lb_at_body():
					meet = _bull_body_spot()
				else:
					meet = _stand_off(_bull.position, _player_pos, 2.3)
				_bull_route(_bull_way_to(meet), 1.5)
		"to_lb":
			if not _bull.is_walking() and _bull_path.is_empty() and not _show_active:
				if _player_pos.distance_to(_bull.position) > 6.5:
					_bull.face_point(_player_pos)
					if _hud != null:
						_hud.objective = "Inferno's back - he's outside Rich's." if _bull.position.distance_to(_quad.position) < 8.0 else "Inferno's back."
					return
				_bull_task = "greeted"
				_bull.face_point(_player_pos)
				look_toward(_bull.head_world(), 2.4)
				if _lb_at_body() and _bull.position.distance_to(_opp.position) < 4.5:
					# met at the body (Lil Blunt was already standing with Mike Dean): the same lines, in the order a person would say them
					# where he stands - hello, what happened here, THEN the whiskey - and no walk back to the quad and down again
					_body_at_meet = true
					_bull.face_point(_minister.position if _minister != null else _opp.position)
					_start_show(_caption_steps([BULL_BACK_LINES[0]]) + [{"do": "call", "fn": _bull_face_minister}]
						+ _caption_steps(BODY_LINES) + [{"do": "call", "fn": func() -> void: _bull.face_point(_player_pos)}]
						+ _caption_steps([BULL_BACK_LINES[1]]) + [{"do": "call", "fn": release_look}], false)
				else:
					_body_at_meet = false
					_start_show(_caption_steps(BULL_BACK_LINES) + [{"do": "call", "fn": release_look}], false)
		"greeted":
			if not _show_active:
				_advance_to(Beat.BODY)


## Lil Blunt is standing with the fallen stranger (and Mike Dean praying by him): where Inferno's "what happened" belongs.
func _lb_at_body() -> bool:
	return _opp != null and _player_pos.distance_to(_opp.position) < BODY_NEAR and not _in_room("Bldg_Armory", -0.5)


## Where Inferno stops by the fallen stranger when Lil Blunt is already standing there: by the body, a talking distance from Lil Blunt
## (never on top of him - Inferno is 2.9 m tall), clear of Mike Dean praying and of the body itself.
func _bull_body_spot() -> Vector3:
	var o: Vector3 = _opp.position
	var best: Vector3 = _body_stand()
	var best_score: float = -INF
	for off in [Vector3(-1.5, 0.0, 2.3), Vector3(1.5, 0.0, 2.3), Vector3(-2.4, 0.0, 0.9), Vector3(2.4, 0.0, 0.9), Vector3(0.0, 0.0, 3.0),
			Vector3(-2.2, 0.0, -1.4), Vector3(2.2, 0.0, -1.4), Vector3(0.0, 0.0, -3.0)]:
		var spot: Vector3 = o + off
		var to_lb: float = spot.distance_to(_player_pos)
		var to_mike: float = spot.distance_to(_minister.position) if _minister != null else 9.0
		if to_lb < 2.0 or to_mike < 1.8 or to_lb > 5.0:
			continue
		var score: float = -absf(to_lb - 2.6) + minf(to_mike, 3.0) * 0.3
		if score > best_score:
			best_score = score
			best = spot
	return best if best_score > -INF else _stand_off(_body_stand(), _player_pos, 2.4)


func _bull_face_minister() -> void:
	_bull.face_point(_minister.position if _minister != null else _opp.position)
	look_toward(_opp.position + Vector3(0.0, 0.5, 0.0), 2.2)


## Inferno's walk from where he stands to `goal`: down the Armory's side lane first when he is in it (the lane's corner marks, the way
## the room always walked him), straight across the open street otherwise. Never a mark behind him: a route that starts at Rich's door
## while he is already in Main Street is the walk back to the quad the founder saw.
func _bull_way_to(goal: Vector3, from: Vector3 = Vector3.INF) -> Array:
	var at: Vector3 = _bull.position if from == Vector3.INF else from
	var way: Array = []
	var shop: Vector3 = Ep2GoldTown.door_world("Bldg_Armory", 6.0)
	var in_lane: bool = at.distance_to(shop) < 9.0 or at.distance_to(LANE_MARK) < 4.0
	var goal_in_lane: bool = goal.distance_to(shop) < 9.0
	if in_lane and not goal_in_lane:
		if at.distance_to(LANE_MARK) > 4.0:
			way.append(shop)
		way.append(LANE_MARK)
		way.append(Vector3(-2.2, 0.0, 1450.0))
	elif goal_in_lane and not in_lane:
		way.append(Vector3(-2.2, 0.0, 1450.0))
		way.append(LANE_MARK)
		if goal.distance_to(LANE_MARK) > 4.0:
			way.append(shop)
	way.append(goal)
	return way


## Where Inferno stops by the fallen stranger: on the lane side of him, the Minister kneeling on the other.
func _body_stand() -> Vector3:
	return _opp.position + Vector3(-1.5, 0.0, 2.3)


var _bull_path: Array = []
var _body_at_meet: bool = false                      # Inferno met Lil Blunt at the body: the body talk was part of his greeting
var _bull_speed: float = 1.5
var _make_way_t: float = 0.0
var _duck: Ep2DuckModifier = null


## Inferno walks the points in order (Ep2Actor walks one point at a time).
func _bull_route(points: Array, speed: float) -> void:
	_bull_path = points.duplicate()
	_bull_speed = speed
	_bull_wait_t = 0.0
	if not _bull_path.is_empty():
		_bull_walk(_bull_path.pop_front())


## One leg of Inferno's route; remembered so he can stop for someone in his way and carry on afterwards.
func _bull_walk(p: Vector3) -> void:
	_bull_goal = Vector3(p.x, 0.0, p.z)
	_bull.walk_to(p, _bull_speed)


func _tick_bull_route() -> void:
	if _bull == null or _bull_task not in ["to_lb", "to_body", "to_bar", "leaving"]:
		return
	_duck_bull()
	if _bull.is_walking() or _bull_wait_t > 0.0:
		_bull_mind_the_way()
		return
	if not _bull_path.is_empty():
		_bull_walk(_bull_path.pop_front())
		return
	match _bull_task:
		"to_body":
			_bull_task = "at_body"
			_bull.face_point(_minister.position if _minister != null else _opp.position)
		"to_bar":
			_bull_task = "at_bar"
			_bull.face_point(_player_pos)
		"leaving":
			_set_duck(0.0)
			_ensure_quad_parked()
			_bull.position = _quad.dismount_spot()
			_ride_off()


const BULL_BLOCK_REACH := 1.3      # m ahead of Inferno on foot that must be clear of bodies
const BULL_BLOCK_HALF := 0.6       # m either side of his line
const BULL_WAIT_S := 1.6           # he waits this long for someone to move, then steps round them
const BULL_STEP_ROUND := 1.3       # m beside the person he steps round
const QUAD_BLOCK_REACH := 5.0      # m ahead of the quad's centre that must be clear before it rolls
const QUAD_BLOCK_HALF := 1.6

var _bull_goal: Vector3 = Vector3.ZERO
var _bull_wait_t: float = 0.0


## Every body in town that can stand in someone's way: Lil Blunt, the townspeople and the story cast (ep2-world-common-sense), minus `skip`.
func _town_bodies(skip: Node3D, with_player: bool = true) -> Array:
	var out: Array = []
	if with_player:
		out.append(_player_pos)
	if _people != null:
		for q in _people.people:
			if q.folk != null and q.folk.visible:
				out.append(q.folk.position)
	for who in [_minister, _sheriff, _bull, _bartender, _accomplice, _rich, _utah, _opp]:
		if who != null and who != skip and (who as Node3D).visible:
			out.append((who as Node3D).position)
	return out


## The nearest body in a box `reach` long and `half` wide either side, ahead of `from` along unit `fwd`; Vector3.INF when clear.
static func _first_ahead(bodies: Array, from: Vector3, fwd: Vector3, reach: float, half: float) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	for b in bodies:
		var d: Vector3 = (b as Vector3) - from
		d.y = 0.0
		var along: float = d.dot(fwd)
		if along > 0.05 and along < reach and absf(d.dot(side)) < half and along < best_d:
			best_d = along
			best = b
	return best


## Inferno on foot never walks through anybody (founder 2026-11-08): someone in his way, he stops and looks at them; still there after
## BULL_WAIT_S, he steps round on the far side of them and carries on to where he was going.
func _bull_mind_the_way() -> void:
	var to_goal: Vector3 = _bull_goal - _bull.position
	to_goal.y = 0.0
	var dist: float = to_goal.length()
	if dist < 0.35:
		if _bull_wait_t > 0.0:
			_bull_wait_t = 0.0
			_bull.walk_to(_bull_goal, _bull_speed)
		return
	var fwd: Vector3 = to_goal / dist
	# walking up to Lil Blunt (or to a spot beside him), Lil Blunt is where he is going, not in his way
	var with_lb: bool = _bull_task != "to_lb" and _player_pos.distance_to(_bull_goal) > 1.8
	var blocker: Vector3 = _first_ahead(_town_bodies(_bull, with_lb), _bull.position, fwd, minf(BULL_BLOCK_REACH, dist - 0.3), BULL_BLOCK_HALF)
	if blocker == Vector3.INF:
		if _bull_wait_t > 0.0:
			_bull_wait_t = 0.0
			_bull.walk_to(_bull_goal, _bull_speed)
		return
	if _bull_wait_t == 0.0:
		_bull.stop()
		_bull.play(BULL_IDLE, 1.0, 0.25)
		_bull.face_point(blocker)
	_bull_wait_t += get_process_delta_time()
	if _bull_wait_t >= BULL_WAIT_S:
		var side := Vector3(fwd.z, 0.0, -fwd.x)
		var off: float = (blocker - _bull.position).dot(side)
		var around: Vector3 = blocker - side * (signf(off) if off != 0.0 else -1.0) * BULL_STEP_ROUND
		_bull_path.push_front(_bull_goal)
		_bull_wait_t = 0.0
		_bull_walk(around)


## The quad rolls only while nobody is in front of it (founder 2026-11-08): it stops for Lil Blunt, a townsperson or the story cast,
## idles until they clear, then carries on. No ramming, no sliding through anyone.
func _quad_step_minding(delta: float) -> void:
	var fwd := Vector3(sin(_quad.yaw), 0.0, cos(_quad.yaw))
	var from: Vector3 = _quad.position - fwd * 0.5
	if _first_ahead(_town_bodies(_bull), from, fwd, QUAD_BLOCK_REACH, QUAD_BLOCK_HALF) == Vector3.INF:
		_quad.step(delta)


## The quad parked outside Rich's, built if this run never saw it ride in (a warp, a skipped Gatling beat): the ride-out needs it.
func _ensure_quad_parked() -> void:
	if _quad == null:
		_quad = Ep2TownQuad.new()
		_quad.name = "InfernoQuad"
		_visuals.add_child(_quad)
		_quad.build()
	if not _quad.visible or not _quad.is_parked:
		var park: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", QUAD_PARK_LOCAL)
		var last: Vector3 = QUAD_RETURN[QUAD_RETURN.size() - 1]
		_quad.drive([park])
		_quad.position = Vector3(park.x, 0.0, park.z)
		_quad.yaw = atan2(park.x - last.x, park.z - last.z)
		_quad.rotation = Vector3(0.0, _quad.yaw, 0.0)


## Inferno back in the saddle and away: the ride in, reversed (the lane, the street's end, the road out of town). The quad stops being
## a solid thing in the lane, and he is gone once it is out of sight up the road.
func _ride_off() -> void:
	_bull_task = "riding_off"
	if _town_col.has("props"):
		var props: Array = _town_col["props"]
		for i in range(props.size() - 1, -1, -1):
			if (props[i][0] as Vector2).distance_to(Vector2(_quad.position.x, _quad.position.z)) < 0.05:
				props.remove_at(i)
	var back: Array = [_quad.position]
	for i in range(QUAD_RETURN.size() - 1, -1, -1):
		back.append(QUAD_RETURN[i])
	_quad.drive(back)
	if _bull.anim != null and _bull.anim.has_animation(WoodsQuadChamber.BULL_SIT_CLIP):
		_bull.play(WoodsQuadChamber.BULL_SIT_CLIP, 0.0, 0.0)
		_bull.anim.seek(WoodsQuadChamber.BULL_SIT_AT, true)
	_bull.clear_face_goal()
	_seat_bull()


## The ride out: nobody is run down - he waits while Lil Blunt stands in front of the quad, and the street makes way as it did coming in.
func _tick_ride_off(delta: float) -> void:
	if _bull_task != "riding_off" or _quad == null:
		return
	_quad_step_minding(delta)
	_seat_bull()
	_make_way_t -= delta
	if _people != null and _make_way_t <= 0.0:
		_make_way_t = 0.25
		_people.make_way(_quad.position, Vector2(sin(_quad.yaw), cos(_quad.yaw)), 14.0, 2.0)
	if _quad.is_parked:
		_quad.visible = false
		_bull.visible = false
		_bull_task = ""


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


## What follows Dude's horse (the town's last errand): the ride - straight on if he has the water & river gear from Rich's,
## else back to Rich's counter for it first. Founder 2026-11-03: the long rifle no longer holds the lake ride back (it was the
## recurring "after Dude he is sent back to Rich and Utah" stall); the water gear is the one priority buy and the counter's first row.
func _after_story() -> void:
	if armory.river_gear:
		_advance_to(Beat.GEARED)
	else:
		_armory_return = true
		_advance_to(Beat.ARMORY)


## Section 2 step 2: close enough to the fallen stranger (or the Borchardt by him) for E to search him.
func _can_loot() -> bool:
	if _beat != Beat.LOOT or _got_peacemaker or _show_active or _opp == null:
		return false
	var near: float = _player_pos.distance_to(_opp.position)
	if _revolver != null and _revolver.get_parent() == _visuals:
		near = minf(near, _player_pos.distance_to(_revolver.position))
	return near < LOOT_R


## E at the body: his Borchardt and the map to the auction are Lil Blunt's. Then Minister Mike Dean comes running (step 3).
func _loot() -> void:
	_got_peacemaker = true
	_got_map = true
	armory.take_found(Ep2ArmoryState.BORCH)
	GameManager.has_region_map = true
	GameManager.map_active_destination = "auction"
	GameManager.save_session()
	_town_sfx("gun_pickup")
	if _revolver != null:
		_revolver.visible = false
	if _hud != null:
		_hud.set_search_prompt("")
		_hud.objective = ""
		_hud.toast("YOU TOOK HIS BORCHARDT AND THE MAP TO THE AUCTION", 3.4)
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


## Phase 2 reframe (2026-11-03): the second visit ends with the license / bond close heard - a story flag only. No paper, no stamp,
## no mint: the real license / bond surfaces are the protocol's own (out of scope in the game, section 6).
func _hear_license_talk() -> void:
	_license_talk = true


## Turn Lil Blunt's eye to the four licenses on the left wall for one line, then back to Mike Dean.
func _look_at_license_wall() -> void:
	look_toward(Ep2GoldTown.local_to_world("Bldg_Certificates", LICENSE_WALL_AT + Vector3(0.0, 0.15, -LICENSE_WALL_STEP * 1.5)), 2.4)


func _look_at_minister() -> void:
	if _minister != null:
		look_toward(_minister.position + Vector3(0.0, MINISTER_HEIGHT * 0.85, 0.0), 2.4)


## Mike Dean's lines with a glance at the license wall on `wall_line` (the doc: "gesture or glance toward the left-wall display").
func _minister_steps(lines: Array, wall_line: int) -> Array:
	return (_caption_steps(lines.slice(0, wall_line)) + [{"do": "call", "fn": _look_at_license_wall}]
		+ _caption_steps(lines.slice(wall_line, wall_line + 1)) + [{"do": "call", "fn": _look_at_minister}]
		+ _caption_steps(lines.slice(wall_line + 1)))


## The four Miner's License certificates on the certificate office's RIGHT wall, opposite Mike Dean's desk (founder 2026-11-03 follow-up):
## a slight rising diagonal of framed papers beside the counter, each with its tier name, so the ladder reads during the talk.
## Procedural (wood frame, paper, a tier-coloured seal, Label3D lettering) so it always shows - no asset, no pack weight.
func _build_license_wall() -> void:
	if _visuals != null:
		build_license_wall(_visuals)


## Static so every copy of the town hangs the same wall: the woods' copy is what he sees first from the street (skill ep2-interior-visible-on-approach).
static func build_license_wall(parent: Node3D) -> void:
	var e: Array = Ep2GoldTown.entry("Bldg_Certificates")
	if e.is_empty():
		return
	var wall := Node3D.new()
	wall.name = "LicenseWall"
	parent.add_child(wall)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.24, 0.14, 0.07)
	frame_mat.roughness = 0.8
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.93, 0.87, 0.72)
	paper_mat.roughness = 0.95
	for i in LICENSE_TIERS.size():
		var rank: int = LICENSE_TIERS.size() - 1 - i                    # 0 = Mine Owner's (front, highest) ... 3 = Prospector's (back)
		var local: Vector3 = LICENSE_WALL_AT + Vector3(0.0, -rank * LICENSE_WALL_RISE, -rank * LICENSE_WALL_STEP)
		var cert := Node3D.new()
		cert.name = "License%d" % (i + 1)
		cert.transform = Ep2GoldTown.building_xform(e) * Transform3D(Basis(Vector3.UP, -PI * 0.5), local)  # faces -x: into the room
		cert.set_meta("tier", str(LICENSE_TIERS[i][0]))
		wall.add_child(cert)
		var frame := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.52, 0.66, 0.03)
		frame.mesh = fb
		frame.material_override = frame_mat
		cert.add_child(frame)
		var paper := MeshInstance3D.new()
		var pq := QuadMesh.new()
		pq.size = Vector2(0.44, 0.58)
		paper.mesh = pq
		paper.material_override = paper_mat
		paper.position.z = 0.017
		paper.name = "Paper"
		cert.add_child(paper)
		var seal := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.055
		sm.bottom_radius = 0.055
		sm.height = 0.01
		seal.mesh = sm
		var seal_mat := StandardMaterial3D.new()
		seal_mat.albedo_color = LICENSE_TIERS[i][1]
		seal_mat.metallic = 0.7
		seal_mat.roughness = 0.35
		seal.material_override = seal_mat
		seal.rotation.x = PI * 0.5
		seal.position = Vector3(0.0, -0.17, 0.022)
		seal.name = "Seal"
		cert.add_child(seal)
		for t in [[str(LICENSE_TIERS[i][0]), 0.15, 34], ["BACKED BY THE wBTC VAULT", 0.04, 18], ["TIER %d OF 4" % (i + 1), -0.03, 18]]:
			var label := Label3D.new()
			label.text = str(t[0])
			label.font_size = int(t[2])
			label.pixel_size = 0.001
			label.modulate = Color(0.22, 0.13, 0.06)
			label.outline_size = 0
			label.width = 400.0
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.position = Vector3(0.0, float(t[1]), 0.02)
			label.double_sided = false
			cert.add_child(label)
	if not upgrade_license_wall(wall):
		# the printed certificates arrive with the streamed extras pack: look again twice a second until they are in
		var t := Timer.new()
		t.name = "LicenseArtWait"
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(func() -> void:
			if upgrade_license_wall(wall): t.queue_free())
		wall.add_child(t)


## Swap each placard for its printed certificate once every texture can load. True when the wall shows the printed art.
static func upgrade_license_wall(wall: Node3D) -> bool:
	if wall == null:
		return false
	if bool(wall.get_meta("printed", false)):
		return true
	for tier in LICENSE_TIERS:
		if not Ep2Extras.has(str(tier[2])):
			return false
	for i in LICENSE_TIERS.size():
		var cert: Node3D = wall.get_node_or_null("License%d" % (i + 1)) as Node3D
		if cert == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(str(LICENSE_TIERS[i][2])) as Texture2D
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		(cert.get_node("Paper") as MeshInstance3D).material_override = mat
		for n in cert.get_children():
			if n is Label3D or n.name == "Seal":
				(n as Node3D).visible = false                   # the print carries its own title, lettering and seal
	wall.set_meta("printed", true)
	return true


## A shot horse stays shot until he brings it to Dude (founder 2026-11-04); walking up to Dude is all it takes.
## Founder brief 2026-11-08: this is the dear reset - Dude takes the wrecked mount and ONE Bitcoin (Logan's salve at the lake is the
## half-Bitcoin local fix). Short of a coin he still swaps it, on his auction credit (as the horse itself can be): never a soft-lock.
const DUDE_SWAP_BTC := 1
func _dude_treats_horse() -> void:
	if armory.horse_is_sound() or _player_pos.distance_to(_stable_yard.dude_position()) > DUDE_TREATS_WITHIN:
		return
	var paid: bool = GameManager.purse_spend("btc", DUDE_SWAP_BTC)
	if not paid:
		GameManager.record_dude_credit(DUDE_SWAP_BTC)
	armory.treat_horse()
	if _hud != null:
		_hud.toast(("DUDE SWAPS THE WRECKED HORSE FOR A FRESH ONE · -1 BTC" if paid
			else "DUDE SWAPS THE WRECKED HORSE FOR A FRESH ONE · 1 BTC ON CREDIT TILL THE AUCTION"), 3.0)


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
		if _law.retaliation.active: return
		if _law.suspends_story():
			_tick_people(delta)
			return
	var intro_busy: bool = _intro != null and _intro.is_busy()
	var duel: bool = _beat in [Beat.BAR, Beat.SQUARE_UP, Beat.DRAW]
	if _stable_yard != null:
		_stable_yard.step(delta, _player_pos, duel or _hold > 0.0 or _show_active or intro_busy or _shop_open)
		_dude_treats_horse()
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
	_tick_ride_off(delta)
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
				# the toast, then they really drink (step 7), then Inferno points him back to Mike Dean (no paper) and Flux's kettle (step 8)
				_start_show(_caption_steps(DRINK_LINES) + [{"do": "call", "fn": _drink_together}, {"do": "wait", "t": FP_DRINK_S + 0.2}]
					+ _caption_steps(INFERNO_LICENSE_LINES) + _caption_steps(FLUX_LINES) + [
					{"do": "call", "fn": release_look}], false)
			elif _drinks_said and not _show_active and not is_drinking():
				# Inferno heads off to his cousin's; the story's next thread is the second visit to Mike Dean. He rode in, so he rides out:
				# back to his quad outside Rich's and away up the road he came in on (he used to walk off and leave it parked for good)
				_bull_task = "leaving"
				# founder 2026-11-08: walking is only bar -> bike; he never crosses town on foot to Flux. A warped/skipped run that has no quad
				# in town yet gets it parked where the story leaves it (outside Rich's) so the ride-out always happens.
				var out_door: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 3.0)
				_ensure_quad_parked()
				_bull_route([Ep2GoldTown.door_world("Bldg_Saloon", -1.0), out_door] + _bull_way_to(_quad.dismount_spot(), out_door), 1.6)
				_advance_to(Beat.MINISTER2)
		Beat.MINISTER2:
			# the second visit: in at the counter - the license / bond close, then the referral to Dude (steps 9-10)
			if not _minister2_said and not _show_active and _in_room("Bldg_Certificates", -1.4) \
					and (_minister == null or not _minister.is_walking()):
				_minister2_said = true
				if _minister != null:
					_minister.face_point(_player_pos)
					look_toward(_minister.position + Vector3(0.0, MINISTER_HEIGHT * 0.85, 0.0), 2.4)
				_start_show(_minister_steps(MINISTER2_LINES, MINISTER_WALL_LINE) + [{"do": "call", "fn": _hear_license_talk},
					{"do": "call", "fn": release_look}], false)
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
				# no turn: he keeps looking where he was looking as he swings up (founder 2026-11-01: mounting "forces the player to turn
				# around"); the trail takes this gaze as it is
				if _end_t == 0.0 and _handoff_ok(): _advance_to(Beat.DONE)

	if _stable_yard != null and _hud != null:
		var show_prompt: bool = _stable_interaction_allowed() and _stable_yard.can_talk(_player_pos)
		var patch_prompt: bool = not show_prompt and can_use_bud_patch()
		if patch_prompt:
			_hud.set_search_prompt("Buy Chill Buds [E]" if TouchUi.keys_shown() else "Buy Chill Buds")
			show_prompt = true
		elif show_prompt:
			_hud.set_search_prompt("Talk to Dude [E]" if TouchUi.keys_shown() else "Talk to Dude")
		elif _stable_prompt_shown and _beat != Beat.ARMORY:
			_hud.set_search_prompt("")
		_stable_prompt_shown = show_prompt


func _stable_interaction_allowed() -> bool:
	return (_world_revisit or _beat not in [Beat.BAR, Beat.SQUARE_UP, Beat.DRAW, Beat.GEARED, Beat.DONE]) and _hold <= 0.0 and not _show_active and not _shop_open and not (_intro != null and _intro.is_busy())


func _on_stable_line(who: String, text: String, id: String, _voice: String) -> void:
	var seconds: float = Ep2Speech.pace(id, text)
	if _hud != null:
		_hud.speech("%s: %s" % [who, text], seconds, Ep2Speech.voiced(id))
	if id != "":
		line_spoken.emit(id)
		if Ep2TownVoiceBank.LINES.has(id):
			if _town_audio != null: _town_audio.silence_greeting()
			var recording: AudioStream = Ep2TownVoiceBank.stream(id)
			if recording != null:
				var am: Node = get_node_or_null("/root/AudioManager")
				if am != null: am.play_voice(id, recording)
		if id == "dude_ranch_16" and _hud != null:     # the hint goes with his one telling: where the buds are, never a caption of his words
			_hud.toast("BUY CHILL BUDS AT DUDE'S PATCH  ·  OUTSIDE THE EAST FENCE", 4.2)
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
		_update_keep_clear()
		_people.step(delta, _player_pos)
	if _miners != null:
		# the back-lot miners talk only when Lil Blunt is in earshot and no story scene is speaking (never over the draw or a briefing)
		var free_talk: bool = not (_beat in [Beat.BAR, Beat.SQUARE_UP, Beat.DRAW, Beat.OFFICE, Beat.WON, Beat.JOB, Beat.BODY, Beat.JAIL])
		_miners.player_pos = _player_pos if free_talk else Vector3(0.0, 0.0, -9999.0)
	_step_doors(delta)
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
	_tick_opp_draw(delta)
	if not _opp_gun_real and _revolver != null and Ep2Extras.state() == "ready":
		_arm_stranger()
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
		# A phone has no Enter to draw with first: one tap draws AND fires, so the reaction starts
		# at the tap exactly like the keyboard's Enter-then-fire (audit 2026-10-29 P1-4). A desktop
		# first press stays "draw only"; Enter owns the draw there.
		if not TouchUi.is_touch():
			return false
		if not draw_weapon():
			return false
	if _mounted:
		if not has_player_control() or _gatling == null:
			return false
		if _gatling.fire_burst(0.7):
			_mount_bursts += 1
			if _people != null: _people.notify_danger(_player_pos, 32.0)
			if _miners != null: _miners.notify_danger(_player_pos)
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
	if _miners != null: _miners.notify_danger(_player_pos)
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


## The draw's stranger is the town's one hostile in the sights (townsfolk never turn the sight red: shooting them is a crime).
func aim_on_target(eye: Vector3, dir: Vector3) -> bool:
	return _beat == Beat.DRAW and _draw_state == "go" and _opp != null and aim_hits_opponent(eye, dir)


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


## Put the Borchardt in the holder once it can be loaded; the primitive holds its place until then.
func _arm_stranger() -> void:
	if not Ep2Extras.has(Ep2Extras.BORCHARDT_GUN):
		if _revolver.get_child_count() == 0:
			var stand_in: Node3D = _make_revolver()
			stand_in.name = "BorchardtStandIn"
			_revolver.add_child(stand_in)
		return
	for old in _revolver.get_children():
		old.queue_free()
	var gun: Node3D = (load(Ep2Extras.BORCHARDT_GUN) as PackedScene).instantiate() as Node3D
	gun.name = "Borchardt"
	_revolver.add_child(gun)
	_opp_gun_real = true


## Where the holder goes for his fist to close on the grip.
static func opp_gun_in_hand() -> Vector3:
	return COWBOY_HAND_DRAW * COWBOY_HEIGHT - OPP_GUN_GRIP


## The bell: the baked "Draw" arm comes up and the pistol travels from the hip into his fist (a short, readable move; he fires well after it lands).
func _opp_draws() -> void:
	_opp.set_pose("draw")
	if _revolver.get_parent() != _opp:
		_revolver.reparent(_opp, false)
	_revolver.visible = true
	_opp_draw_k = 0.0
	_opp.kick()


func _tick_opp_draw(delta: float) -> void:
	if _opp_draw_k < 0.0:
		return
	_opp_draw_k = minf(_opp_draw_k + delta / OPP_DRAW_S, 1.0)
	var k: float = smoothstep(0.0, 1.0, _opp_draw_k)
	_revolver.position = OPP_HOLSTER.lerp(opp_gun_in_hand(), k)
	_revolver.rotation = OPP_HOLSTER_ROT.lerp(Vector3.ZERO, k)
	if _opp_draw_k >= 1.0:
		_opp_draw_k = -1.0


## The Borchardt back in its holster on his hip, barrel down (a new round, a restage).
func _holster_revolver() -> void:
	if _revolver == null:
		return
	if _revolver.get_parent() != _opp:
		_revolver.reparent(_opp, false)
	_opp_draw_k = -1.0
	_revolver.visible = true
	_revolver.position = OPP_HOLSTER
	_revolver.rotation = OPP_HOLSTER_ROT


## He falls: the Borchardt leaves his hand and lies in the dirt by him, on its side - E there takes it (and the map) in Beat.LOOT.
func _drop_revolver() -> void:
	if _revolver == null:
		return
	_opp_draw_k = -1.0
	var at: Vector3 = _opp.to_global(Vector3(-0.42, 0.0, 0.38)) if _opp.is_inside_tree() else _opp.position + Vector3(-0.42, 0.0, 0.38)
	_revolver.reparent(_visuals, false)
	_revolver.position = Vector3(at.x, 0.045, at.z)
	_revolver.rotation = Vector3(0.0, _opp.rotation.y + 0.9, PI * 0.5)
	_revolver.visible = true


## Where the round leaves the Borchardt's barrel (the origin is on the bore; the barrel runs +z).
func _opp_muzzle() -> Vector3:
	if _revolver != null and _revolver.is_inside_tree():
		return _revolver.to_global(Vector3(0.0, 0.0, 0.223))
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


func remember_retaliation_entry() -> void:
	_retaliation_entry = {"position": _player_pos, "yaw": _look_yaw, "pitch": _look_pitch}


func retry_protected_npc() -> void:
	if _law == null or not _law.retaliation.active: return
	_law.retaliation.reset()
	if _mounted: _dismount()
	if not _retaliation_entry.is_empty():
		_player_pos = _retaliation_entry.position
		_look_yaw = _retaliation_entry.yaw
		_look_pitch = _retaliation_entry.pitch
	_move_input = Vector2.ZERO
	_vel_y = 0.0
	_running = true
	_resolved = false
	remove_meta("protected_npc_defeat")
	_hud.fade_to(0.0, 0.3)
	_update_camera(0.0)
	_sync_visuals()


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
func license_talk_heard() -> bool: return _license_talk
func license_wall() -> Node3D: return _visuals.get_node_or_null("LicenseWall") as Node3D if _visuals != null else null
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
