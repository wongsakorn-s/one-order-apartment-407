class_name BeliefDirective
extends RefCounted

## BeliefDirective defines a philosophical lens or interpretation angle chosen by the player.
## Modifies utility scores (+1.0 to +1.6) without creating a forced, scripted path.

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

## Modify utility interpretation for an action candidate.
func modify_interpretation(actor: CharacterState, action: BaseAction, _context: Dictionary) -> float:
	if actor == null or action == null:
		return 0.0

	match id:
		"everyone_hiding_something":
			# Increased curiosity and suspicion; favors investigating and questioning
			if action.id in ["investigate", "ask_question"]:
				return 1.5
			elif action.id == "talk":
				return 1.0

		"most_people_trusted":
			# High baseline trust; favors cooperative and social actions
			if action.id in ["talk", "help"]:
				return 1.4
			elif action.id in ["confront", "refuse"]:
				return -0.8

		"money_solves_problems":
			# Materialistic mindset; favors acquiring items or resources
			if action.id == "take_item":
				return 1.4
			elif action.id == "give_item":
				return -0.8

		"helping_pays_off":
			# Altruistic investment; favors helping and gifting
			if action.id == "help":
				return 1.6
			elif action.id == "give_item":
				return 1.2
			elif action.id == "refuse":
				return -1.0

		"nobody_gives_anything_for_free":
			# Skeptical and transactional mindset; favors caution and self-reliance
			if action.id == "refuse":
				return 1.4
			elif action.id == "help":
				return -0.8
			elif action.id == "idle" or action.id == "rest":
				return 0.5

	return 0.0

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description
	}

