class_name TestKnowledgeBeliefs
extends RefCounted

## Automated test suite for TASK-010: Knowledge & Belief Propagation.
## Validates:
## 1. NPC cannot use undiscovered world truth (subjective navigation vs omniscience)
## 2. Direct observation produces high-confidence knowledge (confidence = 1.0, source = "self")
## 3. Shared information records its source
## 4. Trust affects confidence in received information
## 5. Different NPCs may hold contradictory beliefs
## 6. Debug inspector displays known facts and confidence

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const BeliefClass = preload("res://scripts/characters/belief.gd")
const RelationshipClass = preload("res://scripts/characters/relationship.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const SimulationEventClass = preload("res://scripts/events/simulation_event.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")
const TalkActionClass = preload("res://scripts/actions/talk_action.gd")
const TakeItemActionClass = preload("res://scripts/actions/take_item_action.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_npc_cannot_use_undiscovered_world_truth())
	results.append(test_direct_observation_produces_high_confidence_knowledge())
	results.append(test_shared_information_records_source())
	results.append(test_trust_affects_confidence_in_received_information())
	results.append(test_different_npcs_hold_contradictory_beliefs())
	results.append(test_debug_inspector_displays_known_facts_and_confidence())
	return results

static func test_npc_cannot_use_undiscovered_world_truth() -> Dictionary:
	var test_name = "test_npc_cannot_use_undiscovered_world_truth"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_marcus")

	# World truth: Marcus is far away on the rooftop
	target.current_location = "rooftop"
	actor.current_location = "room_102"

	# Clear any prior beliefs about Marcus's location
	actor.beliefs.erase("npc_marcus:location")
	actor.beliefs.erase("npc_marcus:default_room")

	# Actor has a goal to meet Marcus
	actor.goals = [
		{"type": "meet_character", "target": "npc_marcus", "description": "Find Marcus"}
	]

	var ai = UtilityAIClass.new()
	var wg = runner.world_graph

	# 1. When Nina has NO belief about Marcus's location:
	# Navigation to hallway_1 should NOT get a distance bonus toward rooftop
	var score_no_belief: float = ai._evaluate_movement_goal(actor, "hallway_1", wg, runner._characters)
	# With no belief, Nina only gets communal exploratory weight (priority_weight 2.5 * 0.4 = 1.0)
	if not is_equal_approx(score_no_belief, 1.0):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected communal exploratory score 1.0 without location belief, got %f" % score_no_belief}

	# 2. Give Nina a subjective belief that Marcus is in room_101
	# Moving from room_102 to hallway_1 gets closer to room_101 (dist: 2 -> 1)
	actor.set_belief("npc_marcus", "location", "room_101", 0.9, "self", 10.0)
	var score_believes_101: float = ai._evaluate_movement_goal(actor, "hallway_1", wg, runner._characters)
	if score_believes_101 <= score_no_belief:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected higher score moving toward believed location, got %f vs %f" % [score_believes_101, score_no_belief]}

	# 3. Give Nina a subjective belief that Marcus is in room_102 (same room)
	# Moving away to hallway_1 increases distance from room_102 (dist: 0 -> 1)
	actor.set_belief("npc_marcus", "location", "room_102", 0.9, "self", 20.0)
	var score_believes_same_room: float = ai._evaluate_movement_goal(actor, "hallway_1", wg, runner._characters)
	if score_believes_same_room >= 0.0:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Moving away from believed location should be penalized (< 0.0), got %f" % score_believes_same_room}

	# Marcus remained on the rooftop the entire time — actor's decisions were driven 100% by subjective beliefs
	runner.free()
	return {"name": test_name, "passed": true}

static func test_direct_observation_produces_high_confidence_knowledge() -> Dictionary:
	var test_name = "test_direct_observation_produces_high_confidence_knowledge"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var bystander = runner.get_character("char_protagonist")
	var outside_char = runner.get_character("npc_marcus")

	actor.current_location = "room_102"
	bystander.current_location = "room_102"
	outside_char.current_location = "rooftop"

	var take_action = TakeItemActionClass.new(actor.id, "toolbox", "", 1.0)
	var context = runner.get_simulation_context()

	if not take_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "TakeItemAction failed to start: %s" % take_action.failure_reason}

	take_action.tick(1.0, context)
	var evt = take_action._create_completion_event(context)
	runner._record_event(evt)

	# Direct observer (bystander in same room) MUST acquire belief with confidence = 1.0 and source = "self"
	var bystander_loc_belief = bystander.get_belief(actor.id, "location")
	if bystander_loc_belief == null:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Bystander in same room did not gain location belief"}

	if bystander_loc_belief.value != "room_102":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected observed location 'room_102', got '%s'" % bystander_loc_belief.value}

	if not is_equal_approx(bystander_loc_belief.confidence, 1.0):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Direct observation must have confidence 1.0, got %f" % bystander_loc_belief.confidence}

	if bystander_loc_belief.source != "self":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Direct observation must have source 'self', got '%s'" % bystander_loc_belief.source}

	# Outside character on rooftop must NOT receive unobserved event knowledge
	var outside_action_belief = outside_char.get_belief(actor.id, "last_action")
	if outside_action_belief != null:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Outside character gained knowledge of unobserved event"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_shared_information_records_source() -> Dictionary:
	var test_name = "test_shared_information_records_source"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var speaker = runner.get_character("npc_nina")
	var listener = runner.get_character("npc_tom")

	speaker.current_location = "room_102"
	listener.current_location = "room_102"

	# Give speaker a high-confidence belief that listener does NOT have
	listener.beliefs.erase("room_407:status")
	speaker.set_belief("room_407", "status", "strange_scratching", 0.95, "self", 100.0)

	# Establish trust from listener to speaker
	var rel = listener.get_relationship(speaker.id)
	if rel != null:
		rel.set_value("trust", 0.85)
		rel.set_value("suspicion", 0.05)

	var talk_action = TalkActionClass.new(speaker.id, listener.id, 2.0)
	var context = runner.get_simulation_context()

	if not talk_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "TalkAction failed to start: %s" % talk_action.failure_reason}

	talk_action.tick(2.0, context)
	var evt = talk_action._create_completion_event(context)
	runner._record_event(evt)

	# Verify listener received the belief
	var received = listener.get_belief("room_407", "status")
	if received == null:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Listener did not receive belief about room_407"}

	if received.value != "strange_scratching":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected received value 'strange_scratching', got '%s'" % received.value}

	# Source must be the speaker's ID
	if received.source != speaker.id:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected source '%s', got '%s'" % [speaker.id, received.source]}

	# Action metadata should record the shared facts
	if not talk_action.metadata.has("shared_facts") or talk_action.metadata["shared_facts"].is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "TalkAction metadata missing shared_facts"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_trust_affects_confidence_in_received_information() -> Dictionary:
	var test_name = "test_trust_affects_confidence_in_received_information"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var speaker = runner.get_character("npc_nina")
	var listener_high_trust = runner.get_character("npc_tom")
	var listener_low_trust = runner.get_character("char_protagonist")

	speaker.current_location = "room_102"
	listener_high_trust.current_location = "room_102"
	listener_low_trust.current_location = "room_102"

	# High trust listener: trust = 0.90, suspicion = 0.05
	var rel_high = listener_high_trust.get_relationship(speaker.id)
	if rel_high != null:
		rel_high.set_value("trust", 0.90)
		rel_high.set_value("suspicion", 0.05)

	# Low trust listener: trust = 0.20, suspicion = 0.80
	var rel_low = listener_low_trust.get_relationship(speaker.id)
	if rel_low != null:
		rel_low.set_value("trust", 0.20)
		rel_low.set_value("suspicion", 0.80)

	# Speaker shares fact
	speaker.set_belief("rumor", "conspiracy", "landlord_scheme", 1.0, "self", 10.0)

	var talk1 = TalkActionClass.new(speaker.id, listener_high_trust.id, 2.0)
	var talk2 = TalkActionClass.new(speaker.id, listener_low_trust.id, 2.0)

	var context = runner.get_simulation_context()
	talk1.start(context)
	talk1.tick(2.0, context)
	talk2.start(context)
	talk2.tick(2.0, context)

	var b_high = listener_high_trust.get_belief("rumor", "conspiracy")
	var b_low = listener_low_trust.get_belief("rumor", "conspiracy")

	if b_high == null or b_low == null:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Beliefs were not received by both listeners"}

	if b_high.confidence <= b_low.confidence:
		runner.free()
		return {"name": test_name, "passed": false, "error": "High trust confidence (%f) must be strictly greater than low trust confidence (%f)" % [b_high.confidence, b_low.confidence]}

	# The difference should be significant (high trust ~ 0.88, low trust ~ 0.13)
	if (b_high.confidence - b_low.confidence) < 0.4:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Confidence gap between high and low trust is too small: %f" % (b_high.confidence - b_low.confidence)}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_different_npcs_hold_contradictory_beliefs() -> Dictionary:
	var test_name = "test_different_npcs_hold_contradictory_beliefs"

	var char_a = CharacterStateClass.new("char_alex", "Alex", "room_101")
	var char_b = CharacterStateClass.new("npc_elena", "Elena", "office")

	# Alex believes room 407 is a dangerous locked secret
	char_a.set_belief("room_407", "status", "dangerous_anomaly", 0.95, "self", 50.0)

	# Elena believes room 407 is just unoccupied and undergoing maintenance
	char_b.set_belief("room_407", "status", "under_maintenance", 0.80, "self", 20.0)

	if char_a.get_belief_value("room_407", "status") != "dangerous_anomaly":
		return {"name": test_name, "passed": false, "error": "Alex's belief value mismatch"}

	if char_b.get_belief_value("room_407", "status") != "under_maintenance":
		return {"name": test_name, "passed": false, "error": "Elena's belief value mismatch"}

	if not is_equal_approx(char_a.get_belief("room_407", "status").confidence, 0.95):
		return {"name": test_name, "passed": false, "error": "Alex's belief confidence mismatch"}

	if not is_equal_approx(char_b.get_belief("room_407", "status").confidence, 0.80):
		return {"name": test_name, "passed": false, "error": "Elena's belief confidence mismatch"}

	# Serialization test: both retain distinct beliefs when serialized
	var dict_a = char_a.to_dict()
	var dict_b = char_b.to_dict()

	var beliefs_a: Dictionary = dict_a.get("beliefs", {})
	var beliefs_b: Dictionary = dict_b.get("beliefs", {})

	if not beliefs_a.has("room_407:status") or beliefs_a["room_407:status"]["value"] != "dangerous_anomaly":
		return {"name": test_name, "passed": false, "error": "Serialized Alex belief value mismatch"}

	if not beliefs_b.has("room_407:status") or beliefs_b["room_407:status"]["value"] != "under_maintenance":
		return {"name": test_name, "passed": false, "error": "Serialized Elena belief value mismatch"}

	# Belief reconstruction test via Belief.from_dict
	var restored_b_a = BeliefClass.new()
	restored_b_a.from_dict(beliefs_a["room_407:status"])
	var restored_b_b = BeliefClass.new()
	restored_b_b.from_dict(beliefs_b["room_407:status"])

	if restored_b_a.value != "dangerous_anomaly" or not is_equal_approx(restored_b_a.confidence, 0.95):
		return {"name": test_name, "passed": false, "error": "Restored Alex belief mismatch"}

	if restored_b_b.value != "under_maintenance" or not is_equal_approx(restored_b_b.confidence, 0.80):
		return {"name": test_name, "passed": false, "error": "Restored Elena belief mismatch"}

	return {"name": test_name, "passed": true}

static func test_debug_inspector_displays_known_facts_and_confidence() -> Dictionary:
	var test_name = "test_debug_inspector_displays_known_facts_and_confidence"

	var char_state = CharacterStateClass.new("npc_nina", "Nina", "room_102")
	char_state.clear_memories()
	char_state.beliefs.clear()

	char_state.set_belief("room_407", "status", "locked", 0.95, "self", 10.0)
	char_state.set_belief("npc_marcus", "location", "courtyard", 0.60, "npc_tom", 25.0)

	var summary = char_state.get_debug_summary()

	if not "[Beliefs & Knowledge (2)]" in summary:
		return {"name": test_name, "passed": false, "error": "Summary missing '[Beliefs & Knowledge (2)]' header: %s" % summary}

	if not "room_407:status = locked (Conf: 0.95, Src: self)" in summary:
		return {"name": test_name, "passed": false, "error": "Summary missing formatted room_407 belief: %s" % summary}

	if not "npc_marcus:location = courtyard (Conf: 0.60, Src: npc_tom)" in summary:
		return {"name": test_name, "passed": false, "error": "Summary missing formatted Marcus belief: %s" % summary}

	return {"name": test_name, "passed": true}
