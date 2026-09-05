class_name NPCGenerator
extends RefCounted

## NPCGenerator handles procedural generation of NPC characters based on the run seed.
## Ensures deterministic character attributes, valid world entity references in goals,
## and meaningful differences between different seeds.
## Pure simulation logic; decoupled from scene nodes.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")

const GOAL_TYPES: Array[String] = [
	"EarnMoney",
	"AvoidCharacter",
	"MeetCharacter",
	"RetrieveItem",
	"HideItem",
	"RepairRelationship",
	"InvestigateLocation",
	"LeaveBuilding",
	"FindFood",
	"Rest"
]

const ITEM_POOL: Array[String] = [
	"cash",
	"phone",
	"flashlight",
	"notepad",
	"camera",
	"crowbar",
	"detergent",
	"first_aid_kit",
	"lighter",
	"book",
	"snack",
	"pocket_knife",
	"lockpick",
	"water_bottle"
]

## Predefined NPC templates providing archetypal tendencies and preferred baseline locations.
const NPC_TEMPLATES: Array[Dictionary] = [
	{
		"id": "npc_nina",
		"name": "Nina",
		"default_room": "room_102",
		"possible_locations": ["room_102", "lobby", "hallway_1", "laundry_room"],
		"personality_base": {
			"empathy": 0.8, "greed": 0.2, "fear": 0.5, "aggression": 0.15,
			"curiosity": 0.6, "honesty": 0.8, "sociability": 0.7, "impulsiveness": 0.3
		},
		"needs_base": {"safety": 0.75, "social": 0.7, "rest": 0.6},
		"preferred_items": ["notepad", "book"]
	},
	{
		"id": "npc_bob",
		"name": "Bob",
		"default_room": "room_103",
		"possible_locations": ["room_103", "hallway_1", "stairwell", "room_407"],
		"personality_base": {
			"empathy": 0.3, "greed": 0.85, "fear": 0.4, "aggression": 0.65,
			"curiosity": 0.55, "honesty": 0.25, "sociability": 0.4, "impulsiveness": 0.7
		},
		"needs_base": {"money": 0.85, "safety": 0.5, "information": 0.6},
		"preferred_items": ["crowbar", "cash", "lockpick"]
	},
	{
		"id": "npc_sarah",
		"name": "Sarah",
		"default_room": "room_201",
		"possible_locations": ["room_201", "hallway_2", "stairwell", "room_407", "rooftop"],
		"personality_base": {
			"empathy": 0.6, "greed": 0.35, "fear": 0.35, "aggression": 0.3,
			"curiosity": 0.85, "honesty": 0.65, "sociability": 0.6, "impulsiveness": 0.5
		},
		"needs_base": {"information": 0.85, "social": 0.5, "safety": 0.6},
		"preferred_items": ["camera", "flashlight", "notepad"]
	},
	{
		"id": "npc_tom",
		"name": "Tom",
		"default_room": "room_202",
		"possible_locations": ["room_202", "hallway_2", "laundry_room", "lobby"],
		"personality_base": {
			"empathy": 0.5, "greed": 0.45, "fear": 0.7, "aggression": 0.3,
			"curiosity": 0.4, "honesty": 0.55, "sociability": 0.35, "impulsiveness": 0.4
		},
		"needs_base": {"safety": 0.85, "rest": 0.7, "food": 0.6},
		"preferred_items": ["first_aid_kit", "water_bottle"]
	},
	{
		"id": "npc_mia",
		"name": "Mia",
		"default_room": "room_203",
		"possible_locations": ["room_203", "hallway_2", "lobby", "rooftop"],
		"personality_base": {
			"empathy": 0.75, "greed": 0.3, "fear": 0.4, "aggression": 0.2,
			"curiosity": 0.7, "honesty": 0.7, "sociability": 0.85, "impulsiveness": 0.55
		},
		"needs_base": {"social": 0.85, "information": 0.65, "safety": 0.5},
		"preferred_items": ["phone", "book", "snack"]
	},
	{
		"id": "npc_elena",
		"name": "Elena",
		"default_room": "lobby",
		"possible_locations": ["lobby", "hallway_1", "hallway_2", "stairwell"],
		"personality_base": {
			"empathy": 0.65, "greed": 0.45, "fear": 0.3, "aggression": 0.25,
			"curiosity": 0.6, "honesty": 0.7, "sociability": 0.75, "impulsiveness": 0.35
		},
		"needs_base": {"information": 0.75, "safety": 0.7, "social": 0.6},
		"preferred_items": ["notepad", "flashlight"]
	},
	{
		"id": "npc_david",
		"name": "David",
		"default_room": "laundry_room",
		"possible_locations": ["laundry_room", "hallway_1", "lobby", "room_102"],
		"personality_base": {
			"empathy": 0.45, "greed": 0.55, "fear": 0.45, "aggression": 0.4,
			"curiosity": 0.4, "honesty": 0.5, "sociability": 0.4, "impulsiveness": 0.45
		},
		"needs_base": {"rest": 0.75, "money": 0.65, "food": 0.6},
		"preferred_items": ["detergent", "cash", "lighter"]
	},
	{
		"id": "npc_marcus",
		"name": "Marcus",
		"default_room": "rooftop",
		"possible_locations": ["rooftop", "stairwell", "hallway_2", "room_407"],
		"personality_base": {
			"empathy": 0.4, "greed": 0.35, "fear": 0.25, "aggression": 0.35,
			"curiosity": 0.65, "honesty": 0.6, "sociability": 0.3, "impulsiveness": 0.5
		},
		"needs_base": {"rest": 0.7, "safety": 0.5, "information": 0.5},
		"preferred_items": ["lighter", "pocket_knife"]
	}
]

