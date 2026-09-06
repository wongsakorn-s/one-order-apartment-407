class_name TestRunEvaluator
extends RefCounted

## Automated test suite for TASK-016: Run Ending & Causal Timeline.
## Validates RunEvaluator: WANT success/partial/failure, NEVER respected/
## violated, BELIEVE narrative (not pass/fail), discovered secrets, major
## relationships/memories, and the causal timeline.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const RunEvaluatorClass = preload("res://scripts/simulation/run_evaluator.gd")
const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const ConfrontActionClass = preload("res://scripts/actions/confront_action.gd")
const TakeItemActionClass = preload("res://scripts/actions/take_item_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_want_learn_room_407_success_partial_failure())
	results.append(test_want_earn_money_thresholds())
	results.append(test_want_survive_night_degrades_with_confrontations())
	results.append(test_never_steal_detected_as_violated())
	results.append(test_never_respected_when_no_violation())
	results.append(test_believe_is_never_pass_fail())
	results.append(test_discovered_secrets_reflect_actual_knowledge())
	results.append(test_causal_timeline_starts_with_directive_and_is_chronological())
	results.append(test_evaluate_returns_full_schema())
	return results

static func test_want_learn_room_407_success_partial_failure() -> Dictionary:
	var test_name = "test_want_learn_room_407_success_partial_failure"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()
	runner.set_player_directives("learn_room_407", "never_steal", "everyone_hiding_something")
	var protagonist = runner.get_protagonist()

	# Failure: no engagement with room_407 at all.
	protagonist.beliefs.clear()
	protagonist.clear_memories()
	var result_fail = RunEvaluatorClass.evaluate(runner)
	if result_fail["want"]["status"] != "failure":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'failure' with no engagement, got '%s'" % result_fail["want"]["status"]}

	# Partial: protagonist looked into Room 407 (has a memory of being there)
	# but never learned anything beyond the default belief.
	protagonist.beliefs.clear()
	var mem = MemoryClass.new("mem_partial", 100.0, "investigate", [protagonist.id], "room_407", 0.5, 0.1, "", {}, "Alex investigated Room 407")
	protagonist.add_memory(mem)
	var result_partial = RunEvaluatorClass.evaluate(runner)
	if result_partial["want"]["status"] != "partial":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'partial' after investigating without learning, got '%s'" % result_partial["want"]["status"]}

	# Success: protagonist learned something beyond the default "locked" status.
	protagonist.set_belief("room_407", "status", "hiding_stolen_goods", 0.9, "self", 100.0)
	var result_success = RunEvaluatorClass.evaluate(runner)
	if result_success["want"]["status"] != "success":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'success' after learning something, got '%s'" % result_success["want"]["status"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_want_earn_money_thresholds() -> Dictionary:
	var test_name = "test_want_earn_money_thresholds"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 54321
	runner._init_simulation()
	runner.set_player_directives("earn_money", "never_steal", "everyone_hiding_something")
	var protagonist = runner.get_protagonist()

	protagonist.inventory = []
	protagonist.hidden_items = []
	var result_fail = RunEvaluatorClass.evaluate(runner)
	if result_fail["want"]["status"] != "failure":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'failure' with no valuables, got '%s'" % result_fail["want"]["status"]}

	protagonist.inventory = ["cash", "stolen_jewelry"]
	var result_success = RunEvaluatorClass.evaluate(runner)
	if result_success["want"]["status"] != "success":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'success' with 2 valuables, got '%s'" % result_success["want"]["status"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_want_survive_night_degrades_with_confrontations() -> Dictionary:
	var test_name = "test_want_survive_night_degrades_with_confrontations"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 999
	runner._init_simulation()
	runner.set_player_directives("survive_night", "never_steal", "everyone_hiding_something")
	var protagonist = runner.get_protagonist()
	var bob = runner.get_character("npc_bob")
	protagonist.current_location = "lobby"
	bob.current_location = "lobby"

	var result_clean = RunEvaluatorClass.evaluate(runner)
	if result_clean["want"]["status"] != "success":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'success' with no confrontations, got '%s'" % result_clean["want"]["status"]}

	var context = runner.get_simulation_context()
	for i in range(2):
		var confront = ConfrontActionClass.new(bob.id, protagonist.id, 1.0)
		confront.start(context)
		confront.tick(1.0, context)
		var evt = confront._create_completion_event(context)
		runner._record_event(evt)

	var result_bad = RunEvaluatorClass.evaluate(runner)
	if result_bad["want"]["status"] != "failure":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 'failure' after 2 confrontations, got '%s'" % result_bad["want"]["status"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_never_steal_detected_as_violated() -> Dictionary:
	var test_name = "test_never_steal_detected_as_violated"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 42
	runner._init_simulation()
	runner.set_player_directives("survive_night", "never_steal", "everyone_hiding_something")
	var protagonist = runner.get_protagonist()
	var nina = runner.get_character("npc_nina")
	protagonist.current_location = "room_102"
	nina.current_location = "room_102"
	if not ("book" in nina.inventory):
		nina.inventory.append("book")

	var context = runner.get_simulation_context()
	var steal = TakeItemActionClass.new(protagonist.id, "book", nina.id, 1.0)
	if not steal.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Setup steal action failed to start: %s" % steal.failure_reason}
	steal.tick(1.0, context)
	var evt = steal._create_completion_event(context)
	runner._record_event(evt)

	var result = RunEvaluatorClass.evaluate(runner)
	if result["never"]["status"] != "violated":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected NEVER status 'violated', got '%s'" % result["never"]["status"]}
	if result["never"]["violating_event_id"].is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "Violation should reference the specific violating event ID"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_never_respected_when_no_violation() -> Dictionary:
	var test_name = "test_never_respected_when_no_violation"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 7
	runner._init_simulation()
	runner.set_player_directives("survive_night", "never_lie", "everyone_hiding_something")

	var result = RunEvaluatorClass.evaluate(runner)
	if result["never"]["status"] != "respected":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected NEVER status 'respected' with no lies, got '%s'" % result["never"]["status"]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_believe_is_never_pass_fail() -> Dictionary:
	var test_name = "test_believe_is_never_pass_fail"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 555
	runner._init_simulation()
	runner.set_player_directives("survive_night", "never_steal", "everyone_hiding_something")

	var result = RunEvaluatorClass.evaluate(runner)
	var believe_result: Dictionary = result["believe"]

	if believe_result.has("status"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "BELIEVE must not have a pass/fail 'status' field"}
	if not believe_result.has("summary") or believe_result["summary"].is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "BELIEVE must have a non-empty narrative summary"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_discovered_secrets_reflect_actual_knowledge() -> Dictionary:
	var test_name = "test_discovered_secrets_reflect_actual_knowledge"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 8080
	runner._init_simulation()

	# Manually inject a controlled "stole_item" secret so the test doesn't
	# depend on which secrets the seed happens to generate.
	var thief = runner.get_character("npc_bob")
	var victim = runner.get_character("npc_nina")
	thief.set_belief("self", "stole_item_from", victim.id, 1.0, "self", 0.0)
	victim.set_belief("self", "missing_item", "crowbar", 0.9, "self", 0.0)

	var injected_secret: Dictionary = {
		"id": "secret_test_stole", "type": "stole_item",
		"subject_id": thief.id, "subject_name": thief.name,
		"target_id": victim.id, "target_name": victim.name,
		"detail": "crowbar",
		"description": "%s secretly stole crowbar from %s." % [thief.name, victim.name]
	}
	var typed_secrets: Array[Dictionary] = [injected_secret]
	runner._secrets = typed_secrets

	var result_before = RunEvaluatorClass.evaluate(runner)
	var found_before: bool = false
	for s in result_before["discovered_secrets"]:
		if s["description"] == injected_secret["description"]:
			found_before = s["discovered"]

	if found_before:
		return {"name": test_name, "passed": false, "error": "Secret should not be marked discovered before anyone else learns it"}

	# Now the victim learns who did it (e.g. via ShareInformation/AskQuestion/Confront elsewhere).
	victim.set_belief(thief.id, "stole_item_from", victim.id, 0.8, "npc_sarah", 100.0)
	var result_after = RunEvaluatorClass.evaluate(runner)
	var found_after: bool = false
	for s in result_after["discovered_secrets"]:
		if s["description"] == injected_secret["description"]:
			found_after = s["discovered"]

	if not found_after:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Secret should be marked discovered once another character holds the belief"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_causal_timeline_starts_with_directive_and_is_chronological() -> Dictionary:
	var test_name = "test_causal_timeline_starts_with_directive_and_is_chronological"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 321
	runner._init_simulation()
	runner.set_player_directives("make_friend", "never_steal", "helping_pays_off")
	var protagonist = runner.get_protagonist()
	var mia = runner.get_character("npc_mia")
	protagonist.current_location = "lobby"
	mia.current_location = "lobby"

	var context = runner.get_simulation_context()
	var help_action = HelpActionClass.new(protagonist.id, mia.id, 1.0)
	help_action.start(context)
	help_action.tick(1.0, context)
	var evt = help_action._create_completion_event(context)
	runner._record_event(evt)

	var result = RunEvaluatorClass.evaluate(runner)
	var timeline: Array = result["causal_timeline"]

	if timeline.is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "Causal timeline is empty"}
	if not timeline[0].begins_with("Player directive:"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "First timeline entry should state the player's directive, got: %s" % timeline[0]}

	var found_help_line: bool = false
	for line in timeline:
		if evt.description in line:
			found_help_line = true
	if not found_help_line:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Timeline missing the recorded help event"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_evaluate_returns_full_schema() -> Dictionary:
	var test_name = "test_evaluate_returns_full_schema"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 246810
	runner._init_simulation()

	var result = RunEvaluatorClass.evaluate(runner)
	for key in ["want", "never", "believe", "protagonist_final_state", "major_relationships", "discovered_secrets", "major_memories", "causal_timeline"]:
		if not result.has(key):
			runner.free()
			return {"name": test_name, "passed": false, "error": "evaluate() result missing key '%s'" % key}

	for key in ["status", "reason", "title"]:
		if not result["want"].has(key):
			runner.free()
			return {"name": test_name, "passed": false, "error": "want result missing key '%s'" % key}

	for key in ["status", "title"]:
		if not result["never"].has(key):
			runner.free()
			return {"name": test_name, "passed": false, "error": "never result missing key '%s'" % key}

	runner.free()
	return {"name": test_name, "passed": true}
