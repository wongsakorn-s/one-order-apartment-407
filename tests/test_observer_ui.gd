class_name TestObserverUI
extends RefCounted

## Automated test suite for TASK-014: Observer UI & Debug Inspector.
## Validates:
## 1. Clicking a character (resolved via WorldView's hit-test) selects them.
## 2. The always-visible Left Panel updates with the selected character's state.
## 3. Protagonist directives (WANT/NEVER/BELIEVE) are visible only for the
##    protagonist, never for NPCs.
## 4. The live Event Feed panel updates as events are emitted.
## 5. Developer Debug Mode still exposes full decision reasoning (unchanged
##    from earlier tasks, re-verified here as part of the same UI).

const MainScene = preload("res://scenes/main.tscn")
const WorldViewClass = preload("res://scripts/world/world_view.gd")
const HelpActionClass = preload("res://scripts/actions/help_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_clicking_a_character_resolves_its_id())
	results.append(test_clicking_empty_space_resolves_nothing())
	results.append(test_left_panel_updates_for_selected_character())
	results.append(test_protagonist_directives_visible_only_for_protagonist())
	results.append(test_event_feed_updates_live())
	results.append(test_debug_mode_still_exposes_full_reasoning())
	return results

static func test_clicking_a_character_resolves_its_id() -> Dictionary:
	var test_name = "test_clicking_a_character_resolves_its_id"

	var view = WorldViewClass.new()
	view._character_hit_positions = {
		"npc_a": Vector2(100, 100),
		"npc_b": Vector2(300, 300)
	}

	# GDScript lambdas capture locals by value, not by reference; use a single-
	# element Array (a reference type) so the connected callback's writes are
	# visible after the signal has fired.
	var received: Array = [""]
	view.character_selected.connect(func(id: String): received[0] = id)

	var event = InputEventMouseButton.new()
	event.position = Vector2(104, 96)
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)

	if received[0] != "npc_a":
		return {"name": test_name, "passed": false, "error": "Expected click near npc_a to resolve to 'npc_a', got '%s'" % received[0]}

	return {"name": test_name, "passed": true}

static func test_clicking_empty_space_resolves_nothing() -> Dictionary:
	var test_name = "test_clicking_empty_space_resolves_nothing"

	var view = WorldViewClass.new()
	view._character_hit_positions = {"npc_a": Vector2(100, 100)}

	var received: Array = ["", false]
	view.character_selected.connect(func(id: String): received[0] = id; received[1] = true)

	var event = InputEventMouseButton.new()
	event.position = Vector2(900, 900)
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)

	if received[1]:
		return {"name": test_name, "passed": false, "error": "Clicking far from any character incorrectly emitted character_selected('%s')" % received[0]}

	return {"name": test_name, "passed": true}

static func test_left_panel_updates_for_selected_character() -> Dictionary:
	var test_name = "test_left_panel_updates_for_selected_character"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI

	runner._ready()
	ui.bind_runner(runner)

	var nina = runner.get_character("npc_nina")
	ui.select_character(nina.id)

	if ui.left_name_label.text != nina.name:
		main.free()
		return {"name": test_name, "passed": false, "error": "Left panel name mismatch: %s" % ui.left_name_label.text}

	if not ("Location:" in ui.left_location_label.text):
		main.free()
		return {"name": test_name, "passed": false, "error": "Left panel location label malformed: %s" % ui.left_location_label.text}

	if not ("Action:" in ui.left_action_label.text):
		main.free()
		return {"name": test_name, "passed": false, "error": "Left panel action label malformed: %s" % ui.left_action_label.text}

	if not ("Goal:" in ui.left_goal_label.text):
		main.free()
		return {"name": test_name, "passed": false, "error": "Left panel goal label malformed: %s" % ui.left_goal_label.text}

	if not ("Emotion:" in ui.left_emotion_label.text):
		main.free()
		return {"name": test_name, "passed": false, "error": "Left panel emotion label malformed: %s" % ui.left_emotion_label.text}

	main.free()
	return {"name": test_name, "passed": true}

static func test_protagonist_directives_visible_only_for_protagonist() -> Dictionary:
	var test_name = "test_protagonist_directives_visible_only_for_protagonist"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI

	runner._ready()
	ui.bind_runner(runner)

	var protagonist = runner.get_protagonist()
	ui.select_character(protagonist.id)

	if not ui.left_want_label.visible or not ui.left_never_label.visible or not ui.left_believe_label.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "Directive labels should be visible when protagonist is selected"}

	if not ("WANT:" in ui.left_want_label.text and "NEVER:" in ui.left_never_label.text and "BELIEVE:" in ui.left_believe_label.text):
		main.free()
		return {"name": test_name, "passed": false, "error": "Directive labels missing expected prefixes"}

	var npc = runner.get_character("npc_nina")
	ui.select_character(npc.id)

	if ui.left_want_label.visible or ui.left_never_label.visible or ui.left_believe_label.visible:
		main.free()
		return {"name": test_name, "passed": false, "error": "Directive labels must be hidden for a non-protagonist NPC"}

	main.free()
	return {"name": test_name, "passed": true}

static func test_event_feed_updates_live() -> Dictionary:
	var test_name = "test_event_feed_updates_live"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI

	runner._ready()
	ui.bind_runner(runner)

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var help_action = HelpActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()
	help_action.start(context)
	help_action.tick(1.0, context)
	var evt = help_action._create_completion_event(context)
	runner._record_event(evt)

	if not (evt.description in ui.event_feed_text.text):
		main.free()
		return {"name": test_name, "passed": false, "error": "Event feed missing emitted event description: %s" % ui.event_feed_text.text}

	main.free()
	return {"name": test_name, "passed": true}

static func test_debug_mode_still_exposes_full_reasoning() -> Dictionary:
	var test_name = "test_debug_mode_still_exposes_full_reasoning"

	var main = MainScene.instantiate()
	var runner: SimulationRunner = main.get_node_or_null("SimulationRunner") as SimulationRunner
	var ui: MainUI = main.get_node_or_null("MainUI") as MainUI

	runner._ready()
	ui.bind_runner(runner)

	var protagonist = runner.get_protagonist()
	ui.select_character(protagonist.id)

	var summary: String = ui.debug_text.text
	for section in ["[Personality]", "[Needs]", "[Emotions]", "[Relationships]", "[Memories", "[Beliefs & Knowledge", "[Goals]"]:
		if not (section in summary):
			main.free()
			return {"name": test_name, "passed": false, "error": "Debug inspector missing section '%s'" % section}

	main.free()
	return {"name": test_name, "passed": true}
