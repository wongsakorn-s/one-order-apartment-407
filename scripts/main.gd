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
				main_ui.world_view = world_view
				if not main_ui.character_selected.is_connected(world_view.set_selected_character):
					main_ui.character_selected.connect(world_view.set_selected_character)
			# TASK-020: on real launch, pause before the player has chosen
			# directives and show the setup screen, matching the intended
			# flow (choose WANT/NEVER/BELIEVE, then Start Simulation).
			main_ui.show_initial_setup()
		if world_view != null:
			world_view.setup(
				simulation_runner.get_world_graph(),
				simulation_runner.get_all_characters()
			)
			if not simulation_runner.characters_updated.is_connected(_on_characters_updated):
				simulation_runner.characters_updated.connect(_on_characters_updated)
			if main_ui != null and not world_view.character_selected.is_connected(main_ui.on_world_character_selected):
				world_view.character_selected.connect(main_ui.on_world_character_selected)

func _on_characters_updated() -> void:
	if world_view != null and simulation_runner != null:
		world_view.set_characters(simulation_runner.get_all_characters())
