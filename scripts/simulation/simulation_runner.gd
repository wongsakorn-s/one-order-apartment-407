class_name SimulationRunner
extends Node

## SimulationRunner coordinates the core simulation loop, clock, random service, world graph, and character states.
## Ticks during physics process to ensure deterministic time step advancement decoupled from FPS.

signal time_updated(sim_time_seconds: float, formatted_time: String)
signal pause_state_changed(is_paused: bool)
signal speed_multiplier_changed(multiplier: float)
signal simulation_completed()
signal seed_changed(current_seed: int)
signal characters_updated()
signal event_emitted(event_dict: Dictionary)
signal directives_updated(want_dict: Dictionary, never_dict: Dictionary, believe_dict: Dictionary)

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const NPCGeneratorClass = preload("res://scripts/generation/npc_generator.gd")
const SimulationEventClass = preload("res://scripts/events/simulation_event.gd")
const BaseActionClass = preload("res://scripts/actions/base_action.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")
const DirectiveCatalogClass = preload("res://scripts/directives/directive_catalog.gd")
const RelationshipGeneratorClass = preload("res://scripts/generation/relationship_generator.gd")
const SecretGeneratorClass = preload("res://scripts/generation/secret_generator.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")

@export var initial_seed: int = 12345

var clock: SimulationClock
var random_service: RandomService
var world_graph: WorldGraph
var utility_ai: UtilityAI
var active_want_id: String = "learn_room_407"
var active_never_id: String = "never_steal"
var active_belief_id: String = "everyone_hiding_something"
var _characters: Dictionary = {}
var _events: Array[Dictionary] = []
var _secrets: Array[Dictionary] = []

func _ready() -> void:
	_init_simulation()

func _init_simulation() -> void:
	random_service = RandomService.new(initial_seed)
	clock = SimulationClock.new()
	world_graph = WorldGraph.create_default_apartment()
	utility_ai = UtilityAIClass.new()

	clock.time_advanced.connect(_on_clock_time_advanced)
	clock.pause_toggled.connect(_on_clock_pause_toggled)
	clock.speed_changed.connect(_on_clock_speed_changed)
	clock.simulation_completed.connect(_on_clock_simulation_completed)

	spawn_initial_characters()

	# Initial announcement of state
	time_updated.emit(clock.get_current_sim_seconds(), clock.get_formatted_time(true))
	pause_state_changed.emit(clock.is_paused())
	speed_multiplier_changed.emit(clock.get_speed_multiplier())
	seed_changed.emit(get_seed())

func spawn_initial_characters() -> void:
	_characters.clear()

	# 1. Protagonist (Alex)
	var protagonist = CharacterStateClass.new("char_protagonist", "Alex", "room_101", true)
	protagonist.set_personality_trait("empathy", 0.7)
	protagonist.set_personality_trait("greed", 0.3)
	protagonist.set_personality_trait("fear", 0.4)
	protagonist.set_personality_trait("aggression", 0.2)
	protagonist.set_personality_trait("curiosity", 0.8)
	protagonist.set_personality_trait("honesty", 0.75)
	protagonist.set_personality_trait("sociability", 0.65)
	protagonist.set_personality_trait("impulsiveness", 0.4)
	protagonist.set_need("safety", 0.7)
	protagonist.set_need("money", 0.4)
	protagonist.set_need("social", 0.5)
	protagonist.set_need("information", 0.8)
	protagonist.set_need("rest", 0.6)
	protagonist.set_need("food", 0.5)
	protagonist.set_emotion("happiness", 0.6)
	protagonist.set_emotion("fear", 0.2)
	protagonist.set_emotion("anger", 0.1)
	protagonist.set_emotion("stress", 0.3)
	protagonist.inventory = ["phone", "apartment_key", "wallet"]
	protagonist.goals = [
		{"id": "SurviveNight", "type": "survive_night", "target": "", "target_name": "", "description": "Survive until morning"},
		{"id": "InvestigateLocation", "type": "investigate_location", "target": "room_407", "target_name": "Room 407", "description": "Investigate Room 407"}
	]
	_apply_player_directives(protagonist)
	_characters[protagonist.id] = protagonist

	# 2. Procedurally Generate 8 NPCs using seeded random_service
	var generator = NPCGeneratorClass.new()
	var npcs = generator.generate_npcs(random_service, world_graph, protagonist.id, protagonist.name)
	for npc in npcs:
		_characters[npc.id] = npc

	# 3. Generate initial directional relationships between all characters
	var rel_gen = RelationshipGeneratorClass.new()
	rel_gen.generate_initial_relationships(random_service, get_all_characters())

	# 4. Seed initial subjective knowledge and beliefs
	_seed_initial_knowledge()

	# 5. Generate run secrets (TASK-011): mutates inventory, hidden items,
	# relationships, goals, and beliefs consistently, continuing the same
	# deterministic RNG stream used by NPC and relationship generation.
	var secret_gen = SecretGeneratorClass.new()
	_secrets = secret_gen.generate_secrets(random_service, get_all_characters())

	# Print generated roster and secrets for debug visibility
	NPCGeneratorClass.print_generated_roster(get_seed(), get_all_characters())
	SecretGeneratorClass.print_generated_secrets(get_seed(), _secrets)

	characters_updated.emit()


