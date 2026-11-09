class_name Ep2Playtest
extends RefCounted
## FOUNDER PLAYTEST PRESET "dude" (founder brief 2026-11-09). Opens Episode 2 in the gold town at Dude's stables (the Minister's
## referral beat) with every Episode 2 gun owned, a 2000-round reserve each (the save's RESERVE_CAP, so Save/Continue keeps it), the
## Shipment and the Sharps bought, and a fat BTC purse - so the horse, the lake trail, day-88 and the auction can be tested without
## replaying the mine, the hideout and the draw (the founder's laptop often crashed before Dude).
## Entry: `?playtest=dude` on the game's own URL (web), or F3 (DebugOverlay on) then F8. No menu, pause or HUD chrome; the Episode 2
## access code still applies. Everything goes through production state: Ep2ArmoryState.restore, GameManager.purse_add, the session
## root's own room entry. A save made in the warped town carries `"playtest": "dude"`, so Continue lands at Dude's again.

const PRESET := "dude"
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


## ?playtest=dude at boot or F3+F8 (DebugOverlay): ask for the preset and (re)enter Episode 2.
static func warp() -> void:
	preset = PRESET
	SceneRouter.load_scene(GameManager.EPISODE2_SCENE, SceneRouter.Transition.FADE)


## Every gun owned, loaded, 2000 in reserve; the Shipment and the Sharps bought; a sound horse; nothing held by the Sheriff.
static func grant(armory: Ep2ArmoryState) -> void:
	var data: Dictionary = armory.snapshot()
	for id in Ep2ArmoryState.IDS:
		data.weapons[id] = {"owned": true, "loaded": 999, "reserve": Ep2ArmoryState.RESERVE_CAP, "locked": false,
			"reload_locked": false, "training_complete": true}
	data.merge({"arrows": ARROWS, "sniper": true, "sniper_rounds": Ep2ArmoryState.RESERVE_CAP, "river_gear": true,
		"horse_wounds": 0, "confiscated": false, "held": [], "equipped": Ep2ArmoryState.WIN}, true)
	armory.restore(data)
	GameManager.purse_add("btc", BTC_FLOOR - GameManager.purse_balance("btc"))
	GameManager.has_region_map = true
	print("[PLAYTEST] dude: %d guns, reserve %d, %d BTC" % [Ep2ArmoryState.IDS.size(), Ep2ArmoryState.RESERVE_CAP, GameManager.purse_balance("btc")])


## The town's handoff for the preset (GoldTownChamber opens on its STABLES beat, standing at Dude's). No town class is named here:
## DebugOverlay (an autoload) loads this script at boot, and the town must not load with the title screen.
static func town_handoff() -> Dictionary:
	return {"playtest": PRESET}