## Generate the complete array of 8 NPCs deterministically using random_service.
func generate_npcs(
	random_service: RandomService,
	world_graph: WorldGraph,
	protagonist_id: String = "char_protagonist",
	protagonist_name: String = "Alex"
) -> Array[CharacterState]:
	var npcs: Array[CharacterState] = []

	# Build pool of all potential character references for goal targeting
	var all_characters_info: Array[Dictionary] = [
		{"id": protagonist_id, "name": protagonist_name}
	]
	for t in NPC_TEMPLATES:
		all_characters_info.append({"id": t["id"], "name": t["name"]})

	for template in NPC_TEMPLATES:
		var npc_id: String = template["id"]
		var npc_name: String = template["name"]

		# 1. Starting location
		var starting_loc: String = _generate_starting_location(random_service, world_graph, template)

		var npc = CharacterStateClass.new(npc_id, npc_name, starting_loc, false)

		# 2. Personality
		_apply_personality(npc, random_service, template)

		# 3. Initial Needs
		_apply_needs(npc, random_service, template)

		# 4. Initial Emotions
		_apply_emotions(npc, random_service)

		# 5. Starting Inventory
		npc.inventory = _generate_inventory(random_service, template)

		# 6. Goals (Primary + Optional Secondary)
		npc.goals = _generate_goals(
			random_service,
			npc_id,
			all_characters_info,
			world_graph,
			template
		)

		npcs.append(npc)

	return npcs

func _apply_personality(npc: CharacterState, rng: RandomService, template: Dictionary) -> void:
	var base_dict: Dictionary = template.get("personality_base", {})
	for trait_name in CharacterStateClass.PERSONALITY_TRAITS:
		var base_val: float = base_dict.get(trait_name, 0.5)
		# Add seeded variation [-0.2, +0.2]
		var variation: float = rng.rand_range_float(-0.2, 0.2)
		var final_val: float = snappedf(clampf(base_val + variation, 0.05, 0.95), 0.01)
		npc.set_personality_trait(trait_name, final_val)

func _apply_needs(npc: CharacterState, rng: RandomService, template: Dictionary) -> void:
	var base_dict: Dictionary = template.get("needs_base", {})
	for need_name in CharacterStateClass.BASIC_NEEDS:
		var base_val: float = base_dict.get(need_name, 0.5)
		# Add seeded variation [-0.25, +0.25]
		var variation: float = rng.rand_range_float(-0.25, 0.25)
		var final_val: float = snappedf(clampf(base_val + variation, 0.1, 0.9), 0.01)
		npc.set_need(need_name, final_val)