func _physics_process(delta: float) -> void:
	if clock != null and not clock.is_paused() and not clock.is_finished():
		var sim_delta: float = delta * clock.BASE_SIM_SECONDS_PER_REAL_SECOND * clock.get_speed_multiplier()
		clock.advance(delta)
		_tick_simulation(sim_delta)

func get_simulation_context() -> Dictionary:
	return {
		"characters": _characters,
		"world_graph": world_graph,
		"sim_time": clock.get_current_sim_seconds() if clock != null else 0.0,
		"rng": random_service
	}

func execute_character_action(char_id: String, action: BaseAction) -> bool:
	var character = get_character(char_id)
	if character == null or action == null:
		return false

	var context = get_simulation_context()
	if action.start(context):
		character.set_active_action(action)
		characters_updated.emit()
		return true
	return false

func cancel_character_action(char_id: String, reason: String = "Cancelled") -> void:
	var character = get_character(char_id)
	if character != null:
		character.cancel_current_action(reason)
		characters_updated.emit()

func _tick_simulation(sim_delta: float) -> void:
	var context = get_simulation_context()
	var any_state_changed: bool = false

	for c in _characters.values():
		var char_state: CharacterState = c as CharacterState
		if char_state.active_action != null:
			var completed_action = char_state.tick_action(sim_delta, context)
			any_state_changed = true
			if completed_action != null:
				var evt = completed_action._create_completion_event(context)
				_record_event(evt)

	# Autonomous Utility AI decision cycle for idle characters
	if utility_ai != null:
		context = get_simulation_context()
		for c in _characters.values():
			var char_state: CharacterState = c as CharacterState
			if char_state.active_action == null:
				var decision: UtilityDecision = utility_ai.decide_action(char_state, context)
				if decision != null and decision.action != null:
					char_state.last_decision = decision.to_dict()
					if decision.action.start(context):
						char_state.set_active_action(decision.action)
						any_state_changed = true

	if any_state_changed:
		characters_updated.emit()

const EVENT_IMPORTANCE: Dictionary = {
	"confront": 0.85,
	"take_item": 0.80,
	"help": 0.70,
	"give_item": 0.65,
	"refuse": 0.60,
	"flee": 0.60,
	"investigate": 0.45,
	"talk": 0.35,
	"move_to": 0.20,
	"rest": 0.15,
	"idle": 0.05
}

func _record_event(evt: SimulationEvent) -> void:
	if evt == null:
		return
	var evt_dict = evt.to_dict()
	_events.append(evt_dict)
	if _events.size() > 200:
		_events.pop_front()

	_distribute_event_memory(evt)
	_distribute_event_knowledge(evt)
	event_emitted.emit(evt_dict)

