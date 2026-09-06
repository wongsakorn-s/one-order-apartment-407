class_name TestRunner
extends SceneTree

## Headless test runner for automated tests.
## Can be executed via: godot_console.exe --headless -s res://tests/test_runner.gd

const TestRandomServiceScript = preload("res://tests/test_random_service.gd")
const TestSimulationClockScript = preload("res://tests/test_simulation_clock.gd")
const TestMainSceneScript = preload("res://tests/test_main_scene.gd")
const TestWorldGraphScript = preload("res://tests/test_world_graph.gd")
const TestCharacterStateScript = preload("res://tests/test_character_state.gd")
const TestNPCGeneratorScript = preload("res://tests/test_npc_generator.gd")
const TestActionsScript = preload("res://tests/test_actions.gd")
const TestUtilityAIScript = preload("res://tests/test_utility_ai.gd")
const TestPlayerDirectivesScript = preload("res://tests/test_player_directives.gd")
const TestRelationshipsScript = preload("res://tests/test_relationships.gd")
const TestMemoriesScript = preload("res://tests/test_memories.gd")

func _init() -> void:
	print("========================================")
	print(" RUNNING AUTOMATED TESTS: TASK-001 - TASK-009")
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

	# 5. Character State Tests (TASK-003)
	print("\n[SUITE] TestCharacterState:")
	var char_results: Array[Dictionary] = TestCharacterStateScript.run_all()
	for res in char_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	# 6. NPC Procedural Generation Tests (TASK-004)
	print("\n[SUITE] TestNPCGenerator:")
	var npc_results: Array[Dictionary] = TestNPCGeneratorScript.run_all()
	for res in npc_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	# 7. Action System Tests (TASK-005)
	print("\n[SUITE] TestActions:")
	var action_results: Array[Dictionary] = TestActionsScript.run_all()
	for res in action_results:
		if res["passed"]:
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res["name"], res.get("error", "unknown error")])
			total_failed += 1

	# 8. Utility AI Decision Tests (TASK-006)
	print("\n[SUITE] TestUtilityAI:")
	var utility_results: Array[Dictionary] = TestUtilityAIScript.run_all()
	for res in utility_results:
		if res.get("passed", false):
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res.get("name", "unknown_test"), res.get("error", "unknown error")])
			total_failed += 1

	# 9. Player Directives Tests (TASK-007)
	print("\n[SUITE] TestPlayerDirectives:")
	var directives_results: Array[Dictionary] = TestPlayerDirectivesScript.run_all()
	for res in directives_results:
		if res.get("passed", false):
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res.get("name", "unknown_test"), res.get("error", "unknown error")])
			total_failed += 1

	# 10. Relationships Tests (TASK-008)
	print("\n[SUITE] TestRelationships:")
	var rel_results: Array[Dictionary] = TestRelationshipsScript.run_all()
	for res in rel_results:
		if res.get("passed", false):
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res.get("name", "unknown_test"), res.get("error", "unknown error")])
			total_failed += 1

	# 11. Memories Tests (TASK-009)
	print("\n[SUITE] TestMemories:")
	var mem_results: Array[Dictionary] = TestMemoriesScript.run_all()
	for res in mem_results:
		if res.get("passed", false):
			print("  [PASS] %s" % res["name"])
			total_passed += 1
		else:
			print("  [FAIL] %s - %s" % [res.get("name", "unknown_test"), res.get("error", "unknown error")])
			total_failed += 1

	print("\n========================================")
	print(" TEST SUMMARY: %d PASSED, %d FAILED" % [total_passed, total_failed])
	print("========================================")

	if total_failed > 0:
		quit(1)
	else:
		quit(0)
