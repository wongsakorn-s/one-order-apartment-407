class_name Room407Generator
extends RefCounted

## Room407Generator selects at most one procedural "mystery catalyst" scenario
## for Room 407 per run (TASK-015). Room 407 has no fixed canonical explanation:
## different seeds can make it about hidden money, a missing tenant, a secret
## meeting, stolen goods, someone hiding, abandoned belongings, innocent noise,
## or nothing noteworthy at all. Every scenario mutates real state (world
## items, beliefs, goals, relationships) using the existing character/world
## systems rather than scripting a resolution; NPCs discover and resolve it
## purely through existing goal/belief/investigate mechanics. The protagonist
## is never assigned Room 407 knowledge or goals here, so they are never
## nudged toward investigating it.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")

const SCENARIO_TYPES: Array[String] = [
	"hidden_money",
	"missing_tenant",
	"secret_meeting",
	"stolen_goods",
	"someone_hiding",
	"abandoned_belongings",
	"innocent_noise",
	"irrelevant",
]

## Probability that no scenario is selected at all -- distinct from selecting
## the "irrelevant" archetype -- so Room 407 is doubly likely to sometimes be
## completely unremarkable.
const SKIP_PROBABILITY: float = 0.25

const ROOM_ID: String = "room_407"

## Generate (at most) one Room 407 scenario deterministically from `rng`,
## applying its effects to `characters` and `world_graph`. Returns an empty
## Dictionary if no scenario was selected this run, otherwise a secret-shaped
## summary dict compatible with SecretGenerator's schema (id/type/subject_id/
## subject_name/target_id/target_name/detail/description) so it can be
## appended directly to the run's secrets list.
func generate_scenario(rng: RandomService, characters: Array, world_graph: WorldGraph) -> Dictionary:
	if rng == null or characters.is_empty():
		return {}

	if rng.rand_float() < SKIP_PROBABILITY:
		return {}

	# NPCs only: never assign Room 407 knowledge/goals to the protagonist.
	var npc_pool: Array = []
	for c in characters:
		if not (c as CharacterState).is_protagonist:
			npc_pool.append(c)
	npc_pool.sort_custom(func(a, b): return a.id < b.id)

	var scenario_type: String = str(rng.pick(SCENARIO_TYPES))

	match scenario_type:
		"hidden_money":
			return _apply_hidden_money(rng, npc_pool, world_graph)
		"missing_tenant":
			return _apply_missing_tenant(rng, npc_pool)
		"secret_meeting":
			return _apply_secret_meeting(rng, npc_pool)
		"stolen_goods":
			return _apply_stolen_goods(rng, npc_pool, world_graph)
		"someone_hiding":
			return _apply_someone_hiding(rng, npc_pool)
		"abandoned_belongings":
			return _apply_abandoned_belongings(rng, npc_pool, world_graph)
		"innocent_noise":
			return _apply_innocent_noise(rng, npc_pool)
		_:
			return {
				"id": "room_407_scenario", "type": "irrelevant",
				"subject_id": "", "subject_name": "",
				"target_id": "", "target_name": "",
				"detail": "",
				"description": "Room 407 holds no notable secret this time."
			}

func _apply_hidden_money(rng: RandomService, npc_pool: Array, world_graph: WorldGraph) -> Dictionary:
	if npc_pool.is_empty():
		return {}
	var anchor: CharacterState = npc_pool[rng.rand_range_int(0, npc_pool.size() - 1)]

	if world_graph != null and world_graph.has_location(ROOM_ID):
		world_graph.get_location(ROOM_ID).add_item("hidden_cash")

	anchor.set_belief("self", "hid_money_in", ROOM_ID, 1.0, "self", 0.0)
	anchor.set_belief(ROOM_ID, "status", "hiding_money_here", 0.9, "self", 0.0)

	return {
		"id": "room_407_scenario", "type": "hidden_money",
		"subject_id": anchor.id, "subject_name": anchor.name,
		"target_id": "", "target_name": "",
		"detail": "hidden_cash",
		"description": "%s secretly hid cash somewhere in Room 407." % anchor.name
	}

func _apply_missing_tenant(rng: RandomService, npc_pool: Array) -> Dictionary:
	if npc_pool.is_empty():
		return {}
	var anchor: CharacterState = npc_pool[rng.rand_range_int(0, npc_pool.size() - 1)]
	anchor.set_belief(ROOM_ID, "status", "tenant_missing", 0.85, "self", 0.0)

	return {
		"id": "room_407_scenario", "type": "missing_tenant",
		"subject_id": anchor.id, "subject_name": anchor.name,
		"target_id": "", "target_name": "",
		"detail": "",
		"description": "%s has noticed Room 407's tenant seems to have vanished." % anchor.name
	}