func _distribute_event_memory(evt: SimulationEvent) -> void:
	if evt == null or _characters.is_empty():
		return

	var base_importance: float = EVENT_IMPORTANCE.get(evt.event_type, 0.40)
	if evt.event_type == "investigate" and evt.location_id == "room_407":
		base_importance = 0.75

	# Do not store trivial events below threshold to prevent cluttering capacity
	if base_importance < 0.25:
		return

	var participants: Array[String] = []
	if not evt.actor_id.is_empty():
		participants.append(evt.actor_id)
	if not evt.target_id.is_empty() and evt.target_id != evt.actor_id and _characters.has(evt.target_id):
		participants.append(evt.target_id)

	for char_id in _characters.keys():
		var character = _characters[char_id] as CharacterState
		if character == null:
			continue

		var is_actor: bool = (character.id == evt.actor_id)
		var is_target: bool = (character.id == evt.target_id)
		var is_present: bool = (character.current_location == evt.location_id)

		# Characters do NOT automatically remember events they did not observe
		if not (is_actor or is_target or is_present):
			continue

		var emotional_impact: float = _calculate_emotional_impact(evt, character, is_actor, is_target)
		var importance: float = base_importance

		if is_actor or is_target:
			importance = clampf(importance + 0.10, 0.0, 1.0)
		else:
			importance = clampf(importance - 0.10, 0.0, 1.0)

		var memory_id: String = "mem_%s_%d" % [character.id, character.get_memory_count() + 1]
		var facts: Dictionary = {
			"event_type": evt.event_type,
			"actor": evt.actor_id,
			"target": evt.target_id,
			"location": evt.location_id,
			"is_actor": is_actor,
			"is_target": is_target
		}
		if evt.metadata.has("item_name"):
			facts["item"] = evt.metadata["item_name"]

		var memory = MemoryClass.new(
			memory_id,
			evt.timestamp,
			evt.event_type,
			participants,
			evt.location_id,
			importance,
			emotional_impact,
			evt.id,
			facts,
			evt.description
		)
		character.add_memory(memory)

func _calculate_emotional_impact(evt: SimulationEvent, _character: CharacterState, is_actor: bool, is_target: bool) -> float:
	match evt.event_type:
		"help":
			if is_target:
				return 0.70
			elif is_actor:
				return 0.35
			else:
				return 0.20
		"confront":
			if is_target:
				return -0.80
			elif is_actor:
				return 0.20
			else:
				return -0.40
		"refuse":
			if is_target:
				return -0.50
			elif is_actor:
				return -0.10
			else:
				return -0.15
		"talk":
			return 0.25
		"give_item":
			if is_target:
				return 0.65
			elif is_actor:
				return 0.30
			else:
				return 0.15
		"take_item":
			if is_target:
				return -0.80
			elif is_actor:
				return 0.40
			else:
				return -0.30
		"flee":
			return -0.40
		"investigate":
			return 0.10
	return 0.0

func _seed_initial_knowledge() -> void:
	for c in get_all_characters():
		c.set_belief(c.id, "location", c.current_location, 1.0, "self", 0.0)
		c.set_belief(c.id, "default_room", c.current_location, 1.0, "self", 0.0)

	var protagonist = get_protagonist()
	if protagonist != null:
		protagonist.set_belief("room_407", "status", "locked", 0.95, "self", 0.0)

	var elena = get_character("npc_elena")
	if elena != null:
		for c in get_all_characters():
			if c.id != elena.id:
				elena.set_belief(c.id, "default_room", c.current_location, 1.0, "self", 0.0)

func _distribute_event_knowledge(evt: SimulationEvent) -> void:
	if evt == null or _characters.is_empty():
		return

	for char_id in _characters.keys():
		var character = _characters[char_id] as CharacterState
		if character == null:
			continue

		var is_actor: bool = (character.id == evt.actor_id)
		var is_target: bool = (character.id == evt.target_id)
		var is_present: bool = (character.current_location == evt.location_id)

		# Characters do NOT gain knowledge of unobserved events
		if not (is_actor or is_target or is_present):
			continue

		# Direct observation produces high-confidence knowledge (confidence = 1.0, source = "self")
		if not evt.actor_id.is_empty():
			character.set_belief(evt.actor_id, "location", evt.location_id, 1.0, "self", evt.timestamp)
			character.set_belief(evt.actor_id, "last_action", evt.event_type, 1.0, "self", evt.timestamp)

		if not evt.target_id.is_empty() and _characters.has(evt.target_id):
			character.set_belief(evt.target_id, "location", evt.location_id, 1.0, "self", evt.timestamp)

		match evt.event_type:
			"take_item":
				var item = evt.metadata.get("item_name", evt.target_id)
				character.set_belief(evt.actor_id, "has_item", item, 1.0, "self", evt.timestamp)
			"give_item":
				var item = evt.metadata.get("item_name", "")
				if not item.is_empty():
					character.set_belief(evt.target_id, "has_item", item, 1.0, "self", evt.timestamp)
			"confront":
				character.set_belief(evt.actor_id, "hostile_towards", evt.target_id, 1.0, "self", evt.timestamp)
			"help":
				character.set_belief(evt.actor_id, "helped", evt.target_id, 1.0, "self", evt.timestamp)

