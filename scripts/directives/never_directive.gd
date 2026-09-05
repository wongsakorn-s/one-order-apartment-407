class_name NeverDirective
extends RefCounted

## NeverDirective defines a strictly prohibited rule chosen by the player for the protagonist.
## Imposes heavy negative utility penalties (-15.0) or invalidates actions violating the directive.

const BaseActionClass = preload("res://scripts/actions/base_action.gd")

var id: String = ""
var title: String = ""
var name: String:
	get:
		return title
var description: String = ""

func _init(p_id: String = "", p_title: String = "", p_desc: String = "") -> void:
	id = p_id
	title = p_title
	description = p_desc

## Evaluate if an action violates this NEVER directive and calculate penalty.
func evaluate_violation(actor: CharacterState, action: BaseAction, _context: Dictionary) -> Dictionary:
	if actor == null or action == null:
		return {"is_violating": false, "penalty": 0.0, "reason": ""}

	match id:
		"never_enter_room_407":
			if (action.id == "move_to" or action.id == "flee") and action.target_id == "room_407":
				return {
					"is_violating": true,
					"penalty": -15.0,
					"reason": "Directly violates NEVER: Never enter Room 407"
				}
			elif action.id == "investigate" and (action.target_id == "room_407" or actor.current_location == "room_407"):
				return {
					"is_violating": true,
					"penalty": -15.0,
					"reason": "Directly violates NEVER: Never enter Room 407"
				}

		"never_steal":
			if action.id == "take_item":
				# Taking an item from another character is considered stealing
				var take_action = action as TakeItemAction
				if take_action != null and not take_action.source_character_id.is_empty():
					return {
						"is_violating": true,
						"penalty": -15.0,
						"reason": "Directly violates NEVER: Never steal from residents"
					}

		"never_hurt_anyone":
			if action.id == "confront":
				return {
					"is_violating": true,
					"penalty": -15.0,
					"reason": "Directly violates NEVER: Never hurt or confront anyone"
				}

		"never_lie":
			# Placeholder for when LieAction is introduced in social tasks; discourages deceptive actions
			if action.id in ["deceive", "lie"]:
				return {
					"is_violating": true,
					"penalty": -15.0,
					"reason": "Directly violates NEVER: Never lie"
				}

		"never_trust_police":
			if action.id in ["call_police", "report_to_police"]:
				return {
					"is_violating": true,
					"penalty": -15.0,
					"reason": "Directly violates NEVER: Never trust police"
				}

	return {"is_violating": false, "penalty": 0.0, "reason": ""}

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description
	}

