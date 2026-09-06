class_name ShareInformationAction
extends BaseAction

## ShareInformationAction lets the actor deliberately volunteer a known fact to a
## co-located target, distinct from the ambient background chatter already
## exchanged during a plain Talk. Because it represents a deliberate act of
## openness, a successful share also builds a small amount of trust from the
## target toward the actor.
##
## The shared fact is chosen internally (highest-confidence external fact the
## target doesn't already hold with equal or higher confidence), mirroring the
## selection already used for passive Talk sharing but as an explicit,
## AI-scored decision with its own causal event.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 6.0
) -> void:
	super._init("share_information", "Share Information", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot share information with self"
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

	if find_shareable_fact(actor, target) == null:
		failure_reason = "Actor has no fact worth sharing with %s" % target.name
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor: CharacterState = characters.get(actor_id, null)
	var target: CharacterState = characters.get(target_id, null)
	if actor == null or target == null:
		return

	var fact: Belief = find_shareable_fact(actor, target)
	if fact == null:
		return

	var sim_time: float = float(context.get("sim_time", 0.0))
	var trust: float = target.get_relationship_value(actor_id, "trust")
	var suspicion: float = target.get_relationship_value(actor_id, "suspicion")
	var rec_confidence: float = clampf(fact.confidence * trust * (1.0 - suspicion * 0.4), 0.1, 1.0)

	target.receive_belief(fact.subject, fact.predicate, fact.value, rec_confidence, actor_id, sim_time)
	# Voluntary disclosure builds goodwill beyond what casual talk provides.
	target.modify_relationship(actor_id, "trust", 0.05)

	metadata["subject"] = fact.subject
	metadata["predicate"] = fact.predicate
	metadata["value"] = fact.value
	metadata["confidence"] = rec_confidence

## Find the single best external fact the actor could deliberately reveal to target.
## Returns null if the actor has nothing worth sharing (target already knows it as
## well or better, or the actor holds no qualifying external belief).
static func find_shareable_fact(actor: CharacterState, target: CharacterState) -> Belief:
	if actor == null or target == null:
		return null

	var candidates: Array[Belief] = []
	for b in actor.get_beliefs():
		if b.source == target.id or b.confidence < 0.3:
			continue
		if b.subject == actor.id and b.predicate == "location":
			continue

		var target_belief = target.get_belief(b.subject, b.predicate)
		if target_belief != null and target_belief.confidence >= b.confidence:
			continue
		candidates.append(b)

	if candidates.is_empty():
		return null

	candidates.sort_custom(func(a, b):
		var a_is_ext: bool = (a.subject != actor.id)
		var b_is_ext: bool = (b.subject != actor.id)
		if a_is_ext != b_is_ext:
			return a_is_ext
		return a.confidence > b.confidence
	)
	return candidates[0]

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	var subject: String = str(metadata.get("subject", "something"))
	return "%s shared what they knew about %s with %s" % [a_name, subject, t_name]
