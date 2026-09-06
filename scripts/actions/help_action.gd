class_name HelpAction
extends BaseAction

## HelpAction allows an actor to assist another character in the same room.
## Reduces target's stress and strengthens social ties.

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 20.0
) -> void:
	super._init("help", "Help", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot help self"
		return false

	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor == null or target == null:
		failure_reason = "Actor or target not found"
		return false

	if actor.current_location != target.current_location:
		failure_reason = "Cannot help %s; in different rooms (%s vs %s)" % [target.name, actor.current_location, target.current_location]
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor != null and target != null:
		target.set_emotion("stress", target.get_emotion("stress") - 0.10)
		actor.set_need("social", actor.get_need("social") + 0.05)
		# Directional relationship updates:
		# Target toward Actor: trust +0.15, debt +0.20
		target.modify_relationship(actor_id, "trust", 0.15)
		target.modify_relationship(actor_id, "debt", 0.20)
		# Actor toward Target: trust +0.05
		actor.modify_relationship(target_id, "trust", 0.05)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	return "%s helped %s" % [a_name, t_name]

