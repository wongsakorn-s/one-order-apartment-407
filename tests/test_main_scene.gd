class_name TestMainScene
extends RefCounted

## Integration test verifying Main scene, SimulationRunner, and MainUI binding.

const MainScene = preload("res://scenes/main.tscn")

static func run_all(_tree: SceneTree = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_main_scene_instantiation_and_wiring())
	results.append(_test_ui_interactions())
	return results

static func _test_main_scene_instantiation_and_wiring() -> Dictionary:
	var main = MainScene.instantiate()
	if main == null:
		return {"name": "test_main_scene_instantiation_and_wiring", "passed": false, "error": "Failed to instantiate Main scene"}

	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI
	var world: WorldView = main.get_node_or_null("WorldView") as WorldView

	if runner == null:
		main.free()
		return {"name": "test_main_scene_instantiation_and_wiring", "passed": false, "error": "SimulationRunner child node not found"}
	if ui == null:
		main.free()
		return {"name": "test_main_scene_instantiation_and_wiring", "passed": false, "error": "MainUI child node not found"}
	if world == null:
		main.free()
		return {"name": "test_main_scene_instantiation_and_wiring", "passed": false, "error": "WorldView child node not found"}

	# Initialize runner & ui
	runner._ready()
	ui.bind_runner(runner)

	var time_label: Label = ui.get_node_or_null("%TimeLabel") as Label
	var seed_label: Label = ui.get_node_or_null("%SeedLabel") as Label

	if time_label == null or not time_label.text.begins_with("18:00"):
		var text = time_label.text if time_label != null else "null"
		main.free()
		return {"name": "test_main_scene_instantiation_and_wiring", "passed": false, "error": "Initial time label expected to start with 18:00, got %s" % text}

	var expected_seed_text = "Seed: %d" % runner.get_seed()
	if seed_label == null or seed_label.text != expected_seed_text:
		var text = seed_label.text if seed_label != null else "null"
		main.free()
		return {"name": "test_main_scene_instantiation_and_wiring", "passed": false, "error": "Expected seed label '%s', got '%s'" % [expected_seed_text, text]}

	main.free()
	return {"name": "test_main_scene_instantiation_and_wiring", "passed": true}

static func _test_ui_interactions() -> Dictionary:
	var main = MainScene.instantiate()
	if main == null:
		return {"name": "test_ui_interactions", "passed": false, "error": "Failed to instantiate Main scene"}

	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI

	if runner == null or ui == null:
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Failed to find runner or ui"}

	runner._ready()
	ui.bind_runner(runner)

	var pause_btn: Button = ui.get_node_or_null("%PauseButton") as Button
	var clock = runner.get_clock()

	if pause_btn == null or clock == null:
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Failed to find pause button or clock"}

	# Pause
	ui._on_pause_pressed()
	if not clock.is_paused():
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Pressing pause did not pause clock"}
	if pause_btn.text != "Resume":
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Pause button text is not Resume: %s" % pause_btn.text}

	# Resume
	ui._on_pause_pressed()
	if clock.is_paused():
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Pressing resume did not resume clock"}

	# Speed 2x
	ui._on_speed_pressed(2.0)
	if not is_equal_approx(clock.get_speed_multiplier(), 2.0):
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Speed 2x button failed"}

	# Speed 4x
	ui._on_speed_pressed(4.0)
	if not is_equal_approx(clock.get_speed_multiplier(), 4.0):
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Speed 4x button failed"}

	# Speed 1x
	ui._on_speed_pressed(1.0)
	if not is_equal_approx(clock.get_speed_multiplier(), 1.0):
		main.free()
		return {"name": "test_ui_interactions", "passed": false, "error": "Speed 1x button failed"}

	main.free()
	return {"name": "test_ui_interactions", "passed": true}

