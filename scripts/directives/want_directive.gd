class_name WantDirective
extends RefCounted

## WantDirective defines a high-level intention chosen by the player for the protagonist.
## Provides strong positive utility scoring (+3.0 to +4.0) to actions that advance the goal.

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

## Calculate positive utility score contribution for a candidate action.
func calculate_utility(actor: CharacterState, action: BaseAction, context: Dictionary) -> float:
	if actor == null or action == null:
		return 0.0

	var world_graph: WorldGraph = context.get("world_graph", null)
	var characters: Dictionary = context.get("characters", {})

	match id:
		"learn_room_407":
			var already_searched: bool = false
			if actor.current_location == "room_407":
				for rec in actor.recent_actions:
					if rec.get("id", "") == "investigate" and (rec.get("target_id", "") == "room_407" or rec.get("target_id", "") == ""):
						already_searched = true
						break

			if action.id == "investigate" and (action.target_id == "room_407" or actor.current_location == "room_407"):
				if already_searched:
					return 1.2
				return 4.0
			elif action.id == "move_to" and world_graph != null:
				if actor.current_location == "room_407" and already_searched:
					# Motivate leaving Room 407 to explore or question witnesses
					return 2.5
				var dist_cur: int = world_graph.get_distance(actor.current_location, "room_407")
				var dist_next: int = world_graph.get_distance(action.target_id, "room_407")
				if dist_next < dist_cur and dist_cur >= 0:
					return 3.8
			elif action.id in ["talk", "ask_question"]:
				return 1.8

		"earn_money":
			# Focus on acquiring resources, items, trade, or asking around
			if action.id == "take_item":
				return 3.5
			elif action.id == "investigate":
				# Searching rooms for valuables or lost items
				return 2.2
			elif action.id in ["talk", "ask_question"]:
				return 2.0
			elif action.id == "move_to":
				# Move towards communal areas or storage where items might be
				if action.target_id in ["laundry_room", "lobby", "room_407"]:
					return 2.2

		"make_friend":
			# Focus on cooperative social interactions
			if action.id == "help":
				return 3.8
			elif action.id == "talk":
				return 3.2
			elif action.id == "give_item":
				return 2.5
			elif action.id == "move_to":
				# Move towards populated locations
				var count_in_target: int = _count_others_in_location(action.target_id, actor.id, characters)
				if count_in_target > 0:
					return 1.8

		"survive_night":
			# Focus on personal safety, resting, and avoiding conflict
			if action.id == "rest" and actor.current_location in ["room_101", "room_102", "room_103", "room_201", "room_202", "room_203"]:
				return 3.2
			elif action.id == "flee":
				return 3.5
			elif action.id == "confront":
				return -3.5
			elif action.id == "move_to" and action.target_id == "room_407":
				return -2.5

		"be_trusted":
			# Focus on helping others and building positive reputation
			if action.id == "help":
				return 4.0
			elif action.id == "give_item":
				return 3.0
			elif action.id == "talk":
				return 2.2
			elif action.id in ["confront", "refuse"]:
				return -3.0

	return 0.0

func _count_others_in_location(loc_id: String, actor_id: String, characters: Dictionary) -> int:
	var count: int = 0
	for c in characters.values():
		var char_state = c as CharacterState
		if char_state != null and char_state.id != actor_id and char_state.current_location == loc_id:
			count += 1
	return count

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description
	}

