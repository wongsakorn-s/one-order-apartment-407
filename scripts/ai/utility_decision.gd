class_name UtilityDecision
extends RefCounted

## UtilityDecision stores the result of an AI decision cycle.
## Contains the chosen action, its final score, detailed reason components,
## and a record of all evaluated candidate actions for debug explainability.

const BaseActionClass = preload("res://scripts/actions/base_action.gd")

var action: BaseAction = null
var score: float = 0.0
var reasons: Dictionary = {}
var candidates: Array[Dictionary] = []
var explanation: String = ""

## TASK-013: IDs of earlier events (drawn from memories that influenced this
## decision) that causally contributed to choosing this action.
var contributing_event_ids: Array[String] = []

func _init(
	p_action: BaseAction = null,
	p_score: float = 0.0,
	p_reasons: Dictionary = {},
	p_candidates: Array[Dictionary] = [],
	p_explanation: String = "",
	p_contributing_event_ids: Array[String] = []
) -> void:
	action = p_action
	score = p_score
	reasons = p_reasons.duplicate(true)
	candidates = p_candidates.duplicate(true)
	explanation = p_explanation
	contributing_event_ids = p_contributing_event_ids.duplicate()

func get_explanation() -> String:
	if not explanation.is_empty():
		return explanation
	if action == null:
		return "No action chosen"
	var reason_parts: Array[String] = []
	for k in reasons.keys():
		var val: float = float(reasons[k])
		if not is_zero_approx(val):
			reason_parts.append("%s: %+.2f" % [k, val])
	var breakdown: String = ", ".join(reason_parts)
	return "%s (Score: %.2f) [%s]" % [action.action_name, score, breakdown]

func to_dict() -> Dictionary:
	return {
		"action_id": action.id if action != null else "",
		"action_name": action.action_name if action != null else "",
		"target_id": action.target_id if action != null else "",
		"score": score,
		"reasons": reasons.duplicate(true),
		"explanation": get_explanation(),
		"candidates": candidates.duplicate(true),
		"contributing_event_ids": contributing_event_ids.duplicate()
	}
