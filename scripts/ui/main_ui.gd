class_name MainUI
extends CanvasLayer

## MainUI presentation layer displaying simulation clock, active seed, and control buttons.
## Listens to signals from SimulationRunner and sends user commands.

@export var simulation_runner: SimulationRunner

@onready var time_label: Label = %TimeLabel
@onready var seed_label: Label = %SeedLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_1x_button: Button = %Speed1xButton
@onready var speed_2x_button: Button = %Speed2xButton
@onready var speed_4x_button: Button = %Speed4xButton

func _ready() -> void:
	_ensure_node_references()
	if pause_button != null and not pause_button.pressed.is_connected(_on_pause_pressed):
		pause_button.pressed.connect(_on_pause_pressed)
	if speed_1x_button != null and not speed_1x_button.pressed.is_connected(_on_speed_1x_pressed):
		speed_1x_button.pressed.connect(_on_speed_1x_pressed)
	if speed_2x_button != null and not speed_2x_button.pressed.is_connected(_on_speed_2x_pressed):
		speed_2x_button.pressed.connect(_on_speed_2x_pressed)
	if speed_4x_button != null and not speed_4x_button.pressed.is_connected(_on_speed_4x_pressed):
		speed_4x_button.pressed.connect(_on_speed_4x_pressed)

	if simulation_runner != null:
		bind_runner(simulation_runner)

func _ensure_node_references() -> void:
	if time_label == null:
		time_label = get_node_or_null("%TimeLabel") as Label
	if seed_label == null:
		seed_label = get_node_or_null("%SeedLabel") as Label
	if status_label == null:
		status_label = get_node_or_null("%StatusLabel") as Label
	if pause_button == null:
		pause_button = get_node_or_null("%PauseButton") as Button
	if speed_1x_button == null:
		speed_1x_button = get_node_or_null("%Speed1xButton") as Button
	if speed_2x_button == null:
		speed_2x_button = get_node_or_null("%Speed2xButton") as Button
	if speed_4x_button == null:
		speed_4x_button = get_node_or_null("%Speed4xButton") as Button

func _on_speed_1x_pressed() -> void:
	_on_speed_pressed(1.0)

func _on_speed_2x_pressed() -> void:
	_on_speed_pressed(2.0)

func _on_speed_4x_pressed() -> void:
	_on_speed_pressed(4.0)

func bind_runner(runner: SimulationRunner) -> void:
	_ensure_node_references()
	if simulation_runner != null and simulation_runner != runner:
		_unbind_runner(simulation_runner)

	simulation_runner = runner
	if not runner.time_updated.is_connected(_on_time_updated):
		runner.time_updated.connect(_on_time_updated)
	if not runner.pause_state_changed.is_connected(_on_pause_state_changed):
		runner.pause_state_changed.connect(_on_pause_state_changed)
	if not runner.speed_multiplier_changed.is_connected(_on_speed_multiplier_changed):
		runner.speed_multiplier_changed.connect(_on_speed_multiplier_changed)
	if not runner.simulation_completed.is_connected(_on_simulation_completed):
		runner.simulation_completed.connect(_on_simulation_completed)
	if not runner.seed_changed.is_connected(_on_seed_changed):
		runner.seed_changed.connect(_on_seed_changed)

	_refresh_display()

func _unbind_runner(runner: SimulationRunner) -> void:
	if runner.time_updated.is_connected(_on_time_updated):
		runner.time_updated.disconnect(_on_time_updated)
	if runner.pause_state_changed.is_connected(_on_pause_state_changed):
		runner.pause_state_changed.disconnect(_on_pause_state_changed)
	if runner.speed_multiplier_changed.is_connected(_on_speed_multiplier_changed):
		runner.speed_multiplier_changed.disconnect(_on_speed_multiplier_changed)
	if runner.simulation_completed.is_connected(_on_simulation_completed):
		runner.simulation_completed.disconnect(_on_simulation_completed)
	if runner.seed_changed.is_connected(_on_seed_changed):
		runner.seed_changed.disconnect(_on_seed_changed)

func _refresh_display() -> void:
	_ensure_node_references()
	if simulation_runner == null:
		return

	if seed_label != null:
		seed_label.text = "Seed: %d" % simulation_runner.get_seed()
	var clock: SimulationClock = simulation_runner.get_clock()
	if clock != null:
		if time_label != null:
			time_label.text = clock.get_formatted_time(true)
		_update_pause_ui(clock.is_paused())
		_update_speed_buttons(clock.get_speed_multiplier())

func _on_seed_changed(new_seed: int) -> void:
	_ensure_node_references()
	if seed_label != null:
		seed_label.text = "Seed: %d" % new_seed

func _on_time_updated(_sim_time_seconds: float, formatted_time: String) -> void:
	_ensure_node_references()
	if time_label != null:
		time_label.text = formatted_time

func _on_pause_state_changed(is_paused: bool) -> void:
	_update_pause_ui(is_paused)

func _on_speed_multiplier_changed(multiplier: float) -> void:
	_update_speed_buttons(multiplier)

func _on_simulation_completed() -> void:
	_ensure_node_references()
	if status_label != null:
		status_label.text = "[COMPLETED - 06:00]"
		status_label.modulate = Color(1.0, 0.8, 0.2)
	if pause_button != null:
		pause_button.disabled = true

func _on_pause_pressed() -> void:
	if simulation_runner != null:
		simulation_runner.toggle_pause()

func _on_speed_pressed(multiplier: float) -> void:
	if simulation_runner != null:
		simulation_runner.set_speed_multiplier(multiplier)

func _update_pause_ui(is_paused: bool) -> void:
	_ensure_node_references()
	if pause_button == null or status_label == null:
		return

	pause_button.disabled = false
	if is_paused:
		pause_button.text = "Resume"
		status_label.text = "[PAUSED]"
		status_label.modulate = Color(1.0, 0.5, 0.3)
	else:
		pause_button.text = "Pause"
		status_label.text = "[RUNNING]"
		status_label.modulate = Color(0.4, 0.9, 0.4)

func _update_speed_buttons(active_multiplier: float) -> void:
	_ensure_node_references()
	if speed_1x_button == null or speed_2x_button == null or speed_4x_button == null:
		return
	_style_speed_button(speed_1x_button, is_equal_approx(active_multiplier, 1.0))
	_style_speed_button(speed_2x_button, is_equal_approx(active_multiplier, 2.0))
	_style_speed_button(speed_4x_button, is_equal_approx(active_multiplier, 4.0))

func _style_speed_button(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	if is_active:
		btn.modulate = Color(0.4, 0.85, 1.0, 1.0)
	else:
		btn.modulate = Color(0.75, 0.75, 0.75, 0.85)
