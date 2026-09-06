class_name MainUI
extends CanvasLayer

## MainUI presentation layer displaying simulation clock, active seed, control buttons,
## and a Character Debug Inspector.
## Listens to signals from SimulationRunner and sends user commands.

const DirectiveCatalogClass = preload("res://scripts/directives/directive_catalog.gd")
const RunEvaluatorClass = preload("res://scripts/simulation/run_evaluator.gd")

@export var simulation_runner: SimulationRunner

var _selected_character_id: String = ""
var _feed_lines: Array[String] = []
const MAX_FEED_LINES: int = 100

@onready var time_label: Label = %TimeLabel
@onready var seed_label: Label = %SeedLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_1x_button: Button = %Speed1xButton
@onready var speed_2x_button: Button = %Speed2xButton
@onready var speed_4x_button: Button = %Speed4xButton

@onready var directives_button: Button = %DirectivesButton
@onready var inspect_button: Button = %InspectButton
@onready var debug_panel: PanelContainer = %DebugPanel
@onready var close_inspect_button: Button = %CloseInspectButton
@onready var character_option_button: OptionButton = %CharacterOptionButton
@onready var debug_text: RichTextLabel = %DebugText

@onready var left_name_label: Label = %LeftNameLabel
@onready var left_location_label: Label = %LeftLocationLabel
@onready var left_action_label: Label = %LeftActionLabel
@onready var left_goal_label: Label = %LeftGoalLabel
@onready var left_emotion_label: Label = %LeftEmotionLabel
@onready var left_directives_separator: HSeparator = %LeftDirectivesSeparator
@onready var left_directives_title: Label = %LeftDirectivesTitle
@onready var left_want_label: Label = %LeftWantLabel
@onready var left_never_label: Label = %LeftNeverLabel
@onready var left_believe_label: Label = %LeftBelieveLabel

@onready var event_feed_text: RichTextLabel = %EventFeedText

@onready var setup_panel: PanelContainer = %SetupPanel
@onready var close_setup_button: Button = %CloseSetupButton
@onready var want_option_button: OptionButton = %WantOptionButton
@onready var want_desc_label: Label = %WantDescLabel
@onready var never_option_button: OptionButton = %NeverOptionButton
@onready var never_desc_label: Label = %NeverDescLabel
@onready var believe_option_button: OptionButton = %BelieveOptionButton
@onready var believe_desc_label: Label = %BelieveDescLabel
@onready var start_simulation_button: Button = %StartSimulationButton

