class_name TestSimulationClock
extends RefCounted

## Automated unit tests for SimulationClock.

const SimulationClockClass = preload("res://scripts/simulation/simulation_clock.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_initial_state())
	results.append(_test_advancement_at_1x())
	results.append(_test_pause_behavior())
	results.append(_test_speed_multipliers())
	results.append(_test_simulation_end_boundary())
	results.append(_test_reset())
	return results

static func _test_initial_state() -> Dictionary:
	var clock = SimulationClockClass.new()

	if not is_equal_approx(clock.get_current_sim_seconds(), 18.0 * 3600.0):
		return {"name": "test_initial_state", "passed": false, "error": "Start time is not 18:00 (64800s)"}

	if clock.is_paused():
		return {"name": "test_initial_state", "passed": false, "error": "Clock should not start paused"}

	if not is_equal_approx(clock.get_speed_multiplier(), 1.0):
		return {"name": "test_initial_state", "passed": false, "error": "Default speed is not 1x"}

	if clock.get_formatted_time(false) != "18:00":
		return {"name": "test_initial_state", "passed": false, "error": "Initial short formatted time is not 18:00: %s" % clock.get_formatted_time(false)}

	if clock.get_formatted_time(true) != "18:00:00":
		return {"name": "test_initial_state", "passed": false, "error": "Initial full formatted time is not 18:00:00: %s" % clock.get_formatted_time(true)}

	return {"name": "test_initial_state", "passed": true}

static func _test_advancement_at_1x() -> Dictionary:
	var clock = SimulationClockClass.new()

	# Advance by 1 real second -> should advance by 60 sim seconds (1 minute)
	clock.advance(1.0)
	var expected_seconds: float = 18.0 * 3600.0 + 60.0
	if not is_equal_approx(clock.get_current_sim_seconds(), expected_seconds):
		return {"name": "test_advancement_at_1x", "passed": false, "error": "Expected %f sim seconds, got %f" % [expected_seconds, clock.get_current_sim_seconds()]}

	if clock.get_formatted_time(false) != "18:01":
		return {"name": "test_advancement_at_1x", "passed": false, "error": "Expected 18:01, got %s" % clock.get_formatted_time(false)}

	return {"name": "test_advancement_at_1x", "passed": true}

static func _test_pause_behavior() -> Dictionary:
	var clock = SimulationClockClass.new()
	clock.advance(1.0) # 18:01:00

	clock.toggle_pause()
	if not clock.is_paused():
		return {"name": "test_pause_behavior", "passed": false, "error": "toggle_pause() did not pause"}

	var paused_seconds: float = clock.get_current_sim_seconds()
	clock.advance(5.0)

	if not is_equal_approx(clock.get_current_sim_seconds(), paused_seconds):
		return {"name": "test_pause_behavior", "passed": false, "error": "Clock advanced while paused"}

	clock.toggle_pause()
	if clock.is_paused():
		return {"name": "test_pause_behavior", "passed": false, "error": "toggle_pause() did not unpause"}

	clock.advance(1.0)
	if is_equal_approx(clock.get_current_sim_seconds(), paused_seconds):
		return {"name": "test_pause_behavior", "passed": false, "error": "Clock failed to resume advancing"}

	return {"name": "test_pause_behavior", "passed": true}

static func _test_speed_multipliers() -> Dictionary:
	var clock2x = SimulationClockClass.new()
	clock2x.set_speed_multiplier(2.0)
	clock2x.advance(1.0) # 1 real second at 2x = 120 sim seconds
	var expected_2x: float = 18.0 * 3600.0 + 120.0
	if not is_equal_approx(clock2x.get_current_sim_seconds(), expected_2x):
		return {"name": "test_speed_multipliers", "passed": false, "error": "2x speed failed: expected %f, got %f" % [expected_2x, clock2x.get_current_sim_seconds()]}

	var clock4x = SimulationClockClass.new()
	clock4x.set_speed_multiplier(4.0)
	clock4x.advance(1.0) # 1 real second at 4x = 240 sim seconds
	var expected_4x: float = 18.0 * 3600.0 + 240.0
	if not is_equal_approx(clock4x.get_current_sim_seconds(), expected_4x):
		return {"name": "test_speed_multipliers", "passed": false, "error": "4x speed failed: expected %f, got %f" % [expected_4x, clock4x.get_current_sim_seconds()]}

	return {"name": "test_speed_multipliers", "passed": true}

static func _test_simulation_end_boundary() -> Dictionary:
	var clock = SimulationClockClass.new()
	var completed_fired: Array[bool] = [false]
	clock.simulation_completed.connect(func(): completed_fired[0] = true)

	# Advance 12 sim hours = 43200 sim seconds = 720 real seconds
	clock.advance(720.0)

	if not clock.is_finished():
		return {"name": "test_simulation_end_boundary", "passed": false, "error": "Clock should be finished after 12 sim hours"}

	if not is_equal_approx(clock.get_current_sim_seconds(), 30.0 * 3600.0):
		return {"name": "test_simulation_end_boundary", "passed": false, "error": "Clock did not clamp to 30:00:00 (06:00 next day)"}

	if clock.get_formatted_time(false) != "06:00":
		return {"name": "test_simulation_end_boundary", "passed": false, "error": "End time display should be 06:00, got %s" % clock.get_formatted_time(false)}

	if not completed_fired[0]:
		return {"name": "test_simulation_end_boundary", "passed": false, "error": "simulation_completed signal was not emitted"}

	if not clock.is_paused():
		return {"name": "test_simulation_end_boundary", "passed": false, "error": "Clock did not pause upon reaching end time"}

	# Further advancement should do nothing
	clock.advance(60.0)
	if not is_equal_approx(clock.get_current_sim_seconds(), 30.0 * 3600.0):
		return {"name": "test_simulation_end_boundary", "passed": false, "error": "Clock advanced past end time"}

	return {"name": "test_simulation_end_boundary", "passed": true}

static func _test_reset() -> Dictionary:
	var clock = SimulationClockClass.new()
	clock.advance(360.0)
	clock.set_speed_multiplier(4.0)
	clock.set_paused(true)

	clock.reset()

	if not is_equal_approx(clock.get_current_sim_seconds(), 18.0 * 3600.0):
		return {"name": "test_reset", "passed": false, "error": "Clock reset did not restore 18:00"}

	if clock.is_paused():
		return {"name": "test_reset", "passed": false, "error": "Clock reset did not clear pause"}

	if not is_equal_approx(clock.get_speed_multiplier(), 1.0):
		return {"name": "test_reset", "passed": false, "error": "Clock reset did not reset speed to 1x"}

	return {"name": "test_reset", "passed": true}

