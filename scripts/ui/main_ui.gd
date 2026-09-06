class_name MainUI
extends CanvasLayer

## MainUI presentation layer displaying simulation clock, active seed, control buttons,
## and a Character Debug Inspector.
## Listens to signals from SimulationRunner and sends user commands.

signal character_selected(char_id: String)

const DirectiveCatalogClass = preload("res://scripts/directives/directive_catalog.gd")
const RunEvaluatorClass = preload("res://scripts/simulation/run_evaluator.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")

@export var simulation_runner: SimulationRunner
@export var world_view: Node = null

var _selected_character_id: String = ""
var _feed_lines: Array[String] = []
var _notification_timer: float = 0.0
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
@onready var left_relationship_label: Label = %LeftRelationshipLabel
@onready var left_memory_label: Label = %LeftMemoryLabel
@onready var left_directives_separator: HSeparator = %LeftDirectivesSeparator
@onready var left_directives_title: Label = %LeftDirectivesTitle
@onready var left_want_label: Label = %LeftWantLabel
@onready var left_want_progress_label: Label = %LeftWantProgressLabel
@onready var left_never_label: Label = %LeftNeverLabel
@onready var left_believe_label: Label = %LeftBelieveLabel

@onready var event_feed_text: RichTextLabel = %EventFeedText
@onready var notification_banner: PanelContainer = %NotificationBanner
@onready var notification_label: RichTextLabel = %NotificationLabel

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

func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			if notification_banner != null:
				notification_banner.visible = false

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
	if left_relationship_label == null:
		left_relationship_label = get_node_or_null("%LeftRelationshipLabel") as Label
	if left_memory_label == null:
		left_memory_label = get_node_or_null("%LeftMemoryLabel") as Label
	if left_directives_separator == null:
		left_directives_separator = get_node_or_null("%LeftDirectivesSeparator") as HSeparator
	if left_directives_title == null:
		left_directives_title = get_node_or_null("%LeftDirectivesTitle") as Label
	if left_want_label == null:
		left_want_label = get_node_or_null("%LeftWantLabel") as Label
	if left_want_progress_label == null:
		left_want_progress_label = get_node_or_null("%LeftWantProgressLabel") as Label
	if left_never_label == null:
		left_never_label = get_node_or_null("%LeftNeverLabel") as Label
	if left_believe_label == null:
		left_believe_label = get_node_or_null("%LeftBelieveLabel") as Label

	if event_feed_text == null:
		event_feed_text = get_node_or_null("%EventFeedText") as RichTextLabel
	if notification_banner == null:
		notification_banner = get_node_or_null("%NotificationBanner") as PanelContainer
	if notification_label == null:
		notification_label = get_node_or_null("%NotificationLabel") as RichTextLabel

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

	var etype: String = str(event_dict.get("event_type", "")).to_lower()
	var actor_id: String = str(event_dict.get("actor_id", ""))
	var target_id: String = str(event_dict.get("target_id", ""))

	var protagonist_id: String = ""
	if simulation_runner != null and simulation_runner.get_protagonist() != null:
		protagonist_id = simulation_runner.get_protagonist().id

	var is_actor_protagonist: bool = (not protagonist_id.is_empty() and actor_id == protagonist_id)
	var is_target_protagonist: bool = (not protagonist_id.is_empty() and target_id == protagonist_id)

	var actor_tag: String = ""
	if is_actor_protagonist:
		actor_tag = "[b][color=#40c4ff][Alex][/color][/b] "
	elif is_target_protagonist:
		actor_tag = "[b][color=#ffb74d][►Alex][/color][/b] "

	var time_prefix: String = "[color=#7a8b9e]%02d:%02d[/color] " % [hours, minutes]
	var formatted_body: String = description

	# Categorize event severity & style
	var is_high_priority: bool = false
	if etype in ["confront", "argue", "flee"]:
		formatted_body = "[b][color=#ff6b6b]⚠️ %s[/color][/b]" % description
		is_high_priority = true
	elif etype in ["take_item", "steal"]:
		formatted_body = "[b][color=#ff8a65]✋ %s[/color][/b]" % description
		is_high_priority = true
	elif "secret" in description.to_lower() or "room 407" in description.to_lower() or etype in ["search_room", "investigate"]:
		formatted_body = "[color=#cc88ff]🔍 %s[/color]" % description
		if "room 407" in description.to_lower() or "secret" in description.to_lower():
			is_high_priority = true
	elif etype in ["help", "give_item"]:
		formatted_body = "[color=#69f0ae]🤝 %s[/color]" % description
	elif etype in ["talk", "converse", "share_info"]:
		formatted_body = "[color=#80d8ff]💬 %s[/color]" % description
	elif etype in ["move", "move_to"]:
		formatted_body = "[color=#78909c]  %s[/color]" % description
	else:
		formatted_body = "[color=#cfd8dc]%s[/color]" % description

	var line: String = "%s%s%s" % [time_prefix, actor_tag, formatted_body]
	_feed_lines.append(line)
	if _feed_lines.size() > MAX_FEED_LINES:
		_feed_lines.remove_at(0)

	event_feed_text.text = "\n".join(_feed_lines)
	event_feed_text.scroll_to_line(event_feed_text.get_line_count() - 1)

	if is_high_priority:
		_trigger_notification(description, etype)

