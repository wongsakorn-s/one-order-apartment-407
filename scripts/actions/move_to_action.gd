class_name MoveToAction
extends BaseAction

## MoveToAction moves a character between directly connected logical locations.
## Validates adjacency in WorldGraph to prevent teleportation across disconnected nodes.

var from_location: String = ""

func _init(
	p_actor_id: String = "",
	p_destination_id: String = "",
	p_duration: float = 15.0
) -> void:
	super._init("move_to", "Move To", p_actor_id, p_destination_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor == null:
		failure_reason = "Actor not found"
		return false

	var world_graph: WorldGraph = context.get("world_graph", null)
	if world_graph == null:
		failure_reason = "WorldGraph missing in context"
		return false

	if not world_graph.has_location(target_id):
		failure_reason = "Destination location %s does not exist" % target_id
		return false

	from_location = actor.current_location
	if from_location == target_id:
		failure_reason = "Actor is already at destination %s" % target_id
		return false

	# Must be directly connected neighbor in WorldGraph
	if not world_graph.are_locations_connected(from_location, target_id):
		failure_reason = "Locations %s and %s are not directly connected" % [from_location, target_id]
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor != null:
		from_location = actor.current_location
		actor.current_location = target_id

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	var origin: String = from_location if not from_location.is_empty() else (actor.current_location if actor != null else "somewhere")
	return "%s moved from %s to %s" % [actor_name, origin.capitalize(), target_id.capitalize()]
