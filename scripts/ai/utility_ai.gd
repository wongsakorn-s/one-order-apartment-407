class_name UtilityAI
extends RefCounted

## UtilityAI Decision Engine
## Evaluates candidate actions for autonomous characters, filters impossible actions,
## scores each valid candidate based on goals, personality, needs, emotions,
## relationships, risk, and seeded controlled noise, and selects the highest-scoring action.
## Pure simulation logic; 100% deterministic with seeded RNG.

const BaseActionClass = preload("res://scripts/actions/base_action.gd")
const IdleActionClass = preload("res://scripts/actions/idle_action.gd")
const MoveToActionClass = preload("res://scripts/actions/move_to_action.gd")
const TalkActionClass = preload("res://scripts/actions/talk_action.gd")
const InvestigateActionClass = preload("res://scripts/actions/investigate_action.gd")
const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const RefuseActionClass = preload("res://scripts/actions/refuse_action.gd")
const RestActionClass = preload("res://scripts/actions/rest_action.gd")
const TakeItemActionClass = preload("res://scripts/actions/take_item_action.gd")
const GiveItemActionClass = preload("res://scripts/actions/give_item_action.gd")
const FleeActionClass = preload("res://scripts/actions/flee_action.gd")
const ConfrontActionClass = preload("res://scripts/actions/confront_action.gd")
const AskQuestionActionClass = preload("res://scripts/actions/ask_question_action.gd")
const ShareInformationActionClass = preload("res://scripts/actions/share_information_action.gd")
const LieActionClass = preload("res://scripts/actions/lie_action.gd")
const UtilityDecisionClass = preload("res://scripts/ai/utility_decision.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")

## Primary entry point: Generates, scores, and selects an action for actor.
func decide_action(actor: CharacterState, context: Dictionary) -> UtilityDecision:
	if actor == null:
		return null

	var candidates: Array[BaseAction] = generate_candidate_actions(actor, context)
	var valid_candidates: Array[BaseAction] = filter_valid_actions(candidates, context)

	if valid_candidates.is_empty():
		# Fallback to pure Idle if no other action is valid
		var fallback_idle = IdleActionClass.new(actor.id, 5.0)
		return UtilityDecisionClass.new(
			fallback_idle,
			0.0,
			{"fallback": 0.0},
			[{"action_id": "idle", "score": 0.0, "reasons": {}, "explanation": "Fallback idle"}],
			"Idle (no valid candidates available)"
		)

	var evaluated_candidates: Array[Dictionary] = []
	var best_action: BaseAction = null
	var best_score: float = -999999.0
	var best_reasons: Dictionary = {}
	var best_explanation: String = ""
	var best_contributing_event_ids: Array[String] = []

	for candidate in valid_candidates:
		var eval_data: Dictionary = score_action(actor, candidate, context)
		evaluated_candidates.append(eval_data)
		var current_score: float = float(eval_data.get("score", 0.0))

		if current_score > best_score:
			best_score = current_score
			best_action = candidate
			best_reasons = eval_data.get("reasons", {})
			best_explanation = eval_data.get("explanation", "")
			best_contributing_event_ids = []
			best_contributing_event_ids.assign(eval_data.get("contributing_event_ids", []))

	# Sort candidate summaries descending by score for debug visibility
	evaluated_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	return UtilityDecisionClass.new(
		best_action,
		best_score,
		best_reasons,
		evaluated_candidates,
		best_explanation,
		best_contributing_event_ids
	)