@onready var end_run_panel: PanelContainer = %EndRunPanel
@onready var end_run_seed_label: Label = %EndRunSeedLabel
@onready var end_run_directives_text: RichTextLabel = %EndRunDirectivesText
@onready var end_run_final_state_text: RichTextLabel = %EndRunFinalStateText
@onready var end_run_relationships_text: RichTextLabel = %EndRunRelationshipsText
@onready var end_run_secrets_text: RichTextLabel = %EndRunSecretsText
@onready var end_run_memories_text: RichTextLabel = %EndRunMemoriesText
@onready var end_run_timeline_text: RichTextLabel = %EndRunTimelineText
@onready var replay_same_seed_button: Button = %ReplaySameSeedButton
@onready var new_seed_button: Button = %NewSeedButton
@onready var run_again_button: Button = %RunAgainButton

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

	if directives_button != null and not directives_button.pressed.is_connected(_on_directives_pressed):
		directives_button.pressed.connect(_on_directives_pressed)
	if close_setup_button != null and not close_setup_button.pressed.is_connected(_on_close_setup_pressed):
		close_setup_button.pressed.connect(_on_close_setup_pressed)
	if want_option_button != null and not want_option_button.item_selected.is_connected(_on_want_selected):
		want_option_button.item_selected.connect(_on_want_selected)
	if never_option_button != null and not never_option_button.item_selected.is_connected(_on_never_selected):
		never_option_button.item_selected.connect(_on_never_selected)
	if believe_option_button != null and not believe_option_button.item_selected.is_connected(_on_believe_selected):
		believe_option_button.item_selected.connect(_on_believe_selected)
	if start_simulation_button != null and not start_simulation_button.pressed.is_connected(_on_start_simulation_pressed):
		start_simulation_button.pressed.connect(_on_start_simulation_pressed)

	if inspect_button != null and not inspect_button.pressed.is_connected(_on_inspect_pressed):
		inspect_button.pressed.connect(_on_inspect_pressed)
	if close_inspect_button != null and not close_inspect_button.pressed.is_connected(_on_close_inspect_pressed):
		close_inspect_button.pressed.connect(_on_close_inspect_pressed)
	if character_option_button != null and not character_option_button.item_selected.is_connected(_on_character_selected):
		character_option_button.item_selected.connect(_on_character_selected)

	if replay_same_seed_button != null and not replay_same_seed_button.pressed.is_connected(_on_replay_same_seed_pressed):
		replay_same_seed_button.pressed.connect(_on_replay_same_seed_pressed)
	if new_seed_button != null and not new_seed_button.pressed.is_connected(_on_new_seed_pressed):
		new_seed_button.pressed.connect(_on_new_seed_pressed)
	if run_again_button != null and not run_again_button.pressed.is_connected(_on_run_again_pressed):
		run_again_button.pressed.connect(_on_run_again_pressed)

	_populate_directives_options()

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

	if directives_button == null:
		directives_button = get_node_or_null("%DirectivesButton") as Button
	if inspect_button == null:
		inspect_button = get_node_or_null("%InspectButton") as Button
	if debug_panel == null:
		debug_panel = get_node_or_null("%DebugPanel") as PanelContainer
	if close_inspect_button == null:
		close_inspect_button = get_node_or_null("%CloseInspectButton") as Button
	if character_option_button == null:
		character_option_button = get_node_or_null("%CharacterOptionButton") as OptionButton
	if debug_text == null:
		debug_text = get_node_or_null("%DebugText") as RichTextLabel

	if left_name_label == null:
		left_name_label = get_node_or_null("%LeftNameLabel") as Label
	if left_location_label == null:
		left_location_label = get_node_or_null("%LeftLocationLabel") as Label
	if left_action_label == null:
		left_action_label = get_node_or_null("%LeftActionLabel") as Label
	if left_goal_label == null:
		left_goal_label = get_node_or_null("%LeftGoalLabel") as Label
	if left_emotion_label == null:
		left_emotion_label = get_node_or_null("%LeftEmotionLabel") as Label
	if left_directives_separator == null:
		left_directives_separator = get_node_or_null("%LeftDirectivesSeparator") as HSeparator
	if left_directives_title == null:
		left_directives_title = get_node_or_null("%LeftDirectivesTitle") as Label
	if left_want_label == null:
		left_want_label = get_node_or_null("%LeftWantLabel") as Label
	if left_never_label == null:
		left_never_label = get_node_or_null("%LeftNeverLabel") as Label
	if left_believe_label == null:
		left_believe_label = get_node_or_null("%LeftBelieveLabel") as Label

	if event_feed_text == null:
		event_feed_text = get_node_or_null("%EventFeedText") as RichTextLabel

	if setup_panel == null:
		setup_panel = get_node_or_null("%SetupPanel") as PanelContainer
	if close_setup_button == null:
		close_setup_button = get_node_or_null("%CloseSetupButton") as Button
	if want_option_button == null:
		want_option_button = get_node_or_null("%WantOptionButton") as OptionButton
	if want_desc_label == null:
		want_desc_label = get_node_or_null("%WantDescLabel") as Label
	if never_option_button == null:
		never_option_button = get_node_or_null("%NeverOptionButton") as OptionButton
	if never_desc_label == null:
		never_desc_label = get_node_or_null("%NeverDescLabel") as Label
	if believe_option_button == null:
		believe_option_button = get_node_or_null("%BelieveOptionButton") as OptionButton
	if believe_desc_label == null:
		believe_desc_label = get_node_or_null("%BelieveDescLabel") as Label
	if start_simulation_button == null:
		start_simulation_button = get_node_or_null("%StartSimulationButton") as Button

	if end_run_panel == null:
		end_run_panel = get_node_or_null("%EndRunPanel") as PanelContainer
	if end_run_seed_label == null:
		end_run_seed_label = get_node_or_null("%EndRunSeedLabel") as Label
	if end_run_directives_text == null:
		end_run_directives_text = get_node_or_null("%EndRunDirectivesText") as RichTextLabel
	if end_run_final_state_text == null:
		end_run_final_state_text = get_node_or_null("%EndRunFinalStateText") as RichTextLabel
	if end_run_relationships_text == null:
		end_run_relationships_text = get_node_or_null("%EndRunRelationshipsText") as RichTextLabel
	if end_run_secrets_text == null:
		end_run_secrets_text = get_node_or_null("%EndRunSecretsText") as RichTextLabel
	if end_run_memories_text == null:
		end_run_memories_text = get_node_or_null("%EndRunMemoriesText") as RichTextLabel
	if end_run_timeline_text == null:
		end_run_timeline_text = get_node_or_null("%EndRunTimelineText") as RichTextLabel
	if replay_same_seed_button == null:
		replay_same_seed_button = get_node_or_null("%ReplaySameSeedButton") as Button
	if new_seed_button == null:
		new_seed_button = get_node_or_null("%NewSeedButton") as Button
	if run_again_button == null:
		run_again_button = get_node_or_null("%RunAgainButton") as Button

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
	if not runner.characters_updated.is_connected(_on_characters_updated):
		runner.characters_updated.connect(_on_characters_updated)
	if not runner.event_emitted.is_connected(_on_event_emitted):
		runner.event_emitted.connect(_on_event_emitted)
	if not runner.directives_updated.is_connected(_on_directives_updated):
		runner.directives_updated.connect(_on_directives_updated)

	_populate_directives_options()
	_populate_character_options()
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
	if runner.characters_updated.is_connected(_on_characters_updated):
		runner.characters_updated.disconnect(_on_characters_updated)
	if runner.event_emitted.is_connected(_on_event_emitted):
		runner.event_emitted.disconnect(_on_event_emitted)
	if runner.directives_updated.is_connected(_on_directives_updated):
		runner.directives_updated.disconnect(_on_directives_updated)

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

