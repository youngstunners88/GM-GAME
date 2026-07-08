class_name BlazeRushLayouts
extends RefCounted
## Data-driven Blaze Rush course layouts — one per level.
## Obstacle types:
##   "candle"   — red candle spike on the ground (market dip). Jump it.
##   "fud_wall" — tall FUD block. Jump onto/over it.
##   "smoke"    — $SMOKE token pickup, offset above ground by `y` px.
##   "gap"      — pit in the floor of width `w`. Clear it airborne.
## Positions are x offsets (px) from run start. Ground sits at y=500.

const GROUND_Y: float = 500.0

## Per-level course data. Index = level number (1-based).
const LAYOUTS: Dictionary = {
	1: {
		"length": 3400.0,
		"obstacles": [
			{"type": "smoke", "x": 400.0, "y": 60.0},
			{"type": "candle", "x": 620.0},
			{"type": "smoke", "x": 640.0, "y": 140.0},
			{"type": "smoke", "x": 880.0, "y": 60.0},
			{"type": "candle", "x": 1100.0},
			{"type": "candle", "x": 1160.0},
			{"type": "smoke", "x": 1130.0, "y": 170.0},
			{"type": "fud_wall", "x": 1500.0},
			{"type": "smoke", "x": 1520.0, "y": 200.0},
			{"type": "gap", "x": 1850.0, "w": 140.0},
			{"type": "smoke", "x": 1920.0, "y": 120.0},
			{"type": "candle", "x": 2250.0},
			{"type": "smoke", "x": 2270.0, "y": 150.0},
			{"type": "candle", "x": 2600.0},
			{"type": "candle", "x": 2660.0},
			{"type": "smoke", "x": 2630.0, "y": 180.0},
			{"type": "smoke", "x": 3000.0, "y": 60.0},
		],
	},
	2: {
		"length": 4000.0,
		"obstacles": [
			{"type": "candle", "x": 450.0},
			{"type": "smoke", "x": 470.0, "y": 150.0},
			{"type": "gap", "x": 750.0, "w": 150.0},
			{"type": "smoke", "x": 820.0, "y": 120.0},
			{"type": "fud_wall", "x": 1150.0},
			{"type": "smoke", "x": 1170.0, "y": 210.0},
			{"type": "candle", "x": 1480.0},
			{"type": "candle", "x": 1540.0},
			{"type": "smoke", "x": 1510.0, "y": 170.0},
			{"type": "gap", "x": 1850.0, "w": 170.0},
			{"type": "smoke", "x": 1930.0, "y": 130.0},
			{"type": "candle", "x": 2200.0},
			{"type": "fud_wall", "x": 2450.0},
			{"type": "smoke", "x": 2470.0, "y": 210.0},
			{"type": "candle", "x": 2800.0},
			{"type": "candle", "x": 2860.0},
			{"type": "candle", "x": 2920.0},
			{"type": "smoke", "x": 2880.0, "y": 190.0},
			{"type": "gap", "x": 3250.0, "w": 150.0},
			{"type": "smoke", "x": 3320.0, "y": 120.0},
			{"type": "smoke", "x": 3650.0, "y": 60.0},
		],
	},
	3: {
		"length": 4600.0,
		"obstacles": [
			{"type": "candle", "x": 400.0},
			{"type": "smoke", "x": 420.0, "y": 150.0},
			{"type": "candle", "x": 700.0},
			{"type": "candle", "x": 760.0},
			{"type": "smoke", "x": 730.0, "y": 180.0},
			{"type": "gap", "x": 1050.0, "w": 160.0},
			{"type": "smoke", "x": 1120.0, "y": 130.0},
			{"type": "fud_wall", "x": 1400.0},
			{"type": "smoke", "x": 1420.0, "y": 210.0},
			{"type": "candle", "x": 1700.0},
			{"type": "gap", "x": 1950.0, "w": 180.0},
			{"type": "smoke", "x": 2030.0, "y": 140.0},
			{"type": "candle", "x": 2350.0},
			{"type": "candle", "x": 2410.0},
			{"type": "fud_wall", "x": 2700.0},
			{"type": "smoke", "x": 2720.0, "y": 210.0},
			{"type": "gap", "x": 3050.0, "w": 160.0},
			{"type": "candle", "x": 3350.0},
			{"type": "candle", "x": 3410.0},
			{"type": "candle", "x": 3470.0},
			{"type": "smoke", "x": 3430.0, "y": 190.0},
			{"type": "gap", "x": 3800.0, "w": 190.0},
			{"type": "smoke", "x": 3890.0, "y": 130.0},
			{"type": "smoke", "x": 4250.0, "y": 60.0},
		],
	},
}

static func get_layout(level_index: int) -> Dictionary:
	return LAYOUTS.get(level_index, LAYOUTS[1])
