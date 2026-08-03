class_name BlazeRushLayouts
extends RefCounted
## Data-driven Blaze Rush course layouts — one per level.
## Obstacle types:
##   "candle"   — red candle spike on the ground (market dip). Jump it.
##   "fud_wall" — tall FUD block. Jump onto/over it.
##   "smoke"    — $SMOKE token pickup, offset above ground by `y` px.
##   "gap"      — pit in the floor of width `w`. Clear it airborne.
## Positions are x offsets (px) from run start. Ground sits at y=500.
##
## Each level is built in four escalating zones — warm-up, building, rhythm,
## gauntlet finale — with hazard spacing shrinking zone over zone. Combined
## with the speed_start -> speed_end ramp in blaze_rush.gd (same distance to
## the telegraph = less real time to react as speed climbs), this is what
## makes a run get harder as it progresses instead of holding one flat
## difficulty end to end. There is deliberately zero RNG anywhere in this
## file — every position below is hand-placed and reproducible; "feels
## random" was a pacing/density complaint, not a literal randomness one, and
## the fix is deliberate rhythm, not adding real randomness.
##
## Jump arc reference (GRAVITY=2200, JUMP_VELOCITY=-700): air time is fixed
## at ~0.636s regardless of run speed, so horizontal clearance a jump can
## cover is speed * 0.636. Every "gap" width below was sized against the
## LOCAL speed at that x (via the level's speed_start/speed_end lerp) with
## at least a 20% safety margin, so gaps stay fair even as speed ramps.

const GROUND_Y: float = 500.0

static func get_layout(level_index: int) -> Dictionary:
	match level_index:
		2:
			return _level_2()
		3:
			return _level_3()
		_:
			return _level_1()

## --- Level 1 — Warm-up run: 320 -> 400 px/s over 5450px. ---------------------
static func _level_1() -> Dictionary:
	return {
		"length": 5450.0,
		"speed_start": 320.0,
		"speed_end": 400.0,
		"obstacles": [
			# Zone A — warm-up: singles only, wide spacing.
			{"type": "candle", "x": 420.0},
			{"type": "smoke", "x": 440.0, "y": 60.0},
			{"type": "candle", "x": 980.0},
			{"type": "smoke", "x": 1000.0, "y": 150.0},
			{"type": "gap", "x": 1350.0, "w": 140.0},
			{"type": "smoke", "x": 1430.0, "y": 120.0},

			# Zone B — building: a wall, a double-candle combo, a wider gap.
			{"type": "fud_wall", "x": 1750.0},
			{"type": "smoke", "x": 1770.0, "y": 210.0},
			{"type": "candle", "x": 2100.0},
			{"type": "candle", "x": 2160.0},
			{"type": "smoke", "x": 2130.0, "y": 170.0},
			{"type": "gap", "x": 2500.0, "w": 160.0},
			{"type": "smoke", "x": 2580.0, "y": 130.0},
			{"type": "candle", "x": 2850.0},
			{"type": "smoke", "x": 2870.0, "y": 150.0},

			# Zone C — rhythm: tighter, evenly spaced combo train.
			{"type": "fud_wall", "x": 3150.0},
			{"type": "smoke", "x": 3170.0, "y": 210.0},
			{"type": "candle", "x": 3500.0},
			{"type": "candle", "x": 3560.0},
			{"type": "candle", "x": 3620.0},
			{"type": "smoke", "x": 3560.0, "y": 190.0},
			{"type": "gap", "x": 3900.0, "w": 160.0},
			{"type": "smoke", "x": 3980.0, "y": 130.0},
			{"type": "candle", "x": 4220.0},
			{"type": "smoke", "x": 4240.0, "y": 150.0},

			# Zone D — gauntlet finale: densest, least recovery time.
			{"type": "candle", "x": 4500.0},
			{"type": "candle", "x": 4560.0},
			{"type": "smoke", "x": 4530.0, "y": 180.0},
			{"type": "gap", "x": 4800.0, "w": 170.0},
			{"type": "smoke", "x": 4880.0, "y": 130.0},
			{"type": "candle", "x": 5080.0},
			{"type": "candle", "x": 5140.0},
			{"type": "candle", "x": 5200.0},
			{"type": "smoke", "x": 5140.0, "y": 200.0},

			# Victory stretch — clear run-up to the finish line.
			{"type": "smoke", "x": 5350.0, "y": 60.0},
		],
		# Founder defect F — magic marijuana skateboard: steer through this
		# stretch to auto-collect its token line, no jump needed. Centred on
		# the existing gap at x=3900 (w=160) so the board's purpose is
		# legible at a glance — it flies you over the pit instead of a timed
		# jump — with generous lead-in/lead-out either side. 600px wide: at
		# this course's ~370-390px/s local speed a narrower zone (originally
		# 280px) crossed in under a second, barely long enough to register
		# as a ride before the spring's-target check in the probe caught the
		# player already exiting the far side back into free-fall.
		"board_zone": {"start": 3700.0, "end": 4300.0, "path_height": 140.0},
	}