func _apply_emotions(npc: CharacterState, rng: RandomService) -> void:
	# Baseline emotions for the start of the night
	var happiness: float = snappedf(rng.rand_range_float(0.3, 0.75), 0.01)
	var fear: float = snappedf(rng.rand_range_float(0.05, 0.4), 0.01)
	var anger: float = snappedf(rng.rand_range_float(0.0, 0.35), 0.01)
	var stress: float = snappedf(rng.rand_range_float(0.1, 0.55), 0.01)

	npc.set_emotion("happiness", happiness)
	npc.set_emotion("fear", fear)
	npc.set_emotion("anger", anger)
	npc.set_emotion("stress", stress)

func _generate_starting_location(
	rng: RandomService,
	world_graph: WorldGraph,
	template: Dictionary
) -> String:
	var possible_locations: Array = template.get("possible_locations", [])
	# 70% chance to pick from possible locations, 30% default room
	var pick_default: bool = rng.rand_float() < 0.3
	var chosen_loc: String = template.get("default_room", "lobby")

	if not pick_default and not possible_locations.is_empty():
		var picked = rng.pick(possible_locations)
		if picked != null:
			chosen_loc = str(picked)

	# Ensure location strictly exists in world graph
	if world_graph != null and not world_graph.has_location(chosen_loc):
		chosen_loc = template.get("default_room", "lobby")
		if not world_graph.has_location(chosen_loc):
			chosen_loc = "lobby"

	return chosen_loc

func _generate_inventory(rng: RandomService, template: Dictionary) -> Array:
	var inv: Array = ["apartment_key"]
	var preferred: Array = template.get("preferred_items", [])

	# Give 1 preferred item if available
	if not preferred.is_empty():
		var pref_item = rng.pick(preferred)
		if pref_item != null and not pref_item in inv:
			inv.append(pref_item)

	# 50% chance to give 1 additional random item from ITEM_POOL
	if rng.rand_float() < 0.5:
		var bonus_item = rng.pick(ITEM_POOL)
		if bonus_item != null and not bonus_item in inv:
			inv.append(bonus_item)

	return inv

func _generate_goals(
	rng: RandomService,
	npc_id: String,
	all_characters: Array[Dictionary],
	world_graph: WorldGraph,
	template: Dictionary
) -> Array:
	var generated_goals: Array = []

	# Candidate other characters for social goals
	var other_chars: Array[Dictionary] = []
	for c in all_characters:
		if c["id"] != npc_id:
			other_chars.append(c)

	# All valid locations in world graph
	var valid_locations: Array[String] = []
	if world_graph != null:
		valid_locations = world_graph.get_all_location_ids()
	if valid_locations.is_empty():
		valid_locations = ["lobby", "room_102", "room_103", "room_201", "room_202", "room_203", "room_407"]

	# 1. Primary Goal (always present)
	var primary_goal_type: String = _pick_primary_goal_type(rng, template)
	var primary_goal: Dictionary = _build_goal(
		primary_goal_type,
		rng,
		other_chars,
		valid_locations,
		template
	)
	generated_goals.append(primary_goal)

	# 2. Optional Secondary Goal (60% chance)
	if rng.rand_float() < 0.6:
		var secondary_types: Array[String] = []
		for g in GOAL_TYPES:
			if g != primary_goal_type:
				secondary_types.append(g)

		var secondary_type: String = rng.pick(secondary_types) if not secondary_types.is_empty() else "Rest"
		var secondary_goal: Dictionary = _build_goal(
			secondary_type,
			rng,
			other_chars,
			valid_locations,
			template
		)
		generated_goals.append(secondary_goal)

	return generated_goals

func _pick_primary_goal_type(rng: RandomService, template: Dictionary) -> String:
	# Tendency based on personality traits
	var p = template.get("personality_base", {})
	var candidates: Array[String] = []

	if p.get("greed", 0.5) > 0.6:
		candidates.append("EarnMoney")
		candidates.append("RetrieveItem")
	if p.get("curiosity", 0.5) > 0.6:
		candidates.append("InvestigateLocation")
	if p.get("fear", 0.5) > 0.6:
		candidates.append("AvoidCharacter")
		candidates.append("Rest")
	if p.get("sociability", 0.5) > 0.6:
		candidates.append("MeetCharacter")
		candidates.append("RepairRelationship")
	if p.get("aggression", 0.5) > 0.6:
		candidates.append("HideItem")

	if candidates.is_empty() or rng.rand_float() < 0.35:
		return str(rng.pick(GOAL_TYPES))

	return str(rng.pick(candidates))

