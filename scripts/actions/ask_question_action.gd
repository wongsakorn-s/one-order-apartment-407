class_name AskQuestionAction
extends BaseAction

## AskQuestionAction lets the actor probe a co-located target about a specific
## topic (subject/predicate) the actor wants to know. The topic is chosen
## deterministically from the actor's active goals (what they're trying to
## investigate or who they're trying to find), falling back to general
## curiosity about Room 407 if nothing goal-relevant is missing.
##
## The target's response is resolved deterministically from relationship and
## personality state (never by a random roll):
## - REFUSE  : target is more suspicious of the actor than they trust them.
## - UNKNOWN : target genuinely holds no belief about the topic.
## - LIE     : target dishonestly fabricates an answer (low honesty / high
##             greed / low trust in the actor).
## - TRUTH   : target shares their genuine belief, confidence scaled by trust.

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 6.0
) -> void:
	super._init("ask_question", "Ask Question", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot ask self a question"
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

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor: CharacterState = characters.get(actor_id, null)
	var target: CharacterState = characters.get(target_id, null)
	if actor == null or target == null:
		return

	var topic: Array = _pick_topic(actor, target)
	var subject: String = str(topic[0])
	var predicate: String = str(topic[1])
	var sim_time: float = float(context.get("sim_time", 0.0))

	metadata["subject"] = subject
	metadata["predicate"] = predicate

	var target_belief = target.get_belief(subject, predicate)
	var trust: float = target.get_relationship_value(actor_id, "trust")
	var suspicion: float = target.get_relationship_value(actor_id, "suspicion")
	var honesty: float = target.get_personality_trait("honesty")
	var greed: float = target.get_personality_trait("greed")

	var refusal_score: float = suspicion - trust * 0.6

	if refusal_score > 0.15:
		metadata["outcome"] = "refuse"
		actor.modify_relationship(target_id, "trust", -0.05)
		actor.modify_relationship(target_id, "suspicion", 0.05)
		state_changes = {"outcome": "refuse", "relationship_actor_to_target": {"trust": -0.05, "suspicion": 0.05}}
		return

	if target_belief == null:
		metadata["outcome"] = "unknown"
		state_changes = {"outcome": "unknown"}
		return

	var lie_score: float = (1.0 - honesty) + greed * 0.3 - trust * 0.3

	if lie_score > 0.45:
		metadata["outcome"] = "lie"
		var false_value = _fabricate_alternate_value(predicate, target_belief.value)
		var rec_confidence: float = clampf(0.75 * trust * (1.0 - suspicion * 0.3), 0.1, 1.0)
		actor.receive_belief(subject, predicate, false_value, rec_confidence, target_id, sim_time)
		state_changes = {"outcome": "lie", "belief_received": {"subject": subject, "predicate": predicate, "value": false_value, "confidence": rec_confidence}}
		return

	metadata["outcome"] = "truth"
	var rec_confidence: float = clampf(target_belief.confidence * trust * (1.0 - suspicion * 0.4), 0.1, 1.0)
	actor.receive_belief(subject, predicate, target_belief.value, rec_confidence, target_id, sim_time)
	target.modify_relationship(actor_id, "trust", 0.03)
	state_changes = {
		"outcome": "truth",
		"belief_received": {"subject": subject, "predicate": predicate, "value": target_belief.value, "confidence": rec_confidence},
		"relationship_target_to_actor": {"trust": 0.03}
	}

## Deterministically choose what the actor wants to know, prioritizing active goals.
func _pick_topic(actor: CharacterState, target: CharacterState) -> Array:
	for g in actor.goals:
		if not (g is Dictionary):
			continue
		var g_type: String = g.get("type", "")
		var g_target: String = g.get("target", "")
		if g_target.is_empty():
			continue

		if g_type == "investigate_location" and not actor.has_belief(g_target, "status"):
			return [g_target, "status"]
		elif g_type in ["meet_character", "repair_relationship", "avoid_character"] and g_target != target.id and g_target != actor.id and not actor.has_belief(g_target, "location"):
			return [g_target, "location"]

	return ["room_407", "status"]

## Deterministic fabrication of a plausible-but-false alternative to true_value.
func _fabricate_alternate_value(predicate: String, true_value: Variant) -> Variant:
	match predicate:
		"location":
			return "hallway_2" if str(true_value) != "hallway_2" else "hallway_1"
		"status":
			return "nothing_unusual" if str(true_value) != "nothing_unusual" else "seems_fine"
		_:
			return "unknown"

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	var subject: String = str(metadata.get("subject", ""))
	var predicate: String = str(metadata.get("predicate", ""))
	var outcome: String = str(metadata.get("outcome", ""))

	match outcome:
		"refuse":
			return "%s asked %s about %s, but %s refused to answer" % [a_name, t_name, subject, t_name]
		"unknown":
			return "%s asked %s about %s, but %s didn't know" % [a_name, t_name, subject, t_name]
		"lie":
			return "%s asked %s about %s" % [a_name, t_name, subject]
		"truth":
			return "%s asked %s about %s" % [a_name, t_name, subject]
		_:
			return "%s asked %s a question about %s:%s" % [a_name, t_name, subject, predicate]