func _trigger_notification(description: String, etype: String) -> void:
	_ensure_node_references()
	if notification_banner == null or notification_label == null:
		return

	var icon: String = "📢"
	var color_hex: String = "#ffd54f"
	if etype in ["confront", "argue", "flee"]:
		icon = "⚠️"
		color_hex = "#ff6b6b"
	elif etype in ["take_item", "steal"]:
		icon = "✋"
		color_hex = "#ff8a65"
	elif "room 407" in description.to_lower():
		icon = "🗝️"
		color_hex = "#b388ff"
	elif etype in ["help", "give_item"]:
		icon = "🤝"
		color_hex = "#69f0ae"

	notification_label.text = "[center][b][color=%s]%s %s[/color][/b][/center]" % [color_hex, icon, description]
	notification_banner.visible = true
	_notification_timer = 4.0

func _on_inspect_pressed() -> void:
	_ensure_node_references()
	if debug_panel != null:
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_populate_character_options()

func _on_close_inspect_button() -> void:
	_ensure_node_references()
	if debug_panel != null:
		debug_panel.visible = false

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
	if world_view != null and world_view.has_method("set_selected_character"):
		world_view.set_selected_character(char_id)
	character_selected.emit(char_id)

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
## location, current action, primary goal, mood in human terms, bond, recent memory,
## and for the protagonist also dynamic WANT progress and NEVER/BELIEVE.
func _update_left_panel(char_id: String) -> void:
	_ensure_node_references()
	if simulation_runner == null:
		return
	var c: CharacterState = simulation_runner.get_character(char_id)
	if c == null:
		return

	if left_name_label != null:
		left_name_label.text = "★ %s (YOU)" % c.name if c.is_protagonist else c.name
		if c.is_protagonist:
			left_name_label.modulate = Color(1.0, 0.9, 0.3)
		else:
			left_name_label.modulate = Color(1.0, 1.0, 1.0)
	if left_location_label != null:
		left_location_label.text = "Location: %s" % _location_display_name(c.current_location)
	if left_action_label != null:
		var act_desc: String = c.current_action.get("description", c.current_action.get("id", "Idle"))
		left_action_label.text = "Action: %s" % act_desc
	if left_goal_label != null:
		var goal_desc: String = "None"
		if not c.goals.is_empty() and c.goals[0] is Dictionary:
			goal_desc = c.goals[0].get("description", c.goals[0].get("id", "Unnamed goal"))
		left_goal_label.text = "Goal: %s" % goal_desc
	if left_emotion_label != null:
		left_emotion_label.text = "Emotion: %s" % _format_qualitative_mood(c)
	if left_relationship_label != null:
		left_relationship_label.text = "Bond: %s" % _format_key_relationship(c)
	if left_memory_label != null:
		left_memory_label.text = "Recent: %s" % _format_recent_memory(c)

	var show_directives: bool = c.is_protagonist and c.has_directives()
	if left_directives_separator != null:
		left_directives_separator.visible = show_directives
	if left_directives_title != null:
		left_directives_title.visible = show_directives
	if left_want_label != null:
		left_want_label.visible = show_directives
	if left_want_progress_label != null:
		left_want_progress_label.visible = show_directives
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
		if left_want_progress_label != null and want_dir != null:
			var wid: String = want_dir.id if "id" in want_dir else ""
			left_want_progress_label.text = _format_want_progress(c, wid)
		if left_never_label != null and never_dir != null:
			left_never_label.text = "NEVER: %s" % never_dir.title
		if left_believe_label != null and believe_dir != null:
			left_believe_label.text = "BELIEVE: %s" % believe_dir.title

func _format_qualitative_mood(c: CharacterState) -> String:
	var happy: float = c.get_emotion("happiness")
	var fear: float = c.get_emotion("fear")
	var anger: float = c.get_emotion("anger")
	var stress: float = c.get_emotion("stress")

	if stress >= 0.7 or fear >= 0.7:
		if anger >= 0.5:
			return "Cornered & Hostile"
		elif fear >= 0.7:
			return "Terrified & Paranoid"
		else:
			return "Severe Stress & Shaken"
	elif anger >= 0.6:
		return "Agitated & Confrontational"
	elif fear >= 0.5:
		return "Anxious & On Edge"
	elif stress >= 0.5:
		return "Tense & Pressured"
	elif happy >= 0.65:
		return "Optimistic & Cheerful"
	elif happy >= 0.45:
		return "Calm & Composed"
	elif fear >= 0.35 or stress >= 0.35:
		return "Uneasy & Guarded"
	else:
		return "Quiet & Observant"

