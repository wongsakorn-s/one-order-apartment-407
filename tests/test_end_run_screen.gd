class_name TestEndRunScreen
extends RefCounted

## Automated test suite for TASK-016's UI wiring: the End Run screen appears
## automatically at 06:00, shows the evaluated summary, and its three replay
## controls (Replay Same Seed / New Seed / Run Again) behave as specified.

const MainScene = preload("res://scenes/main.tscn")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_end_run_screen_appears_on_completion())
	results.append(test_end_run_screen_shows_want_never_believe())
	results.append(test_replay_same_seed_keeps_seed_and_hides_panel())
	results.append(test_new_seed_changes_seed())
	results.append(test_run_again_reopens_setup_paused())
	return results

## Force the clock straight to 06:00 in one call (avoids ticking the full
## night), which still fires the same clock.simulation_completed signal chain
## that a real run relies on.
static func _fast_forward_to_completion(runner: SimulationRunner) -> void:
	runner.set_speed_multiplier(4.0)
	runner.get_clock().advance(200.0)

static func test_end_run_screen_appears_on_completion() -> Dictionary:
	var test_name = "test_end_run_screen_appears_on_completion"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI
	runner._ready()
	ui.bind_runner(runner)

	if ui.end_run_panel.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "End run panel should be hidden before the run completes"}

	_fast_forward_to_completion(runner)

	if not ui.end_run_panel.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "End run panel did not appear after simulation_completed"}

	if ui.end_run_timeline_text.text.is_empty():
		main.free()
		return {"name": test_name, "passed": false, "error": "Causal timeline text was left empty"}

	main.free()
	return {"name": test_name, "passed": true}

static func test_end_run_screen_shows_want_never_believe() -> Dictionary:
	var test_name = "test_end_run_screen_shows_want_never_believe"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI
	runner._ready()
	ui.bind_runner(runner)

	_fast_forward_to_completion(runner)

	var text: String = ui.end_run_directives_text.text
	for token in ["[b]WANT[/b]", "[b]NEVER[/b]", "[b]BELIEVE[/b]"]:
		if not (token in text):
			main.free()
			return {"name": test_name, "passed": false, "error": "Directives summary missing '%s': %s" % [token, text]}

	main.free()
	return {"name": test_name, "passed": true}

static func test_replay_same_seed_keeps_seed_and_hides_panel() -> Dictionary:
	var test_name = "test_replay_same_seed_keeps_seed_and_hides_panel"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI
	runner._ready()
	ui.bind_runner(runner)

	var original_seed: int = runner.get_seed()
	_fast_forward_to_completion(runner)

	ui._on_replay_same_seed_pressed()

	if ui.end_run_panel.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "End run panel should hide after Replay Same Seed"}
	if runner.get_seed() != original_seed:
		main.free()
		return {"name": test_name, "passed": false, "error": "Seed changed after Replay Same Seed: %d -> %d" % [original_seed, runner.get_seed()]}
	if runner.get_clock().is_finished():
		main.free()
		return {"name": test_name, "passed": false, "error": "Clock should have reset back to 18:00"}

	main.free()
	return {"name": test_name, "passed": true}

static func test_new_seed_changes_seed() -> Dictionary:
	var test_name = "test_new_seed_changes_seed"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI
	runner._ready()
	ui.bind_runner(runner)

	var original_seed: int = runner.get_seed()
	_fast_forward_to_completion(runner)

	ui._on_new_seed_pressed()

	if ui.end_run_panel.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "End run panel should hide after New Seed"}
	if runner.get_seed() == original_seed:
		main.free()
		return {"name": test_name, "passed": false, "error": "Seed did not change after New Seed"}

	main.free()
	return {"name": test_name, "passed": true}

static func test_run_again_reopens_setup_paused() -> Dictionary:
	var test_name = "test_run_again_reopens_setup_paused"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI
	runner._ready()
	ui.bind_runner(runner)

	_fast_forward_to_completion(runner)
	ui._on_run_again_pressed()

	if ui.end_run_panel.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "End run panel should hide after Run Again"}
	if not ui.setup_panel.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "Setup panel should reopen after Run Again"}
	if not runner.get_clock().is_paused():
		main.free()
		return {"name": test_name, "passed": false, "error": "Simulation should be paused while the setup panel is open"}

	main.free()
	return {"name": test_name, "passed": true}