## Generate potential actions available to the character in the current state.
func generate_candidate_actions(actor: CharacterState, context: Dictionary) -> Array[BaseAction]:
	var list: Array[BaseAction] = []
	var world_graph: WorldGraph = context.get("world_graph", null)
	var characters: Dictionary = context.get("characters", {})

	# 1. Baseline Idle
	list.append(IdleActionClass.new(actor.id, 6.0))

	# 2. Rest in current location
	list.append(RestActionClass.new(actor.id, actor.current_location, 10.0))

	# 3. Investigate current location
	list.append(InvestigateActionClass.new(actor.id, actor.current_location, 8.0))

	# 4. Movement to neighboring locations
	if world_graph != null:
		var neighbors: Array[String] = world_graph.get_neighbors(actor.current_location)
		for neighbor_id in neighbors:
			list.append(MoveToActionClass.new(actor.id, neighbor_id, 6.0))
			list.append(FleeActionClass.new(actor.id, neighbor_id, 4.0))

	# 5. Co-located character interactions
	for other_id in characters.keys():
		if other_id == actor.id:
			continue
		var other = characters[other_id] as CharacterState
		if other != null and other.current_location == actor.current_location:
			list.append(TalkActionClass.new(actor.id, other.id, 6.0))
			list.append(HelpActionClass.new(actor.id, other.id, 8.0))
			list.append(ConfrontActionClass.new(actor.id, other.id, 8.0))
			list.append(RefuseActionClass.new(actor.id, other.id, 4.0))
			list.append(AskQuestionActionClass.new(actor.id, other.id, 6.0))
			list.append(ShareInformationActionClass.new(actor.id, other.id, 6.0))
			list.append(LieActionClass.new(actor.id, other.id, 5.0))

			# Item transfers
			if not actor.inventory.is_empty():
				list.append(GiveItemActionClass.new(actor.id, other.id, str(actor.inventory[0]), 5.0))
			if not other.inventory.is_empty():
				list.append(TakeItemActionClass.new(actor.id, str(other.inventory[0]), other.id, 5.0))

	return list

## Filter out any candidate actions that violate preconditions.
func filter_valid_actions(candidates: Array[BaseAction], context: Dictionary) -> Array[BaseAction]:
	var valid: Array[BaseAction] = []
	for action in candidates:
		if action.can_execute(context):
			valid.append(action)
	return valid

