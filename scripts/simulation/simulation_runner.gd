class_name SimulationRunner
extends Node

## SimulationRunner coordinates the core simulation loop, clock, random service, and world graph.
## Ticks during physics process to ensure deterministic time step advancement decoupled from FPS.

signal time_updated(sim_time_seconds: float, formatted_time: String)
signal pause_state_changed(is_paused: bool)
signal speed_multiplier_changed(multiplier: float)
signal simulation_completed()

@export var initial_seed: int = 12345

var clock: SimulationClock
var random_service: RandomService
var world_graph: WorldGraph

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

	# Initial announcement of state
	time_updated.emit(clock.get_current_sim_seconds(), clock.get_formatted_time(true))
	pause_state_changed.emit(clock.is_paused())
	speed_multiplier_changed.emit(clock.get_speed_multiplier())

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

func _on_clock_time_advanced(sim_time: float, formatted_time: String) -> void:
	time_updated.emit(sim_time, formatted_time)

func _on_clock_pause_toggled(is_paused: bool) -> void:
	pause_state_changed.emit(is_paused)

func _on_clock_speed_changed(multiplier: float) -> void:
	speed_multiplier_changed.emit(multiplier)

func _on_clock_simulation_completed() -> void:
	simulation_completed.emit()
