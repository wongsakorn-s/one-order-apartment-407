class_name TestActions
extends RefCounted

## Automated test suite for TASK-005: Action System.
## Verifies BaseAction lifecycle, 11 actions, precondition validation,
## co-location requirements, anti-teleportation constraints, and structured events.

const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
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

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_character_can_execute_idle())
	results.append(_test_character_can_move_between_locations())
	results.append(_test_cannot_teleport_across_disconnected_nodes())
	results.append(_test_talk_only_when_colocated())
	results.append(_test_invalid_actions_fail_safely())
	results.append(_test_actions_have_measurable_duration())
	results.append(_test_action_completion_generates_structured_event())
	results.append(_test_item_transfer_actions())
	results.append(_test_rest_and_investigate_actions())
	results.append(_test_runner_action_integration())
	return results

static func _test_character_can_execute_idle() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()

	var action = IdleActionClass.new("char_protagonist", 10.0)
	if not action.can_execute(context):
		runner.free()
		return {"name": "test_character_can_execute_idle", "passed": false, "error": "Idle should always be executable"}

	var started = action.start(context)
	if not started or action.status != BaseActionClass.Status.RUNNING:
		runner.free()
		return {"name": "test_character_can_execute_idle", "passed": false, "error": "Idle failed to start"}

	action.tick(5.0, context)
	if not is_equal_approx(action.get_progress(), 0.5):
		runner.free()
		return {"name": "test_character_can_execute_idle", "passed": false, "error": "Progress mismatch at half time"}

	action.tick(5.0, context)
	if action.status != BaseActionClass.Status.COMPLETED:
		runner.free()
		return {"name": "test_character_can_execute_idle", "passed": false, "error": "Idle failed to complete after full duration"}

	runner.free()
	return {"name": "test_character_can_execute_idle", "passed": true}

static func _test_character_can_move_between_locations() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()
	var protagonist = runner.get_protagonist()

	# Start in room_101. Connected to hallway_1.
	protagonist.current_location = "room_101"
	var move_action = MoveToActionClass.new("char_protagonist", "hallway_1", 15.0)

	if not move_action.can_execute(context):
		runner.free()
		return {"name": "test_character_can_move_between_locations", "passed": false, "error": "Moving to adjacent room should be valid: %s" % move_action.failure_reason}

	move_action.start(context)
	# Location should NOT change while moving
	if protagonist.current_location != "room_101":
		runner.free()
		return {"name": "test_character_can_move_between_locations", "passed": false, "error": "Location changed before action completion"}

	move_action.tick(15.0, context)
	if protagonist.current_location != "hallway_1":
		runner.free()
		return {"name": "test_character_can_move_between_locations", "passed": false, "error": "Location not updated after move completed"}

	runner.free()
	return {"name": "test_character_can_move_between_locations", "passed": true}

static func _test_cannot_teleport_across_disconnected_nodes() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()
	var protagonist = runner.get_protagonist()
	protagonist.current_location = "room_101"

	# room_101 is NOT connected to rooftop or room_203
	var invalid_move = MoveToActionClass.new("char_protagonist", "rooftop", 15.0)

	if invalid_move.can_execute(context):
		runner.free()
		return {"name": "test_cannot_teleport_across_disconnected_nodes", "passed": false, "error": "Moving across disconnected nodes must be rejected"}

	var started = invalid_move.start(context)
	if started or invalid_move.status != BaseActionClass.Status.FAILED:
		runner.free()
		return {"name": "test_cannot_teleport_across_disconnected_nodes", "passed": false, "error": "Disconnected move action should fail start"}

	if protagonist.current_location != "room_101":
		runner.free()
		return {"name": "test_cannot_teleport_across_disconnected_nodes", "passed": false, "error": "Protagonist teleported despite failed action"}

	runner.free()
	return {"name": "test_cannot_teleport_across_disconnected_nodes", "passed": true}

