class_name Ep2Playtest
extends RefCounted
## FOUNDER PLAYTEST PRESETS (founder briefs 2026-11-09 and 2026-11-11). Each opens Episode 2 at a late point of the story, fully geared,
## so it can be tested without replaying the mine, the hideout and the draw (the founder's laptop often crashed before Dude):
##   dude         the gold town at Dude's stables, on the Minister's referral beat (buy the horse, ride the lake trail)
##   auction      Logan's Lake AFTER day-88 (Utah has the Shipment): the horse is at the water and mountable, the AUCTION GROUNDS
##                signpost is up, and the ride down the road to the grounds and into the hall is the game's own (one room, no load)
##   day88_ridge  the overlook above the river with the Shipment bought and the Sharps in hand: walk to the marker and launch it
## Every preset gives every Episode 2 gun with a 2000-round reserve (the save's RESERVE_CAP, so Save/Continue keeps it), the Shipment
## and the Sharps bought, a sound horse and a fat BTC purse.
## Entry: `?playtest=<name>` on the game's own URL (web); F3 (DebugOverlay on) then F8 / F9 / F2, or a click on the overlay's preset
## row; on a phone, five quick taps in the top-left corner bring up the same row. No menu, pause or HUD chrome in normal play; the
## Episode 2 access code still applies. Everything goes through production state: Ep2ArmoryState.restore, GameManager.purse_add, the
## session root's own room entry (the one Continue uses) and the rooms' own handoff flags - no room content is touched.
## A save made in the warped town carries `"playtest": "dude"`, so Continue lands at Dude's again; a save at the lake after day-88 or
## on the ridge is an ordinary checkpoint of that room.

const PRESET := "dude"
const AUCTION := "auction"
const RIDGE := "day88_ridge"
## name -> [the room the session enters, the handoff that room is given]. The lake's own `after_day88` flag is what puts the horse at
## the water, shows the signpost and opens the road; nothing about the auction is decided here.
const PRESETS := {
	PRESET: ["gold_town", {"playtest": PRESET}],
	AUCTION: ["logans_lake", {"after_day88": true}],
	RIDGE: ["river_cover", {}],
}
const BTC_FLOOR := 64
const ARROWS := 999

## Set by `warp`; read once by the Episode 2 boot.
static var preset: String = ""


## The preset this Episode 2 boot asked for ("" in normal play), consumed: a retry, Quit + Continue or a later entry in the same page is
## a normal run. Refreshing the ?playtest=dude page warps again (DebugOverlay reads the query once per page load).
static func take() -> String:
	var asked: String = preset
	preset = ""
	return asked


## ?playtest=<name> at boot, or the DebugOverlay's keys / preset row: ask for the preset and (re)enter Episode 2. An unknown name is
## ignored (the game starts normally).
static func warp(name: String = PRESET) -> void:
	if not PRESETS.has(name):
		return
	preset = name
	SceneRouter.load_scene(GameManager.EPISODE2_SCENE, SceneRouter.Transition.FADE)


## The room a preset opens in, and the handoff it is given.
static func room(name: String) -> String:
	return str(PRESETS.get(name, PRESETS[PRESET])[0])


static func handoff(name: String) -> Dictionary:
	return (PRESETS.get(name, PRESETS[PRESET])[1] as Dictionary).duplicate()


## Every gun owned, loaded, 2000 in reserve; the Shipment and the Sharps bought; a sound horse; nothing held by the Sheriff.
static func grant(armory: Ep2ArmoryState, name: String = PRESET) -> void:
	var data: Dictionary = armory.snapshot()
	for id in Ep2ArmoryState.IDS:
		data.weapons[id] = {"owned": true, "loaded": 999, "reserve": Ep2ArmoryState.RESERVE_CAP, "locked": false,
			"reload_locked": false, "training_complete": true}
	data.merge({"arrows": ARROWS, "sniper": true, "sniper_rounds": Ep2ArmoryState.RESERVE_CAP, "river_gear": true,
		"horse_wounds": 0, "confiscated": false, "held": [], "equipped": Ep2ArmoryState.WIN}, true)
	armory.restore(data)
	GameManager.purse_add("btc", BTC_FLOOR - GameManager.purse_balance("btc"))
	GameManager.has_region_map = true
	print("[PLAYTEST] %s: %d guns, reserve %d, %d BTC" % [name, Ep2ArmoryState.IDS.size(), Ep2ArmoryState.RESERVE_CAP, GameManager.purse_balance("btc")])


## The town's handoff for the preset (GoldTownChamber opens on its STABLES beat, standing at Dude's). No town class is named here:
## DebugOverlay (an autoload) loads this script at boot, and the town must not load with the title screen.
static func town_handoff() -> Dictionary:
	return handoff(PRESET)
