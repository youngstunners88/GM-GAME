class_name Ep2Bow
extends Ep2Winchester
## Tap starts a visible 0.7-second draw; release event spends exactly one recovered arrow.
const DRAW_TIME := 0.7
var drawing: bool = false
var draw_time: float = 0.0
var release_time: float = 0.0
## Drawing brings the bow up to the eye (the aimed pose) and tightens the view like aiming; it relaxes slowly after the loose so the camera does not snap.
var _draw_ads: float = 0.0

func _init() -> void:
	capacity = 999
	reserve = 0
	cycle_time = 0.35

func trigger() -> int:
	if locked:
		blocked.emit("locked")
		return Shot.LOCKED
	if drawing or _cycle > 0.0:
		return Shot.CYCLING
	if rounds <= 0:
		dry_fires += 1
		dry_fired.emit()
		return Shot.EMPTY
	drawing = true
	draw_time = 0.0
	return Shot.OK

func step(delta: float) -> void:
	super.step(delta)
	release_time = maxf(0.0, release_time - delta)
	var d: float = draw_amount() if drawing else 0.0
	var want: float = d * d * (3.0 - 2.0 * d) * 0.85
	_draw_ads = move_toward(_draw_ads, want, delta * (4.0 if want > _draw_ads else 2.2))
	ads = maxf(ads, _draw_ads)
	if not drawing:
		return
	if sprinting or locked:
		cancel_reload()
		return
	draw_time += delta
	if draw_time >= DRAW_TIME:
		drawing = false
		release_time = 0.12
		super.trigger()

func cancel_reload() -> void:
	super.cancel_reload()
	drawing = false
	draw_time = 0.0

func start_reload() -> bool:
	return false   # arrow pool is owned by armory, never a gun magazine/reserve

func draw_amount() -> float:
	return clampf(draw_time / DRAW_TIME, 0.0, 1.0) if drawing else release_time / 0.12

func spread_deg(moving: bool = false, airborne: bool = false) -> float:
	return (0.45 if wants_ads else 1.3) * (1.6 if moving else 1.0) * (2.0 if airborne else 1.0)

func kick_rad() -> float:
	return deg_to_rad(0.25)
