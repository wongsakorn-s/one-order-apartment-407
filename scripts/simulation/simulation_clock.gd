class_name SimulationClock
extends RefCounted

## SimulationClock manages deterministic passage of simulation time.
## Starts at 18:00 (Day 1) and runs until 06:00 (Day 2).
## Time is tracked in simulation seconds, decoupled from rendering frame rate.

signal time_advanced(sim_time_seconds: float, formatted_time: String)
signal pause_toggled(is_paused: bool)
signal speed_changed(multiplier: float)
signal simulation_completed()

const START_SIM_SECONDS: float = 18.0 * 3600.0 # 64,800s (18:00)
const END_SIM_SECONDS: float = 30.0 * 3600.0   # 108,000s (06:00 next day)
const BASE_SIM_SECONDS_PER_REAL_SECOND: float = 60.0 # 1 real second = 1 simulation minute at 1x
const ALLOWED_SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var _current_sim_seconds: float = START_SIM_SECONDS
var _is_paused: bool = false
var _speed_multiplier: float = 1.0

func _init() -> void:
	_current_sim_seconds = START_SIM_SECONDS
	_is_paused = false
	_speed_multiplier = 1.0

## Advance the simulation clock by a fixed real-time delta.
func advance(real_delta: float) -> void:
	if _is_paused or is_finished():
		return

	var sim_delta: float = real_delta * BASE_SIM_SECONDS_PER_REAL_SECOND * _speed_multiplier
	_current_sim_seconds = minf(_current_sim_seconds + sim_delta, END_SIM_SECONDS)

	time_advanced.emit(_current_sim_seconds, get_formatted_time(true))

	if is_finished():
		_is_paused = true
		pause_toggled.emit(_is_paused)
		simulation_completed.emit()

## Toggle pause state. If simulation already completed, it cannot be unpaused without reset.
func toggle_pause() -> void:
	if is_finished() and _is_paused:
		return
	set_paused(not _is_paused)

## Set explicit pause state.
func set_paused(paused: bool) -> void:
	if _is_paused == paused:
		return
	if not paused and is_finished():
		return
	_is_paused = paused
	pause_toggled.emit(_is_paused)

## Check whether the clock is currently paused.
func is_paused() -> bool:
	return _is_paused

## Set speed multiplier (supported: 1.0, 2.0, 4.0).
func set_speed_multiplier(multiplier: float) -> void:
	if not multiplier in ALLOWED_SPEEDS and multiplier <= 0.0:
		return
	if is_equal_approx(_speed_multiplier, multiplier):
		return
	_speed_multiplier = multiplier
	speed_changed.emit(_speed_multiplier)

## Get current speed multiplier.
func get_speed_multiplier() -> float:
	return _speed_multiplier

## Check if simulation reached 06:00 next day.
func is_finished() -> bool:
	return _current_sim_seconds >= END_SIM_SECONDS or is_equal_approx(_current_sim_seconds, END_SIM_SECONDS)

## Return current simulation seconds.
func get_current_sim_seconds() -> float:
	return _current_sim_seconds

## Return formatted time string HH:MM or HH:MM:SS.
func get_formatted_time(include_seconds: bool = false) -> String:
	var total_sec: int = int(round(_current_sim_seconds))
	var day_sec: int = total_sec % 86400
	var hour: int = day_sec / 3600
	var minute: int = (day_sec % 3600) / 60
	var second: int = day_sec % 60

	if include_seconds:
		return "%02d:%02d:%02d" % [hour, minute, second]
	return "%02d:%02d" % [hour, minute]

## Reset clock to initial state (18:00 Day 1).
func reset() -> void:
	_current_sim_seconds = START_SIM_SECONDS
	_is_paused = false
	_speed_multiplier = 1.0
	pause_toggled.emit(_is_paused)
	speed_changed.emit(_speed_multiplier)
	time_advanced.emit(_current_sim_seconds, get_formatted_time(true))

