class_name TestUtilityAI
extends RefCounted

## Automated test suite for TASK-006: Utility AI Decision Making.
## Validates autonomous action selection, personality divergence,
## seed determinism, impossible action filtering, and explainability.

const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")
const UtilityDecisionClass = preload("res://scripts/ai/utility_decision.gd")
const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_npc_selects_and_executes_action_autonomously())
	results.append(test_personality_produces_divergent_preferences())
	results.append(test_seed_determinism_in_decisions())
	results.append(test_ai_filters_impossible_actions())
	results.append(test_debug_candidate_scores_and_explanations())
	results.append(test_simulation_runner_autonomous_loop())
	return results

static func test_npc_selects_and_executes_action_autonomously() -> Dictionary:
	var test_name = "test_npc_selects_and_executes_action_autonomously"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	# Initially before ticking, verify characters exist
	var characters = runner.get_all_characters()
	if characters.is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "No characters spawned"}

	# Force characters to have no active action
	for c in characters:
		c.active_action = null

	# Tick simulation forward by 1 second
	runner._tick_simulation(1.0)

	# Verify characters have selected an active action autonomously
	var characters_with_actions: int = 0
	for c in characters:
		if c.active_action != null:
			characters_with_actions += 1

	runner.free()

	if characters_with_actions < characters.size():
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected all %d characters to autonomously choose actions, but only %d did" % [characters.size(), characters_with_actions]
		}

	return {"name": test_name, "passed": true}

static func test_personality_produces_divergent_preferences() -> Dictionary:
	var test_name = "test_personality_produces_divergent_preferences"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(42)
	var ai = UtilityAIClass.new()

	# Character A: High curiosity, low fear, wants to investigate
	var curious_char = CharacterStateClass.new("char_curious", "Curious Bob", "room_101")
	curious_char.set_personality_trait("curiosity", 0.95)
	curious_char.set_personality_trait("fear", 0.05)
	curious_char.set_need("information", 0.1) # high need for info
	curious_char.goals = [{"id": "Inv", "type": "investigate_location", "target": "room_101"}]

	# Character B: High fear, low curiosity, exhausted
	var fearful_char = CharacterStateClass.new("char_fearful", "Fearful Alice", "room_101")
	fearful_char.set_personality_trait("curiosity", 0.05)
	fearful_char.set_personality_trait("fear", 0.95)
	fearful_char.set_need("rest", 0.1) # extremely tired
	fearful_char.set_emotion("stress", 0.8)

	var context = {
		"characters": {
			curious_char.id: curious_char,
			fearful_char.id: fearful_char
		},
		"world_graph": world,
		"rng": rng,
		"sim_time": 100.0
	}

	var dec_curious: UtilityDecision = ai.decide_action(curious_char, context)
	var dec_fearful: UtilityDecision = ai.decide_action(fearful_char, context)

	if dec_curious == null or dec_curious.action == null:
		return {"name": test_name, "passed": false, "error": "Curious character failed to make a decision"}
	if dec_fearful == null or dec_fearful.action == null:
		return {"name": test_name, "passed": false, "error": "Fearful character failed to make a decision"}

	if dec_curious.action.id != "investigate":
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected curious character to prefer investigate, chose: %s (score: %.2f)" % [dec_curious.action.id, dec_curious.score]
		}

	if dec_fearful.action.id != "rest":
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected fearful exhausted character to prefer rest, chose: %s (score: %.2f)" % [dec_fearful.action.id, dec_fearful.score]
		}

	# Test 2: High aggression vs high empathy with co-located target
	var aggressive_char = CharacterStateClass.new("char_aggro", "Aggro Dan", "hallway_1")
	aggressive_char.set_personality_trait("aggression", 0.95)
	aggressive_char.set_personality_trait("empathy", 0.05)
	aggressive_char.set_emotion("anger", 0.9)

	var empathetic_char = CharacterStateClass.new("char_empath", "Kind Emma", "hallway_1")
	empathetic_char.set_personality_trait("aggression", 0.05)
	empathetic_char.set_personality_trait("empathy", 0.95)
	empathetic_char.set_emotion("happiness", 0.8)

	var bystander = CharacterStateClass.new("char_bystander", "Target Sam", "hallway_1")

	var social_context = {
		"characters": {
			aggressive_char.id: aggressive_char,
			empathetic_char.id: empathetic_char,
			bystander.id: bystander
		},
		"world_graph": world,
		"rng": rng,
		"sim_time": 200.0
	}

	var dec_aggro = ai.decide_action(aggressive_char, social_context)
	var dec_empath = ai.decide_action(empathetic_char, social_context)

	if dec_aggro.action.id != "confront":
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected aggressive angry character to confront, chose: %s" % dec_aggro.action.id
		}

	if dec_empath.action.id != "help" and dec_empath.action.id != "talk":
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected empathetic character to help or talk, chose: %s" % dec_empath.action.id
		}

	return {"name": test_name, "passed": true}

