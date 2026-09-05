class_name TestPlayerDirectives
extends RefCounted

## Automated test suite for TASK-007: Player Directives (WANT / NEVER / BELIEVE).
## Validates selectable directives, protagonist-only application,
## behavioral differentiation, NEVER strict violation penalties,
## WANT utility bonuses in debug scores, and BELIEVE interpretation shaping.

const DirectiveCatalogClass = preload("res://scripts/directives/directive_catalog.gd")
const WantDirectiveClass = preload("res://scripts/directives/want_directive.gd")
const NeverDirectiveClass = preload("res://scripts/directives/never_directive.gd")
const BeliefDirectiveClass = preload("res://scripts/directives/belief_directive.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")
const UtilityDecisionClass = preload("res://scripts/ai/utility_decision.gd")
const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")

const MoveToActionClass = preload("res://scripts/actions/move_to_action.gd")
const InvestigateActionClass = preload("res://scripts/actions/investigate_action.gd")
const TalkActionClass = preload("res://scripts/actions/talk_action.gd")
const ConfrontActionClass = preload("res://scripts/actions/confront_action.gd")
const TakeItemActionClass = preload("res://scripts/actions/take_item_action.gd")
const RestActionClass = preload("res://scripts/actions/rest_action.gd")
const IdleActionClass = preload("res://scripts/actions/idle_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_player_can_select_all_three_directives())
	results.append(test_protagonist_behavior_changes_with_directives())
	results.append(test_npcs_do_not_inherit_protagonist_directives())
	results.append(test_never_visibly_prevents_violating_behavior())
	results.append(test_want_contributes_clearly_to_utility_debug_scores())
	results.append(test_believe_modifies_interpretation_without_forced_path())
	return results

static func test_player_can_select_all_three_directives() -> Dictionary:
	var test_name = "test_player_can_select_all_three_directives"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	# Verify catalog availability
	var wants = DirectiveCatalogClass.get_available_wants()
	var nevers = DirectiveCatalogClass.get_available_nevers()
	var beliefs = DirectiveCatalogClass.get_available_beliefs()

	if wants.size() < 5:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected at least 5 wants, got %d" % wants.size()}
	if nevers.size() < 5:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected at least 5 nevers, got %d" % nevers.size()}
	if beliefs.size() < 5:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected at least 5 beliefs, got %d" % beliefs.size()}

	# Initial default directives on runner
	var initial_dirs = runner.get_player_directives()
	if initial_dirs["want"].id != "learn_room_407":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected default want 'learn_room_407', got '%s'" % initial_dirs["want"].id}

	# Set custom directives
	runner.set_player_directives("earn_money", "never_enter_room_407", "money_solves_problems")
	var updated_dirs = runner.get_player_directives()

	if updated_dirs["want"].id != "earn_money" or updated_dirs["never"].id != "never_enter_room_407" or updated_dirs["believe"].id != "money_solves_problems":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Runner directives did not update correctly"}

	var protagonist = runner.get_character("char_protagonist")
	if protagonist == null:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist character not found in runner"}

	if not protagonist.has_directives():
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist character has_directives() returned false"}

	if protagonist.get_directive("want").id != "earn_money":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist want directive does not match"}
	if protagonist.get_directive("never").id != "never_enter_room_407":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist never directive does not match"}
	if protagonist.get_directive("believe").id != "money_solves_problems":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist believe directive does not match"}

	# Verify serialization
	var state_dict = protagonist.to_dict()
	if not state_dict.has("directives"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist to_dict() missing directives field"}
	var dir_dict = state_dict["directives"]
	var want_sub = dir_dict.get("want", {})
	var never_sub = dir_dict.get("never", {})
	var believe_sub = dir_dict.get("believe", {})
	if want_sub.get("id") != "earn_money" or never_sub.get("id") != "never_enter_room_407" or believe_sub.get("id") != "money_solves_problems":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Protagonist serialized directives incorrect: %s" % str(dir_dict)}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_protagonist_behavior_changes_with_directives() -> Dictionary:
	var test_name = "test_protagonist_behavior_changes_with_directives"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(42)
	var ai = UtilityAIClass.new()

	# Scenario 1: Protagonist in hallway_2 with WANT learn_room_407 (room_407 is directly connected to hallway_2)
	var protagonist_a = CharacterStateClass.new("char_protagonist", "Alex", "hallway_2")
	protagonist_a.is_protagonist = true
	var want_407 = DirectiveCatalogClass.get_want("learn_room_407")
	var never_steal = DirectiveCatalogClass.get_never("never_steal")
	var believe_suspicious = DirectiveCatalogClass.get_belief("everyone_hiding_something")
	protagonist_a.set_directives(want_407, never_steal, believe_suspicious)

	var context_a = {
		"characters": {protagonist_a.id: protagonist_a},
		"world_graph": world,
		"rng": rng,
		"sim_time": 100.0
	}

	var decision_a: UtilityDecision = ai.decide_action(protagonist_a, context_a)

	# Scenario 2: Protagonist in hallway_2 with WANT survive_night and NEVER never_enter_room_407
	var protagonist_b = CharacterStateClass.new("char_protagonist", "Alex", "hallway_2")
	protagonist_b.is_protagonist = true
	var want_survive = DirectiveCatalogClass.get_want("survive_night")
	var never_407 = DirectiveCatalogClass.get_never("never_enter_room_407")
	var believe_helping = DirectiveCatalogClass.get_belief("helping_pays_off")
	protagonist_b.set_directives(want_survive, never_407, believe_helping)

	var context_b = {
		"characters": {protagonist_b.id: protagonist_b},
		"world_graph": world,
		"rng": rng,
		"sim_time": 100.0
	}

	var decision_b: UtilityDecision = ai.decide_action(protagonist_b, context_b)

	if decision_a == null or decision_a.action == null:
		return {"name": test_name, "passed": false, "error": "Scenario A decision failed"}
	if decision_b == null or decision_b.action == null:
		return {"name": test_name, "passed": false, "error": "Scenario B decision failed"}

	# Protagonist A should target room_407 (move_to or investigate)
	var a_targets_407: bool = false
	if decision_a.action.id == "move_to" and decision_a.action.target_id == "room_407":
		a_targets_407 = true
	elif decision_a.action.id == "investigate" and decision_a.action.target_id == "room_407":
		a_targets_407 = true

	if not a_targets_407:
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected Protagonist A with WANT learn_room_407 to target room_407, chose: %s target: %s" % [decision_a.action.id, decision_a.action.target_id]
		}

	# Protagonist B has NEVER enter room_407: must NOT choose room_407
	if decision_b.action.target_id == "room_407":
		return {
			"name": test_name,
			"passed": false,
			"error": "Protagonist B violated NEVER never_enter_room_407 by choosing %s to room_407" % decision_b.action.id
		}

	return {"name": test_name, "passed": true}

static func test_npcs_do_not_inherit_protagonist_directives() -> Dictionary:
	var test_name = "test_npcs_do_not_inherit_protagonist_directives"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 9999
	runner._init_simulation()

	# Set explicit player directives on the runner
	runner.set_player_directives("make_friend", "never_hurt_anyone", "most_people_trusted")

	var world = runner.get_world()
	var rng = runner.get_rng()
	var ai = UtilityAIClass.new()
	var all_chars = runner.get_all_characters()

	var char_map: Dictionary = {}
	for c in all_chars:
		char_map[c.id] = c

	var npc_count = 0
	for c in all_chars:
		if c.is_protagonist:
			continue
		npc_count += 1
		if c.has_directives():
			runner.free()
			return {"name": test_name, "passed": false, "error": "NPC %s (%s) has directives!" % [c.id, c.name]}
		if not c.directives.is_empty():
			runner.free()
			return {"name": test_name, "passed": false, "error": "NPC %s has non-empty directives dictionary" % c.id}

		# Score an action for this NPC and verify explanation has no directive tags
		var context = {
			"characters": char_map,
			"world_graph": world,
			"rng": rng,
			"sim_time": 100.0
		}
		var test_action = RestActionClass.new(c.id, c.current_location, 10.0)
		var score_result = ai.score_action(c, test_action, context)
		if score_result.reasons.has("want") or score_result.reasons.has("never") or score_result.reasons.has("believe"):
			runner.free()
			return {
				"name": test_name,
				"passed": false,
				"error": "NPC %s score reasons contained directive keys: %s" % [c.id, score_result.reasons]
			}

	runner.free()

	if npc_count < 3:
		return {"name": test_name, "passed": false, "error": "Expected at least 3 NPCs in simulation, checked %d" % npc_count}

	return {"name": test_name, "passed": true}

static func test_never_visibly_prevents_violating_behavior() -> Dictionary:
	var test_name = "test_never_visibly_prevents_violating_behavior"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(777)
	var ai = UtilityAIClass.new()

	var protagonist = CharacterStateClass.new("char_protagonist", "Alex", "room_101")
	protagonist.is_protagonist = true
	var npc = CharacterStateClass.new("char_npc", "Target NPC", "room_101")
	npc.inventory.append("gold_watch")

	var context = {
		"characters": {protagonist.id: protagonist, npc.id: npc},
		"world_graph": world,
		"rng": rng,
		"sim_time": 50.0
	}

	# 1. Test never_steal
	var want_money = DirectiveCatalogClass.get_want("earn_money")
	var never_steal = DirectiveCatalogClass.get_never("never_steal")
	var believe_default = DirectiveCatalogClass.get_belief("everyone_hiding_something")
	protagonist.set_directives(want_money, never_steal, believe_default)

	var steal_action = TakeItemActionClass.new(protagonist.id, "gold_watch", npc.id, 5.0)
	var score_steal = ai.score_action(protagonist, steal_action, context)

	if not ("never: -15.00" in score_steal.explanation):
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected 'never: -15.00' in steal explanation, got: %s" % score_steal.explanation
		}

	if score_steal.score > -5.0:
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected severely negative utility score for stealing, got: %.2f" % score_steal.score
		}

	# 2. Test never_enter_room_407
	var never_407 = DirectiveCatalogClass.get_never("never_enter_room_407")
	protagonist.set_directives(want_money, never_407, believe_default)
	var move_407_action = MoveToActionClass.new(protagonist.id, "room_407", 5.0)
	var score_407 = ai.score_action(protagonist, move_407_action, context)

	if not ("never: -15.00" in score_407.explanation):
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected 'never: -15.00' in move explanation, got: %s" % score_407.explanation
		}

	# 3. Test never_hurt_anyone
	var never_hurt = DirectiveCatalogClass.get_never("never_hurt_anyone")
	protagonist.set_directives(want_money, never_hurt, believe_default)
	var confront_action = ConfrontActionClass.new(protagonist.id, npc.id, 5.0)
	var score_confront = ai.score_action(protagonist, confront_action, context)

	if not ("never: -15.00" in score_confront.explanation):
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected 'never: -15.00' in confront explanation, got: %s" % score_confront.explanation
		}

	return {"name": test_name, "passed": true}

