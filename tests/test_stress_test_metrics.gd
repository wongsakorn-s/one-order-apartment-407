class_name TestStressTestMetrics
extends RefCounted

## Automated tests for TASK-018's StressTestMetrics collector: verifies the
## metric extraction logic itself (fast, deterministic, small-scale) rather
## than running the full 50-seed stress test as part of the normal suite --
## that's invoked separately as a developer diagnostic via
## res://scripts/tools/stress_test_runner.gd.

const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const StressTestMetricsClass = preload("res://scripts/tools/stress_test_metrics.gd")
const TalkActionClass = preload("res://scripts/actions/talk_action.gd")
const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const LieActionClass = preload("res://scripts/actions/lie_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_collect_counts_conversations_and_interactions())
	results.append(test_collect_counts_lies())
	results.append(test_collect_tracks_relationship_changes())
	results.append(test_signature_reflects_event_order())
	results.append(test_primary_goal_types_excludes_protagonist())
	return results

static func test_collect_counts_conversations_and_interactions() -> Dictionary:
	var test_name = "test_collect_counts_conversations_and_interactions"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var a = runner.get_character("npc_nina")
	var b = runner.get_character("npc_tom")
	a.current_location = "room_102"
	b.current_location = "room_102"

	var context = runner.get_simulation_context()
	var talk = TalkActionClass.new(a.id, b.id, 1.0)
	talk.start(context)
	talk.tick(1.0, context)
	runner._record_event(talk._create_completion_event(context))

	var help = HelpActionClass.new(a.id, b.id, 1.0)
	help.start(context)
	help.tick(1.0, context)
	runner._record_event(help._create_completion_event(context))

	var metrics = StressTestMetricsClass.collect(runner)

	if metrics["conversations"] != 1:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 1 conversation, got %d" % metrics["conversations"]}
	if metrics["interactions"] != 2:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 2 interactions (talk+help), got %d" % metrics["interactions"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_collect_counts_lies() -> Dictionary:
	var test_name = "test_collect_counts_lies"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 42
	runner._init_simulation()

	var a = runner.get_character("npc_bob")
	var b = runner.get_character("npc_sarah")
	a.current_location = "room_103"
	b.current_location = "room_103"
	a.set_belief("self", "hiding_item", "cash", 1.0, "self", 0.0)

	var context = runner.get_simulation_context()
	var lie = LieActionClass.new(a.id, b.id, 1.0)
	if not lie.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Lie failed to start: %s" % lie.failure_reason}
	lie.tick(1.0, context)
	runner._record_event(lie._create_completion_event(context))

	var metrics = StressTestMetricsClass.collect(runner)
	if metrics["lies"] != 1:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 1 lie, got %d" % metrics["lies"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_collect_tracks_relationship_changes() -> Dictionary:
	var test_name = "test_collect_tracks_relationship_changes"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 777
	runner._init_simulation()

	var a = runner.get_character("npc_nina")
	var b = runner.get_character("npc_tom")
	a.current_location = "room_102"
	b.current_location = "room_102"

	var context = runner.get_simulation_context()
	var help = HelpActionClass.new(a.id, b.id, 1.0)
	help.start(context)
	help.tick(1.0, context)
	runner._record_event(help._create_completion_event(context))

	var metrics = StressTestMetricsClass.collect(runner)
	if metrics["relationship_changes"] < 1:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected at least 1 relationship change, got %d" % metrics["relationship_changes"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_signature_reflects_event_order() -> Dictionary:
	var test_name = "test_signature_reflects_event_order"

	var metrics_a: Dictionary = {"event_type_sequence": ["talk", "help", "confront"]}
	var metrics_b: Dictionary = {"event_type_sequence": ["talk", "help", "confront"]}
	var metrics_c: Dictionary = {"event_type_sequence": ["confront", "help", "talk"]}

	if StressTestMetricsClass.signature(metrics_a) != StressTestMetricsClass.signature(metrics_b):
		return {"name": test_name, "passed": false, "error": "Identical event sequences produced different signatures"}
	if StressTestMetricsClass.signature(metrics_a) == StressTestMetricsClass.signature(metrics_c):
		return {"name": test_name, "passed": false, "error": "Different event orderings produced the same signature"}

	return {"name": test_name, "passed": true}

static func test_primary_goal_types_excludes_protagonist() -> Dictionary:
	var test_name = "test_primary_goal_types_excludes_protagonist"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 5050
	runner._init_simulation()

	var metrics = StressTestMetricsClass.collect(runner)
	var goal_types: Array = metrics["primary_goal_types"]

	if goal_types.size() != 8:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 8 NPC primary goal types (protagonist excluded), got %d" % goal_types.size()}

	runner.free()
	return {"name": test_name, "passed": true}