func get_secrets() -> Array[Dictionary]:
	return _secrets

func get_events() -> Array[Dictionary]:
	return _events

func get_recent_events(count: int = 20) -> Array[Dictionary]:
	if _events.size() <= count:
		return _events.duplicate()
	return _events.slice(_events.size() - count, _events.size())

func toggle_pause() -> void:
	if clock != null:
		clock.toggle_pause()

func set_paused(paused: bool) -> void:
	if clock != null:
		clock.set_paused(paused)

func set_speed_multiplier(multiplier: float) -> void:
	if clock != null:
		clock.set_speed_multiplier(multiplier)

func get_clock() -> SimulationClock:
	return clock

func get_random_service() -> RandomService:
	return random_service

func get_rng() -> RandomService:
	return random_service

func get_world_graph() -> WorldGraph:
	return world_graph

func get_world() -> WorldGraph:
	return world_graph

func get_character(id: String) -> CharacterState:
	return _characters.get(id, null)

func get_all_characters() -> Array[CharacterState]:
	var list: Array[CharacterState] = []
	for c in _characters.values():
		list.append(c as CharacterState)
	return list

func get_character_count() -> int:
	return _characters.size()

func get_protagonist() -> CharacterState:
	for c in _characters.values():
		if (c as CharacterState).is_protagonist:
			return c as CharacterState
	return null

func get_characters_in_location(location_id: String) -> Array[CharacterState]:
	var list: Array[CharacterState] = []
	for c in _characters.values():
		var char_state: CharacterState = c as CharacterState
		if char_state.current_location == location_id:
			list.append(char_state)
	return list

func get_seed() -> int:
	if random_service != null:
		return random_service.get_seed()
	return initial_seed

func reset_simulation(new_seed: int = -1) -> void:
	if new_seed >= 0:
		initial_seed = new_seed
		if random_service != null:
			random_service.set_seed(new_seed)
	else:
		if random_service != null:
			random_service.reset()

	if clock != null:
		clock.reset()

	_events.clear()
	world_graph = WorldGraph.create_default_apartment()
	utility_ai = UtilityAIClass.new()
	spawn_initial_characters()
	seed_changed.emit(get_seed())

func get_utility_ai() -> UtilityAI:
	return utility_ai

func set_player_directives(want_id: String, never_id: String, belief_id: String) -> void:
	active_want_id = want_id
	active_never_id = never_id
	active_belief_id = belief_id

	var protagonist = get_protagonist()
	if protagonist != null:
		_apply_player_directives(protagonist)
		characters_updated.emit()

func _apply_player_directives(protagonist: CharacterState) -> void:
	if protagonist == null:
		return
	var want_dir = DirectiveCatalogClass.get_want_by_id(active_want_id)
	var never_dir = DirectiveCatalogClass.get_never_by_id(active_never_id)
	var belief_dir = DirectiveCatalogClass.get_belief_by_id(active_belief_id)

	protagonist.set_directives(want_dir, never_dir, belief_dir)
	directives_updated.emit(want_dir.to_dict(), never_dir.to_dict(), belief_dir.to_dict())

func get_player_directives() -> Dictionary:
	return {
		"want": DirectiveCatalogClass.get_want_by_id(active_want_id),
		"never": DirectiveCatalogClass.get_never_by_id(active_never_id),
		"believe": DirectiveCatalogClass.get_belief_by_id(active_belief_id)
	}

func get_player_directive_ids() -> Dictionary:
	return {
		"want": active_want_id,
		"never": active_never_id,
		"believe": active_belief_id
	}

func _on_clock_time_advanced(sim_time: float, formatted_time: String) -> void:
	time_updated.emit(sim_time, formatted_time)

func _on_clock_pause_toggled(is_paused: bool) -> void:
	pause_state_changed.emit(is_paused)

func _on_clock_speed_changed(multiplier: float) -> void:
	speed_multiplier_changed.emit(multiplier)

func _on_clock_simulation_completed() -> void:
	simulation_completed.emit()
