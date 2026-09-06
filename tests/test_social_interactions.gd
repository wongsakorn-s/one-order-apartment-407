class_name TestSocialInteractions
extends RefCounted

## Automated test suite for TASK-012: Social Interactions.
## Validates:
## 1. NPCs can ask and answer questions (truth / lie / refuse / unknown outcomes).
## 2. NPCs can share known facts deliberately (ShareInformationAction).
## 3. NPCs can lie.
## 4. Lies create false beliefs, never mutate the liar's own true belief.
## 5. Social interactions update relationships.
## 6. Information can propagate across several NPCs.
## 7. Personality (honesty/greed) and relationships (trust/suspicion) shape outcomes.
## 8. NEVER never_lie penalizes the Lie action like other prohibited behaviors.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const AskQuestionActionClass = preload("res://scripts/actions/ask_question_action.gd")
const ShareInformationActionClass = preload("res://scripts/actions/share_information_action.gd")
const LieActionClass = preload("res://scripts/actions/lie_action.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")
const DirectiveCatalogClass = preload("res://scripts/directives/directive_catalog.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_ask_question_truthful_answer())
	results.append(test_ask_question_refuses_when_suspicious())
	results.append(test_ask_question_unknown_when_target_has_no_belief())
	results.append(test_ask_question_lies_when_dishonest_and_greedy())
	results.append(test_share_information_transfers_fact_and_builds_trust())
	results.append(test_share_information_precondition_fails_with_nothing_to_share())
	results.append(test_lie_creates_false_belief_without_mutating_truth())
	results.append(test_lie_precondition_fails_without_sensitive_belief())
	results.append(test_never_lie_directive_penalizes_lie_action())
	results.append(test_personality_influences_lie_utility_score())
	results.append(test_information_propagates_across_multiple_npcs())
	results.append(test_utility_ai_generates_new_social_action_candidates())
	return results

static func test_ask_question_truthful_answer() -> Dictionary:
	var test_name = "test_ask_question_truthful_answer"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	target.set_personality_trait("honesty", 0.9)
	target.set_personality_trait("greed", 0.1)
	target.get_relationship(actor.id).set_value("trust", 0.9)
	target.get_relationship(actor.id).set_value("suspicion", 0.05)
	target.set_belief("room_407", "status", "under_maintenance", 0.9, "self", 0.0)

	var action = AskQuestionActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}

	if not action.start(context):
		return {"name": test_name, "passed": false, "error": "AskQuestion failed to start: %s" % action.failure_reason}
	action.tick(3.0, context)

	if action.metadata.get("outcome", "") != "truth":
		return {"name": test_name, "passed": false, "error": "Expected outcome 'truth', got '%s'" % action.metadata.get("outcome", "")}

	var received = actor.get_belief("room_407", "status")
	if received == null or received.value != "under_maintenance":
		return {"name": test_name, "passed": false, "error": "Actor did not receive the truthful answer"}
	if received.source != target.id:
		return {"name": test_name, "passed": false, "error": "Received belief source should be target, got '%s'" % received.source}

	# Answering honestly builds a small amount of trust from target toward actor.
	if target.get_relationship_value(actor.id, "trust") <= 0.9:
		return {"name": test_name, "passed": false, "error": "Expected target's trust in actor to increase after truthful answer"}

	return {"name": test_name, "passed": true}

static func test_ask_question_refuses_when_suspicious() -> Dictionary:
	var test_name = "test_ask_question_refuses_when_suspicious"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	target.get_relationship(actor.id).set_value("trust", 0.05)
	target.get_relationship(actor.id).set_value("suspicion", 0.85)
	target.set_belief("room_407", "status", "hiding_stolen_goods", 0.9, "self", 0.0)

	var initial_actor_trust: float = actor.get_relationship_value(target.id, "trust")

	var action = AskQuestionActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}
	action.start(context)
	action.tick(3.0, context)

	if action.metadata.get("outcome", "") != "refuse":
		return {"name": test_name, "passed": false, "error": "Expected outcome 'refuse', got '%s'" % action.metadata.get("outcome", "")}

	if actor.has_belief("room_407", "status"):
		return {"name": test_name, "passed": false, "error": "Actor should not have received any belief after a refusal"}

	if actor.get_relationship_value(target.id, "trust") >= initial_actor_trust:
		return {"name": test_name, "passed": false, "error": "Expected actor's trust in target to drop after being refused"}

	return {"name": test_name, "passed": true}

