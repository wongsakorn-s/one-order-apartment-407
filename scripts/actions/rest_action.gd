class_name RestAction
extends BaseAction

## RestAction allows a character to rest in their current location.
## Restores rest need and reduces stress.

func _init(
	p_actor_id: String = "",
	p_location_id: String = "",
	p_duration: float = 30.0
) -> void:
	super._init("rest", "Rest", p_actor_id, p_location_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor == null:
		failure_reason = "Actor not found"
		return false

	var world_graph: WorldGraph = context.get("world_graph", null)
	if not target_id.is_empty() and world_graph != null:
		if not world_graph.has_location(target_id):
			failure_reason = "Rest location %s does not exist" % target_id
			return false
		if actor.current_location != target_id:
			failure_reason = "Actor must be at %s to rest there (currently in %s)" % [target_id, actor.current_location]
			return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor != null:
		actor.set_need("rest", actor.get_need("rest") + 0.20)
		actor.set_emotion("stress", actor.get_emotion("stress") - 0.10)
		actor.set_emotion("happiness", actor.get_emotion("happiness") + 0.05)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	var loc: String = actor.current_location if actor != null else target_id
	return "%s rested in %s" % [actor_name, loc.capitalize()]

