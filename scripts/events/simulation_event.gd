class_name SimulationEvent
extends RefCounted

## SimulationEvent represents a structured domain event produced when actions complete or significant state changes occur.
## Pure simulation data class decoupled from scene nodes.

var id: String = ""
var timestamp: float = 0.0
var event_type: String = ""
var actor_id: String = ""
var target_id: String = ""
var location_id: String = ""
var description: String = ""
var metadata: Dictionary = {}

## TASK-013: Causal Event System.
## parent_event_ids reference earlier events that causally contributed to this
## one (e.g. a memory of a past event that swayed the decision). reasons holds
## the same structured contribution breakdown the Utility AI already computes
## (goal/personality/need/emotion/relationship/memory/directive), not just a
## human-readable string. state_changes records the concrete simulation state
## deltas this event's action applied.
var parent_event_ids: Array[String] = []
var reasons: Dictionary = {}
var state_changes: Dictionary = {}

func _init(
	p_id: String = "",
	p_timestamp: float = 0.0,
	p_event_type: String = "",
	p_actor_id: String = "",
	p_target_id: String = "",
	p_location_id: String = "",
	p_description: String = "",
	p_metadata: Dictionary = {},
	p_parent_event_ids: Array[String] = [],
	p_reasons: Dictionary = {},
	p_state_changes: Dictionary = {}
) -> void:
	id = p_id
	timestamp = p_timestamp
	event_type = p_event_type
	actor_id = p_actor_id
	target_id = p_target_id
	location_id = p_location_id
	description = p_description
	metadata = p_metadata
	parent_event_ids = p_parent_event_ids.duplicate()
	reasons = p_reasons.duplicate(true)
	state_changes = p_state_changes.duplicate(true)

## Convert event to serializable dictionary.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"timestamp": timestamp,
		"event_type": event_type,
		"actor_id": actor_id,
		"target_id": target_id,
		"location_id": location_id,
		"description": description,
		"metadata": metadata.duplicate(),
		"parent_event_ids": parent_event_ids.duplicate(),
		"reasons": reasons.duplicate(true),
		"state_changes": state_changes.duplicate(true)
	}

## Returns formatted readable time string (HH:MM) plus description.
func get_readable_text() -> String:
	var total_seconds: int = int(timestamp)
	var hours: int = (total_seconds / 3600) % 24
	var minutes: int = (total_seconds % 3600) / 60
	return "%02d:%02d - %s" % [hours, minutes, description]

