class_name IdleAction
extends BaseAction

## IdleAction keeps the character resting or waiting in place for a short duration.
## Always executable. Slightly restores rest and lowers stress.

func _init(p_actor_id: String = "", p_duration: float = 10.0) -> void:
	super._init("idle", "Idle", p_actor_id, "", p_duration)

func _check_preconditions(_context: Dictionary) -> bool:
	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	if actor != null:
		# Slight baseline relaxation
		actor.set_emotion("stress", actor.get_emotion("stress") - 0.02)
		actor.set_need("rest", actor.get_need("rest") + 0.01)
		state_changes = {"stress_delta": -0.02, "rest_delta": 0.01}

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var actor_name: String = actor.name if actor != null else actor_id
	var loc_name: String = actor.current_location if actor != null else "their location"
	return "%s is idling in %s" % [actor_name, loc_name.capitalize()]