func _build_goal(
	goal_type: String,
	rng: RandomService,
	other_chars: Array[Dictionary],
	valid_locations: Array[String],
	template: Dictionary
) -> Dictionary:
	var goal: Dictionary = {
		"id": goal_type,
		"type": goal_type.to_snake_case(),
		"target": "",
		"target_name": "",
		"description": ""
	}

	match goal_type:
		"EarnMoney":
			goal["description"] = "Earn money for rent or debts"

		"AvoidCharacter":
			var target_char = _pick_target_character(rng, other_chars)
			goal["target"] = target_char.get("id", "")
			goal["target_name"] = target_char.get("name", "Someone")
			goal["description"] = "Avoid %s" % goal["target_name"]

		"MeetCharacter":
			var target_char = _pick_target_character(rng, other_chars)
			goal["target"] = target_char.get("id", "")
			goal["target_name"] = target_char.get("name", "Someone")
			goal["description"] = "Meet and talk with %s" % goal["target_name"]

		"RepairRelationship":
			var target_char = _pick_target_character(rng, other_chars)
			goal["target"] = target_char.get("id", "")
			goal["target_name"] = target_char.get("name", "Someone")
			goal["description"] = "Repair relationship with %s" % goal["target_name"]

		"InvestigateLocation":
			var target_loc: String = _pick_interesting_location(rng, valid_locations)
			goal["target"] = target_loc
			goal["target_name"] = target_loc.capitalize()
			goal["description"] = "Investigate %s" % goal["target_name"]

		"RetrieveItem":
			var item: String = str(rng.pick(ITEM_POOL))
			goal["target"] = item
			goal["target_name"] = item.capitalize()
			goal["description"] = "Retrieve %s" % item

		"HideItem":
			var item: String = str(rng.pick(ITEM_POOL))
			var loc: String = _pick_interesting_location(rng, valid_locations)
			goal["target"] = item
			goal["target_name"] = "%s in %s" % [item, loc]
			goal["target_location"] = loc
			goal["description"] = "Hide %s safely" % item

		"LeaveBuilding":
			goal["target"] = "lobby"
			goal["description"] = "Find a way to leave the building safely"

		"FindFood":
			goal["description"] = "Find food and supplies"

		"Rest":
			var default_room: String = template.get("default_room", "room_102")
			if not default_room in valid_locations:
				default_room = valid_locations[0]
			goal["target"] = default_room
			goal["target_name"] = default_room.capitalize()
			goal["description"] = "Rest and recover in %s" % goal["target_name"]

		_:
			goal["description"] = "Rest"

	return goal

func _pick_target_character(rng: RandomService, other_chars: Array[Dictionary]) -> Dictionary:
	if other_chars.is_empty():
		return {"id": "char_protagonist", "name": "Alex"}
	var picked = rng.pick(other_chars)
	if picked != null:
		return picked as Dictionary
	return {"id": "char_protagonist", "name": "Alex"}

func _pick_interesting_location(rng: RandomService, valid_locations: Array[String]) -> String:
	# 40% chance to target Room 407 if valid, creating mystery convergence!
	if "room_407" in valid_locations and rng.rand_float() < 0.4:
		return "room_407"
	var picked = rng.pick(valid_locations)
	if picked != null:
		return str(picked)
	return "lobby"

## Helper to print the generated roster to Godot console for debugging and verification.
static func print_generated_roster(seed_num: int, characters: Array[CharacterState]) -> void:
	print("------------------------------------------------------------")
	print(" [NPC GENERATOR] Roster for Seed %d (%d characters)" % [seed_num, characters.size()])
	print("------------------------------------------------------------")
	for c in characters:
		var role_tag = "PROTAGONIST" if c.is_protagonist else "NPC"
		var goal_descs: Array[String] = []
		for g in c.goals:
			if g is Dictionary:
				goal_descs.append(g.get("description", str(g)))
			else:
				goal_descs.append(str(g))
		print(" - %s (%s) [%s] Location: %s" % [c.name, c.id, role_tag, c.current_location])
		print("   Goals: %s" % (", ".join(goal_descs) if not goal_descs.is_empty() else "None"))
		print("   Inventory: %s" % str(c.inventory))
	print("------------------------------------------------------------")

