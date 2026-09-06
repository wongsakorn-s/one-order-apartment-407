class_name SecretGenerator
extends RefCounted

## SecretGenerator creates hidden pieces of information ("secrets") during run generation.
## TASK-011: Secrets & Run Setup.
##
## Every secret mutates real character/world state (inventory, hidden items, relationships,
## goals) rather than only recording a flavor-text description. Knowledge of a secret is only
## granted to characters who logically should hold it: the secret-holder always knows, and a
## counterpart only gains knowledge when the template implies mutual or partial awareness
## (e.g. a shared debt) rather than pure discovery (e.g. who actually stole an item).
## Secrets create motivations that existing goal/relationship/belief-driven Utility AI scoring
## already responds to. They never script, force, or predetermine a specific run result.
## Pure simulation logic; decoupled from scene nodes.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")

const MIN_SECRETS: int = 3
const MAX_SECRETS: int = 5

const SECRET_TYPES: Array[String] = [
	"owes_money",
	"stole_item",
	"secretly_likes",
	"planning_to_leave",
	"has_room_407_key",
	"saw_something_near_407",
	"hiding_item",
	"lied_about",
]

## Items plausible to steal or hide; kept distinct from world/quest-critical items.
const CANDIDATE_ITEMS: Array[String] = [
	"cash", "notepad", "camera", "lockpick", "pocket_knife", "flashlight", "lighter", "book"
]

## (predicate, ground_truth, told_lie) triples used to seed a pre-existing false belief.
const LIE_TOPICS: Array[Array] = [
	["true_relationship_status", "single", "in_a_relationship"],
	["true_job_situation", "unemployed", "employed"],
	["true_whereabouts_last_night", "was_at_room_407", "was_at_work"],
	["true_debt_situation", "deep_in_debt", "financially_fine"],
]

## Generate secrets deterministically from `rng` and apply their effects to `characters`.
## Returns an Array[Dictionary] summary of each secret (id, type, participants, description).
## Same seed (and thus same rng sequence position) always reproduces the same secrets.
func generate_secrets(rng: RandomService, characters: Array) -> Array[Dictionary]:
	var secrets: Array[Dictionary] = []
	if rng == null or characters.is_empty():
		return secrets

	# Sort deterministically by ID so secret selection never depends on Dictionary iteration order.
	var sorted_chars: Array = characters.duplicate()
	sorted_chars.sort_custom(func(a, b): return a.id < b.id)

	var secret_count: int = rng.rand_range_int(MIN_SECRETS, MAX_SECRETS)

	for i in range(secret_count):
		var secret_type: String = str(rng.pick(SECRET_TYPES))
		var subject: CharacterState = sorted_chars[rng.rand_range_int(0, sorted_chars.size() - 1)]

		var others: Array = []
		for c in sorted_chars:
			if c.id != subject.id:
				others.append(c)

		var target: CharacterState = null
		if secret_type in ["owes_money", "stole_item", "secretly_likes", "lied_about"]:
			if others.is_empty():
				continue
			target = others[rng.rand_range_int(0, others.size() - 1)]

		var secret_id: String = "secret_%02d_%s" % [i, secret_type]
		var secret: Dictionary = _apply_secret(rng, secret_id, secret_type, subject, target)
		if not secret.is_empty():
			secrets.append(secret)

	return secrets

func _apply_secret(rng: RandomService, secret_id: String, secret_type: String, subject: CharacterState, target: CharacterState) -> Dictionary:
	match secret_type:
		"owes_money":
			return _apply_owes_money(rng, secret_id, subject, target)
		"stole_item":
			return _apply_stole_item(rng, secret_id, subject, target)
		"secretly_likes":
			return _apply_secretly_likes(rng, secret_id, subject, target)
		"planning_to_leave":
			return _apply_planning_to_leave(secret_id, subject)
		"has_room_407_key":
			return _apply_has_room_407_key(secret_id, subject)
		"saw_something_near_407":
			return _apply_saw_something_near_407(secret_id, subject)
		"hiding_item":
			return _apply_hiding_item(rng, secret_id, subject)
		"lied_about":
			return _apply_lied_about(rng, secret_id, subject, target)
	return {}

