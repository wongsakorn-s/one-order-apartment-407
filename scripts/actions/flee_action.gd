class_name FleeAction
extends BaseAction

## FleeAction moves a character rapidly away to an adjacent location.
## Requires direct connectivity in WorldGraph.

var from_location: String = ""

func _init(
	p_actor_id: String = "",
	p_destination_id: String = "",
	p_duration: float = 8.0
) -> void:
	super._init("flee", "Flee", p_actor_id, p_destination_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor == null:
		failure_reason = "Actor not found"
		return false

	var world_graph: WorldGraph = context.get("world_graph", null)
	if world_graph == null:
		failure_reason = "WorldGraph missing"
		return false

	if not world_graph.has_location(target_id):
		failure_reason = "Escape destination %s does not exist" % target_id
		return false

	from_location = actor.current_location
	if from_location == target_id:
		failure_reason = "Cannot flee to current location"
		return false

	if not world_graph.are_locations_connected(from_location, target_id):
		failure_reason = "Locations %s and %s are not connected" % [from_location, target_id]
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor != null:
		from_location = actor.current_location
		actor.current_location = target_id
		actor.set_need("safety", actor.get_need("safety") + 0.10)
		actor.set_emotion("stress", actor.get_emotion("stress") + 0.05)
		state_changes = {
			"location": {"from": from_location, "to": target_id},
			"safety_delta": 0.10,
			"stress_delta": 0.05
		}

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	var origin: String = from_location if not from_location.is_empty() else (actor.current_location if actor != null else "danger")
	return "%s fled from %s to %s" % [actor_name, origin.capitalize(), target_id.capitalize()]