func _apply_secret_meeting(rng: RandomService, npc_pool: Array) -> Dictionary:
	if npc_pool.size() < 2:
		return {}
	var idx_a: int = rng.rand_range_int(0, npc_pool.size() - 1)
	var idx_b: int = idx_a
	while idx_b == idx_a:
		idx_b = rng.rand_range_int(0, npc_pool.size() - 1)
	var a: CharacterState = npc_pool[idx_a]
	var b: CharacterState = npc_pool[idx_b]

	a.set_belief("self", "met_secretly_in", ROOM_ID, 1.0, "self", 0.0)
	b.set_belief("self", "met_secretly_in", ROOM_ID, 1.0, "self", 0.0)
	a.get_relationship(b.id).set_value("trust", clampf(a.get_relationship_value(b.id, "trust") + 0.15, 0.0, 1.0))
	b.get_relationship(a.id).set_value("trust", clampf(b.get_relationship_value(a.id, "trust") + 0.15, 0.0, 1.0))

	return {
		"id": "room_407_scenario", "type": "secret_meeting",
		"subject_id": a.id, "subject_name": a.name,
		"target_id": b.id, "target_name": b.name,
		"detail": "",
		"description": "%s and %s secretly met in Room 407." % [a.name, b.name]
	}

func _apply_stolen_goods(rng: RandomService, npc_pool: Array, world_graph: WorldGraph) -> Dictionary:
	if npc_pool.is_empty():
		return {}
	var anchor: CharacterState = npc_pool[rng.rand_range_int(0, npc_pool.size() - 1)]

	if world_graph != null and world_graph.has_location(ROOM_ID):
		world_graph.get_location(ROOM_ID).add_item("stolen_jewelry")

	anchor.set_belief("self", "stashed_item_in", ROOM_ID, 1.0, "self", 0.0)
	anchor.set_belief(ROOM_ID, "status", "hiding_stolen_goods", 0.9, "self", 0.0)

	return {
		"id": "room_407_scenario", "type": "stolen_goods",
		"subject_id": anchor.id, "subject_name": anchor.name,
		"target_id": "", "target_name": "",
		"detail": "stolen_jewelry",
		"description": "%s stashed stolen jewelry in Room 407." % anchor.name
	}

func _apply_someone_hiding(rng: RandomService, npc_pool: Array) -> Dictionary:
	if npc_pool.size() < 2:
		return {}
	var hider: CharacterState = npc_pool[rng.rand_range_int(0, npc_pool.size() - 1)]

	var others: Array = []
	for c in npc_pool:
		if c.id != hider.id:
			others.append(c)
	var avoided: CharacterState = others[rng.rand_range_int(0, others.size() - 1)]

	hider.current_location = ROOM_ID
	hider.set_belief("self", "hiding_from", avoided.id, 1.0, "self", 0.0)

	var already_has_goal: bool = false
	for g in hider.goals:
		if g is Dictionary and g.get("type", "") == "avoid_character" and g.get("target", "") == avoided.id:
			already_has_goal = true
			break
	if not already_has_goal:
		hider.goals.append({
			"id": "AvoidCharacter", "type": "avoid_character", "target": avoided.id,
			"target_name": avoided.name, "description": "Avoid %s while hiding in Room 407" % avoided.name
		})

	return {
		"id": "room_407_scenario", "type": "someone_hiding",
		"subject_id": hider.id, "subject_name": hider.name,
		"target_id": avoided.id, "target_name": avoided.name,
		"detail": "",
		"description": "%s is secretly hiding in Room 407, avoiding %s." % [hider.name, avoided.name]
	}

func _apply_abandoned_belongings(rng: RandomService, npc_pool: Array, world_graph: WorldGraph) -> Dictionary:
	if world_graph != null and world_graph.has_location(ROOM_ID):
		world_graph.get_location(ROOM_ID).add_item("old_suitcase")

	var anchor_id: String = ""
	var anchor_name: String = ""
	if not npc_pool.is_empty():
		var anchor: CharacterState = npc_pool[rng.rand_range_int(0, npc_pool.size() - 1)]
		anchor.set_belief(ROOM_ID, "status", "abandoned_belongings", 0.7, "self", 0.0)
		anchor_id = anchor.id
		anchor_name = anchor.name

	return {
		"id": "room_407_scenario", "type": "abandoned_belongings",
		"subject_id": anchor_id, "subject_name": anchor_name,
		"target_id": "", "target_name": "",
		"detail": "old_suitcase",
		"description": "Room 407 contains a suitcase of belongings left behind by a previous occupant."
	}

func _apply_innocent_noise(rng: RandomService, npc_pool: Array) -> Dictionary:
	if npc_pool.is_empty():
		return {}
	var anchor: CharacterState = npc_pool[rng.rand_range_int(0, npc_pool.size() - 1)]
	# The witness's own honest interpretation sounds alarming, even though the
	# scenario is ultimately harmless -- it only resolves as innocent if
	# someone actually investigates further.
	anchor.set_belief(ROOM_ID, "status", "suspicious_activity", 0.7, "self", 0.0)

	return {
		"id": "room_407_scenario", "type": "innocent_noise",
		"subject_id": anchor.id, "subject_name": anchor.name,
		"target_id": "", "target_name": "",
		"detail": "",
		"description": "%s heard a strange noise from Room 407 (probably nothing)." % anchor.name
	}