static func test_want_contributes_clearly_to_utility_debug_scores() -> Dictionary:
	var test_name = "test_want_contributes_clearly_to_utility_debug_scores"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(123)
	var ai = UtilityAIClass.new()

	var protagonist = CharacterStateClass.new("char_protagonist", "Alex", "room_407")
	protagonist.is_protagonist = true

	var want_407 = DirectiveCatalogClass.get_want("learn_room_407")
	var never_lie = DirectiveCatalogClass.get_never("never_lie")
	var believe_distrust = DirectiveCatalogClass.get_belief("nobody_gives_anything_for_free")
	protagonist.set_directives(want_407, never_lie, believe_distrust)

	var context = {
		"characters": {protagonist.id: protagonist},
		"world_graph": world,
		"rng": rng,
		"sim_time": 20.0
	}

	var investigate_action = InvestigateActionClass.new(protagonist.id, "room_407", 10.0)
	var score_result = ai.score_action(protagonist, investigate_action, context)

	if not ("want: +4.00" in score_result.explanation or "want: +" in score_result.explanation):
		return {
			"name": test_name,
			"passed": false,
			"error": "Candidate score explanation missing 'want: +', got: %s" % score_result.explanation
		}

	if score_result.reasons.get("want", 0.0) < 3.5:
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected want bonus >= 3.5, got %.2f" % score_result.reasons.get("want", 0.0)
		}

	# Verify debug summary contains directive section
	var debug_str = protagonist.get_debug_summary()
	if not ("[Directives (Player)]" in debug_str and "learn_room_407" in debug_str and "never_lie" in debug_str):
		return {
			"name": test_name,
			"passed": false,
			"error": "Character debug summary missing directive details: %s" % debug_str
		}

	return {"name": test_name, "passed": true}