static func test_ask_question_unknown_when_target_has_no_belief() -> Dictionary:
	var test_name = "test_ask_question_unknown_when_target_has_no_belief"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	target.get_relationship(actor.id).set_value("trust", 0.6)
	target.get_relationship(actor.id).set_value("suspicion", 0.1)
	# Target deliberately holds no belief about room_407 (the fallback topic).

	var action = AskQuestionActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}
	action.start(context)
	action.tick(3.0, context)

	if action.metadata.get("outcome", "") != "unknown":
		return {"name": test_name, "passed": false, "error": "Expected outcome 'unknown', got '%s'" % action.metadata.get("outcome", "")}
	if actor.has_belief("room_407", "status"):
		return {"name": test_name, "passed": false, "error": "Actor should not have gained a belief when target didn't know"}

	return {"name": test_name, "passed": true}

static func test_ask_question_lies_when_dishonest_and_greedy() -> Dictionary:
	var test_name = "test_ask_question_lies_when_dishonest_and_greedy"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	target.set_personality_trait("honesty", 0.1)
	target.set_personality_trait("greed", 0.9)
	target.get_relationship(actor.id).set_value("trust", 0.1)
	target.get_relationship(actor.id).set_value("suspicion", 0.1)
	target.set_belief("room_407", "status", "hiding_stolen_goods", 0.9, "self", 0.0)

	var action = AskQuestionActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}
	action.start(context)
	action.tick(3.0, context)

	if action.metadata.get("outcome", "") != "lie":
		return {"name": test_name, "passed": false, "error": "Expected outcome 'lie', got '%s'" % action.metadata.get("outcome", "")}

	var received = actor.get_belief("room_407", "status")
	if received == null:
		return {"name": test_name, "passed": false, "error": "Actor did not receive any belief from the lie"}
	if received.value == "hiding_stolen_goods":
		return {"name": test_name, "passed": false, "error": "Lie must not transmit the true value"}

	# Target's own true belief must remain untouched by their own lie.
	if target.get_belief_value("room_407", "status") != "hiding_stolen_goods":
		return {"name": test_name, "passed": false, "error": "Target's own true belief was corrupted by lying"}

	return {"name": test_name, "passed": true}

static func test_share_information_transfers_fact_and_builds_trust() -> Dictionary:
	var test_name = "test_share_information_transfers_fact_and_builds_trust"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	actor.set_belief("npc_marcus", "location", "rooftop", 0.9, "self", 0.0)
	actor.get_relationship(target.id) # ensure relationship exists
	target.get_relationship(actor.id).set_value("trust", 0.7)
	target.get_relationship(actor.id).set_value("suspicion", 0.1)

	var initial_trust: float = target.get_relationship_value(actor.id, "trust")

	var action = ShareInformationActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}

	if not action.start(context):
		return {"name": test_name, "passed": false, "error": "ShareInformation failed to start: %s" % action.failure_reason}
	action.tick(3.0, context)

	var received = target.get_belief("npc_marcus", "location")
	if received == null or received.value != "rooftop":
		return {"name": test_name, "passed": false, "error": "Target did not receive the shared fact"}
	if received.source != actor.id:
		return {"name": test_name, "passed": false, "error": "Shared fact should record actor as source, got '%s'" % received.source}

	if target.get_relationship_value(actor.id, "trust") <= initial_trust:
		return {"name": test_name, "passed": false, "error": "Expected target's trust in actor to increase after voluntary disclosure"}

	return {"name": test_name, "passed": true}

static func test_share_information_precondition_fails_with_nothing_to_share() -> Dictionary:
	var test_name = "test_share_information_precondition_fails_with_nothing_to_share"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	# actor has no external beliefs at all (fresh character).

	var action = ShareInformationActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}

	if action.can_execute(context):
		return {"name": test_name, "passed": false, "error": "ShareInformation should be impossible when actor has nothing to share"}

	return {"name": test_name, "passed": true}

