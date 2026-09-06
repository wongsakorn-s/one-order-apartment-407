class_name TestRoom407
extends RefCounted

## Automated test suite for TASK-015: Room 407 Mystery Catalyst.
## Validates:
## 1. Multiple Room 407 configurations exist.
## 2. Same seed reproduces the configuration; different seeds vary.
## 3. Different configurations lead to different information chains.
## 4. Room 407 can occasionally be irrelevant (no scenario, or "irrelevant").
## 5. No hardcoded quest path (generator source has no ending/outcome hooks).
## 6. NPCs can independently interact with Room 407-related state (any
##    investigating character can discover a world-truth item there).
## 7. The protagonist is never assigned Room 407 knowledge/goals/location.

const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const NPCGeneratorClass = preload("res://scripts/generation/npc_generator.gd")
const RelationshipGeneratorClass = preload("res://scripts/generation/relationship_generator.gd")
const SecretGeneratorClass = preload("res://scripts/generation/secret_generator.gd")
const Room407GeneratorClass = preload("res://scripts/generation/room_407_generator.gd")
const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const InvestigateActionClass = preload("res://scripts/actions/investigate_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_multiple_configurations_exist())
	results.append(test_same_seed_reproduces_configuration())
	results.append(test_different_configurations_differ())
	results.append(test_room_407_can_be_irrelevant_or_skipped())
	results.append(test_no_hardcoded_ending_hooks_in_source())
	results.append(test_any_npc_can_independently_discover_item())
	results.append(test_protagonist_never_assigned_room_407_state())
	results.append(test_runner_integration_includes_scenario_in_secrets())
	return results

## Builds a roster continuing the exact same RNG sequence SimulationRunner
## uses (NPCs -> relationships -> secrets), so Room407Generator sees the same
## stream position it would during a real run.
static func _build_roster(seed_val: int) -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(seed_val)

	var npc_gen = NPCGeneratorClass.new()
	var npcs = npc_gen.generate_npcs(rng, graph, "char_protagonist", "Alex")

	var protagonist = CharacterStateClass.new("char_protagonist", "Alex", "room_101", true)
	var all_chars: Array = [protagonist]
	for npc in npcs:
		all_chars.append(npc)

	var rel_gen = RelationshipGeneratorClass.new()
	rel_gen.generate_initial_relationships(rng, all_chars)

	var secret_gen = SecretGeneratorClass.new()
	secret_gen.generate_secrets(rng, all_chars)

	return {"rng": rng, "characters": all_chars, "graph": graph}

static func test_multiple_configurations_exist() -> Dictionary:
	var test_name = "test_multiple_configurations_exist"

	var seen_types: Dictionary = {}
	for seed_val in range(1, 60):
		var fixture = _build_roster(seed_val)
		var gen = Room407GeneratorClass.new()
		var scenario = gen.generate_scenario(fixture["rng"], fixture["characters"], fixture["graph"])
		var type_key: String = scenario.get("type", "none") if not scenario.is_empty() else "none"
		seen_types[type_key] = true

	if seen_types.size() < 4:
		return {"name": test_name, "passed": false, "error": "Expected at least 4 distinct configurations across 59 seeds, got %d: %s" % [seen_types.size(), str(seen_types.keys())]}

	return {"name": test_name, "passed": true}

static func test_same_seed_reproduces_configuration() -> Dictionary:
	var test_name = "test_same_seed_reproduces_configuration"

	var fixture_a = _build_roster(777)
	var gen_a = Room407GeneratorClass.new()
	var scenario_a = gen_a.generate_scenario(fixture_a["rng"], fixture_a["characters"], fixture_a["graph"])

	var fixture_b = _build_roster(777)
	var gen_b = Room407GeneratorClass.new()
	var scenario_b = gen_b.generate_scenario(fixture_b["rng"], fixture_b["characters"], fixture_b["graph"])

	if str(scenario_a) != str(scenario_b):
		return {"name": test_name, "passed": false, "error": "Seed 777 produced different scenarios: %s vs %s" % [str(scenario_a), str(scenario_b)]}

	return {"name": test_name, "passed": true}

static func test_different_configurations_differ() -> Dictionary:
	var test_name = "test_different_configurations_differ"

	var fixture_a = _build_roster(1)
	var gen_a = Room407GeneratorClass.new()
	var scenario_a = gen_a.generate_scenario(fixture_a["rng"], fixture_a["characters"], fixture_a["graph"])

	var fixture_b = _build_roster(2)
	var gen_b = Room407GeneratorClass.new()
	var scenario_b = gen_b.generate_scenario(fixture_b["rng"], fixture_b["characters"], fixture_b["graph"])

	if str(scenario_a) == str(scenario_b):
		return {"name": test_name, "passed": false, "error": "Seeds 1 and 2 produced identical Room 407 scenarios"}

	return {"name": test_name, "passed": true}

static func test_room_407_can_be_irrelevant_or_skipped() -> Dictionary:
	var test_name = "test_room_407_can_be_irrelevant_or_skipped"

	var found_unremarkable: bool = false
	for seed_val in range(1, 60):
		var fixture = _build_roster(seed_val)
		var gen = Room407GeneratorClass.new()
		var scenario = gen.generate_scenario(fixture["rng"], fixture["characters"], fixture["graph"])
		if scenario.is_empty() or scenario.get("type", "") == "irrelevant":
			found_unremarkable = true
			break

	if not found_unremarkable:
		return {"name": test_name, "passed": false, "error": "No seed in [1,59] produced an empty or 'irrelevant' Room 407 outcome"}

	return {"name": test_name, "passed": true}

static func test_no_hardcoded_ending_hooks_in_source() -> Dictionary:
	var test_name = "test_no_hardcoded_ending_hooks_in_source"

	var script_text: String = FileAccess.get_file_as_string("res://scripts/generation/room_407_generator.gd").to_lower()
	var forbidden_terms: Array[String] = ["ending", "win_", "lose_", "force_success", "force_failure", "outcome"]
	for term in forbidden_terms:
		if term in script_text:
			return {"name": test_name, "passed": false, "error": "Room407Generator source unexpectedly references '%s'" % term}

	return {"name": test_name, "passed": true}

static func test_any_npc_can_independently_discover_item() -> Dictionary:
	var test_name = "test_any_npc_can_independently_discover_item"

	var graph = WorldGraphClass.create_default_apartment()
	graph.get_location("room_407").add_item("hidden_cash")

	# A completely unrelated NPC (not the one who "hid" it) investigates.
	var discoverer = CharacterStateClass.new("npc_discoverer", "Discoverer", "room_407", false)
	var context = {"characters": {discoverer.id: discoverer}, "world_graph": graph, "sim_time": 100.0}

	var investigate = InvestigateActionClass.new(discoverer.id, "room_407", 5.0)
	if not investigate.start(context):
		return {"name": test_name, "passed": false, "error": "Investigate failed to start: %s" % investigate.failure_reason}
	investigate.tick(5.0, context)

	if not ("hidden_cash" in discoverer.inventory):
		return {"name": test_name, "passed": false, "error": "Discoverer did not pick up the item found in Room 407"}

	if graph.get_location("room_407").has_item("hidden_cash"):
		return {"name": test_name, "passed": false, "error": "Item was not removed from the location after being found"}

	if discoverer.get_belief_value("room_407", "contained_item") != "hidden_cash":
		return {"name": test_name, "passed": false, "error": "Discoverer did not gain a belief recording what they found"}

	return {"name": test_name, "passed": true}

static func test_protagonist_never_assigned_room_407_state() -> Dictionary:
	var test_name = "test_protagonist_never_assigned_room_407_state"

	for seed_val in range(1, 60):
		var fixture = _build_roster(seed_val)
		var gen = Room407GeneratorClass.new()
		var scenario = gen.generate_scenario(fixture["rng"], fixture["characters"], fixture["graph"])

		if scenario.get("subject_id", "") == "char_protagonist" or scenario.get("target_id", "") == "char_protagonist":
			return {"name": test_name, "passed": false, "error": "Seed %d assigned the protagonist as a Room 407 scenario participant" % seed_val}

		for c in fixture["characters"]:
			if c.is_protagonist and c.current_location == "room_407":
				return {"name": test_name, "passed": false, "error": "Seed %d relocated the protagonist into Room 407" % seed_val}
			if c.is_protagonist and c.has_belief("self", "hiding_from"):
				return {"name": test_name, "passed": false, "error": "Seed %d gave the protagonist Room 407 hiding knowledge" % seed_val}

	return {"name": test_name, "passed": true}

static func test_runner_integration_includes_scenario_in_secrets() -> Dictionary:
	var test_name = "test_runner_integration_includes_scenario_in_secrets"

	# The general secrets list must stay exactly TASK-011's 3-5 range,
	# regardless of whether a Room 407 scenario was also selected.
	var found_any_scenario_seed: bool = false
	for seed_val in [11111, 22222, 33333, 44444, 55555]:
		var runner = SimulationRunnerClass.new()
		runner.initial_seed = seed_val
		runner._init_simulation()

		var secret_count: int = runner.get_secrets().size()
		if secret_count < SecretGeneratorClass.MIN_SECRETS or secret_count > SecretGeneratorClass.MAX_SECRETS:
			runner.free()
			return {"name": test_name, "passed": false, "error": "Seed %d: general secrets count %d outside TASK-011's 3-5 range" % [seed_val, secret_count]}

		var scenario: Dictionary = runner.get_room_407_scenario()
		if not scenario.is_empty():
			found_any_scenario_seed = true
			if not (scenario.get("type", "") in ["hidden_money", "missing_tenant", "secret_meeting", "stolen_goods", "someone_hiding", "abandoned_belongings", "innocent_noise", "irrelevant"]):
				runner.free()
				return {"name": test_name, "passed": false, "error": "Unexpected Room 407 scenario type: %s" % scenario.get("type", "")}

		runner.free()

	if not found_any_scenario_seed:
		return {"name": test_name, "passed": false, "error": "No tested seed produced a room_407_scenario via get_room_407_scenario()"}

	return {"name": test_name, "passed": true}
