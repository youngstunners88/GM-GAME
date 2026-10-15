class_name DistantLake
extends ParallaxLayer
## Far-distance lake behind the GoldMine rail line — still water under the
## horizon with drifting sun-glint. Sits on ParallaxBackground layer -17 at
## 0.10x (farther than the train at -15/0.18x), screen-pinned vertically.
## All art is code-drawn and re-drawn every frame for the shimmer; no textures.

@export var span: float = 3200.0
@export var shore_y: float = 452.0
@export var water_bottom: float = 640.0

var _t: float = 0.0


func _ready() -> void:
	motion_scale = Vector2(0.10, 0.0)
	motion_mirroring = Vector2(span, 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Far tree-line/shore silhouette.
	draw_rect(Rect2(0.0, shore_y - 14.0, span, 16.0), Color(0.13, 0.20, 0.20, 1.0))
	draw_rect(Rect2(0.0, shore_y + 2.0, span, 4.0), Color(0.35, 0.32, 0.22, 1.0))
	# Water body: three hazy bands, lighter toward the viewer.
	draw_rect(Rect2(0.0, shore_y + 6.0, span, 46.0), Color(0.16, 0.26, 0.34, 1.0))
	draw_rect(Rect2(0.0, shore_y + 52.0, span, 60.0), Color(0.20, 0.32, 0.40, 1.0))
	draw_rect(Rect2(0.0, shore_y + 112.0, span, water_bottom - shore_y - 112.0), Color(0.24, 0.37, 0.45, 1.0))
	# Sun-glint path: brighter cluster mid-span, twinkling shingles elsewhere.
	for i in range(46):
		var gx: float = fmod(float(i) * 197.3, span)
		var gy: float = shore_y + 16.0 + fmod(float(i) * 89.7, 150.0)
		var near_path: bool = absf(gx - span * 0.5) < 260.0
		var tw: float = 0.5 + 0.5 * sin(_t * 1.4 + float(i) * 1.7)
		var a: float = (0.55 + 0.40 * tw) if near_path else (0.12 + 0.30 * tw)
		var w: float = 26.0 if near_path else 12.0
		draw_line(Vector2(gx, gy), Vector2(gx + w, gy), Color(0.95, 0.88, 0.62, a), 2.0)
	# Slow travelling ripple lines.
	for k in range(4):
		var ry: float = shore_y + 30.0 + float(k) * 38.0
		var off: float = fmod(_t * (6.0 + float(k) * 2.0), span)
		draw_line(Vector2(-80.0 + off, ry), Vector2(220.0 + off, ry), Color(0.7, 0.8, 0.85, 0.10), 5.0)