static func test_lie_creates_false_belief_without_mutating_truth() -> Dictionary:
	var test_name = "test_lie_creates_false_belief_without_mutating_truth"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	actor.set_belief("self", "stole_item_from", target.id, 1.0, "self", 0.0)
	target.get_relationship(actor.id).set_value("trust", 0.5)
	target.get_relationship(actor.id).set_value("suspicion", 0.2)

	var action = LieActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}

	if not action.start(context):
		return {"name": test_name, "passed": false, "error": "Lie failed to start: %s" % action.failure_reason}
	action.tick(3.0, context)

	var received = target.get_belief(actor.id, "stole_item_from")
	if received == null:
		return {"name": test_name, "passed": false, "error": "Target did not receive the fabricated belief"}
	if received.value == target.id:
		return {"name": test_name, "passed": false, "error": "Lie must not transmit the true (incriminating) value"}
	if received.source != actor.id:
		return {"name": test_name, "passed": false, "error": "Fabricated belief should record actor as its source"}

	# The actor's own private true belief must remain unchanged: a lie mutates
	# only the listener's belief store, never the world/actor's own truth.
	if actor.get_belief_value("self", "stole_item_from") != target.id:
		return {"name": test_name, "passed": false, "error": "Lying corrupted the actor's own true belief"}

	return {"name": test_name, "passed": true}

static func test_lie_precondition_fails_without_sensitive_belief() -> Dictionary:
	var test_name = "test_lie_precondition_fails_without_sensitive_belief"

	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	# actor holds no sensitive self-belief to lie about.

	var action = LieActionClass.new(actor.id, target.id, 3.0)
	var context = {"characters": {actor.id: actor, target.id: target}, "sim_time": 10.0}

	if action.can_execute(context):
		return {"name": test_name, "passed": false, "error": "Lie should be impossible when actor has nothing sensitive to hide"}

	return {"name": test_name, "passed": true}

static func test_never_lie_directive_penalizes_lie_action() -> Dictionary:
	var test_name = "test_never_lie_directive_penalizes_lie_action"

	var world = WorldGraphClass.create_default_apartment()
	var actor = CharacterStateClass.new("char_protagonist", "Alex", "room_101", true)
	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)
	actor.set_belief("self", "hiding_item", "cash", 1.0, "self", 0.0)

	var want_default = DirectiveCatalogClass.get_want("survive_night")
	var never_lie = DirectiveCatalogClass.get_never("never_lie")
	var believe_default = DirectiveCatalogClass.get_belief("everyone_hiding_something")
	actor.set_directives(want_default, never_lie, believe_default)

	var ai = UtilityAIClass.new()
	var context = {"characters": {actor.id: actor, target.id: target}, "world_graph": world, "sim_time": 10.0}
	var lie_action = LieActionClass.new(actor.id, target.id, 5.0)
	var eval = ai.score_action(actor, lie_action, context)

	if not ("never: -15.00" in str(eval.get("explanation", ""))):
		return {"name": test_name, "passed": false, "error": "Expected 'never: -15.00' in explanation, got: %s" % eval.get("explanation", "")}
	if float(eval.get("score", 0.0)) > -5.0:
		return {"name": test_name, "passed": false, "error": "Expected severely negative score for lying under NEVER lie, got %f" % eval.get("score", 0.0)}

	return {"name": test_name, "passed": true}

