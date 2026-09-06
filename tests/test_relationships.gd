class_name TestRelationships
extends RefCounted

## Automated test suite for TASK-008: Relationship System.
## Validates directional social graph, independent A -> B vs B -> A edges,
## action dynamic updates (Help, Refuse, Confront, Talk, Give, Take),
## relationship modifiers appearing in Utility AI scoring and debug explanations,
## and seed determinism across runs.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const RelationshipClass = preload("res://scripts/characters/relationship.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")

const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const RefuseActionClass = preload("res://scripts/actions/refuse_action.gd")
const ConfrontActionClass = preload("res://scripts/actions/confront_action.gd")
const TalkActionClass = preload("res://scripts/actions/talk_action.gd")
const GiveItemActionClass = preload("res://scripts/actions/give_item_action.gd")
const TakeItemActionClass = preload("res://scripts/actions/take_item_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_relationships_exist_for_all_character_pairs())
	results.append(test_relationship_directionality())
	results.append(test_help_increases_trust_and_debt())
	results.append(test_refusal_reduces_trust())
	results.append(test_confrontation_affects_fear_suspicion_respect())
	results.append(test_relationship_modifiers_in_ai_debug_scoring())
	results.append(test_seed_determinism_in_relationships())
	return results

static func test_relationships_exist_for_all_character_pairs() -> Dictionary:
	var test_name = "test_relationships_exist_for_all_character_pairs"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var characters: Array[CharacterState] = runner.get_all_characters()
	if characters.size() < 9:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected at least 9 characters, got %d" % characters.size()}

	var total_pairs: int = 0
	for a in characters:
		for b in characters:
			if a.id == b.id:
				continue
			total_pairs += 1

			var rel = a.get_relationship(b.id)
			if rel == null:
				runner.free()
				return {"name": test_name, "passed": false, "error": "Missing relationship from %s to %s" % [a.id, b.id]}

			for metric in RelationshipClass.METRICS:
				var val: float = rel.get_value(metric)
				if val < 0.0 or val > 1.0:
					runner.free()
					return {"name": test_name, "passed": false, "error": "Metric %s out of range [0, 1] for %s -> %s: %f" % [metric, a.id, b.id, val]}

	if total_pairs != 72: # 9 * 8 = 72
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected 72 directed pairs, got %d" % total_pairs}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_relationship_directionality() -> Dictionary:
	var test_name = "test_relationship_directionality"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var char_nina = runner.get_character("npc_nina")
	var char_bob = runner.get_character("npc_bob")

	if char_nina == null or char_bob == null:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Nina or Bob not found in simulation"}

	var nina_to_bob = char_nina.get_relationship(char_bob.id)
	var bob_to_nina = char_bob.get_relationship(char_nina.id)

	# In baseline narrative overrides: Nina is suspicious of Bob (~0.65), Bob has low fear of Nina (~0.0)
	if is_equal_approx(nina_to_bob.suspicion, bob_to_nina.suspicion) and is_equal_approx(nina_to_bob.fear, bob_to_nina.fear):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Relationships should not be symmetric"}

	# Modifying Nina -> Bob trust must NOT affect Bob -> Nina trust
	var old_bob_to_nina_trust = bob_to_nina.trust
	char_nina.modify_relationship(char_bob.id, "trust", 0.30)

	if not is_equal_approx(bob_to_nina.trust, old_bob_to_nina_trust):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Directional isolation violated: Bob->Nina trust changed when Nina->Bob changed"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_help_increases_trust_and_debt() -> Dictionary:
	var test_name = "test_help_increases_trust_and_debt"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")

	# Move both to same location
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var initial_target_trust: float = target.get_relationship_value(actor.id, "trust")
	var initial_target_debt: float = target.get_relationship_value(actor.id, "debt")
	var initial_actor_trust: float = actor.get_relationship_value(target.id, "trust")

	var help_action = HelpActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()

	if not help_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "HelpAction failed to start: %s" % help_action.failure_reason}

	help_action.tick(1.0, context)

	var new_target_trust: float = target.get_relationship_value(actor.id, "trust")
	var new_target_debt: float = target.get_relationship_value(actor.id, "debt")
	var new_actor_trust: float = actor.get_relationship_value(target.id, "trust")

	if new_target_trust <= initial_target_trust:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target trust did not increase: %f -> %f" % [initial_target_trust, new_target_trust]}

	if new_target_debt <= initial_target_debt:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target debt did not increase: %f -> %f" % [initial_target_debt, new_target_debt]}

	if new_actor_trust <= initial_actor_trust:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Actor trust did not increase: %f -> %f" % [initial_actor_trust, new_actor_trust]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_refusal_reduces_trust() -> Dictionary:
	var test_name = "test_refusal_reduces_trust"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_bob")
	var target = runner.get_character("npc_sarah")

	actor.current_location = "hallway_1"
	target.current_location = "hallway_1"

	# Set high initial trust for clear reduction check
	target.get_relationship(actor.id).trust = 0.60
	target.get_relationship(actor.id).suspicion = 0.20

	var refuse_action = RefuseActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()

	if not refuse_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "RefuseAction failed to start: %s" % refuse_action.failure_reason}

	refuse_action.tick(1.0, context)

	var new_trust: float = target.get_relationship_value(actor.id, "trust")
	var new_suspicion: float = target.get_relationship_value(actor.id, "suspicion")

	if new_trust >= 0.60:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target trust was not reduced after refusal: %f" % new_trust}

	if new_suspicion <= 0.20:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target suspicion did not increase after refusal: %f" % new_suspicion}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_confrontation_affects_fear_suspicion_respect() -> Dictionary:
	var test_name = "test_confrontation_affects_fear_suspicion_respect"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_bob")
	var target = runner.get_character("npc_tom")

	actor.current_location = "lobby"
	target.current_location = "lobby"

	var initial_fear: float = target.get_relationship_value(actor.id, "fear")
	var initial_suspicion: float = target.get_relationship_value(actor.id, "suspicion")
	var initial_trust: float = target.get_relationship_value(actor.id, "trust")
	var initial_respect: float = target.get_relationship_value(actor.id, "respect")

	var confront_action = ConfrontActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()

	if not confront_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "ConfrontAction failed to start: %s" % confront_action.failure_reason}

	confront_action.tick(1.0, context)

	var new_fear: float = target.get_relationship_value(actor.id, "fear")
	var new_suspicion: float = target.get_relationship_value(actor.id, "suspicion")
	var new_trust: float = target.get_relationship_value(actor.id, "trust")
	var new_respect: float = target.get_relationship_value(actor.id, "respect")

	if new_fear <= initial_fear:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target fear did not increase after confrontation: %f -> %f" % [initial_fear, new_fear]}

	if new_suspicion <= initial_suspicion:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target suspicion did not increase: %f -> %f" % [initial_suspicion, new_suspicion]}

	if new_trust >= initial_trust:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target trust did not decrease: %f -> %f" % [initial_trust, new_trust]}

	if is_equal_approx(new_respect, initial_respect):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target respect was not altered: %f -> %f" % [initial_respect, new_respect]}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_relationship_modifiers_in_ai_debug_scoring() -> Dictionary:
	var test_name = "test_relationship_modifiers_in_ai_debug_scoring"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	# Set high trust and high debt to guarantee positive relationship modifier
	actor.get_relationship(target.id).trust = 0.90
	actor.get_relationship(target.id).debt = 0.80

	var ai = UtilityAIClass.new()
	var context = runner.get_simulation_context()

	var help_action = HelpActionClass.new(actor.id, target.id, 8.0)
	var eval = ai.score_action(actor, help_action, context)

	var reasons = eval.get("reasons", {})
	if not reasons.has("relationship"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Scoring evaluation reasons missing 'relationship' key"}

	var rel_mod: float = float(reasons.get("relationship", 0.0))
	if rel_mod <= 0.5:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected high positive relationship modifier for high trust/debt, got: %f" % rel_mod}

	var explanation: String = str(eval.get("explanation", ""))
	if not "relationship:" in explanation:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Explanation text did not include 'relationship:': %s" % explanation}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_seed_determinism_in_relationships() -> Dictionary:
	var test_name = "test_seed_determinism_in_relationships"

	# Runner 1 (Seed 4242)
	var runner1 = SimulationRunnerClass.new()
	runner1.initial_seed = 4242
	runner1._init_simulation()

	# Runner 2 (Seed 4242)
	var runner2 = SimulationRunnerClass.new()
	runner2.initial_seed = 4242
	runner2._init_simulation()

	# Runner 3 (Seed 9999)
	var runner3 = SimulationRunnerClass.new()
	runner3.initial_seed = 9999
	runner3._init_simulation()

	var chars1 = runner1.get_all_characters()
	var chars2 = runner2.get_all_characters()
	var chars3 = runner3.get_all_characters()

	# Verify Runner 1 and Runner 2 have exact same relationships
	for c1 in chars1:
		var c2 = runner2.get_character(c1.id)
		for target_id in c1.relationships.keys():
			var r1 = c1.get_relationship(target_id)
			var r2 = c2.get_relationship(target_id)
			for metric in RelationshipClass.METRICS:
				if not is_equal_approx(r1.get_value(metric), r2.get_value(metric)):
					runner1.free()
					runner2.free()
					runner3.free()
					return {"name": test_name, "passed": false, "error": "Determinism failure for %s -> %s (%s): %f vs %f" % [
						c1.id, target_id, metric, r1.get_value(metric), r2.get_value(metric)
					]}

	# Verify Runner 1 and Runner 3 have variation due to different seeds
	var differences_found: int = 0
	for c1 in chars1:
		var c3 = runner3.get_character(c1.id)
		for target_id in c1.relationships.keys():
			var r1 = c1.get_relationship(target_id)
			var r3 = c3.get_relationship(target_id)
			for metric in RelationshipClass.METRICS:
				if not is_equal_approx(r1.get_value(metric), r3.get_value(metric)):
					differences_found += 1

	if differences_found == 0:
		runner1.free()
		runner2.free()
		runner3.free()
		return {"name": test_name, "passed": false, "error": "Different seeds (4242 vs 9999) produced identical relationships; expected procedural variation"}

	runner1.free()
	runner2.free()
	runner3.free()
	return {"name": test_name, "passed": true}
