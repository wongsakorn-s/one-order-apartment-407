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
		state_changes = {"information_delta": 0.10}
		# Investigating Room 407 causes slight tension/stress
		if target_id == "room_407":
			actor.set_emotion("stress", actor.get_emotion("stress") + 0.05)
			actor.set_emotion("fear", actor.get_emotion("fear") + 0.05)
			state_changes["stress_delta"] = 0.05
			state_changes["fear_delta"] = 0.05

		# TASK-015: any character investigating a location may independently
		# discover and pick up world-truth items left there (e.g. hidden cash,
		# stolen goods, abandoned belongings), regardless of who placed them.
		var world_graph: WorldGraph = context.get("world_graph", null)
		if world_graph != null and world_graph.has_location(target_id):
			var loc: Location = world_graph.get_location(target_id)
			if loc != null and not loc.items.is_empty():
				var found_item: String = loc.items[0]
				loc.remove_item(found_item)
				if not found_item in actor.inventory:
					actor.inventory.append(found_item)
				actor.set_belief(target_id, "contained_item", found_item, 1.0, "self", float(context.get("sim_time", 0.0)))
				metadata["found_item"] = found_item
				state_changes["item_found"] = {"item": found_item, "location": target_id, "by": actor_id}

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	if metadata.has("found_item"):
		return "%s investigated %s and found %s" % [actor_name, target_id.capitalize(), metadata["found_item"]]
	return "%s investigated %s" % [actor_name, target_id.capitalize()]