static func test_personality_influences_lie_utility_score() -> Dictionary:
	var test_name = "test_personality_influences_lie_utility_score"

	var world = WorldGraphClass.create_default_apartment()
	var ai = UtilityAIClass.new()

	var honest_actor = CharacterStateClass.new("npc_honest", "Honest", "room_101", false)
	honest_actor.set_personality_trait("honesty", 0.95)
	honest_actor.set_personality_trait("greed", 0.1)
	honest_actor.set_belief("self", "hiding_item", "cash", 1.0, "self", 0.0)

	var dishonest_actor = CharacterStateClass.new("npc_dishonest", "Dishonest", "room_101", false)
	dishonest_actor.set_personality_trait("honesty", 0.1)
	dishonest_actor.set_personality_trait("greed", 0.9)
	dishonest_actor.set_belief("self", "hiding_item", "cash", 1.0, "self", 0.0)

	var target = CharacterStateClass.new("npc_b", "B", "room_101", false)

	var context_honest = {"characters": {honest_actor.id: honest_actor, target.id: target}, "world_graph": world, "sim_time": 0.0}
	var context_dishonest = {"characters": {dishonest_actor.id: dishonest_actor, target.id: target}, "world_graph": world, "sim_time": 0.0}

	var eval_honest = ai.score_action(honest_actor, LieActionClass.new(honest_actor.id, target.id, 5.0), context_honest)
	var eval_dishonest = ai.score_action(dishonest_actor, LieActionClass.new(dishonest_actor.id, target.id, 5.0), context_dishonest)

	if float(eval_honest.get("score", 0.0)) >= float(eval_dishonest.get("score", 0.0)):
		return {
			"name": test_name, "passed": false,
			"error": "Expected honest character's lie score (%f) to be lower than dishonest character's (%f)" % [eval_honest.get("score", 0.0), eval_dishonest.get("score", 0.0)]
		}

	return {"name": test_name, "passed": true}

static func test_information_propagates_across_multiple_npcs() -> Dictionary:
	var test_name = "test_information_propagates_across_multiple_npcs"

	var char_a = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var char_b = CharacterStateClass.new("npc_b", "B", "room_101", false)
	var char_c = CharacterStateClass.new("npc_c", "C", "room_101", false)

	char_a.set_belief("npc_marcus", "location", "rooftop", 0.95, "self", 0.0)
	char_b.get_relationship(char_a.id).set_value("trust", 0.8)
	char_b.get_relationship(char_a.id).set_value("suspicion", 0.05)
	char_c.get_relationship(char_b.id).set_value("trust", 0.8)
	char_c.get_relationship(char_b.id).set_value("suspicion", 0.05)

	# Hop 1: A -> B
	var share_ab = ShareInformationActionClass.new(char_a.id, char_b.id, 3.0)
	var context_ab = {"characters": {char_a.id: char_a, char_b.id: char_b}, "sim_time": 10.0}
	if not share_ab.start(context_ab):
		return {"name": test_name, "passed": false, "error": "A->B share failed to start: %s" % share_ab.failure_reason}
	share_ab.tick(3.0, context_ab)

	if char_b.get_belief_value("npc_marcus", "location") != "rooftop":
		return {"name": test_name, "passed": false, "error": "B did not receive fact from A"}

	# Hop 2: B -> C
	var share_bc = ShareInformationActionClass.new(char_b.id, char_c.id, 3.0)
	var context_bc = {"characters": {char_b.id: char_b, char_c.id: char_c}, "sim_time": 20.0}
	if not share_bc.start(context_bc):
		return {"name": test_name, "passed": false, "error": "B->C share failed to start: %s" % share_bc.failure_reason}
	share_bc.tick(3.0, context_bc)

	var final_belief = char_c.get_belief("npc_marcus", "location")
	if final_belief == null or final_belief.value != "rooftop":
		return {"name": test_name, "passed": false, "error": "Information failed to propagate from A through B to C"}
	if final_belief.source != char_b.id:
		return {"name": test_name, "passed": false, "error": "C's belief should record B (the immediate teller) as source, got '%s'" % final_belief.source}

	return {"name": test_name, "passed": true}

static func test_utility_ai_generates_new_social_action_candidates() -> Dictionary:
	var test_name = "test_utility_ai_generates_new_social_action_candidates"

	var world = WorldGraphClass.create_default_apartment()
	var ai = UtilityAIClass.new()
	var actor = CharacterStateClass.new("npc_a", "A", "room_101", false)
	var other = CharacterStateClass.new("npc_b", "B", "room_101", false)

	var context = {"characters": {actor.id: actor, other.id: other}, "world_graph": world, "sim_time": 0.0}
	var candidates = ai.generate_candidate_actions(actor, context)

	var found_ids: Dictionary = {}
	for c in candidates:
		found_ids[c.id] = true

	for expected_id in ["ask_question", "share_information", "lie"]:
		if not found_ids.has(expected_id):
			return {"name": test_name, "passed": false, "error": "Candidate actions missing expected id '%s'" % expected_id}

	return {"name": test_name, "passed": true}