static func test_believe_modifies_interpretation_without_forced_path() -> Dictionary:
	var test_name = "test_believe_modifies_interpretation_without_forced_path"

	var world = WorldGraphClass.create_default_apartment()
	var rng = RandomServiceClass.new(321)
	var ai = UtilityAIClass.new()

	var protagonist = CharacterStateClass.new("char_protagonist", "Alex", "hallway_1")
	protagonist.is_protagonist = true
	var npc = CharacterStateClass.new("char_npc", "Neighbor", "hallway_1")

	var want_neutral = DirectiveCatalogClass.get_want("be_trusted")
	var never_neutral = DirectiveCatalogClass.get_never("never_trust_police")
	var believe_suspicious = DirectiveCatalogClass.get_belief("everyone_hiding_something")
	protagonist.set_directives(want_neutral, never_neutral, believe_suspicious)

	var context = {
		"characters": {protagonist.id: protagonist, npc.id: npc},
		"world_graph": world,
		"rng": rng,
		"sim_time": 60.0
	}

	# 1. Check believe bonus is included in InvestigateAction
	var investigate_action = InvestigateActionClass.new(protagonist.id, "hallway_1", 5.0)
	var investigate_score = ai.score_action(protagonist, investigate_action, context)

	if not ("believe: +1.50" in investigate_score.explanation or "believe: +" in investigate_score.explanation):
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected 'believe: +' in explanation, got: %s" % investigate_score.explanation
		}

	# 2. Check believe does NOT create a rigid forced path:
	# When protagonist is in extreme physiological distress (exhaustion/rest need = 0.0),
	# RestAction should still outscore InvestigateAction despite the belief boost.
	protagonist.set_need("rest", 0.0) # completely exhausted

	var rest_action = RestActionClass.new(protagonist.id, "hallway_1", 10.0)
	var rest_score = ai.score_action(protagonist, rest_action, context)

	if rest_score.score <= investigate_score.score:
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected rest score (%.2f) to exceed belief-influenced investigate score (%.2f)" % [
				rest_score.score,
				investigate_score.score
			]
		}

	# 3. Check another belief: most_people_trusted boosting TalkAction
	var believe_trusting = DirectiveCatalogClass.get_belief("most_people_trusted")
	protagonist.set_directives(want_neutral, never_neutral, believe_trusting)
	var talk_action = TalkActionClass.new(protagonist.id, npc.id, 5.0)
	var talk_score = ai.score_action(protagonist, talk_action, context)

	if not ("believe: +1.40" in talk_score.explanation or "believe: +" in talk_score.explanation):
		return {
			"name": test_name,
			"passed": false,
			"error": "Expected 'believe: +' in talk explanation, got: %s" % talk_score.explanation
		}

	return {"name": test_name, "passed": true}