## --- Level 2 — 330 -> 430 px/s over 6400px, one notch harder throughout. ----
static func _level_2() -> Dictionary:
	return {
		"length": 6400.0,
		"speed_start": 330.0,
		"speed_end": 430.0,
		"obstacles": [
			{"type": "candle", "x": 420.0},
			{"type": "smoke", "x": 440.0, "y": 60.0},
			{"type": "smoke", "x": 600.0, "y": 100.0},
			{"type": "candle", "x": 900.0},
			{"type": "smoke", "x": 920.0, "y": 150.0},
			{"type": "gap", "x": 1250.0, "w": 150.0},
			{"type": "smoke", "x": 1330.0, "y": 120.0},

			{"type": "fud_wall", "x": 1650.0},
			{"type": "smoke", "x": 1670.0, "y": 210.0},
			{"type": "candle", "x": 1980.0},
			{"type": "candle", "x": 2040.0},
			{"type": "smoke", "x": 2010.0, "y": 170.0},
			{"type": "gap", "x": 2380.0, "w": 160.0},
			{"type": "smoke", "x": 2460.0, "y": 130.0},
			{"type": "candle", "x": 2700.0},
			{"type": "smoke", "x": 2720.0, "y": 150.0},

			{"type": "fud_wall", "x": 2950.0},
			{"type": "smoke", "x": 2970.0, "y": 210.0},
			{"type": "candle", "x": 3300.0},
			{"type": "candle", "x": 3360.0},
			{"type": "candle", "x": 3420.0},
			{"type": "smoke", "x": 3360.0, "y": 190.0},
			{"type": "gap", "x": 3750.0, "w": 170.0},
			{"type": "smoke", "x": 3830.0, "y": 130.0},
			{"type": "candle", "x": 3980.0},
			{"type": "candle", "x": 4040.0},
			{"type": "smoke", "x": 4000.0, "y": 160.0},

			{"type": "fud_wall", "x": 4350.0},
			{"type": "smoke", "x": 4370.0, "y": 210.0},
			{"type": "candle", "x": 4650.0},
			{"type": "candle", "x": 4710.0},
			{"type": "smoke", "x": 4680.0, "y": 180.0},
			{"type": "gap", "x": 4980.0, "w": 180.0},
			{"type": "smoke", "x": 5060.0, "y": 130.0},
			{"type": "candle", "x": 5250.0},
			{"type": "candle", "x": 5300.0},
			{"type": "candle", "x": 5350.0},
			{"type": "smoke", "x": 5300.0, "y": 200.0},
			{"type": "gap", "x": 5650.0, "w": 180.0},
			{"type": "smoke", "x": 5730.0, "y": 130.0},
			{"type": "candle", "x": 5900.0},
			{"type": "candle", "x": 5960.0},
			{"type": "candle", "x": 6020.0},
			{"type": "smoke", "x": 5960.0, "y": 210.0},

			{"type": "smoke", "x": 6200.0, "y": 60.0},
		],
		# Founder defect F — board zone over the x=3750 gap (w=170), widened
		# to 600px (see L1's board_zone comment for why 280-320px was too
		# narrow to read as a ride at this course's speed).
		"board_zone": {"start": 3550.0, "end": 4150.0, "path_height": 150.0},
	}

## --- Level 3 — 340 -> 460 px/s over 7350px, the hardest run. ----------------
static func _level_3() -> Dictionary:
	return {
		"length": 7350.0,
		"speed_start": 340.0,
		"speed_end": 460.0,
		"obstacles": [
			{"type": "candle", "x": 500.0},
			{"type": "smoke", "x": 520.0, "y": 60.0},
			{"type": "smoke", "x": 710.0, "y": 100.0},
			{"type": "candle", "x": 1070.0},
			{"type": "smoke", "x": 1090.0, "y": 150.0},
			{"type": "gap", "x": 1490.0, "w": 150.0},
			{"type": "smoke", "x": 1580.0, "y": 120.0},

			{"type": "fud_wall", "x": 1960.0},
			{"type": "smoke", "x": 1980.0, "y": 210.0},
			{"type": "candle", "x": 2350.0},
			{"type": "candle", "x": 2420.0},
			{"type": "smoke", "x": 2390.0, "y": 170.0},
			{"type": "gap", "x": 2830.0, "w": 160.0},
			{"type": "smoke", "x": 2920.0, "y": 130.0},
			{"type": "candle", "x": 3210.0},
			{"type": "smoke", "x": 3230.0, "y": 150.0},

			{"type": "fud_wall", "x": 3500.0},
			{"type": "smoke", "x": 3530.0, "y": 210.0},
			{"type": "candle", "x": 3920.0},
			{"type": "candle", "x": 3990.0},
			{"type": "candle", "x": 4060.0},
			{"type": "smoke", "x": 4000.0, "y": 190.0},
			{"type": "gap", "x": 4450.0, "w": 170.0},
			{"type": "smoke", "x": 4650.0, "y": 130.0},
			{"type": "candle", "x": 4730.0},
			{"type": "candle", "x": 4800.0},
			{"type": "smoke", "x": 4760.0, "y": 160.0},

			{"type": "fud_wall", "x": 5170.0},
			{"type": "smoke", "x": 5190.0, "y": 210.0},
			{"type": "candle", "x": 5520.0},
			{"type": "candle", "x": 5590.0},
			{"type": "smoke", "x": 5560.0, "y": 180.0},
			{"type": "gap", "x": 5920.0, "w": 180.0},
			{"type": "smoke", "x": 6150.0, "y": 130.0},
			{"type": "candle", "x": 6230.0},
			{"type": "candle", "x": 6290.0},
			{"type": "candle", "x": 6350.0},
			{"type": "smoke", "x": 6300.0, "y": 200.0},
			{"type": "gap", "x": 6710.0, "w": 190.0},
			{"type": "smoke", "x": 6950.0, "y": 130.0},
			{"type": "candle", "x": 7010.0},
			{"type": "candle", "x": 7080.0},
			{"type": "candle", "x": 7150.0},
			{"type": "smoke", "x": 7080.0, "y": 210.0},

			{"type": "smoke", "x": 7300.0, "y": 60.0},
		],
		# Founder defect F — board zone over the x=6710 gap (w=190), widened
		# to 600px (see L1's board_zone comment for why 280-320px was too
		# narrow to read as a ride at this course's speed).
		"board_zone": {"start": 6410.0, "end": 7010.0, "path_height": 150.0},
	}