func _populate_character_options() -> void:
	_ensure_node_references()
	if character_option_button == null or simulation_runner == null:
		return

	character_option_button.clear()
	var chars = simulation_runner.get_all_characters()
	for i in range(chars.size()):
		var c = chars[i]
		var label_str = "%s (Protagonist)" % c.name if c.is_protagonist else "%s (%s)" % [c.name, c.current_location]
		character_option_button.add_item(label_str, i)
		character_option_button.set_item_metadata(i, c.id)

	if chars.size() > 0:
		var to_select: String = _selected_character_id
		if to_select.is_empty() or simulation_runner.get_character(to_select) == null:
			to_select = simulation_runner.get_protagonist().id if simulation_runner.get_protagonist() != null else chars[0].id
		select_character(to_select)

func _on_characters_updated() -> void:
	_populate_character_options()

func _on_event_emitted(event_dict: Dictionary) -> void:
	_ensure_node_references()
	_append_event_feed_line(event_dict)

	if debug_panel != null and debug_panel.visible and character_option_button != null:
		var selected_idx = character_option_button.selected
		if selected_idx >= 0:
			var selected_id = character_option_button.get_item_metadata(selected_idx)
			_show_character_debug(selected_id)

	if not _selected_character_id.is_empty():
		_update_left_panel(_selected_character_id)

## Append a formatted line to the always-visible live Event Feed (TASK-014).
func _append_event_feed_line(event_dict: Dictionary) -> void:
	if event_feed_text == null:
		return

	var total_seconds: int = int(float(event_dict.get("timestamp", 0.0)))
	var hours: int = (total_seconds / 3600) % 24
	var minutes: int = (total_seconds % 3600) / 60
	var description: String = str(event_dict.get("description", ""))
	if description.is_empty():
		return

	_feed_lines.append("%02d:%02d %s" % [hours, minutes, description])
	if _feed_lines.size() > MAX_FEED_LINES:
		_feed_lines.remove_at(0)

	event_feed_text.text = "\n".join(_feed_lines)
	event_feed_text.scroll_to_line(event_feed_text.get_line_count() - 1)

func _on_inspect_pressed() -> void:
	_ensure_node_references()
	if debug_panel != null:
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_populate_character_options()

func _on_close_inspect_pressed() -> void:
	_ensure_node_references()
	if debug_panel != null:
		debug_panel.visible = false

func _on_character_selected(index: int) -> void:
	_ensure_node_references()
	if character_option_button == null:
		return
	var char_id: String = character_option_button.get_item_metadata(index)
	select_character(char_id)

## Called when the player clicks a character circle in the WorldView (TASK-014).
func on_world_character_selected(char_id: String) -> void:
	select_character(char_id)

