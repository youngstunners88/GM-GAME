extends RefCounted
## Reusable boss pursuit-pipeline tracer (founder forensic-repair directive §17).
##
## WHY THIS EXISTS: every previous "the boss chases now" claim in this repo was
## backed by a gate that measured ONE number (usually horizontal distance closed
## against a pinned or straight-line player) and passed. The founder kept
## reporting motionless bosses anyway. A single scalar cannot distinguish
## between the many distinct ways a pursuit can look broken:
##
##   - genuinely frozen (velocity always ~0)
##   - moving but pinned against an arena clamp (velocity non-zero, position stuck)
##   - holding a standoff (moves, tracks, but never closes -> reads as "parked")
##   - oscillating around the player (net displacement ~0 -> reads as "twitching")
##   - only moving while the player stands still (fails against a real kiting player)
##
## This records the whole pipeline per sample so the failure MODE is identifiable,
## not just its presence. It is a diagnostic, not a gate: it asserts nothing.

## One sample of the full pursuit pipeline.
class Sample:
	var t: float
	var state: int
	var boss_centre: Vector2
	var player_pos: Vector2
	var velocity: Vector2
	var on_floor: bool
	var clamped_lo: bool      ## sitting on the arena's low-x clamp
	var clamped_hi: bool      ## sitting on the arena's high-x clamp
	var player_found: bool

var samples: Array[Sample] = []
var arena_min: Vector2 = Vector2.ZERO
var arena_max: Vector2 = Vector2.ZERO
var half_body: float = 0.0
var boss_name: String = ""
## Set true by the caller if a boss/player contact fired during the run. Contact
## is an instant full-run restart in this game, so a "chase" that always ends in
## contact within a second or two is a different defect than one that never closes.
var contact_events: int = 0

func configure(boss: Node2D, p_half_body: float) -> void:
	boss_name = boss.name
	half_body = p_half_body
	var amin: Variant = boss.get("arena_min")
	var amax: Variant = boss.get("arena_max")
	arena_min = amin if amin is Vector2 else Vector2.ZERO
	arena_max = amax if amax is Vector2 else Vector2.ZERO

## Record one physics frame. `state_value` is whatever the boss exposes as its
## state machine value (bosses in this repo use different member names, so the
## caller reads it — this class stays boss-agnostic).
func sample(t: float, boss: Node2D, player: Node2D, state_value: int) -> void:
	var s := Sample.new()
	s.t = t
	s.state = state_value
	s.boss_centre = boss.global_position + Vector2(half_body, half_body)
	s.player_found = player != null and is_instance_valid(player)
	s.player_pos = player.global_position if s.player_found else Vector2.ZERO
	var v: Variant = boss.get("velocity")
	s.velocity = v if v is Vector2 else Vector2.ZERO
	s.on_floor = boss.has_method("is_on_floor") and boss.is_on_floor()
	if arena_max != Vector2.ZERO:
		s.clamped_lo = absf(s.boss_centre.x - (arena_min.x + half_body)) < 2.0
		s.clamped_hi = absf(s.boss_centre.x - (arena_max.x - half_body)) < 2.0
	samples.append(s)

# --- Derived metrics -------------------------------------------------------

func reachable_range() -> float:
	if arena_max == Vector2.ZERO:
		return -1.0
	return maxf(0.0, (arena_max.x - half_body) - (arena_min.x + half_body))

## Total absolute distance the boss's centre actually travelled.
func path_length() -> float:
	var total := 0.0
	for i in range(1, samples.size()):
		total += absf(samples[i].boss_centre.x - samples[i - 1].boss_centre.x)
	return total

## Widest span of x the boss's centre ever occupied. A boss that oscillates in a
## tiny band has a large path_length but a tiny span — that is "twitching in place".
func x_span() -> float:
	if samples.is_empty():
		return 0.0
	var lo: float = samples[0].boss_centre.x
	var hi: float = lo
	for s in samples:
		lo = minf(lo, s.boss_centre.x)
		hi = maxf(hi, s.boss_centre.x)
	return hi - lo