## A owes B money. Both parties are aware of a debt they personally agreed to;
## this is bilateral world state, not a discovery, so both may hold consistent knowledge of it.
func _apply_owes_money(rng: RandomService, secret_id: String, subject: CharacterState, target: CharacterState) -> Dictionary:
	var amount: int = rng.rand_range_int(2, 8) * 50 # 100-400 in steps of 50
	var debt_value: float = clampf(0.55 + rng.rand_range_float(0.0, 0.35), 0.0, 1.0)

	subject.get_relationship(target.id).set_value("debt", debt_value)

	subject.set_belief("self", "owes_money_to", target.id, 1.0, "self", 0.0)
	target.set_belief(subject.id, "owes_money_to", target.id, 1.0, "self", 0.0)
	target.set_belief("self", "is_owed_money_by", subject.id, 1.0, "self", 0.0)

	return {
		"id": secret_id,
		"type": "owes_money",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": target.id, "target_name": target.name,
		"detail": amount,
		"description": "%s owes %s %d money." % [subject.name, target.name, amount]
	}

## A stole an item from B. World state changes: the item physically moves from B's
## inventory to A's (hidden). A knows they stole it; B may notice the item is missing,
## but must NOT automatically learn who took it.
func _apply_stole_item(rng: RandomService, secret_id: String, subject: CharacterState, target: CharacterState) -> Dictionary:
	if target.inventory.is_empty():
		target.inventory.append(str(rng.pick(CANDIDATE_ITEMS)))

	var item: String = str(target.inventory[rng.rand_range_int(0, target.inventory.size() - 1)])

	target.inventory.erase(item)
	if not item in subject.inventory:
		subject.inventory.append(item)
	subject.hide_item(item)

	subject.set_belief("self", "stole_item_from", target.id, 1.0, "self", 0.0)
	subject.set_belief(target.id, "missing_item", item, 1.0, "self", 0.0)
	target.set_belief("self", "missing_item", item, 0.9, "self", 0.0)

	return {
		"id": secret_id,
		"type": "stole_item",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": target.id, "target_name": target.name,
		"detail": item,
		"description": "%s secretly stole %s from %s." % [subject.name, item, target.name]
	}

## A secretly likes B. Deliberately asymmetric: only A's directional attraction and
## private belief change. B receives no knowledge of this at all.
func _apply_secretly_likes(rng: RandomService, secret_id: String, subject: CharacterState, target: CharacterState) -> Dictionary:
	var attraction_value: float = clampf(0.65 + rng.rand_range_float(0.0, 0.3), 0.0, 1.0)
	subject.get_relationship(target.id).set_value("attraction", attraction_value)
	subject.set_belief("self", "secretly_likes", target.id, 1.0, "self", 0.0)

	return {
		"id": secret_id,
		"type": "secretly_likes",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": target.id, "target_name": target.name,
		"detail": target.id,
		"description": "%s secretly likes %s." % [subject.name, target.name]
	}

## A plans to leave the building tonight. Only A knows; reinforced with an actual
## LeaveBuilding goal so the motivation is actionable through existing goal-driven scoring.
func _apply_planning_to_leave(secret_id: String, subject: CharacterState) -> Dictionary:
	subject.set_belief("self", "planning_to_leave_tonight", true, 1.0, "self", 0.0)

	var already_has_goal: bool = false
	for g in subject.goals:
		if g is Dictionary and g.get("type", "") == "leave_building":
			already_has_goal = true
			break
	if not already_has_goal:
		subject.goals.append({
			"id": "LeaveBuilding", "type": "leave_building", "target": "lobby",
			"target_name": "Lobby", "description": "Secretly planning to leave the building tonight"
		})

	return {
		"id": secret_id,
		"type": "planning_to_leave",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": "", "target_name": "",
		"detail": "",
		"description": "%s is secretly planning to leave the building tonight." % subject.name
	}

