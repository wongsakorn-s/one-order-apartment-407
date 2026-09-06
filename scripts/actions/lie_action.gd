class_name LieAction
extends BaseAction

## LieAction lets the actor deliberately feed a co-located target a false belief
## about a sensitive private fact the actor is protecting (e.g. a TASK-011
## generated secret such as having stolen an item or secretly liking someone).
## The actor's own true belief is never touched: only the target's belief
## store receives a fabricated value, so a lie creates a false belief without
## ever mutating world truth.
##
## Requires the actor to actually hold a sensitive self-belief to lie about;
## a character with nothing to hide cannot fabricate a baseless denial, so
## this action fails preconditions when none of SENSITIVE_PREDICATES apply.

## Predicates worth lying about. Deliberately excludes bilateral facts like
## "owes_money_to" which both parties already know and agreed to.
const SENSITIVE_PREDICATES: Array[String] = [
	"stole_item_from",
	"secretly_likes",
	"planning_to_leave_tonight",
	"hiding_item",
	"has_key_to",
]

const COVER_VALUES: Dictionary = {
	"stole_item_from": "nobody",
	"secretly_likes": "nobody",
	"planning_to_leave_tonight": false,
	"hiding_item": "nothing",
	"has_key_to": "no_key",
}

func _init(
	p_actor_id: String = "",
	p_target_id: String = "",
	p_duration: float = 5.0
) -> void:
	super._init("lie", "Lie", p_actor_id, p_target_id, p_duration)

func _check_preconditions(context: Dictionary) -> bool:
	if actor_id == target_id:
		failure_reason = "Cannot lie to self"
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

	if _pick_predicate(actor).is_empty():
		failure_reason = "Actor %s has nothing sensitive to lie about" % actor.name
		return false

	return true

func _apply_effects(context: Dictionary) -> void:
	var characters: Dictionary = context.get("characters", {})
	var actor: CharacterState = characters.get(actor_id, null)
	var target: CharacterState = characters.get(target_id, null)
	if actor == null or target == null:
		return

	var predicate: String = _pick_predicate(actor)
	if predicate.is_empty():
		return

	var false_value: Variant = COVER_VALUES.get(predicate, "unknown")
	var sim_time: float = float(context.get("sim_time", 0.0))
	var trust: float = target.get_relationship_value(actor_id, "trust")
	var suspicion: float = target.get_relationship_value(actor_id, "suspicion")
	var rec_confidence: float = clampf(0.8 * trust * (1.0 - suspicion * 0.4), 0.1, 1.0)

	# The subject is the actor's own real ID: from the listener's perspective the
	# fact is about the actor, even though the actor stored it reflexively as "self".
	target.receive_belief(actor_id, predicate, false_value, rec_confidence, actor_id, sim_time)

	# A small psychological cost to deception, independent of whether it succeeds.
	actor.set_emotion("stress", actor.get_emotion("stress") + 0.05)

	metadata["subject"] = actor_id
	metadata["predicate"] = predicate
	metadata["false_value"] = false_value

## Deterministically pick the first sensitive self-belief (fixed priority order)
## the actor actually holds, so the same state always yields the same lie.
func _pick_predicate(actor: CharacterState) -> String:
	for predicate in SENSITIVE_PREDICATES:
		if actor.has_belief("self", predicate):
			return predicate
	return ""

func get_readable_description(context: Dictionary = {}) -> String:
	var characters: Dictionary = context.get("characters", {})
	var actor = characters.get(actor_id, null)
	var target = characters.get(target_id, null)
	var a_name: String = actor.name if actor != null else actor_id
	var t_name: String = target.name if target != null else target_id
	return "%s told %s something that wasn't quite true" % [a_name, t_name]