static func _test_talk_only_when_colocated() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()
	var protagonist = runner.get_protagonist()
	var nina = runner.get_character("npc_nina")

	# 1. Different locations -> Talk must fail
	protagonist.current_location = "room_101"
	nina.current_location = "room_102"

	var talk_action = TalkActionClass.new("char_protagonist", "npc_nina", 20.0)
	if talk_action.can_execute(context):
		runner.free()
		return {"name": "test_talk_only_when_colocated", "passed": false, "error": "Talk should fail when characters are in different rooms"}

	var started = talk_action.start(context)
	if started or talk_action.status != BaseActionClass.Status.FAILED:
		runner.free()
		return {"name": "test_talk_only_when_colocated", "passed": false, "error": "Talk start should fail when not co-located"}

	# 2. Co-located -> Talk must succeed
	nina.current_location = "room_101"
	var colocated_talk = TalkActionClass.new("char_protagonist", "npc_nina", 20.0)
	if not colocated_talk.can_execute(context):
		runner.free()
		return {"name": "test_talk_only_when_colocated", "passed": false, "error": "Talk should pass when characters are in the same room: %s" % colocated_talk.failure_reason}

	colocated_talk.start(context)
	colocated_talk.tick(20.0, context)
	if colocated_talk.status != BaseActionClass.Status.COMPLETED:
		runner.free()
		return {"name": "test_talk_only_when_colocated", "passed": false, "error": "Talk action failed to complete"}

	runner.free()
	return {"name": "test_talk_only_when_colocated", "passed": true}

static func _test_invalid_actions_fail_safely() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()

	# 1. Non-existent actor
	var action_bad_actor = IdleActionClass.new("non_existent_ghost", 10.0)
	if action_bad_actor.can_execute(context) or action_bad_actor.start(context):
		runner.free()
		return {"name": "test_invalid_actions_fail_safely", "passed": false, "error": "Action with non-existent actor must fail"}

	# 2. Non-existent destination
	var action_bad_dest = MoveToActionClass.new("char_protagonist", "narnia_room_999", 10.0)
	if action_bad_dest.can_execute(context) or action_bad_dest.start(context):
		runner.free()
		return {"name": "test_invalid_actions_fail_safely", "passed": false, "error": "Action with invalid destination must fail"}

	# 3. Talk to self
	var talk_self = TalkActionClass.new("char_protagonist", "char_protagonist", 10.0)
	if talk_self.can_execute(context) or talk_self.start(context):
		runner.free()
		return {"name": "test_invalid_actions_fail_safely", "passed": false, "error": "Talk to self must fail"}

	# 4. Give item not possessed
	var give_unowned = GiveItemActionClass.new("char_protagonist", "npc_nina", "golden_statue_unowned", 10.0)
	runner.get_character("npc_nina").current_location = runner.get_protagonist().current_location
	if give_unowned.can_execute(context) or give_unowned.start(context):
		runner.free()
		return {"name": "test_invalid_actions_fail_safely", "passed": false, "error": "Giving unpossessed item must fail"}

	runner.free()
	return {"name": "test_invalid_actions_fail_safely", "passed": true}

static func _test_actions_have_measurable_duration() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()

	var action = RestActionClass.new("char_protagonist", "", 30.0)
	action.start(context)

	if action.duration <= 0.0:
		runner.free()
		return {"name": "test_actions_have_measurable_duration", "passed": false, "error": "Action duration is not measurable"}

	action.tick(10.0, context)
	if not is_equal_approx(action.get_progress(), 10.0 / 30.0):
		runner.free()
		return {"name": "test_actions_have_measurable_duration", "passed": false, "error": "Progress mismatch at 10s"}

	action.tick(10.0, context)
	if not is_equal_approx(action.get_progress(), 20.0 / 30.0):
		runner.free()
		return {"name": "test_actions_have_measurable_duration", "passed": false, "error": "Progress mismatch at 20s"}

	action.tick(10.0, context)
	if action.status != BaseActionClass.Status.COMPLETED or not is_equal_approx(action.get_progress(), 1.0):
		runner.free()
		return {"name": "test_actions_have_measurable_duration", "passed": false, "error": "Action did not complete at duration boundary"}

	runner.free()
	return {"name": "test_actions_have_measurable_duration", "passed": true}

static func _test_action_completion_generates_structured_event() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()

	var action = IdleActionClass.new("char_protagonist", 5.0)
	action.start(context)
	var evt = action.complete(context)

	if evt == null:
		runner.free()
		return {"name": "test_action_completion_generates_structured_event", "passed": false, "error": "complete() did not return an event"}

	var d: Dictionary = evt.to_dict()
	var required_keys = ["id", "timestamp", "event_type", "actor_id", "location_id", "description", "metadata"]
	for k in required_keys:
		if not d.has(k):
			runner.free()
			return {"name": "test_action_completion_generates_structured_event", "passed": false, "error": "Event missing key: %s" % k}

	if evt.actor_id != "char_protagonist" or evt.event_type != "idle":
		runner.free()
		return {"name": "test_action_completion_generates_structured_event", "passed": false, "error": "Event fields corrupted"}

	var readable = evt.get_readable_text()
	if readable.is_empty():
		runner.free()
		return {"name": "test_action_completion_generates_structured_event", "passed": false, "error": "get_readable_text() returned empty string"}

	runner.free()
	return {"name": "test_action_completion_generates_structured_event", "passed": true}