## Unified selection entry point: updates the always-visible Left Panel and,
## if open, the Developer Debug Mode inspector, keeping both in sync regardless
## of whether selection came from clicking the world view or the dropdown.
func select_character(char_id: String) -> void:
	_ensure_node_references()
	if simulation_runner == null or simulation_runner.get_character(char_id) == null:
		return

	_selected_character_id = char_id
	_select_option_by_metadata(character_option_button, char_id)
	_update_left_panel(char_id)
	_show_character_debug(char_id)

func _show_character_debug(char_id: String) -> void:
	_ensure_node_references()
	if debug_text == null or simulation_runner == null:
		return
	var c = simulation_runner.get_character(char_id)
	if c != null:
		debug_text.text = c.get_debug_summary()
	else:
		debug_text.text = "Character not found: %s" % char_id

## Update the always-visible Left Panel (player-facing, TASK-014): name,
## location, current action, primary goal, emotion, and for the protagonist
## also WANT/NEVER/BELIEVE. Distinct from the Developer Debug Mode inspector.
func _update_left_panel(char_id: String) -> void:
	_ensure_node_references()
	if simulation_runner == null:
		return
	var c: CharacterState = simulation_runner.get_character(char_id)
	if c == null:
		return

	if left_name_label != null:
		left_name_label.text = "%s (Protagonist)" % c.name if c.is_protagonist else c.name
	if left_location_label != null:
		left_location_label.text = "Location: %s" % _location_display_name(c.current_location)
	if left_action_label != null:
		left_action_label.text = "Action: %s" % c.current_action.get("description", c.current_action.get("id", "Idle"))
	if left_goal_label != null:
		var goal_desc: String = "None"
		if not c.goals.is_empty() and c.goals[0] is Dictionary:
			goal_desc = c.goals[0].get("description", c.goals[0].get("id", "Unnamed goal"))
		left_goal_label.text = "Goal: %s" % goal_desc
	if left_emotion_label != null:
		left_emotion_label.text = "Emotion: Happy %.2f | Fear %.2f | Anger %.2f | Stress %.2f" % [
			c.get_emotion("happiness"), c.get_emotion("fear"), c.get_emotion("anger"), c.get_emotion("stress")
		]

	var show_directives: bool = c.is_protagonist and c.has_directives()
	if left_directives_separator != null:
		left_directives_separator.visible = show_directives
	if left_directives_title != null:
		left_directives_title.visible = show_directives
	if left_want_label != null:
		left_want_label.visible = show_directives
	if left_never_label != null:
		left_never_label.visible = show_directives
	if left_believe_label != null:
		left_believe_label.visible = show_directives

	if show_directives:
		var want_dir = c.get_directive("want")
		var never_dir = c.get_directive("never")
		var believe_dir = c.get_directive("believe")
		if left_want_label != null and want_dir != null:
			left_want_label.text = "WANT: %s" % want_dir.title
		if left_never_label != null and never_dir != null:
			left_never_label.text = "NEVER: %s" % never_dir.title
		if left_believe_label != null and believe_dir != null:
			left_believe_label.text = "BELIEVE: %s" % believe_dir.title

func _location_display_name(loc_id: String) -> String:
	if simulation_runner != null:
		var world_graph = simulation_runner.get_world_graph()
		if world_graph != null:
			var loc = world_graph.get_location(loc_id)
			if loc != null:
				return loc.display_name
	return loc_id.capitalize()

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

	_show_end_run_screen()

## TASK-016: Build and display the end-of-run summary (WANT/NEVER/BELIEVE,
## major relationships, discovered secrets, memories, and a simple
## chronological causal timeline) automatically when the run ends at 06:00.
func _show_end_run_screen() -> void:
	if simulation_runner == null or end_run_panel == null:
		return

	var result: Dictionary = RunEvaluatorClass.evaluate(simulation_runner)
	if result.is_empty():
		return

	if end_run_seed_label != null:
		end_run_seed_label.text = "Seed: %d" % simulation_runner.get_seed()

	if end_run_directives_text != null:
		end_run_directives_text.text = _format_directives_summary(result)
	if end_run_final_state_text != null:
		end_run_final_state_text.text = _format_final_state(result.get("protagonist_final_state", {}))
	if end_run_relationships_text != null:
		end_run_relationships_text.text = _format_bulleted(result.get("major_relationships", []), "No notable relationships formed.")
	if end_run_secrets_text != null:
		end_run_secrets_text.text = _format_secrets(result.get("discovered_secrets", []))
	if end_run_memories_text != null:
		end_run_memories_text.text = _format_bulleted(result.get("major_memories", []), "No significant memories formed.")
	if end_run_timeline_text != null:
		end_run_timeline_text.text = _format_timeline(result.get("causal_timeline", []))

	end_run_panel.visible = true

