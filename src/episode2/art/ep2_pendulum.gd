class_name Ep2Pendulum
extends Node3D
## A clock's pendulum swinging about its pivot (the node's local z axis): the town's Vienna regulators (founder 2026-10-25 "subtle
## details"; Ep2GoldTown._room_detail). A 0.47 m rod beats at its natural period, 2 pi sqrt(L / g) ~ 1.38 s, a few degrees each way.

@export var period: float = 1.38
@export var amplitude: float = 0.07          # radians (~4 degrees)
var _t: float = 0.0


func _ready() -> void:
	_t = fposmod(position.x * 0.37 + position.z * 0.11, period)    # two clocks in town do not beat in step


func _process(delta: float) -> void:
	_t += delta
	rotation.z = sin(_t * TAU / period) * amplitude
