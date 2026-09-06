class_name TakeItemAction
extends BaseAction

## TakeItemAction allows a character to pick up an item or take it from another character.
## Checks item presence and physical co-location.

var source_character_id: String = ""

func _init(
	p_actor_id: String = "",
	p_item_name: String = "",
	p_source_char_id: String = "",
	p_duration: float = 10.0
) -> void:
	super._init("take_item", "Take Item", p_actor_id, p_item_name, p_duration)
	source_character_id = p_source_char_id

func _check_preconditions(context: Dictionary) -> bool:
	if target_id.is_empty():
		failure_reason = "Item name cannot be empty"
		return false

	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor == null:
		failure_reason = "Actor not found"
		return false

	if not source_character_id.is_empty():
		var source_char = characters.get(source_character_id, null)
		if source_char == null:
			failure_reason = "Source character %s not found" % source_character_id
			return false
		if actor.current_location != source_char.current_location:
			failure_reason = "Actor and source character must be co-located"
			return false
		if not target_id in source_char.inventory:
			failure_reason = "Source character %s does not have item %s" % [source_char.name, target_id]
			return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor == null:
		return

	state_changes = {"item_transfer": {"item": target_id, "to": actor_id}}

	if not source_character_id.is_empty():
		var source_char = characters.get(source_character_id, null)
		if source_char != null:
			source_char.inventory.erase(target_id)
			# Taking an item from a character harms trust and respect, increases suspicion
			source_char.modify_relationship(actor_id, "trust", -0.30)
			source_char.modify_relationship(actor_id, "suspicion", 0.25)
			source_char.modify_relationship(actor_id, "respect", -0.20)
			state_changes["item_transfer"]["from"] = source_character_id
			state_changes["relationship_source_to_actor"] = {"trust": -0.30, "suspicion": 0.25, "respect": -0.20}

	if not target_id in actor.inventory:
		actor.inventory.append(target_id)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	if not source_character_id.is_empty():
		var source_char = characters.get(source_character_id, null)
		var source_name: String = source_char.name if source_char != null else source_character_id
		return "%s took %s from %s" % [actor_name, target_id, source_name]
	return "%s took %s" % [actor_name, target_id]

