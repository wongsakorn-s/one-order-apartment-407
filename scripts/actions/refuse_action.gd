class_name RefuseAction
extends BaseAction

## RefuseAction expresses refusal or rejection toward another character's request.
## Requires co-location.

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 5.0
) -> void:
	super._init("refuse", "Refuse", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot refuse self"
		return false

	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor == null or target == null:
		failure_reason = "Actor or target not found"
		return false

	if actor.current_location != target.current_location:
		failure_reason = "Cannot refuse %s; in different rooms" % target.name
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var target = characters.get(target_id, null)
	if target != null:
		# Refusal causes slight frustration or stress in the target
		target.set_emotion("stress", target.get_emotion("stress") + 0.05)

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	return "%s refused %s" % [a_name, t_name]
