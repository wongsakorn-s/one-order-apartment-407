class_name TestRunner
extends SceneTree

## Headless test runner for automated tests.
## Can be executed via: godot_console.exe --headless -s res://tests/test_runner.gd

const TestRandomServiceScript = preload("res://tests/test_random_service.gd")
const TestSimulationClockScript = preload("res://tests/test_simulation_clock.gd")
const TestMainSceneScript = preload("res://tests/test_main_scene.gd")
const TestWorldGraphScript = preload("res://tests/test_world_graph.gd")

func _init() -> void:
	print("========================================")
	print(" RUNNING AUTOMATED TESTS: TASK-001 & TASK-002")
	print("========================================")

	var total_passed: int = 0
	var total_failed: int = 0

	# 1. RandomService Tests (TASK-001)
	print("\n[SUITE] TestRandomService:")
	var random_results: Array[Dictionary] = TestRandomServiceScript.run_all()
	for res in random_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	# 2. SimulationClock Tests (TASK-001)
	print("\n[SUITE] TestSimulationClock:")
	var clock_results: Array[Dictionary] = TestSimulationClockScript.run_all()
	for res in clock_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	# 3. Main Scene & UI Integration Tests (TASK-001)
	print("\n[SUITE] TestMainScene:")
	var main_results: Array[Dictionary] = TestMainSceneScript.run_all(self)
	for res in main_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	# 4. World Graph Tests (TASK-002)
	print("\n[SUITE] TestWorldGraph:")
	var world_results: Array[Dictionary] = TestWorldGraphScript.run_all()
	for res in world_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	print("\n========================================")
	print(" TEST SUMMARY: %d PASSED, %d FAILED" % [total_passed, total_failed])
	print("========================================")

	if total_failed > 0:
		quit(1)
	else:
		quit(0)
