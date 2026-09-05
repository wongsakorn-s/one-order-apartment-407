class_name Main
extends Node

## Main entry scene for ONE ORDER: Apartment 407.
## Connects the SimulationRunner, WorldView, and MainUI layers.

@onready var simulation_runner: SimulationRunner = $SimulationRunner
@onready var world_view: WorldView = $WorldView
@onready var main_ui: MainUI = $MainUI

func _ready() -> void:
	if simulation_runner != null:
		if main_ui != null:
			main_ui.bind_runner(simulation_runner)
		if world_view != null:
			world_view.setup(simulation_runner.get_world_graph())