## Compute the utility score for an action and return a detailed breakdown.
func score_action(actor: CharacterState, action: BaseAction, context: Dictionary) -> Dictionary:
	var world_graph: WorldGraph = context.get("world_graph", null)
	var characters: Dictionary = context.get("characters", {})
	var rng: RandomService = context.get("rng", null)

	var goal_relevance: float = 0.0
	var personality_mod: float = 0.0
	var need_mod: float = 0.0
	var emotional_mod: float = 0.0
	var relationship_mod: float = 0.0
	var memory_mod: float = 0.0
	var controlled_noise: float = 0.0
	var risk: float = 0.0
	var base_score: float = 0.0

	# Seeded noise for tie-breaking (-0.15 to +0.15)
	if rng != null:
		controlled_noise = (rng.rand_float() - 0.5) * 0.3

	# TASK-019: variety pressure. Repeating the exact same action type the
	# actor just completed is deliberately discouraged (a deterministic,
	# explainable "I just did that" bias, not RNG) so a strong early lead for
	# one action (e.g. talk/help feeding off ever-rising trust/debt) doesn't
	# snowball into that action dominating the whole run. Idle/rest are exempt
	# since repeated rest/idling is expected physiological behavior, not a
	# repetitive-story problem.
	var repetition_mod: float = 0.0
	if not (action.id in ["idle", "rest"]) and actor.current_action.get("id", "") == action.id:
		repetition_mod = -2.0

	# Action-specific evaluation
	match action.id:
		"idle":
			base_score = 0.3
			need_mod = (1.0 - actor.get_need("rest")) * 0.5
			personality_mod = - (actor.get_personality_trait("impulsiveness") - 0.5) * 0.8

		"rest":
			base_score = 0.4
			# Strong need urgency when rest need is low
			need_mod = (1.0 - actor.get_need("rest")) * 3.0
			emotional_mod = actor.get_emotion("stress") * 1.2
			personality_mod = (actor.get_personality_trait("fear") - 0.5) * 0.6
			goal_relevance = _evaluate_goal_match(actor, "rest", "")

		"investigate":
			# TASK-019: raised base/personality weight -- investigate was
			# badly under-represented (10% of NPC actions) next to talk/help.
			base_score = 0.65
			var curiosity: float = actor.get_personality_trait("curiosity")
			var fear: float = actor.get_personality_trait("fear")
			personality_mod = (curiosity - 0.5) * 3.0 - (fear - 0.5) * 0.8
			need_mod = (1.0 - actor.get_need("information")) * 1.8
			emotional_mod = actor.get_emotion("fear") * -1.0

			# Target room matching
			if action.target_id == "room_407":
				risk = 1.0 * (1.0 - curiosity)
				goal_relevance = _evaluate_goal_match(actor, "investigate_location", "room_407")
			else:
				goal_relevance = _evaluate_goal_match(actor, "investigate_location", action.target_id)

		"move_to":
			# TASK-019: raised base/curiosity weight -- NPCs almost never
			# relocated (2% of actions), clustering the same small groups
			# together for the whole night instead of circulating.
			base_score = 0.75
			var target_loc: String = action.target_id
			personality_mod = (actor.get_personality_trait("curiosity") - 0.5) * 1.4

			# Goal navigation
			goal_relevance = _evaluate_movement_goal(actor, target_loc, world_graph, characters)

			# Risk factor for Room 407
			if target_loc == "room_407":
				var fear: float = actor.get_personality_trait("fear")
				risk = 1.2 * fear
				if actor.get_emotion("fear") > 0.4:
					risk += 1.0

		"flee":
			base_score = -0.6
			var fear_trait: float = actor.get_personality_trait("fear")
			var fear_emotion: float = actor.get_emotion("fear")
			var stress_emotion: float = actor.get_emotion("stress")
			emotional_mod = fear_emotion * 3.5 + stress_emotion * 1.5
			personality_mod = (fear_trait - 0.5) * 2.2 - (actor.get_personality_trait("aggression") - 0.5) * 1.5
			need_mod = (1.0 - actor.get_need("safety")) * 2.0
			goal_relevance = _evaluate_flee_goal(actor, characters)

			# Fear of co-located characters triggers fleeing
			var max_co_fear: float = 0.0
			for other_id in characters.keys():
				if other_id != actor.id:
					var other = characters[other_id] as CharacterState
					if other != null and other.current_location == actor.current_location:
						var f: float = _get_relationship_value(actor, other_id, "fear")
						if f > max_co_fear:
							max_co_fear = f
			if max_co_fear > 0.1:
				relationship_mod = max_co_fear * 2.5

		"talk":
			# TASK-019: talk was overwhelmingly dominant (41% of all NPC
			# actions). Lowered base score and relationship coefficient so
			# rising trust from repeated talk doesn't snowball into talk
			# always winning; personality/need influence kept meaningful.
			base_score = 0.5
			var sociability: float = actor.get_personality_trait("sociability")
			var empathy: float = actor.get_personality_trait("empathy")
			personality_mod = (sociability - 0.5) * 2.2 + (empathy - 0.5) * 1.0
			need_mod = (1.0 - actor.get_need("social")) * 1.6 + (1.0 - actor.get_need("information")) * 1.0
			relationship_mod = minf(_get_relationship_value(actor, action.target_id, "trust"), 0.7) * 1.0 - _get_relationship_value(actor, action.target_id, "suspicion") * 0.8 - _get_relationship_value(actor, action.target_id, "fear") * 0.6 + _get_relationship_value(actor, action.target_id, "attraction") * 0.5
			emotional_mod = actor.get_emotion("happiness") * 0.8 - actor.get_emotion("anger") * 1.5
			goal_relevance = _evaluate_social_goal(actor, action.target_id, ["meet_character", "repair_relationship"])

		"help":
			# TASK-019: debt/trust coefficients lowered and soft-capped --
			# debt in particular only ever grows from being helped, so
			# uncapped it made help snowball into a self-reinforcing loop
			# between the same pair once trust/debt approached 1.0.
			base_score = 0.15
			var empathy: float = actor.get_personality_trait("empathy")
			var greed: float = actor.get_personality_trait("greed")
			personality_mod = (empathy - 0.5) * 3.2 - (greed - 0.5) * 1.6
			emotional_mod = actor.get_emotion("happiness") * 1.2 - actor.get_emotion("anger") * 2.5
			relationship_mod = minf(_get_relationship_value(actor, action.target_id, "trust"), 0.7) * 0.8 + minf(_get_relationship_value(actor, action.target_id, "debt"), 0.7) * 0.9
			goal_relevance = _evaluate_social_goal(actor, action.target_id, ["repair_relationship"])

		"confront":
			base_score = -0.2
			var aggression: float = actor.get_personality_trait("aggression")
			var empathy: float = actor.get_personality_trait("empathy")
			var fear: float = actor.get_personality_trait("fear")
			personality_mod = (aggression - 0.5) * 3.5 - (empathy - 0.5) * 2.0 - (fear - 0.5) * 1.2
			emotional_mod = actor.get_emotion("anger") * 3.0 + actor.get_emotion("stress") * 0.8
			relationship_mod = _get_relationship_value(actor, action.target_id, "suspicion") * 2.0 - _get_relationship_value(actor, action.target_id, "trust") * 1.5 - _get_relationship_value(actor, action.target_id, "fear") * 1.5
			risk = 0.8

		"refuse":
			base_score = 0.1
			var aggression: float = actor.get_personality_trait("aggression")
			var empathy: float = actor.get_personality_trait("empathy")
			personality_mod = (aggression - 0.5) * 1.6 - (empathy - 0.5) * 1.8
			emotional_mod = actor.get_emotion("anger") * 1.5
			relationship_mod = - _get_relationship_value(actor, action.target_id, "trust") * 1.2 + _get_relationship_value(actor, action.target_id, "suspicion") * 0.8 - _get_relationship_value(actor, action.target_id, "fear") * 1.0

		"take_item":
			base_score = 0.2
			var greed: float = actor.get_personality_trait("greed")
			var honesty: float = actor.get_personality_trait("honesty")
			personality_mod = (greed - 0.5) * 2.8 - (honesty - 0.5) * 2.0
			need_mod = (1.0 - actor.get_need("money")) * 1.5
			var source_char_id: String = action.source_character_id if "source_character_id" in action else ""
			if not source_char_id.is_empty():
				relationship_mod = - _get_relationship_value(actor, source_char_id, "respect") * 1.0 - _get_relationship_value(actor, source_char_id, "trust") * 0.8
			goal_relevance = _evaluate_goal_match(actor, "retrieve_item", "") + _evaluate_goal_match(actor, "earn_money", "")

		"give_item":
			base_score = 0.1
			var empathy: float = actor.get_personality_trait("empathy")
			var greed: float = actor.get_personality_trait("greed")
			personality_mod = (empathy - 0.5) * 2.5 - (greed - 0.5) * 2.5
			relationship_mod = _get_relationship_value(actor, action.target_id, "trust") * 1.5 + _get_relationship_value(actor, action.target_id, "debt") * 1.2 + _get_relationship_value(actor, action.target_id, "attraction") * 0.8
			goal_relevance = _evaluate_social_goal(actor, action.target_id, ["repair_relationship"])

		"ask_question":
			base_score = 0.5
			var curiosity: float = actor.get_personality_trait("curiosity")
			personality_mod = (curiosity - 0.5) * 2.0
			need_mod = (1.0 - actor.get_need("information")) * 2.0
			relationship_mod = _get_relationship_value(actor, action.target_id, "trust") * 0.8 - _get_relationship_value(actor, action.target_id, "suspicion") * 0.4
			goal_relevance = _evaluate_goal_match(actor, "investigate_location", "") * 0.6 + _evaluate_social_goal(actor, action.target_id, ["meet_character", "repair_relationship"]) * 0.5

		"share_information":
			base_score = 0.3
			var empathy: float = actor.get_personality_trait("empathy")
			var sociability: float = actor.get_personality_trait("sociability")
			personality_mod = (empathy - 0.5) * 2.0 + (sociability - 0.5) * 1.0
			relationship_mod = _get_relationship_value(actor, action.target_id, "trust") * 1.0 + _get_relationship_value(actor, action.target_id, "attraction") * 0.3
			goal_relevance = _evaluate_social_goal(actor, action.target_id, ["repair_relationship"])

		"lie":
			base_score = -0.1
			var honesty: float = actor.get_personality_trait("honesty")
			var greed: float = actor.get_personality_trait("greed")
			personality_mod = (0.5 - honesty) * 3.0 + (greed - 0.5) * 1.0
			emotional_mod = actor.get_emotion("fear") * 1.0
			relationship_mod = - _get_relationship_value(actor, action.target_id, "trust") * 1.0 + _get_relationship_value(actor, action.target_id, "suspicion") * 0.5
			risk = honesty * 0.8

	# Player Directives evaluation (Applied exclusively to the protagonist)
	var want_mod: float = 0.0
	var never_mod: float = 0.0
	var belief_mod: float = 0.0

	if actor.is_protagonist and actor.has_directives():
		var want_dir = actor.get_directive("want")
		if want_dir != null and want_dir.has_method("calculate_utility"):
			want_mod = want_dir.calculate_utility(actor, action, context)

		var never_dir = actor.get_directive("never")
		if never_dir != null and never_dir.has_method("evaluate_violation"):
			var violation_data: Dictionary = never_dir.evaluate_violation(actor, action, context)
			never_mod = float(violation_data.get("penalty", 0.0))

		var belief_dir = actor.get_directive("believe")
		if belief_dir != null and belief_dir.has_method("modify_interpretation"):
			belief_mod = belief_dir.modify_interpretation(actor, action, context)

	var memory_eval: Dictionary = _evaluate_memory_modifier(actor, action, context)
	memory_mod = float(memory_eval.get("modifier", 0.0))
	var contributing_event_ids: Array[String] = []
	contributing_event_ids.assign(memory_eval.get("event_ids", []))

	var total_score: float = base_score + goal_relevance + personality_mod + need_mod + emotional_mod + relationship_mod + memory_mod + repetition_mod + controlled_noise + want_mod + never_mod + belief_mod - risk

	var reasons_dict: Dictionary = {
		"base": base_score,
		"goal": goal_relevance,
		"personality": personality_mod,
		"need": need_mod,
		"emotion": emotional_mod,
		"relationship": relationship_mod,
		"memory": memory_mod,
		"repetition": repetition_mod,
		"noise": controlled_noise,
		"risk": -risk
	}

	if actor.is_protagonist and actor.has_directives():
		reasons_dict["want"] = want_mod
		reasons_dict["never"] = never_mod
		reasons_dict["believe"] = belief_mod

	var explanation_text: String = _format_explanation(action, total_score, reasons_dict)

	return {
		"action": action,
		"action_id": action.id,
		"action_name": action.action_name,
		"target_id": action.target_id,
		"score": total_score,
		"reasons": reasons_dict,
		"explanation": explanation_text,
		"contributing_event_ids": contributing_event_ids
	}

