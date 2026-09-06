class_name GiveItemAction
extends BaseAction

## GiveItemAction transfers an item from the actor's inventory to a co-located target.
## Validates item possession and physical co-location.

var item_name: String = ""

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_item_name: String = "",
	p_duration: float = 10.0
) -> void:
	super._init("give_item", "Give Item", p_actor_id, p_target_id, p_duration)
	item_name = p_item_name
	metadata["item_name"] = item_name

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot give item to self"
		return false
	if item_name.is_empty():
		failure_reason = "Item name cannot be empty"
		return false

	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor == null or target == null:
		failure_reason = "Actor or target not found"
		return false

	if actor.current_location != target.current_location:
		failure_reason = "Actor and target must be co-located"
		return false

	if not item_name in actor.inventory:
		failure_reason = "Actor %s does not possess item %s" % [actor.name, item_name]
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor != null and target != null:
		actor.inventory.erase(item_name)
		target.inventory.append(item_name)
		# Beneficial social effect
		actor.set_need("social", actor.get_need("social") + 0.05)
		target.set_emotion("happiness", target.get_emotion("happiness") + 0.05)

		# Target toward Actor: trust +0.15, debt +0.15
		target.modify_relationship(actor_id, "trust", 0.15)
		target.modify_relationship(actor_id, "debt", 0.15)
		# Actor toward Target: trust +0.05
		actor.modify_relationship(target_id, "trust", 0.05)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	return "%s gave %s to %s" % [a_name, item_name, t_name]

