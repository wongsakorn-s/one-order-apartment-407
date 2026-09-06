class_name TestCausalEvents
extends RefCounted

## Automated test suite for TASK-013: Causal Event System.
## Validates:
## 1. Important actions produce causal events carrying structured fields
##    (not just human-readable strings): reasons, parent_event_ids, state_changes.
## 2. Events have stable, globally unique IDs even within the same tick.
## 3. AI decision events store reason components (goal/personality/relationship/
##    memory/directive contribution breakdown), not just a human-readable string.
## 4. Later events can reference earlier events (via memory-derived parent_event_ids).
## 5. The parent chain can be reconstructed by looking up referenced IDs in the log.
## 6. The event feed still produces readable descriptions.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")
const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const IdleActionClass = preload("res://scripts/actions/idle_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_action_completion_produces_structured_causal_fields())
	results.append(test_events_have_stable_unique_ids_within_same_tick())
	results.append(test_ai_decision_stores_structured_reason_components())
	results.append(test_later_event_references_earlier_event_via_memory())
	results.append(test_parent_chain_can_be_reconstructed_from_event_log())
	results.append(test_event_feed_still_shows_readable_descriptions())
	return results

static func test_action_completion_produces_structured_causal_fields() -> Dictionary:
	var test_name = "test_action_completion_produces_structured_causal_fields"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var help_action = HelpActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()
	if not help_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "HelpAction failed to start: %s" % help_action.failure_reason}
	help_action.tick(1.0, context)
	var evt = help_action._create_completion_event(context)

	var d: Dictionary = evt.to_dict()
	for k in ["parent_event_ids", "reasons", "state_changes"]:
		if not d.has(k):
			runner.free()
			return {"name": test_name, "passed": false, "error": "Event missing structured key: %s" % k}

	if not (d["state_changes"] is Dictionary) or d["state_changes"].is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "state_changes should be a non-empty structured Dictionary for a meaningful action"}

	# state_changes must carry real structured data (a relationship delta dict),
	# not merely a human-readable string.
	if not d["state_changes"].has("relationship_target_to_actor"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "state_changes missing expected structured relationship delta"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_events_have_stable_unique_ids_within_same_tick() -> Dictionary:
	var test_name = "test_events_have_stable_unique_ids_within_same_tick"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 111
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var context = runner.get_simulation_context()

	# Two different actions completing at the exact same sim_time would collide
	# under the old "evt_<type>_<decisecond>" scheme when actor/type also match.
	var idle1 = IdleActionClass.new(actor.id, 1.0)
	idle1.start(context)
	idle1.tick(1.0, context)
	var evt1 = idle1._create_completion_event(context)

	var idle2 = IdleActionClass.new(actor.id, 1.0)
	idle2.start(context)
	idle2.tick(1.0, context)
	var evt2 = idle2._create_completion_event(context)

	# Both drafts would naturally collide before the runner assigns real IDs.
	if evt1.id != evt2.id:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Test setup invalid: draft IDs should collide before runner assignment"}

	runner._record_event(evt1)
	runner._record_event(evt2)

	if evt1.id == evt2.id:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Runner failed to assign unique IDs to two events recorded in the same tick"}

	if evt1.id.is_empty() or evt2.id.is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "Assigned event IDs must not be empty"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_ai_decision_stores_structured_reason_components() -> Dictionary:
	var test_name = "test_ai_decision_stores_structured_reason_components"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 222
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"
	actor.set_personality_trait("empathy", 0.9)

	var ai = UtilityAIClass.new()
	var context = runner.get_simulation_context()
	var help_action = HelpActionClass.new(actor.id, target.id, 5.0)

	var eval: Dictionary = ai.score_action(actor, help_action, context)
	var reasons: Dictionary = eval.get("reasons", {})

	for k in ["goal", "personality", "relationship", "memory"]:
		if not reasons.has(k):
			runner.free()
			return {"name": test_name, "passed": false, "error": "AI reasons dict missing structured component '%s'" % k}

	# Wire reasons onto the action exactly as SimulationRunner does, then verify
	# the resulting event's reasons carry the same structured breakdown.
	help_action.reasons = reasons.duplicate(true)
	help_action.start(context)
	help_action.tick(5.0, context)
	var evt = help_action._create_completion_event(context)

	if not evt.reasons.has("personality"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Completed event lost structured reasons from the AI decision"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_later_event_references_earlier_event_via_memory() -> Dictionary:
	var test_name = "test_later_event_references_earlier_event_via_memory"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 333
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var context = runner.get_simulation_context()

	# Event A: target helps actor. This should give actor a memory referencing it.
	var help1 = HelpActionClass.new(target.id, actor.id, 1.0)
	if not help1.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Setup HelpAction failed to start: %s" % help1.failure_reason}
	help1.tick(1.0, context)
	var evt_a = help1._create_completion_event(context)
	runner._record_event(evt_a)

	var found_memory := false
	for m in actor.get_memories():
		if m.related_event_id == evt_a.id and m.event_type == "help":
			found_memory = true
	if not found_memory:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Actor did not gain a memory referencing event A"}

	# Actor now considers helping target back; the AI should surface event A as
	# a contributing memory reference for that candidate decision.
	var ai = UtilityAIClass.new()
	var help_candidate = HelpActionClass.new(actor.id, target.id, 5.0)
	var eval: Dictionary = ai.score_action(actor, help_candidate, runner.get_simulation_context())
	var contributing: Array = eval.get("contributing_event_ids", [])

	if not (evt_a.id in contributing):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Event A's ID missing from contributing_event_ids: %s" % str(contributing)}

	# Wire it through exactly as SimulationRunner would, then complete event B.
	help_candidate.parent_event_ids.assign(contributing)
	help_candidate.reasons = eval.get("reasons", {})
	help_candidate.start(runner.get_simulation_context())
	help_candidate.tick(5.0, runner.get_simulation_context())
	var evt_b = help_candidate._create_completion_event(runner.get_simulation_context())
	runner._record_event(evt_b)

	if not (evt_a.id in evt_b.parent_event_ids):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Event B does not reference event A as a parent"}

	if evt_a.id == evt_b.id:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Event A and event B must have distinct IDs"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_parent_chain_can_be_reconstructed_from_event_log() -> Dictionary:
	var test_name = "test_parent_chain_can_be_reconstructed_from_event_log"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 444
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var context = runner.get_simulation_context()

	var help1 = HelpActionClass.new(target.id, actor.id, 1.0)
	help1.start(context)
	help1.tick(1.0, context)
	var evt_a = help1._create_completion_event(context)
	runner._record_event(evt_a)

	var ai = UtilityAIClass.new()
	var help_candidate = HelpActionClass.new(actor.id, target.id, 5.0)
	var eval: Dictionary = ai.score_action(actor, help_candidate, runner.get_simulation_context())
	help_candidate.parent_event_ids.assign(eval.get("contributing_event_ids", []))
	help_candidate.start(runner.get_simulation_context())
	help_candidate.tick(5.0, runner.get_simulation_context())
	var evt_b = help_candidate._create_completion_event(runner.get_simulation_context())
	runner._record_event(evt_b)

	if evt_b.parent_event_ids.is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "Event B has no parent_event_ids to reconstruct from"}

	# Reconstruct: every ID referenced by event B's parent_event_ids must be
	# resolvable to a real, earlier entry in the simulation's event log.
	var log: Array[Dictionary] = runner.get_events()
	for parent_id in evt_b.parent_event_ids:
		var found := false
		for logged in log:
			if logged.get("id", "") == parent_id:
				found = true
				if float(logged.get("timestamp", 0.0)) > evt_b.timestamp:
					runner.free()
					return {"name": test_name, "passed": false, "error": "Parent event is not earlier than the child event"}
				break
		if not found:
			runner.free()
			return {"name": test_name, "passed": false, "error": "Parent event ID '%s' could not be resolved in the event log" % parent_id}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_event_feed_still_shows_readable_descriptions() -> Dictionary:
	var test_name = "test_event_feed_still_shows_readable_descriptions"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 555
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var context = runner.get_simulation_context()
	var help_action = HelpActionClass.new(actor.id, target.id, 1.0)
	help_action.start(context)
	help_action.tick(1.0, context)
	var evt = help_action._create_completion_event(context)
	runner._record_event(evt)

	var readable: String = evt.get_readable_text()
	if readable.is_empty():
		runner.free()
		return {"name": test_name, "passed": false, "error": "get_readable_text() returned empty string despite structured fields being populated"}

	if not (target.name in readable or actor.name in readable):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Readable text does not mention either participant: %s" % readable}

	runner.free()
	return {"name": test_name, "passed": true}