func _status_color(status: String) -> String:
	match status:
		"success", "respected":
			return "#66e07a"
		"partial":
			return "#e0c766"
		"failure", "violated":
			return "#e06666"
		_:
			return "#cccccc"

func _format_directives_summary(result: Dictionary) -> String:
	var want: Dictionary = result.get("want", {})
	var never: Dictionary = result.get("never", {})
	var believe: Dictionary = result.get("believe", {})

	var lines: Array[String] = []
	lines.append("[b]WANT[/b]: %s" % want.get("title", ""))
	lines.append("[color=%s]%s[/color] — %s" % [_status_color(want.get("status", "")), str(want.get("status", "")).to_upper(), want.get("reason", "")])
	lines.append("")
	lines.append("[b]NEVER[/b]: %s" % never.get("title", ""))
	lines.append("[color=%s]%s[/color]" % [_status_color(never.get("status", "")), str(never.get("status", "")).to_upper()])
	lines.append("")
	lines.append("[b]BELIEVE[/b]: %s" % believe.get("title", ""))
	lines.append(believe.get("summary", ""))
	return "\n".join(lines)

func _format_final_state(state: Dictionary) -> String:
	if state.is_empty():
		return "-"
	var emotions: Dictionary = state.get("emotions", {})
	var lines: Array[String] = []
	lines.append("%s ended the night in %s." % [state.get("name", ""), str(state.get("location", "")).capitalize()])
	lines.append("Happy %.2f | Fear %.2f | Anger %.2f | Stress %.2f" % [
		emotions.get("happiness", 0.0), emotions.get("fear", 0.0), emotions.get("anger", 0.0), emotions.get("stress", 0.0)
	])
	var inv: Array = state.get("inventory", [])
	lines.append("Inventory: %s" % (", ".join(inv) if not inv.is_empty() else "(empty)"))
	return "\n".join(lines)

func _format_bulleted(lines: Array, empty_text: String) -> String:
	if lines.is_empty():
		return empty_text
	var out: Array[String] = []
	for line in lines:
		out.append("• %s" % str(line))
	return "\n".join(out)

func _format_secrets(secrets: Array) -> String:
	if secrets.is_empty():
		return "No secrets were generated this run."
	var out: Array[String] = []
	for s in secrets:
		var discovered: bool = s.get("discovered", false)
		var tag: String = "[color=#66e07a]discovered[/color]" if discovered else "[color=#888888]hidden[/color]"
		out.append("• %s (%s)" % [s.get("description", ""), tag])
	return "\n".join(out)

func _format_timeline(lines: Array) -> String:
	if lines.is_empty():
		return "Nothing significant happened tonight."
	return "\n↓\n".join(lines)

func _on_replay_same_seed_pressed() -> void:
	_ensure_node_references()
	if simulation_runner == null:
		return
	if end_run_panel != null:
		end_run_panel.visible = false
	simulation_runner.reset_simulation()

func _on_new_seed_pressed() -> void:
	_ensure_node_references()
	if simulation_runner == null:
		return
	if end_run_panel != null:
		end_run_panel.visible = false
	simulation_runner.reset_simulation(_generate_new_seed())

func _on_run_again_pressed() -> void:
	_ensure_node_references()
	if simulation_runner == null:
		return
	if end_run_panel != null:
		end_run_panel.visible = false
	simulation_runner.reset_simulation(_generate_new_seed())
	simulation_runner.set_paused(true)
	if setup_panel != null:
		setup_panel.visible = true
		_sync_directives_ui_from_runner()

## New seeds for replay buttons come from wall-clock time (a meta/UI-level
## choice of which seed to hand the simulation), never from inside the
## deterministic simulation itself.
func _generate_new_seed() -> int:
	return int(Time.get_ticks_usec() % 100000000)

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