static func _test_item_transfer_actions() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()

	var protagonist = runner.get_protagonist()
	var nina = runner.get_character("npc_nina")

	# Place both in room_101
	protagonist.current_location = "room_101"
	nina.current_location = "room_101"

	protagonist.inventory = ["special_key"]
	nina.inventory = []

	# GiveItem: protagonist -> nina
	var give_action = GiveItemActionClass.new("char_protagonist", "npc_nina", "special_key", 5.0)
	if not give_action.can_execute(context):
		runner.free()
		return {"name": "test_item_transfer_actions", "passed": false, "error": "GiveItem can_execute failed: %s" % give_action.failure_reason}

	give_action.start(context)
	give_action.tick(5.0, context)

	if "special_key" in protagonist.inventory or not ("special_key" in nina.inventory):
		runner.free()
		return {"name": "test_item_transfer_actions", "passed": false, "error": "GiveItem failed to transfer item"}

	# TakeItem: protagonist takes special_key back from nina
	var take_action = TakeItemActionClass.new("char_protagonist", "special_key", "npc_nina", 5.0)
	if not take_action.can_execute(context):
		runner.free()
		return {"name": "test_item_transfer_actions", "passed": false, "error": "TakeItem can_execute failed: %s" % take_action.failure_reason}

	take_action.start(context)
	take_action.tick(5.0, context)

	if not ("special_key" in protagonist.inventory) or "special_key" in nina.inventory:
		runner.free()
		return {"name": "test_item_transfer_actions", "passed": false, "error": "TakeItem failed to reclaim item"}

	runner.free()
	return {"name": "test_item_transfer_actions", "passed": true}

static func _test_rest_and_investigate_actions() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var context = runner.get_simulation_context()
	var protagonist = runner.get_protagonist()
	protagonist.current_location = "room_101"

	# Rest Action increases rest
	var initial_rest = protagonist.get_need("rest")
	var rest_action = RestActionClass.new("char_protagonist", "room_101", 10.0)
	rest_action.start(context)
	rest_action.tick(10.0, context)
	if protagonist.get_need("rest") <= initial_rest:
		runner.free()
		return {"name": "test_rest_and_investigate_actions", "passed": false, "error": "Rest did not increase rest need"}

	# Investigate Action increases information
	var initial_info = protagonist.get_need("information")
	var inv_action = InvestigateActionClass.new("char_protagonist", "room_101", 10.0)
	inv_action.start(context)
	inv_action.tick(10.0, context)
	if protagonist.get_need("information") <= initial_info:
		runner.free()
		return {"name": "test_rest_and_investigate_actions", "passed": false, "error": "Investigate did not increase information need"}

	runner.free()
	return {"name": "test_rest_and_investigate_actions", "passed": true}

static func _test_runner_action_integration() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var protagonist = runner.get_protagonist()
	protagonist.current_location = "room_101"

	# Assign MoveTo action through runner
	var move_action = MoveToActionClass.new("char_protagonist", "hallway_1", 10.0)
	var executed = runner.execute_character_action("char_protagonist", move_action)
	if not executed:
		runner.free()
		return {"name": "test_runner_action_integration", "passed": false, "error": "runner.execute_character_action failed"}

	if protagonist.active_action == null:
		runner.free()
		return {"name": "test_runner_action_integration", "passed": false, "error": "Character active_action was not set"}

	# Advance runner physics process by 10s simulation time (at 1x speed, 60 sim sec / 1 real sec -> 10 sim sec = 10/60 real sec)
	var real_delta = 10.0 / 60.0
	runner._physics_process(real_delta)

	if protagonist.current_location != "hallway_1":
		runner.free()
		return {"name": "test_runner_action_integration", "passed": false, "error": "Character did not move after runner simulation tick"}

	var events = runner.get_events()
	if events.is_empty():
		runner.free()
		return {"name": "test_runner_action_integration", "passed": false, "error": "No event recorded in runner after action completed"}

	runner.free()
	return {"name": "test_runner_action_integration", "passed": true}
