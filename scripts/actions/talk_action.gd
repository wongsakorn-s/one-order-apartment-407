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

		# Mutual slight improvement in trust and decrease in suspicion
		actor.modify_relationship(target_id, "trust", 0.04)
		actor.modify_relationship(target_id, "suspicion", -0.03)
		target.modify_relationship(actor_id, "trust", 0.04)
		target.modify_relationship(actor_id, "suspicion", -0.03)

		state_changes = {
			"relationship_actor_to_target": {"trust": 0.04, "suspicion": -0.03},
			"relationship_target_to_actor": {"trust": 0.04, "suspicion": -0.03}
		}

		# Mutual information exchange during conversation
		var sim_time: float = float(context.get("sim_time", 0.0))
		_exchange_information(actor, target, sim_time)
		if metadata.has("shared_facts"):
			state_changes["shared_facts"] = metadata["shared_facts"]

func _exchange_information(char_a: CharacterState, char_b: CharacterState, sim_time: float) -> void:
	_share_belief(char_a, char_b, sim_time)
	_share_belief(char_b, char_a, sim_time)

func _share_belief(speaker: CharacterState, listener: CharacterState, sim_time: float) -> void:
	if speaker == null or listener == null:
		return

	var candidates: Array = []
	for b in speaker.get_beliefs():
		if b.source == listener.id or b.confidence < 0.3:
			continue
		# Skip telling the co-located listener where the speaker is right now
		if b.subject == speaker.id and b.predicate == "location":
			continue

		# Prioritize facts that listener doesn't already know with equal or higher confidence
		var listener_b = listener.get_belief(b.subject, b.predicate)
		if listener_b != null and listener_b.confidence >= b.confidence:
			continue
		candidates.append(b)

	# If all beliefs are already known to listener, fall back to any eligible belief
	if candidates.is_empty():
		for b in speaker.get_beliefs():
			if b.source != listener.id and b.confidence >= 0.3:
				if not (b.subject == speaker.id and b.predicate == "location"):
					candidates.append(b)

	if candidates.is_empty():
		return

	# Prioritize external knowledge (other characters, rooms, rumors) over self-facts, then sort by confidence
	candidates.sort_custom(func(a, b):
		var a_is_ext: bool = (a.subject != speaker.id)
		var b_is_ext: bool = (b.subject != speaker.id)
		if a_is_ext != b_is_ext:
			return a_is_ext
		return a.confidence > b.confidence
	)
	var fact_to_share = candidates[0]

	var trust: float = listener.get_relationship_value(speaker.id, "trust")
	var suspicion: float = listener.get_relationship_value(speaker.id, "suspicion")

	# Trust directly scales confidence; suspicion dampens it
	var rec_confidence: float = clampf(fact_to_share.confidence * trust * (1.0 - suspicion * 0.4), 0.05, 1.0)

	listener.receive_belief(
		fact_to_share.subject,
		fact_to_share.predicate,
		fact_to_share.value,
		rec_confidence,
		speaker.id,
		sim_time
	)

	if not metadata.has("shared_facts"):
		metadata["shared_facts"] = []
	metadata["shared_facts"].append({
		"from": speaker.id,
		"to": listener.id,
		"subject": fact_to_share.subject,
		"predicate": fact_to_share.predicate,
		"value": fact_to_share.value,
		"confidence": rec_confidence
	})

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	var loc_name: String = actor.current_location if actor != null else "their location"
	return "%s talked with %s in %s" % [a_name, t_name, loc_name.capitalize()]