func _evaluate_goal_match(actor: CharacterState, goal_type: String, target_filter: String) -> float:
	var match_score: float = 0.0
	for i in range(actor.goals.size()):
		var g = actor.goals[i]
		if g is Dictionary:
			var g_type: String = g.get("type", "")
			var g_target: String = g.get("target", "")
			if g_type == goal_type:
				if target_filter.is_empty() or g_target == target_filter:
					var weight: float = 3.0 if i == 0 else 1.8
					match_score += weight
	return match_score

func _evaluate_social_goal(actor: CharacterState, target_char_id: String, relevant_types: Array) -> float:
	var match_score: float = 0.0
	for i in range(actor.goals.size()):
		var g = actor.goals[i]
		if g is Dictionary:
			var g_type: String = g.get("type", "")
			var g_target: String = g.get("target", "")
			if g_type in relevant_types and g_target == target_char_id:
				var weight: float = 3.0 if i == 0 else 1.8
				match_score += weight
			elif g_type == "avoid_character" and g_target == target_char_id:
				match_score -= 3.0
	return match_score

func _evaluate_movement_goal(actor: CharacterState, neighbor_id: String, world_graph: WorldGraph, characters: Dictionary) -> float:
	if world_graph == null:
		return 0.0

	var move_score: float = 0.0
	for i in range(actor.goals.size()):
		var g = actor.goals[i]
		if not (g is Dictionary):
			continue
		var g_type: String = g.get("type", "")
		var g_target: String = g.get("target", "")
		var priority_weight: float = 2.5 if i == 0 else 1.5

		# 1. Investigate location goal
		if g_type == "investigate_location" and not g_target.is_empty():
			var dist_cur: int = world_graph.get_distance(actor.current_location, g_target)
			var dist_next: int = world_graph.get_distance(neighbor_id, g_target)
			if dist_next < dist_cur and dist_cur >= 0:
				move_score += priority_weight
			elif dist_next > dist_cur:
				move_score -= priority_weight * 0.5

		# 2. Meet character goal
		elif g_type in ["meet_character", "repair_relationship"] and not g_target.is_empty():
			# Rely on subjective Belief regarding target's location instead of global truth
			var believed_loc: String = ""
			if actor.has_method("get_belief_value"):
				var loc_val = actor.get_belief_value(g_target, "location", null)
				if loc_val != null and str(loc_val) != "":
					believed_loc = str(loc_val)
				else:
					var default_val = actor.get_belief_value(g_target, "default_room", null)
					if default_val != null and str(default_val) != "":
						believed_loc = str(default_val)

			if not believed_loc.is_empty():
				var dist_cur: int = world_graph.get_distance(actor.current_location, believed_loc)
				var dist_next: int = world_graph.get_distance(neighbor_id, believed_loc)
				if dist_next < dist_cur and dist_cur >= 0:
					move_score += priority_weight
				elif dist_next > dist_cur:
					move_score -= priority_weight * 0.5
			else:
				# If character location is unknown, actor searches communal exploratory spaces
				if neighbor_id in ["lobby", "hallway_1", "hallway_2", "laundry_room"]:
					move_score += priority_weight * 0.4

		# 3. Avoid character goal
		elif g_type == "avoid_character" and not g_target.is_empty():
			# Rely on subjective Belief regarding target's location instead of global truth
			var avoid_loc: String = ""
			if actor.has_method("get_belief_value"):
				var loc_val = actor.get_belief_value(g_target, "location", null)
				if loc_val != null and str(loc_val) != "":
					avoid_loc = str(loc_val)

			# If actor directly perceives target in current room, recognize it
			if avoid_loc.is_empty():
				var target_char = characters.get(g_target, null) as CharacterState
				if target_char != null and target_char.current_location == actor.current_location:
					avoid_loc = actor.current_location

			if not avoid_loc.is_empty():
				if neighbor_id == avoid_loc:
					move_score -= 3.5
				elif actor.current_location == avoid_loc:
					move_score += 2.5

	return move_score

