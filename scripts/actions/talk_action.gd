class_name TalkAction
extends BaseAction

## TalkAction allows two co-located characters to converse.
## Requires both characters to be in the same logical location.

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 20.0
) -> void:
	super._init("talk", "Talk", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot talk to self"
		return false

	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor == null:
		failure_reason = "Actor not found"
		return false
	if target == null:
		failure_reason = "Target character %s not found" % target_id
		return false

	# Must be in the exact same location
	if actor.current_location != target.current_location:
		failure_reason = "Actor (%s) and target (%s) are in different locations (%s vs %s)" % [
			actor.name, target.name, actor.current_location, target.current_location
		]
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor != null and target != null:
		# Satisfy social needs
		actor.set_need("social", actor.get_need("social") + 0.05)
		target.set_need("social", target.get_need("social") + 0.05)
		# Slight stress reduction from positive social contact
		actor.set_emotion("stress", actor.get_emotion("stress") - 0.02)
		target.set_emotion("stress", target.get_emotion("stress") - 0.02)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	var loc_name: String = actor.current_location if actor != null else "their location"
	return "%s talked with %s in %s" % [a_name, t_name, loc_name.capitalize()]
