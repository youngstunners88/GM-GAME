class_name Ep2LakeLandform
extends RefCounted
const CENTER_X := 51.0
const RADIUS_X := 54.0
const RADIUS_Z := 45.0
## Shared metre-scale shoreline and walking-height contract. Terrain, reflection
## tree roots, bank dressing and navigation sample the same continuous surface.
static func path_height(z: float) -> float:
	return clampf((z - 33.0) / 28.0, 0.0, 1.0) * 6.0

static func rim_radius(angle: float) -> float:
	return 1.0 + 0.038 * sin(angle * 3.0 + 0.4) + 0.020 * sin(angle * 7.0 - 0.6)

static func lake_radius(x: float, z: float) -> float:
	var p := Vector2((x - CENTER_X) / RADIUS_X, (z - 20.0) / RADIUS_Z)
	return p.length() / rim_radius(atan2(p.y, p.x))

static func flow_center(z: float) -> float:
	return 24.0 + 3.0 * sin(maxf(0.0, z - 51.0) * 0.05)

static func flow_width(z: float) -> float:
	return 4.1 + 0.5 * sin(z * 0.09)

static func cabin_clearance(x: float, z: float) -> bool:
	return x > -31.0 and x < -12.0 and z > 3.0 and z < 23.0

static func terrain_height(x: float, z: float) -> float:
	var base: float = _natural_height(x, z)
	if x >= -14.0: return base
	var wx: float = 1.0 - smoothstep(6.0, 9.0, absf(x + 22.0))
	var wz: float = 1.0 - smoothstep(6.0, 9.0, absf(z - 13.0))
	return lerpf(base, 1.0, wx * wz)

static func drawn_height(x: float, z: float) -> float:
	# Match the actual2m triangle grid, not an unrelated smooth height oracle.
	var gx: float = floorf((x + 130.0) / 2.0) * 2.0 - 130.0
	var gz: float = floorf((z + 100.0) / 2.0) * 2.0 - 100.0
	var u: float = (x - gx) * .5
	var v: float = (z - gz) * .5
	var a: float = terrain_height(gx, gz)
	var b: float = terrain_height(gx + 2.0, gz)
	var c: float = terrain_height(gx, gz + 2.0)
	if u + v <= 1.0: return a + (b - a) * u + (c - a) * v
	var d: float = terrain_height(gx + 2.0, gz + 2.0)
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)

static func _natural_height(x: float, z: float) -> float:
	# Keep the existing walkable corridor and all its story marks intact.
	if x > -14.0 and x < -0.5 and z > -150.0 and z < 68.0:
		return path_height(z)
	var r: float = lake_radius(x, z)
	var shore: float = -2.25 + smoothstep(0.77, 1.11, r) * 2.72
	var outside: float = maxf(0.0, r - 1.1)
	var terrain: float = shore + pow(outside, 1.45) * 2.0
	terrain += outside * (0.8 * sin(x * 0.085) * cos(z * 0.10) + 0.5 * sin(z * 0.18 + x * 0.04))
	# Layered ridges enclose the water beyond the wooded shore, not a flat rim.
	var ridge: float = maxf(0.0, absf(x - CENTER_X) - 82.0) * 0.23
	ridge += maxf(0.0, z - 77.0) * 0.095
	terrain += ridge * (0.75 + 0.25 * sin(x * 0.11 + z * 0.04))
	if z > 46.0:
		var d: float = absf(x - flow_center(z))
		var bank: float = -1.9 + smoothstep(flow_width(z) * 0.52, flow_width(z) + 3.0, d) * 2.65
		var channel_blend: float = 1.0 - smoothstep(flow_width(z) + 3.0, flow_width(z) + 12.0, d)
		terrain = lerpf(terrain, minf(terrain, bank), smoothstep(46.0, 54.0, z) * channel_blend)
	# A continuous hillside supports the existing six-metre overlook trail.
	if z > 30.0 and x > -28.0 and x < 8.0:
		var blend: float = 1.0 - smoothstep(3.0, 18.0, absf(x + 8.0))
		terrain = lerpf(terrain, maxf(terrain, path_height(z) - 0.15), blend)
	return terrain*smoothstep(-100.0,-25.0,z)