func _evaluate_flee_goal(actor: CharacterState, characters: Dictionary) -> float:
	var score: float = 0.0
	for g in actor.goals:
		if g is Dictionary and g.get("type", "") == "avoid_character":
			var avoid_target = g.get("target", "")
			var other = characters.get(avoid_target, null) as CharacterState
			if other != null and other.current_location == actor.current_location:
				score += 3.5
	return score

func _get_relationship_value(actor: CharacterState, other_id: String, field: String) -> float:
	if actor == null or other_id.is_empty():
		return 0.0
	if actor.has_method("get_relationship_value"):
		return actor.get_relationship_value(other_id, field)
	if actor.relationships.has(other_id):
		var rel = actor.relationships[other_id]
		if rel is Dictionary:
			return float(rel.get(field, 0.0))
		elif rel != null and rel.has_method("get_value"):
			return float(rel.get_value(field))
	return 0.0

func _format_explanation(action: BaseAction, total: float, reasons: Dictionary) -> String:
	var desc: String = action.action_name
	if not action.target_id.is_empty():
		desc += " -> %s" % action.target_id
	var parts: Array[String] = []
	for k in reasons.keys():
		var v: float = float(reasons[k])
		if absf(v) >= 0.05:
			parts.append("%s: %+.2f" % [k, v])
	return "%s (Score: %.2f) [%s]" % [desc, total, ", ".join(parts)]

