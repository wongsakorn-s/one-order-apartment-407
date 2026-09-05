class_name InvestigateAction
extends BaseAction

## InvestigateAction allows a character to investigate a specific room or object.
## Requires the character to be at the target location or in possession of the item.

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 25.0
) -> void:
	super._init("investigate", "Investigate", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor == null:
		failure_reason = "Actor not found"
		return false

	var world_graph: WorldGraph = context.get("world_graph", null)
	if target_id.is_empty():
		failure_reason = "Target for investigation cannot be empty"
		return false

	# If target is a valid world location, actor must be physically present there
	if world_graph != null and world_graph.has_location(target_id):
		if actor.current_location != target_id:
			failure_reason = "Actor must be at %s to investigate it (currently in %s)" % [target_id, actor.current_location]
			return false
	else:
		# If target is an item, actor must possess it
		if not target_id in actor.inventory:
			failure_reason = "Actor does not possess item %s to investigate" % target_id
			return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor != null:
		# Gain information
		actor.set_need("information", actor.get_need("information") + 0.10)
		# Investigating Room 407 causes slight tension/stress
		if target_id == "room_407":
			actor.set_emotion("stress", actor.get_emotion("stress") + 0.05)
			actor.set_emotion("fear", actor.get_emotion("fear") + 0.05)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	return "%s investigated %s" % [actor_name, target_id.capitalize()]