static func test_seed_determinism_in_decisions() -> Dictionary:
	var test_name = "test_seed_determinism_in_decisions"

	var seed_val: int = 998877

	# Run 1
	var world1 = WorldGraphClass.create_default_apartment()
	var rng1 = RandomServiceClass.new(seed_val)
	var ai1 = UtilityAIClass.new()
	var char1 = CharacterStateClass.new("npc_test", "Tester", "lobby")
	char1.goals = [{"id": "G1", "type": "investigate_location", "target": "room_201"}]
	var ctx1 = {"characters": {char1.id: char1}, "world_graph": world1, "rng": rng1, "sim_time": 0.0}
	var dec1 = ai1.decide_action(char1, ctx1)

	# Run 2 with identical seed
	var world2 = WorldGraphClass.create_default_apartment()
	var rng2 = RandomServiceClass.new(seed_val)
	var ai2 = UtilityAIClass.new()
	var char2 = CharacterStateClass.new("npc_test", "Tester", "lobby")
	char2.goals = [{"id": "G1", "type": "investigate_location", "target": "room_201"}]
	var ctx2 = {"characters": {char2.id: char2}, "world_graph": world2, "rng": rng2, "sim_time": 0.0}
	var dec2 = ai2.decide_action(char2, ctx2)

	if dec1.action.id != dec2.action.id or dec1.action.target_id != dec2.action.target_id:
		return {
			"name": test_name,
			"passed": false,
			"error": "Non-deterministic choice between identical seeds: Run1=%s->%s, Run2=%s->%s" % [
				dec1.action.id, dec1.action.target_id, dec2.action.id, dec2.action.target_id
			]
		}

	if not is_equal_approx(dec1.score, dec2.score):
		return {
			"name": test_name,
			"passed": false,
			"error": "Score mismatch between identical runs: %.4f vs %.4f" % [dec1.score, dec2.score]
		}

	# Verify all candidates match in order and score
	if dec1.candidates.size() != dec2.candidates.size():
		return {"name": test_name, "passed": false, "error": "Candidates count mismatch"}

	for i in range(dec1.candidates.size()):
		var c1 = dec1.candidates[i]
		var c2 = dec2.candidates[i]
		if c1["action_id"] != c2["action_id"] or not is_equal_approx(float(c1["score"]), float(c2["score"])):
			return {
				"name": test_name,
				"passed": false,
				"error": "Candidate %d differed in score or action: %s(%.3f) vs %s(%.3f)" % [
					i, c1["action_id"], float(c1["score"]), c2["action_id"], float(c2["score"])
				]
			}

	return {"name": test_name, "passed": true}

static func test_ai_filters_impossible_actions() -> Dictionary:
	var test_name = "test_ai_filters_impossible_actions"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(123)
	var ai = UtilityAIClass.new()

	# Character alone in room_101
	var solo_char = CharacterStateClass.new("solo", "Solo", "room_101")
	solo_char.inventory = [] # No items to give

	var context = {
		"characters": {solo_char.id: solo_char},
		"world_graph": world,
		"rng": rng,
		"sim_time": 0.0
	}

	var candidates = ai.generate_candidate_actions(solo_char, context)
	var valid = ai.filter_valid_actions(candidates, context)

	# Verify that no action requiring co-located character exists in valid list
	for a in valid:
		if a.id in ["talk", "help", "confront", "refuse", "give_item", "take_item"]:
			return {
				"name": test_name,
				"passed": false,
				"error": "AI failed to filter impossible action '%s' when character is alone" % a.id
			}
		if a.id == "move_to":
			# Target must be a valid neighbor of room_101
			if not world.are_locations_connected(solo_char.current_location, a.target_id):
				return {
					"name": test_name,
					"passed": false,
					"error": "AI allowed invalid MoveTo to non-neighbor %s" % a.target_id
				}

	return {"name": test_name, "passed": true}

static func test_debug_candidate_scores_and_explanations() -> Dictionary:
	var test_name = "test_debug_candidate_scores_and_explanations"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(555)
	var ai = UtilityAIClass.new()

	var char_state = CharacterStateClass.new("debug_actor", "Actor", "hallway_1")
	char_state.goals = [{"id": "G_Investigate", "type": "investigate_location", "target": "room_101"}]

	var context = {
		"characters": {char_state.id: char_state},
		"world_graph": world,
		"rng": rng,
		"sim_time": 50.0
	}

	var decision = ai.decide_action(char_state, context)

	if decision.candidates.is_empty():
		return {"name": test_name, "passed": false, "error": "Decision has empty candidates list"}

	if decision.reasons.is_empty():
		return {"name": test_name, "passed": false, "error": "Decision has empty reasons dictionary"}

	if not decision.reasons.has("goal") or not decision.reasons.has("personality"):
		return {"name": test_name, "passed": false, "error": "Reasons dictionary missing required factor keys"}

	var explanation = decision.get_explanation()
	if explanation.is_empty():
		return {"name": test_name, "passed": false, "error": "Explanation string is empty"}

	# Also test that CharacterState.get_debug_summary() contains the Utility Decision section
	char_state.last_decision = decision.to_dict()
	var debug_summary = char_state.get_debug_summary()
	if not debug_summary.contains("[Utility Decision]") or not debug_summary.contains("Top Candidates:"):
		return {
			"name": test_name,
			"passed": false,
			"error": "CharacterState debug summary does not display Utility Decision data"
		}

	return {"name": test_name, "passed": true}

static func test_simulation_runner_autonomous_loop() -> Dictionary:
	var test_name = "test_simulation_runner_autonomous_loop"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 777
	runner._init_simulation()

	var initial_events_count: int = runner.get_events().size()

	# Simulate 30 simulation seconds (multiple action cycles)
	for i in range(30):
		runner._tick_simulation(1.0)

	var new_events = runner.get_events()
	runner.free()

	if new_events.size() <= initial_events_count:
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected autonomous action executions to generate simulation events, got %d events" % new_events.size()
		}

	return {"name": test_name, "passed": true}