## A possesses the Room 407 key. World state: the key is physically added to A's
## inventory (hidden from casual view). Only A knows they hold it.
func _apply_has_room_407_key(secret_id: String, subject: CharacterState) -> Dictionary:
	if not "room_407_key" in subject.inventory and not subject.has_hidden_item("room_407_key"):
		subject.inventory.append("room_407_key")
	subject.hide_item("room_407_key")

	subject.set_belief("self", "has_key_to", "room_407", 1.0, "self", 0.0)
	subject.set_belief("room_407", "key_holder", subject.id, 1.0, "self", 0.0)

	return {
		"id": secret_id,
		"type": "has_room_407_key",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": "", "target_name": "",
		"detail": "room_407_key",
		"description": "%s possesses the Room 407 key." % subject.name
	}

## A saw something suspicious near Room 407 earlier tonight. Represented as a
## private high-confidence belief plus a directly-formed memory (A observed it
## personally, so this is not omniscience, merely a pre-run private observation).
func _apply_saw_something_near_407(secret_id: String, subject: CharacterState) -> Dictionary:
	subject.set_belief("room_407", "status", "suspicious_activity", 0.9, "self", 0.0)

	var mem := MemoryClass.new(
		"mem_secret_%s" % subject.id,
		0.0,
		"observed_suspicious",
		[subject.id],
		"room_407",
		0.8,
		0.3,
		"",
		{"location": "room_407"},
		"%s noticed something suspicious near Room 407 earlier tonight." % subject.name
	)
	subject.add_memory(mem)

	return {
		"id": secret_id,
		"type": "saw_something_near_407",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": "", "target_name": "",
		"detail": "room_407",
		"description": "%s saw something suspicious near Room 407 earlier tonight." % subject.name
	}

## A is hiding an item. World state: the item is removed from A's visible inventory
## into their hidden item set. Only A knows where it is.
func _apply_hiding_item(rng: RandomService, secret_id: String, subject: CharacterState) -> Dictionary:
	if subject.inventory.is_empty():
		subject.inventory.append(str(rng.pick(CANDIDATE_ITEMS)))

	var item: String = str(subject.inventory[rng.rand_range_int(0, subject.inventory.size() - 1)])
	subject.hide_item(item)
	subject.set_belief("self", "hiding_item", item, 1.0, "self", 0.0)

	return {
		"id": secret_id,
		"type": "hiding_item",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": "", "target_name": "",
		"detail": item,
		"description": "%s is hiding %s." % [subject.name, item]
	}

## A lied to B about something important before the run began. World state: A holds
## the private ground truth, while B holds a discounted-confidence false belief whose
## source is A. This is an intentionally contradictory belief pair, matching the
## design's explicit allowance for false beliefs.
func _apply_lied_about(rng: RandomService, secret_id: String, subject: CharacterState, target: CharacterState) -> Dictionary:
	var topic: Array = LIE_TOPICS[rng.rand_range_int(0, LIE_TOPICS.size() - 1)]
	var predicate: String = str(topic[0])
	var truth_value: String = str(topic[1])
	var lie_value: String = str(topic[2])

	subject.set_belief("self", predicate, truth_value, 1.0, "self", 0.0)
	target.set_belief(subject.id, predicate, lie_value, 0.7, subject.id, 0.0)

	var readable_topic: String = predicate.replace("true_", "").replace("_", " ")
	return {
		"id": secret_id,
		"type": "lied_about",
		"subject_id": subject.id, "subject_name": subject.name,
		"target_id": target.id, "target_name": target.name,
		"detail": predicate,
		"description": "%s lied to %s about their %s." % [subject.name, target.name, readable_topic]
	}

## Helper to print the generated secrets to the Godot console for debugging and verification.
## Never surfaced to the player; developer/debug visibility only.
static func print_generated_secrets(seed_num: int, secrets: Array[Dictionary]) -> void:
	print("------------------------------------------------------------")
	print(" [SECRET GENERATOR] Secrets for Seed %d (%d generated)" % [seed_num, secrets.size()])
	print("------------------------------------------------------------")
	for s in secrets:
		print(" - [%s] %s" % [s.get("type", "?"), s.get("description", "")])
	print("------------------------------------------------------------")
