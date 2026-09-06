class_name BaseAction
extends RefCounted

## BaseAction is the pure simulation base class for all character actions.
## Manages status lifecycle, preconditions, elapsed duration, effects, and structured event generation.
## Completely decoupled from scene nodes and rendering.

const SimulationEventClass = preload("res://scripts/events/simulation_event.gd")

enum Status {
	PENDING,
	RUNNING,
	COMPLETED,
	FAILED,
	CANCELLED
}

var id: String = "base_action"
var action_name: String = "Base Action"
var actor_id: String = ""
var target_id: String = ""
var duration: float = 10.0 # Duration in simulation seconds
var elapsed_time: float = 0.0
var status: Status = Status.PENDING
var failure_reason: String = ""
var metadata: Dictionary = {}

## TASK-013: Causal Event System.
## reasons and parent_event_ids are populated externally by SimulationRunner
## from the UtilityDecision that selected this action (structured contribution
## breakdown and any memories of past events that swayed the choice), so the
## resulting SimulationEvent can explain WHY the action was chosen, not just
## what it did. state_changes is populated by subclasses in _apply_effects()
## to record the concrete simulation state deltas this action caused.
var reasons: Dictionary = {}
var parent_event_ids: Array[String] = []
var state_changes: Dictionary = {}

func _init(
	p_id: String = "base_action",
	p_action_name: String = "Base Action",
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 10.0,
	p_metadata: Dictionary = {}
) -> void:
	id = p_id
	action_name = p_action_name
	actor_id = p_actor_id
	target_id = p_target_id
	duration = maxf(p_duration, 0.1)
	elapsed_time = 0.0
	status = Status.PENDING
	failure_reason = ""
	metadata = p_metadata

## Verify preconditions required to begin executing this action.
func can_execute(context: Dictionary) -> bool:
	if actor_id.is_empty():
		failure_reason = "Actor ID is empty"
		return false

	var characters: Dictionary = context.get("characters", {})
	if not characters.has(actor_id):
		failure_reason = "Actor %s does not exist in simulation" % actor_id
		return false

	return _check_preconditions(context)

## Subclasses override to validate specific prerequisites.
func _check_preconditions(_context: Dictionary) -> bool:
	return true

## Start the action if preconditions pass. Returns true if successfully started.
func start(context: Dictionary) -> bool:
	if not can_execute(context):
		fail(failure_reason if not failure_reason.is_empty() else "Preconditions not satisfied")
		return false

	status = Status.RUNNING
	elapsed_time = 0.0
	_on_start(context)
	return true

## Subclasses may override for initial setup logic.
func _on_start(_context: Dictionary) -> void:
	pass

## Advance execution time by delta_sim_seconds.
func tick(delta_sim_seconds: float, context: Dictionary) -> void:
	if status != Status.RUNNING:
		return

	elapsed_time += delta_sim_seconds
	_on_tick(delta_sim_seconds, context)

	if elapsed_time >= duration:
		complete(context)

## Subclasses may override for per-tick logic.
func _on_tick(_delta_sim_seconds: float, _context: Dictionary) -> void:
	pass

## Complete the action, apply simulation effects, and create a structured event.
func complete(context: Dictionary) -> SimulationEvent:
	status = Status.COMPLETED
	elapsed_time = duration
	_apply_effects(context)
	return _create_completion_event(context)

## Subclasses override to mutate simulation state (characters, locations, items).
func _apply_effects(_context: Dictionary) -> void:
	pass

## Generate the structured event representing the completion of this action.
func _create_completion_event(context: Dictionary) -> SimulationEvent:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	var loc: String = actor.current_location if actor != null else ""
	var sim_time: float = context.get("sim_time", 0.0)

	var desc: String = get_readable_description(context)

	return SimulationEventClass.new(
		"evt_%s_%d" % [id, int(sim_time * 10.0)],
		sim_time,
		id,
		actor_id,
		target_id,
		loc,
		desc,
		metadata,
		parent_event_ids,
		reasons,
		state_changes
	)

## Return a human-readable description of this action for logging and UI.
func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	return "%s performed %s" % [actor_name, action_name]

## Mark the action as failed with a specified explanation.
func fail(reason: String) -> void:
	status = Status.FAILED
	failure_reason = reason

## Cancel the action while running or pending.
func cancel(reason: String = "Action cancelled") -> void:
	status = Status.CANCELLED
	failure_reason = reason

## Returns normalized progress from 0.0 to 1.0.
func get_progress() -> float:
	if duration <= 0.0:
		return 1.0 if status == Status.COMPLETED else 0.0
	return clampf(elapsed_time / duration, 0.0, 1.0)

## Export action status as a dictionary for UI inspection and debugging.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": action_name,
		"actor_id": actor_id,
		"target_id": target_id,
		"duration": duration,
		"elapsed_time": elapsed_time,
		"progress": get_progress(),
		"status": status,
		"status_name": _get_status_name(),
		"failure_reason": failure_reason,
		"description": get_readable_description(),
		"reasons": reasons.duplicate(true),
		"parent_event_ids": parent_event_ids.duplicate()
	}

func _get_status_name() -> String:
	match status:
		Status.PENDING: return "PENDING"
		Status.RUNNING: return "RUNNING"
		Status.COMPLETED: return "COMPLETED"
		Status.FAILED: return "FAILED"
		Status.CANCELLED: return "CANCELLED"
		_: return "UNKNOWN"