func min_distance() -> float:
	var d := INF
	for s in samples:
		if s.player_found:
			d = minf(d, absf(s.boss_centre.x - s.player_pos.x))
	return d

func max_distance() -> float:
	var d := 0.0
	for s in samples:
		if s.player_found:
			d = maxf(d, absf(s.boss_centre.x - s.player_pos.x))
	return d

func mean_distance() -> float:
	var total := 0.0
	var n := 0
	for s in samples:
		if s.player_found:
			total += absf(s.boss_centre.x - s.player_pos.x)
			n += 1
	return total / float(n) if n > 0 else -1.0

## Fraction of samples where the boss was effectively motionless horizontally.
func frozen_fraction(threshold: float = 5.0) -> float:
	if samples.is_empty():
		return 1.0
	var n := 0
	for s in samples:
		if absf(s.velocity.x) < threshold:
			n += 1
	return float(n) / float(samples.size())

## Fraction of samples sitting on either arena clamp. High = "pinned to a wall",
## which is the specific failure the standoff arithmetic predicts.
func clamped_fraction() -> float:
	if samples.is_empty() or arena_max == Vector2.ZERO:
		return 0.0
	var n := 0
	for s in samples:
		if s.clamped_lo or s.clamped_hi:
			n += 1
	return float(n) / float(samples.size())

## Does the boss move in the SAME direction the player moves? +1 = tracks
## perfectly, 0 = uncorrelated, -1 = consistently moves away.
## This is the metric that actually distinguishes "pursuing" from "wandering".
func tracking_score() -> float:
	var agree := 0
	var total := 0
	for i in range(1, samples.size()):
		if not samples[i].player_found:
			continue
		var pdx: float = samples[i].player_pos.x - samples[i - 1].player_pos.x
		var bdx: float = samples[i].boss_centre.x - samples[i - 1].boss_centre.x
		if absf(pdx) < 1.0 or absf(bdx) < 1.0:
			continue
		total += 1
		if signf(pdx) == signf(bdx):
			agree += 1
	if total == 0:
		return 0.0
	return (float(agree) / float(total)) * 2.0 - 1.0

func states_visited() -> Array:
	var seen: Array = []
	for s in samples:
		if not seen.has(s.state):
			seen.append(s.state)
	return seen

func report(label: String) -> String:
	var lines: Array[String] = []
	lines.append("[BOSS TRACE] %s (%s)" % [label, boss_name])
	lines.append("  arena_min=%s arena_max=%s half_body=%.0f" % [str(arena_min), str(arena_max), half_body])
	lines.append("  reachable_centre_range=%.0f px" % reachable_range())
	lines.append("  samples=%d  states_visited=%s" % [samples.size(), str(states_visited())])
	lines.append("  x_span=%.0f px   path_length=%.0f px" % [x_span(), path_length()])
	lines.append("  distance to player: min=%.0f mean=%.0f max=%.0f" % [min_distance(), mean_distance(), max_distance()])
	lines.append("  frozen_fraction(|vx|<5)=%.2f   clamped_fraction=%.2f" % [frozen_fraction(), clamped_fraction()])
	lines.append("  tracking_score=%+.2f  (+1 follows player, 0 uncorrelated, -1 flees)" % tracking_score())
	lines.append("  contact_events=%d" % contact_events)
	return "\n".join(lines)

## Compact per-sample dump, thinned so a 10s run stays readable.
func trace_lines(every: int = 4) -> String:
	var out: Array[String] = []
	for i in range(samples.size()):
		if i % every != 0:
			continue
		var s: Sample = samples[i]
		out.append("    t=%5.2f state=%d boss_cx=%7.1f player_x=%7.1f dx=%+7.1f vx=%+7.1f floor=%s clamp=%s" % [
			s.t, s.state, s.boss_centre.x, s.player_pos.x,
			s.player_pos.x - s.boss_centre.x, s.velocity.x,
			"Y" if s.on_floor else "n",
			("LO" if s.clamped_lo else ("HI" if s.clamped_hi else "--")),
		])
	return "\n".join(out)