## Returns {"modifier": float, "event_ids": Array[String]} so decisions swayed
## by specific past events (TASK-013) can reference them as parent_event_ids.
func _evaluate_memory_modifier(actor: CharacterState, action: BaseAction, context: Dictionary) -> Dictionary:
	if actor == null or actor.memories.is_empty():
		var empty_ids: Array[String] = []
		return {"modifier": 0.0, "event_ids": empty_ids}

	var mod: float = 0.0
	var event_ids: Array[String] = []
	var target_id: String = action.target_id
	var characters: Dictionary = context.get("characters", {})

	match action.id:
		"help":
			if not target_id.is_empty():
				for m in actor.memories:
					var m_event: String = m.event_type if m is MemoryClass else str(m.get("event_type", ""))
					var m_parts: Array = m.participants if m is MemoryClass else m.get("participants", [])
					var m_actor: String = (m.facts.get("actor", "") if (m is MemoryClass and not m.facts.is_empty()) else "") if m is MemoryClass else m.get("facts", {}).get("actor", "")
					var impact: float = m.emotional_impact if m is MemoryClass else float(m.get("emotional_impact", 0.0))
					var imp: float = m.importance if m is MemoryClass else float(m.get("importance", 0.5))

					# If target previously helped or gifted actor
					if (m_event in ["help", "give_item"]) and (m_actor == target_id or target_id in m_parts):
						if impact > 0.0:
							mod += imp * impact * 2.5
							_append_event_id(event_ids, _mem_event_id(m))
					# If target previously harmed or confronted actor
					elif (m_event in ["confront", "take_item", "refuse"]) and (m_actor == target_id or target_id in m_parts):
						if impact < 0.0:
							mod -= imp * absf(impact) * 1.5
							_append_event_id(event_ids, _mem_event_id(m))

		"confront":
			if not target_id.is_empty():
				for m in actor.memories:
					var m_event: String = m.event_type if m is MemoryClass else str(m.get("event_type", ""))
					var m_parts: Array = m.participants if m is MemoryClass else m.get("participants", [])
					var m_actor: String = (m.facts.get("actor", "") if (m is MemoryClass and not m.facts.is_empty()) else "") if m is MemoryClass else m.get("facts", {}).get("actor", "")
					var impact: float = m.emotional_impact if m is MemoryClass else float(m.get("emotional_impact", 0.0))
					var imp: float = m.importance if m is MemoryClass else float(m.get("importance", 0.5))

					# Grievances: target confronted, refused, or stole from actor
					if (m_event in ["confront", "refuse", "take_item"]) and (m_actor == target_id or target_id in m_parts):
						if impact < 0.0:
							mod += imp * absf(impact) * 2.2
							_append_event_id(event_ids, _mem_event_id(m))
					# Benefactor memory reduces confrontation desire
					elif (m_event in ["help", "give_item"]) and (m_actor == target_id or target_id in m_parts):
						if impact > 0.0:
							mod -= imp * impact * 1.8
							_append_event_id(event_ids, _mem_event_id(m))

		"refuse":
			if not target_id.is_empty():
				for m in actor.memories:
					var m_event: String = m.event_type if m is MemoryClass else str(m.get("event_type", ""))
					var m_parts: Array = m.participants if m is MemoryClass else m.get("participants", [])
					var m_actor: String = (m.facts.get("actor", "") if (m is MemoryClass and not m.facts.is_empty()) else "") if m is MemoryClass else m.get("facts", {}).get("actor", "")
					var imp: float = m.importance if m is MemoryClass else float(m.get("importance", 0.5))

					if (m_event in ["confront", "refuse", "take_item"]) and (m_actor == target_id or target_id in m_parts):
						mod += imp * 1.5
						_append_event_id(event_ids, _mem_event_id(m))
					elif (m_event in ["help", "give_item"]) and (m_actor == target_id or target_id in m_parts):
						mod -= imp * 1.8
						_append_event_id(event_ids, _mem_event_id(m))

		"talk":
			if not target_id.is_empty():
				for m in actor.memories:
					var m_parts: Array = m.participants if m is MemoryClass else m.get("participants", [])
					if target_id in m_parts:
						var impact: float = m.emotional_impact if m is MemoryClass else float(m.get("emotional_impact", 0.0))
						var imp: float = m.importance if m is MemoryClass else float(m.get("importance", 0.5))
						mod += imp * impact * 1.2
						_append_event_id(event_ids, _mem_event_id(m))

		"flee":
			# Fleeing instinct triggered if co-located with someone who previously confronted actor
			for other_id in characters.keys():
				if other_id != actor.id:
					var other = characters[other_id] as CharacterState
					if other != null and other.current_location == actor.current_location:
						for m in actor.memories:
							var m_event: String = m.event_type if m is MemoryClass else str(m.get("event_type", ""))
							var m_parts: Array = m.participants if m is MemoryClass else m.get("participants", [])
							if m_event in ["confront", "take_item"] and other_id in m_parts:
								var imp: float = m.importance if m is MemoryClass else float(m.get("importance", 0.5))
								mod += imp * 2.0
								_append_event_id(event_ids, _mem_event_id(m))

	return {"modifier": clampf(mod, -5.0, 5.0), "event_ids": event_ids}

func _append_event_id(event_ids: Array[String], event_id: String) -> void:
	if not event_id.is_empty() and not event_id in event_ids:
		event_ids.append(event_id)

func _mem_event_id(m) -> String:
	return m.related_event_id if m is MemoryClass else str(m.get("related_event_id", ""))
