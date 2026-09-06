class_name TestSecrets
extends RefCounted

## Automated test suite for TASK-011: Secrets & Run Setup.
## Validates:
## 1. Each run contains multiple secrets (3-5).
## 2. Same seed reproduces the same secrets; different seeds vary.
## 3. Secrets alter world state consistently (inventory, hidden items, relationships, goals).
## 4. Characters only know secrets they logically should know (asymmetric knowledge).
## 5. Secrets produce actionable motivations that existing systems can act on.
## 6. Secrets do not predetermine a specific ending (no scripted outcome hook exists).

const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const NPCGeneratorClass = preload("res://scripts/generation/npc_generator.gd")
const RelationshipGeneratorClass = preload("res://scripts/generation/relationship_generator.gd")
const SecretGeneratorClass = preload("res://scripts/generation/secret_generator.gd")
const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_run_contains_multiple_secrets())
	results.append(test_same_seed_reproduces_same_secrets())
	results.append(test_different_seed_produces_different_secrets())
	results.append(test_secrets_modify_world_state_consistently())
	results.append(test_characters_only_know_secrets_they_should_know())
	results.append(test_secrets_produce_actionable_motivations())
	results.append(test_secrets_do_not_predetermine_ending())
	results.append(test_runner_integration_generates_secrets())
	return results

## Builds a roster (protagonist + 8 NPCs + relationships) for a given seed without
## touching SimulationRunner, mirroring how NPCGenerator tests set up isolated fixtures.
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

	return {"rng": rng, "characters": all_chars}

static func test_run_contains_multiple_secrets() -> Dictionary:
	var test_name = "test_run_contains_multiple_secrets"
	var fixture = _build_roster(12345)
	var gen = SecretGeneratorClass.new()
	var secrets = gen.generate_secrets(fixture["rng"], fixture["characters"])

	if secrets.size() < SecretGeneratorClass.MIN_SECRETS or secrets.size() > SecretGeneratorClass.MAX_SECRETS:
		return {"name": test_name, "passed": false, "error": "Expected 3-5 secrets, got %d" % secrets.size()}

	for s in secrets:
		if not s.has("id") or not s.has("type") or not s.has("description") or s["description"].is_empty():
			return {"name": test_name, "passed": false, "error": "Malformed secret: %s" % str(s)}

	return {"name": test_name, "passed": true}

static func test_same_seed_reproduces_same_secrets() -> Dictionary:
	var test_name = "test_same_seed_reproduces_same_secrets"

	var fixture_a = _build_roster(777)
	var gen_a = SecretGeneratorClass.new()
	var secrets_a = gen_a.generate_secrets(fixture_a["rng"], fixture_a["characters"])

	var fixture_b = _build_roster(777)
	var gen_b = SecretGeneratorClass.new()
	var secrets_b = gen_b.generate_secrets(fixture_b["rng"], fixture_b["characters"])

	if secrets_a.size() != secrets_b.size():
		return {"name": test_name, "passed": false, "error": "Secret count mismatch: %d vs %d" % [secrets_a.size(), secrets_b.size()]}

	for i in range(secrets_a.size()):
		if str(secrets_a[i]) != str(secrets_b[i]):
			return {"name": test_name, "passed": false, "error": "Secret %d differs: %s vs %s" % [i, str(secrets_a[i]), str(secrets_b[i])]}

	return {"name": test_name, "passed": true}

static func test_different_seed_produces_different_secrets() -> Dictionary:
	var test_name = "test_different_seed_produces_different_secrets"

	var fixture_a = _build_roster(111)
	var gen_a = SecretGeneratorClass.new()
	var secrets_a = gen_a.generate_secrets(fixture_a["rng"], fixture_a["characters"])

	var fixture_b = _build_roster(222)
	var gen_b = SecretGeneratorClass.new()
	var secrets_b = gen_b.generate_secrets(fixture_b["rng"], fixture_b["characters"])

	if str(secrets_a) == str(secrets_b):
		return {"name": test_name, "passed": false, "error": "Different seeds produced identical secrets"}

	return {"name": test_name, "passed": true}

static func test_secrets_modify_world_state_consistently() -> Dictionary:
	var test_name = "test_secrets_modify_world_state_consistently"

	# Isolated scenario: force a stole_item secret deterministically by using a
	# minimal two-character roster so subject/target selection is constrained.
	var subject = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_102", false)
	target.inventory = ["cash"]
	subject.inventory = []

	var gen = SecretGeneratorClass.new()
	var secret = gen._apply_stole_item(RandomServiceClass.new(1), "secret_test_stole", subject, target)

	if secret.is_empty():
		return {"name": test_name, "passed": false, "error": "stole_item secret application returned empty dict"}

	var item: String = str(secret.get("detail", ""))
	if item.is_empty():
		return {"name": test_name, "passed": false, "error": "stole_item secret missing item detail"}

	# World state: item physically left target's inventory.
	if item in target.inventory:
		return {"name": test_name, "passed": false, "error": "Target still has the stolen item in inventory: %s" % item}

	# World state: subject now possesses the item (hidden, not casually visible).
	if item in subject.inventory:
		return {"name": test_name, "passed": false, "error": "Stolen item should be hidden, not in visible inventory"}
	if not subject.has_hidden_item(item):
		return {"name": test_name, "passed": false, "error": "Subject does not actually hold the stolen item as a hidden item"}

	# Subject knows they stole it.
	if subject.get_belief_value("self", "stole_item_from") != target.id:
		return {"name": test_name, "passed": false, "error": "Subject does not know they stole the item"}

	return {"name": test_name, "passed": true}