func _format_key_relationship(c: CharacterState) -> String:
	if simulation_runner == null:
		return "None"
	var best_char: String = ""
	var best_trust: float = -1.0
	var worst_char: String = ""
	var worst_trust: float = 2.0

	for other_id in c.relationships.keys():
		var other = simulation_runner.get_character(other_id)
		if other == null:
			continue
		var trust: float = c.get_relationship_value(other_id, "trust")
		if trust > best_trust:
			best_trust = trust
			best_char = other.name
		if trust < worst_trust:
			worst_trust = trust
			worst_char = other.name

	if best_trust >= 0.6:
		return "Close bond with %s" % best_char
	elif worst_trust <= 0.35 and not worst_char.is_empty():
		return "Suspicious of %s" % worst_char
	elif best_trust >= 0.45 and not best_char.is_empty():
		return "Friendly with %s" % best_char
	elif not best_char.is_empty():
		return "Neutral toward %s" % best_char
	return "Keeps to themselves"

func _format_recent_memory(c: CharacterState) -> String:
	var memories = c.get_memories()
	if memories.is_empty():
		return "Nothing notable yet"
	var last_mem = memories[memories.size() - 1]
	var desc: String = ""
	if last_mem is MemoryClass:
		desc = last_mem.description
	elif last_mem is Dictionary:
		desc = str(last_mem.get("description", ""))
	if desc.is_empty():
		return "Routine observations"
	if desc.length() > 36:
		desc = desc.substr(0, 33) + "..."
	return desc

func _format_want_progress(protagonist: CharacterState, want_id: String) -> String:
	match want_id:
		"learn_room_407":
			var has_room_status: bool = protagonist.has_belief("room_407", "status") and protagonist.get_belief_value("room_407", "status") != "locked"
			var has_key: bool = "room_407_key" in protagonist.inventory or protagonist.has_hidden_item("room_407_key") or protagonist.has_belief("room_407", "key_holder")
			if has_room_status:
				return "Progress: Uncovered Room 407 details!"
			elif has_key:
				return "Progress: Has Room 407 key / lead"
			elif protagonist.current_location == "room_407":
				return "Progress: Currently searching Room 407"
			else:
				for m in protagonist.get_memories():
					var loc: String = m.location if m is MemoryClass else str(m.get("location", ""))
					if loc == "room_407":
						return "Progress: Searched 407, seeking clues"
				return "Progress: Not investigated yet"

		"earn_money":
			var valuable_items: Array[String] = ["cash", "hidden_cash", "stolen_jewelry"]
			var count: int = 0
			for item in protagonist.inventory:
				if item in valuable_items: count += 1
			for item in protagonist.hidden_items:
				if item in valuable_items: count += 1
			return "Progress: Holding %d valuable(s)" % count

		"make_friend":
			var best_trust: float = 0.0
			var best_name: String = "nobody"
			for other_id in protagonist.relationships.keys():
				var t: float = protagonist.get_relationship_value(other_id, "trust")
				if t > best_trust:
					best_trust = t
					if simulation_runner != null:
						var other = simulation_runner.get_character(other_id)
						if other != null:
							best_name = other.name
			if best_trust >= 0.7:
				return "Progress: Bond formed with %s!" % best_name
			elif best_trust >= 0.5:
				return "Progress: Warmer with %s (Trust %.0f%%)" % [best_name, best_trust * 100.0]
			return "Progress: No close bonds yet"

		"survive_night":
			var confront_count: int = 0
			if simulation_runner != null:
				for evt in simulation_runner.get_events():
					if evt.get("event_type", "") == "confront" and evt.get("target_id", "") == protagonist.id:
						confront_count += 1
			if confront_count == 0:
				return "Progress: Safe (0 confrontations)"
			else:
				return "Progress: Confronted %d time(s)!" % confront_count

		"be_trusted":
			if simulation_runner == null:
				return "Progress: Evaluating..."
			var total: float = 0.0
			var n: int = 0
			for c in simulation_runner.get_all_characters():
				if c.id == protagonist.id:
					continue
				total += c.get_relationship_value(protagonist.id, "trust")
				n += 1
			var avg: float = total / n if n > 0 else 0.0
			return "Progress: Community trust %.0f%%" % (avg * 100.0)

		_:
			return "Progress: In pursuit"

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
	lines.append("[font_size=15][b][color=#ffd700]▶ DIRECTIVE VERDICTS[/color][/b][/font_size]")
	lines.append("")
	lines.append("[b]WANT[/b]: %s" % want.get("title", ""))
	var want_status: String = str(want.get("status", "")).to_upper()
	lines.append("   Verdict: [b][color=%s]● %s[/color][/b] — %s" % [
		_status_color(want.get("status", "")),
		want_status,
		want.get("reason", "")
	])
	lines.append("")
	lines.append("[b]NEVER[/b]: %s" % never.get("title", ""))
	var never_status: String = str(never.get("status", "")).to_upper()
	var never_detail: String = "Rule was strictly respected throughout the night." if never_status == "RESPECTED" else "Rule was broken during the simulation!"
	lines.append("   Verdict: [b][color=%s]● %s[/color][/b] — %s" % [
		_status_color(never.get("status", "")),
		never_status,
		never_detail
	])
	lines.append("")
	lines.append("[b]BELIEVE[/b]: %s" % believe.get("title", ""))
	lines.append("   Worldview: %s" % believe.get("summary", ""))
	return "\n".join(lines)

