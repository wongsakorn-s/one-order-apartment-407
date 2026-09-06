class_name ConfrontAction
extends BaseAction

## ConfrontAction represents an aggressive or tense confrontation with another character.
## Requires co-location. Increases anger and stress.

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 15.0
) -> void:
	super._init("confront", "Confront", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot confront self"
		return false

	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor == null or target == null:
		failure_reason = "Actor or target not found"
		return false

	if actor.current_location != target.current_location:
		failure_reason = "Cannot confront %s; in different rooms" % target.name
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)

	if actor != null and target != null:
		actor.set_emotion("anger", actor.get_emotion("anger") + 0.15)
		actor.set_emotion("stress", actor.get_emotion("stress") + 0.10)
		target.set_emotion("fear", target.get_emotion("fear") + 0.10)
		target.set_emotion("stress", target.get_emotion("stress") + 0.15)
		target.set_need("safety", target.get_need("safety") - 0.10)

		# Target toward Actor: fear +0.20, suspicion +0.15, trust -0.20, respect change
		target.modify_relationship(actor_id, "fear", 0.20)
		target.modify_relationship(actor_id, "suspicion", 0.15)
		target.modify_relationship(actor_id, "trust", -0.20)
		var respect_delta: float = 0.10 if target.get_personality_trait("fear") >= target.get_personality_trait("aggression") else -0.10
		target.modify_relationship(actor_id, "respect", respect_delta)

		# Actor toward Target: suspicion +0.10, trust -0.10
		actor.modify_relationship(target_id, "suspicion", 0.10)
		actor.modify_relationship(target_id, "trust", -0.10)

		state_changes = {
			"actor_emotion_deltas": {"anger": 0.15, "stress": 0.10},
			"target_emotion_deltas": {"fear": 0.10, "stress": 0.15},
			"target_safety_delta": -0.10,
			"relationship_target_to_actor": {"fear": 0.20, "suspicion": 0.15, "trust": -0.20, "respect": respect_delta},
			"relationship_actor_to_target": {"suspicion": 0.10, "trust": -0.10}
		}

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	var loc_name: String = actor.current_location if actor != null else "their room"
	return "%s confronted %s in %s" % [a_name, t_name, loc_name.capitalize()]

