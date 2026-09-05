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

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")

@export var initial_seed: int = 12345

var clock: SimulationClock
var random_service: RandomService
var world_graph: WorldGraph
var _characters: Dictionary = {}

func _ready() -> void:
	_init_simulation()

func _init_simulation() -> void:
	random_service = RandomService.new(initial_seed)
	clock = SimulationClock.new()
	world_graph = WorldGraph.create_default_apartment()

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
	protagonist.goals = ["survive_night", "investigate_room_407"]
	_characters[protagonist.id] = protagonist

	# 2. Nina (NPC 1)
	var nina = CharacterStateClass.new("npc_nina", "Nina", "room_102", false)
	nina.set_personality_trait("empathy", 0.8)
	nina.set_personality_trait("greed", 0.2)
	nina.set_personality_trait("fear", 0.5)
	nina.set_personality_trait("aggression", 0.15)
	nina.set_personality_trait("curiosity", 0.6)
	nina.set_personality_trait("honesty", 0.8)
	nina.set_personality_trait("sociability", 0.7)
	nina.set_personality_trait("impulsiveness", 0.3)
	nina.set_need("safety", 0.8)
	nina.set_need("social", 0.7)
	nina.inventory = ["apartment_key", "notepad"]
	nina.goals = ["rest", "meet_neighbor"]
	_characters[nina.id] = nina

	# 3. Bob (NPC 2)
	var bob = CharacterStateClass.new("npc_bob", "Bob", "room_103", false)
	bob.set_personality_trait("empathy", 0.3)
	bob.set_personality_trait("greed", 0.85)
	bob.set_personality_trait("fear", 0.35)
	bob.set_personality_trait("aggression", 0.6)
	bob.set_personality_trait("curiosity", 0.5)
	bob.set_personality_trait("honesty", 0.25)
	bob.set_personality_trait("sociability", 0.4)
	bob.set_personality_trait("impulsiveness", 0.7)
	bob.set_need("money", 0.9)
	bob.set_need("safety", 0.5)
	bob.set_emotion("stress", 0.6)
	bob.inventory = ["apartment_key", "crowbar", "cash"]
	bob.goals = ["earn_money", "hide_evidence"]
	_characters[bob.id] = bob

	# 4. Sarah (NPC 3)
	var sarah = CharacterStateClass.new("npc_sarah", "Sarah", "room_201", false)
	sarah.set_personality_trait("empathy", 0.6)
	sarah.set_personality_trait("greed", 0.4)
	sarah.set_personality_trait("fear", 0.3)
	sarah.set_personality_trait("aggression", 0.3)
	sarah.set_personality_trait("curiosity", 0.85)
	sarah.set_personality_trait("honesty", 0.6)
	sarah.set_personality_trait("sociability", 0.6)
	sarah.set_personality_trait("impulsiveness", 0.5)
	sarah.set_need("information", 0.85)
	sarah.inventory = ["apartment_key", "camera", "flashlight"]
	sarah.goals = ["investigate_location"]
	_characters[sarah.id] = sarah

	# 5. Tom (NPC 4)
	var tom = CharacterStateClass.new("npc_tom", "Tom", "room_202", false)
	tom.set_personality_trait("empathy", 0.5)
	tom.set_personality_trait("greed", 0.5)
	tom.set_personality_trait("fear", 0.6)
	tom.set_personality_trait("aggression", 0.4)
	tom.set_personality_trait("curiosity", 0.4)
	tom.set_personality_trait("honesty", 0.5)
	tom.set_personality_trait("sociability", 0.3)
	tom.set_personality_trait("impulsiveness", 0.45)
	tom.set_need("safety", 0.85)
	tom.inventory = ["apartment_key", "first_aid_kit"]
	tom.goals = ["rest", "avoid_trouble"]
	_characters[tom.id] = tom

	# 6. Mia (NPC 5)
	var mia = CharacterStateClass.new("npc_mia", "Mia", "room_203", false)
	mia.set_personality_trait("empathy", 0.75)
	mia.set_personality_trait("greed", 0.25)
	mia.set_personality_trait("fear", 0.4)
	mia.set_personality_trait("aggression", 0.2)
	mia.set_personality_trait("curiosity", 0.7)
	mia.set_personality_trait("honesty", 0.7)
	mia.set_personality_trait("sociability", 0.85)
	mia.set_personality_trait("impulsiveness", 0.5)
	mia.set_need("social", 0.85)
	mia.inventory = ["apartment_key", "book"]
	mia.goals = ["socialize", "explore"]
	_characters[mia.id] = mia

	# 7. Elena (NPC 6)
	var elena = CharacterStateClass.new("npc_elena", "Elena", "lobby", false)
	elena.set_personality_trait("empathy", 0.65)
	elena.set_personality_trait("greed", 0.45)
	elena.set_personality_trait("fear", 0.3)
	elena.set_personality_trait("aggression", 0.25)
	elena.set_personality_trait("curiosity", 0.6)
	elena.set_personality_trait("honesty", 0.7)
	elena.set_personality_trait("sociability", 0.75)
	elena.set_personality_trait("impulsiveness", 0.35)
	elena.set_need("information", 0.7)
	elena.inventory = ["master_keycard", "building_log"]
	elena.goals = ["monitor_building"]
	_characters[elena.id] = elena

	# 8. David (NPC 7)
	var david = CharacterStateClass.new("npc_david", "David", "laundry_room", false)
	david.set_personality_trait("empathy", 0.45)
	david.set_personality_trait("greed", 0.55)
	david.set_personality_trait("fear", 0.5)
	david.set_personality_trait("aggression", 0.45)
	david.set_personality_trait("curiosity", 0.4)
	david.set_personality_trait("honesty", 0.5)
	david.set_personality_trait("sociability", 0.4)
	david.set_personality_trait("impulsiveness", 0.4)
	david.set_need("rest", 0.7)
	david.inventory = ["detergent", "coins"]
	david.goals = ["do_laundry", "rest"]
	_characters[david.id] = david

	# 9. Marcus (NPC 8)
	var marcus = CharacterStateClass.new("npc_marcus", "Marcus", "rooftop", false)
	marcus.set_personality_trait("empathy", 0.4)
	marcus.set_personality_trait("greed", 0.35)
	marcus.set_personality_trait("fear", 0.2)
	marcus.set_personality_trait("aggression", 0.3)
	marcus.set_personality_trait("curiosity", 0.65)
	marcus.set_personality_trait("honesty", 0.6)
	marcus.set_personality_trait("sociability", 0.25)
	marcus.set_personality_trait("impulsiveness", 0.5)
	marcus.set_need("rest", 0.7)
	marcus.inventory = ["lighter", "jacket"]
	marcus.goals = ["clear_mind", "observe_city"]
	_characters[marcus.id] = marcus

	characters_updated.emit()

func _physics_process(delta: float) -> void:
	if clock != null:
		clock.advance(delta)

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

func get_world_graph() -> WorldGraph:
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

	world_graph = WorldGraph.create_default_apartment()
	spawn_initial_characters()
	seed_changed.emit(get_seed())

func _on_clock_time_advanced(sim_time: float, formatted_time: String) -> void:
	time_updated.emit(sim_time, formatted_time)

func _on_clock_pause_toggled(is_paused: bool) -> void:
	pause_state_changed.emit(is_paused)

func _on_clock_speed_changed(multiplier: float) -> void:
	speed_multiplier_changed.emit(multiplier)

func _on_clock_simulation_completed() -> void:
	simulation_completed.emit()