func _populate_directives_options() -> void:
	_ensure_node_references()
	if want_option_button == null or never_option_button == null or believe_option_button == null:
		return

	want_option_button.clear()
	var wants = DirectiveCatalogClass.get_available_wants()
	for i in range(wants.size()):
		var w = wants[i]
		want_option_button.add_item(w.name, i)
		want_option_button.set_item_metadata(i, w.id)

	never_option_button.clear()
	var nevers = DirectiveCatalogClass.get_available_nevers()
	for i in range(nevers.size()):
		var n = nevers[i]
		never_option_button.add_item(n.name, i)
		never_option_button.set_item_metadata(i, n.id)

	believe_option_button.clear()
	var beliefs = DirectiveCatalogClass.get_available_beliefs()
	for i in range(beliefs.size()):
		var b = beliefs[i]
		believe_option_button.add_item(b.name, i)
		believe_option_button.set_item_metadata(i, b.id)

	_sync_directives_ui_from_runner()

func _sync_directives_ui_from_runner() -> void:
	if simulation_runner == null:
		return
	var current_directives = simulation_runner.get_player_directive_ids()
	var want_id = current_directives.get("want", "learn_room_407")
	var never_id = current_directives.get("never", "never_steal")
	var belief_id = current_directives.get("believe", "everyone_hiding_something")

	_select_option_by_metadata(want_option_button, want_id)
	_select_option_by_metadata(never_option_button, never_id)
	_select_option_by_metadata(believe_option_button, belief_id)

	_update_directive_descriptions()

func _select_option_by_metadata(btn: OptionButton, meta_id: String) -> void:
	if btn == null:
		return
	for i in range(btn.item_count):
		if btn.get_item_metadata(i) == meta_id:
			btn.selected = i
			return

func _update_directive_descriptions() -> void:
	if want_option_button != null and want_desc_label != null:
		var idx = want_option_button.selected
		if idx >= 0:
			var wid = want_option_button.get_item_metadata(idx)
			var w = DirectiveCatalogClass.get_want(wid)
			if w != null:
				want_desc_label.text = "%s: %s" % [w.title, w.description]
	if never_option_button != null and never_desc_label != null:
		var idx = never_option_button.selected
		if idx >= 0:
			var nid = never_option_button.get_item_metadata(idx)
			var n = DirectiveCatalogClass.get_never(nid)
			if n != null:
				never_desc_label.text = "%s: %s" % [n.title, n.description]
	if believe_option_button != null and believe_desc_label != null:
		var idx = believe_option_button.selected
		if idx >= 0:
			var bid = believe_option_button.get_item_metadata(idx)
			var b = DirectiveCatalogClass.get_belief(bid)
			if b != null:
				believe_desc_label.text = "%s: %s" % [b.title, b.description]

func _on_directives_pressed() -> void:
	_ensure_node_references()
	if setup_panel != null:
		setup_panel.visible = not setup_panel.visible
		if setup_panel.visible:
			_sync_directives_ui_from_runner()

func _on_close_setup_pressed() -> void:
	_ensure_node_references()
	if setup_panel != null:
		setup_panel.visible = false

func _on_want_selected(_index: int) -> void:
	_update_directive_descriptions()

func _on_never_selected(_index: int) -> void:
	_update_directive_descriptions()

func _on_believe_selected(_index: int) -> void:
	_update_directive_descriptions()

func _on_start_simulation_pressed() -> void:
	_ensure_node_references()
	if simulation_runner != null:
		var want_id = ""
		var never_id = ""
		var belief_id = ""
		if want_option_button != null and want_option_button.selected >= 0:
			want_id = want_option_button.get_item_metadata(want_option_button.selected)
		if never_option_button != null and never_option_button.selected >= 0:
			never_id = never_option_button.get_item_metadata(never_option_button.selected)
		if believe_option_button != null and believe_option_button.selected >= 0:
			belief_id = believe_option_button.get_item_metadata(believe_option_button.selected)

		simulation_runner.set_player_directives(want_id, never_id, belief_id)
		var clock = simulation_runner.get_clock()
		if clock != null and clock.is_paused():
			simulation_runner.set_paused(false)

	if setup_panel != null:
		setup_panel.visible = false

func _on_directives_updated(_want_id: String, _never_id: String, _belief_id: String) -> void:
	_sync_directives_ui_from_runner()
	if debug_panel != null and debug_panel.visible and character_option_button != null:
		var selected_idx = character_option_button.selected
		if selected_idx >= 0:
			var selected_id = character_option_button.get_item_metadata(selected_idx)
			_show_character_debug(selected_id)
	if not _selected_character_id.is_empty():
		_update_left_panel(_selected_character_id)