func _format_final_state(state: Dictionary) -> String:
	if state.is_empty():
		return "-"
	var lines: Array[String] = []
	lines.append("[b]Location:[/b] %s" % str(state.get("location", "")).capitalize())

	var emotions: Dictionary = state.get("emotions", {})
	var happy: float = float(emotions.get("happiness", 0.0))
	var fear: float = float(emotions.get("fear", 0.0))
	var anger: float = float(emotions.get("anger", 0.0))
	var stress: float = float(emotions.get("stress", 0.0))

	var mood_str: String = "Quiet & Guarded"
	if stress >= 0.7 or fear >= 0.7:
		mood_str = "Terrified & Shaken" if fear >= 0.7 else "Severely Stressed"
	elif anger >= 0.6:
		mood_str = "Bitter & Resentful"
	elif fear >= 0.5:
		mood_str = "Nervous & Paranoid"
	elif happy >= 0.6:
		mood_str = "Triumphant & Content"
	elif happy >= 0.4:
		mood_str = "Relieved & Peaceful"
	lines.append("[b]Mental State:[/b] %s" % mood_str)

	var inv: Array = state.get("inventory", [])
	var inv_str: String = "(Nothing in pockets)"
	if not inv.is_empty():
		var pretty_items: Array[String] = []
		for item in inv:
			pretty_items.append(str(item).replace("_", " ").capitalize())
		inv_str = ", ".join(pretty_items)
	lines.append("[b]Possessions:[/b] %s" % inv_str)
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
	var styled_lines: Array[String] = []
	for i in range(lines.size()):
		var line: String = str(lines[i])
		if i == 0 and line.begins_with("Player directive:"):
			styled_lines.append("[color=#ffd54f][b]▶ INTENTION:[/b] %s[/color]" % line.substr(17).strip_edges())
		elif "confront" in line.to_lower() or "refuse" in line.to_lower() or "argue" in line.to_lower():
			styled_lines.append("[color=#ff6b6b]⚠️ %s[/color]" % line)
		elif "room 407" in line.to_lower() or "secret" in line.to_lower():
			styled_lines.append("[color=#cc88ff]🗝️ %s[/color]" % line)
		elif "help" in line.to_lower() or "share" in line.to_lower():
			styled_lines.append("[color=#69f0ae]🤝 %s[/color]" % line)
		elif "alex" in line.to_lower():
			styled_lines.append("[color=#40c4ff]%s[/color]" % line)
		else:
			styled_lines.append("[color=#cfd8dc]%s[/color]" % line)

	return "\n[color=#546e7a]   ↓[/color]\n".join(styled_lines)

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

## Called once by Main._ready() on real launch (TASK-020): pause before the
## player has chosen directives and show the setup screen, so the actual
## play flow matches "choose WANT/NEVER/BELIEVE, then Start Simulation"
## rather than the simulation already running with default directives.
func show_initial_setup() -> void:
	_ensure_node_references()
	if simulation_runner != null:
		simulation_runner.set_paused(true)
	if setup_panel != null:
		setup_panel.visible = true
		_sync_directives_ui_from_runner()

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

func _on_directives_updated(_want_dict: Dictionary, _never_dict: Dictionary, _believe_dict: Dictionary) -> void:
	_sync_directives_ui_from_runner()
	if debug_panel != null and debug_panel.visible and character_option_button != null:
		var selected_idx = character_option_button.selected
		if selected_idx >= 0:
			var selected_id = character_option_button.get_item_metadata(selected_idx)
			_show_character_debug(selected_id)
	if not _selected_character_id.is_empty():
		_update_left_panel(_selected_character_id)
