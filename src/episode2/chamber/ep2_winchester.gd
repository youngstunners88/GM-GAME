class_name Ep2Winchester
extends RefCounted
## The first-person Winchester 1886 as pure, deterministic game logic: ammo, the tube magazine, shell-by-shell
## reload, the lever cycle, aim-down-sights and spread. No nodes, no audio, no rendering: the facility turns the
## events into sound, viewmodel motion and HUD, and the headless tests drive `step()` directly.
##
## Founder 2026-10-04: "The gameplay of the rifle is nothing like Modern Warfare ... the rifle doesn't fire until
## Inferno teaches Lil Blunt to load it, aim and fire." Numbers come from the seeded bot simulation in
## tools/ep2_sim/fps_feel_sim.mjs (docs/ep2_fps_feel_simulation.json; Jev picked the `cod_lever` profile):
## loose hip fire, tight ADS, a 0.65 s lever cycle, shell-by-shell reload, view kick that recovers.
## Skill: ep2-fps-shooter-feel.

signal fired
signal dry_fired
signal shell_loaded(rounds: int)
signal reload_started
signal reload_finished
signal blocked(reason: String)          # "locked" | "reload_locked"

enum Shot { OK, LOCKED, EMPTY, CYCLING }

const MAG := 4                     # the tube magazine holds four for the lesson (the real 1886 holds 8)
const RESERVE_START := 24
const ADS_TIME := 0.24             # seconds from hip to fully aimed (COD-style: quick, never instant)
const CYCLE := 0.65                # the lever cycle: no second shot until it is racked
const LEVER_SOUND_AT := 0.34       # how far into the cycle the lever clack lands (the facility's lever sound delay)
const RELOAD_PER_SHELL := 0.5
const HIP_SPREAD_DEG := 2.6        # one-sigma aim error from the hip
const ADS_SPREAD_DEG := 0.62       # ... and down the sights
const MOVE_SPREAD_MULT := 1.6      # walking widens it; standing still is the tight case
const AIR_SPREAD_MULT := 2.5
const KICK_DEG := 2.0              # view kick per shot (ADS keeps 65 %)
const ADS_KICK_KEEP := 0.65
const SCOPE_SPREAD_DEG := 0.05     # through a telescopic sight the round goes where the reticle is
const SCOPE_KICK_KEEP := 0.25      # and the kick must not throw the lens off the eye

var rounds: int = 0
var reserve: int = RESERVE_START
## The lesson gate: the rifle does not fire until Inferno has taught it (`locked`), and cannot be loaded before he
## has shown the loading (`reload_locked`).
var locked: bool = true
var reload_locked: bool = true
var ads: float = 0.0               # 0 = hip, 1 = fully aimed
var scope_fov: float = 0.0          # above 0 this gun wears a telescopic sight (Ep2ArmoryState.PROFILES)
var wants_ads: bool = false
var reloading: bool = false
## R pressed while the action was still cycling (the Sharps' 1.1 s breech): remembered and started the moment the cycle ends,
## instead of silently dropped - the day-88 ridge "reload is glitched" report (founder 2026-11-06).
var reload_queued: bool = false
var shots_fired: int = 0
var dry_fires: int = 0

var _cycle: float = 0.0            # > 0 while the lever is being racked
var _reload_t: float = 0.0
## Per-firearm game profile; the lesson keeps the existing Winchester defaults.
var capacity: int = MAG
var cycle_time: float = CYCLE
var reload_interval: float = RELOAD_PER_SHELL
var training_complete: bool = false
## Armory profiles (Ep2ArmoryState.PROFILES): the view kick per shot, fire-while-held, a whole-drum reload (one `reload_interval`
## fills the magazine from the reserve), and buckshot (`pellets` per shot; rooms widen their hit test by `hit_scale`).
var kick_deg: float = KICK_DEG
var automatic: bool = false
var drum_reload: bool = false
var pellets: int = 1
var hit_scale: float = 1.0


## Advance the clocks. Call once per physics step.
func step(delta: float) -> void:
	var target: float = 1.0 if wants_ads and not _sprint_blocks() else 0.0
	ads = move_toward(ads, target, delta / ADS_TIME)
	if _cycle > 0.0:
		_cycle = maxf(0.0, _cycle - delta)
	if reload_queued and _cycle <= 0.0:
		reload_queued = false
		start_reload()
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_load_one_shell()


## `true` when sprinting forbids aiming (set by the facility each frame).
var sprinting: bool = false
func _sprint_blocks() -> bool: return sprinting


func set_aim(on: bool) -> void:
	wants_ads = on


## Pull the trigger. Returns what happened; `fired` / `dry_fired` / `blocked` are emitted for the facility.
func trigger() -> int:
	if locked:
		blocked.emit("locked")
		return Shot.LOCKED
	if _cycle > 0.0:
		return Shot.CYCLING
	if rounds <= 0:
		dry_fires += 1
		dry_fired.emit()
		return Shot.EMPTY
	reload_queued = false
	if reloading:
		_stop_reload()              # firing interrupts a shell-by-shell reload, as in Modern Warfare
	rounds -= 1
	shots_fired += 1
	_cycle = cycle_time
	fired.emit()
	return Shot.OK


## Start (or continue) loading shells. Returns false when it cannot start.
func start_reload() -> bool:
	if reload_locked:
		blocked.emit("reload_locked")
		return false
	if reloading or rounds >= capacity or reserve <= 0:
		return false
	if _cycle > 0.0:
		reload_queued = true        # starts when the action has cycled
		return false
	reloading = true
	_reload_t = reload_interval
	reload_started.emit()
	return true


func _load_one_shell() -> void:
	var n: int = mini(capacity - rounds, reserve) if drum_reload else 1
	rounds += n
	reserve -= n
	shell_loaded.emit(rounds)
	if rounds >= capacity or reserve <= 0:
		_stop_reload()
		reload_finished.emit()
	else:
		_reload_t = reload_interval


func _stop_reload() -> void:
	reloading = false
	_reload_t = 0.0


func cancel_reload() -> void:
	reload_queued = false
	_stop_reload()       # only completed shell transactions have spent reserve


func is_cycling() -> bool: return _cycle > 0.0
## 0..1 progress through the lever cycle (1 = ready), for the viewmodel's racking animation.
func cycle_progress() -> float: return 1.0 - _cycle / cycle_time if _cycle > 0.0 else 1.0
func is_full() -> bool: return rounds >= capacity


## One-sigma aim error in degrees right now.
func spread_deg(moving: bool = false, airborne: bool = false) -> float:
	var s: float = lerpf(HIP_SPREAD_DEG, SCOPE_SPREAD_DEG if scope_fov > 0.0 else ADS_SPREAD_DEG, ads)
	if moving:
		s *= lerpf(MOVE_SPREAD_MULT, 1.15, ads)
	if airborne:
		s *= AIR_SPREAD_MULT
	return s


## View kick (radians) one shot adds at the current aim state.
func kick_rad() -> float:
	return deg_to_rad(kick_deg) * lerpf(1.0, SCOPE_KICK_KEEP if scope_fov > 0.0 else ADS_KICK_KEEP, ads)