static func test_characters_only_know_secrets_they_should_know() -> Dictionary:
	var test_name = "test_characters_only_know_secrets_they_should_know"

	var subject = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_102", false)
	target.inventory = ["cash"]

	var gen = SecretGeneratorClass.new()

	# stole_item: target should NOT know who stole it (no belief naming subject as the thief).
	gen._apply_stole_item(RandomServiceClass.new(2), "secret_test_stole_2", subject, target)
	var thief_belief = target.get_belief(subject.id, "stole_item_from")
	if thief_belief != null:
		return {"name": test_name, "passed": false, "error": "Target incorrectly learned the identity of the thief"}
	# Target may know the item itself is missing (their own possession), which is logical.
	if target.get_belief_value("self", "missing_item") == null:
		return {"name": test_name, "passed": false, "error": "Target does not even know their own item is missing"}

	# secretly_likes: target should have zero knowledge of subject's feelings.
	var subject2 = CharacterStateClass.new("npc_c", "C", "room_101", false)
	var target2 = CharacterStateClass.new("npc_d", "D", "room_102", false)
	gen._apply_secretly_likes(RandomServiceClass.new(3), "secret_test_likes", subject2, target2)
	if subject2.get_belief_value("self", "secretly_likes") != target2.id:
		return {"name": test_name, "passed": false, "error": "Subject does not privately know their own feelings"}
	if not target2.get_beliefs().is_empty():
		return {"name": test_name, "passed": false, "error": "Target gained knowledge of a secret they were never told"}

	return {"name": test_name, "passed": true}

static func test_secrets_produce_actionable_motivations() -> Dictionary:
	var test_name = "test_secrets_produce_actionable_motivations"

	var subject = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_102", false)

	var gen = SecretGeneratorClass.new()
	var initial_debt: float = subject.get_relationship_value(target.id, "debt")
	gen._apply_owes_money(RandomServiceClass.new(4), "secret_test_debt", subject, target)
	var new_debt: float = subject.get_relationship_value(target.id, "debt")

	if new_debt <= initial_debt:
		return {"name": test_name, "passed": false, "error": "owes_money secret did not raise directional debt (%f -> %f)" % [initial_debt, new_debt]}

	# planning_to_leave adds an actionable goal that existing goal-relevance scoring understands.
	var subject3 = CharacterStateClass.new("npc_e", "E", "room_101", false)
	gen._apply_planning_to_leave("secret_test_leave", subject3)
	var has_leave_goal: bool = false
	for g in subject3.goals:
		if g is Dictionary and g.get("type", "") == "leave_building":
			has_leave_goal = true
			break
	if not has_leave_goal:
		return {"name": test_name, "passed": false, "error": "planning_to_leave secret did not add an actionable leave_building goal"}

	return {"name": test_name, "passed": true}

## Secrets must not directly script outcomes: verify SecretGenerator only ever
## mutates data (beliefs/relationships/inventory/goals/memories) and never touches
## ending/result state, by checking its public surface contains no ending-related hooks.
static func test_secrets_do_not_predetermine_ending() -> Dictionary:
	var test_name = "test_secrets_do_not_predetermine_ending"

	var script_text: String = FileAccess.get_file_as_string("res://scripts/generation/secret_generator.gd")
	var forbidden_terms: Array[String] = ["ending", "outcome", "win_", "lose_", "force_success", "force_failure"]
	for term in forbidden_terms:
		if term in script_text.to_lower():
			return {"name": test_name, "passed": false, "error": "SecretGenerator source unexpectedly references '%s'" % term}

	return {"name": test_name, "passed": true}

static func test_runner_integration_generates_secrets() -> Dictionary:
	var test_name = "test_runner_integration_generates_secrets"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 54321
	runner._init_simulation()

	var secrets = runner.get_secrets()
	if secrets.size() < SecretGeneratorClass.MIN_SECRETS or secrets.size() > SecretGeneratorClass.MAX_SECRETS:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Runner produced %d secrets, expected 3-5" % secrets.size()}

	# Reproducibility through the full runner pipeline (NPCs + relationships + secrets
	# all share the same seeded RNG stream).
	var runner2 = SimulationRunnerClass.new()
	runner2.initial_seed = 54321
	runner2._init_simulation()
	var secrets2 = runner2.get_secrets()
	runner2.free()

	if str(secrets) != str(secrets2):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Runner secrets not reproducible for identical seed 54321"}

	# Every subject referenced by a secret must be a real character in this run.
	for s in secrets:
		var subject_id: String = str(s.get("subject_id", ""))
		if runner.get_character(subject_id) == null:
			runner.free()
			return {"name": test_name, "passed": false, "error": "Secret references unknown subject '%s'" % subject_id}
		var target_id: String = str(s.get("target_id", ""))
		if not target_id.is_empty() and runner.get_character(target_id) == null:
			runner.free()
			return {"name": test_name, "passed": false, "error": "Secret references unknown target '%s'" % target_id}

	runner.free()
	return {"name": test_name, "passed": true}
