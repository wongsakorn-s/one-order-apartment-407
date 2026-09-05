class_name TestCharacterState
extends RefCounted

## Automated unit tests for CharacterState data model and character spawning.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_nine_characters_spawn())
	results.append(_test_protagonist_and_npc_distribution())
	results.append(_test_personality_traits_validity())
	results.append(_test_needs_and_emotions_validity())
	results.append(_test_starting_locations_validity())
	results.append(_test_pure_simulation_separation())
	results.append(_test_debug_output_and_inspection())
	results.append(_test_attribute_clamping())
	return results

static func _test_nine_characters_spawn() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()

	var chars = runner.get_all_characters()
	if chars.size() != 9:
		runner.free()
		return {"name": "test_nine_characters_spawn", "passed": false, "error": "Expected 9 characters, got %d" % chars.size()}

	if runner.get_character_count() != 9:
		runner.free()
		return {"name": "test_nine_characters_spawn", "passed": false, "error": "get_character_count() expected 9, got %d" % runner.get_character_count()}

	runner.free()
	return {"name": "test_nine_characters_spawn", "passed": true}

static func _test_protagonist_and_npc_distribution() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()

	var protagonist = runner.get_protagonist()
	if protagonist == null:
		runner.free()
		return {"name": "test_protagonist_and_npc_distribution", "passed": false, "error": "No protagonist found"}

	if not protagonist.is_protagonist:
		runner.free()
		return {"name": "test_protagonist_and_npc_distribution", "passed": false, "error": "Protagonist flag is false"}

	var chars = runner.get_all_characters()
	var protagonist_count: int = 0
	var npc_count: int = 0
	for c in chars:
		if c.is_protagonist:
			protagonist_count += 1
		else:
			npc_count += 1

	if protagonist_count != 1:
		runner.free()
		return {"name": "test_protagonist_and_npc_distribution", "passed": false, "error": "Expected exactly 1 protagonist, got %d" % protagonist_count}

	if npc_count != 8:
		runner.free()
		return {"name": "test_protagonist_and_npc_distribution", "passed": false, "error": "Expected exactly 8 NPCs, got %d" % npc_count}

	runner.free()
	return {"name": "test_protagonist_and_npc_distribution", "passed": true}

static func _test_personality_traits_validity() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()

	var required_traits: Array[String] = [
		"empathy", "greed", "fear", "aggression",
		"curiosity", "honesty", "sociability", "impulsiveness"
	]

	for c in runner.get_all_characters():
		for t in required_traits:
			if not c.personality.has(t):
				runner.free()
				return {"name": "test_personality_traits_validity", "passed": false, "error": "Character %s missing personality trait %s" % [c.name, t]}

			var val: float = c.personality[t]
			if val < 0.0 or val > 1.0 or is_nan(val):
				runner.free()
				return {"name": "test_personality_traits_validity", "passed": false, "error": "Character %s trait %s out of range [0.0, 1.0]: %f" % [c.name, t, val]}

	runner.free()
	return {"name": "test_personality_traits_validity", "passed": true}

static func _test_needs_and_emotions_validity() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()

	var required_needs: Array[String] = [
		"safety", "money", "social", "information", "rest", "food"
	]
	var required_emotions: Array[String] = [
		"happiness", "fear", "anger", "stress"
	]

	for c in runner.get_all_characters():
		for n in required_needs:
			if not c.needs.has(n):
				runner.free()
				return {"name": "test_needs_and_emotions_validity", "passed": false, "error": "Character %s missing need %s" % [c.name, n]}

			var val: float = c.needs[n]
			if val < 0.0 or val > 1.0 or is_nan(val):
				runner.free()
				return {"name": "test_needs_and_emotions_validity", "passed": false, "error": "Character %s need %s out of range [0.0, 1.0]: %f" % [c.name, n, val]}

		for e in required_emotions:
			if not c.emotions.has(e):
				runner.free()
				return {"name": "test_needs_and_emotions_validity", "passed": false, "error": "Character %s missing emotion %s" % [c.name, e]}

			var val: float = c.emotions[e]
			if val < 0.0 or val > 1.0 or is_nan(val):
				runner.free()
				return {"name": "test_needs_and_emotions_validity", "passed": false, "error": "Character %s emotion %s out of range [0.0, 1.0]: %f" % [c.name, e, val]}

	runner.free()
	return {"name": "test_needs_and_emotions_validity", "passed": true}

static func _test_starting_locations_validity() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()
	var graph = runner.get_world_graph()

	for c in runner.get_all_characters():
		if c.current_location.is_empty():
			runner.free()
			return {"name": "test_starting_locations_validity", "passed": false, "error": "Character %s has empty current_location" % c.name}

		if not graph.has_location(c.current_location):
			runner.free()
			return {"name": "test_starting_locations_validity", "passed": false, "error": "Character %s exists in invalid location %s" % [c.name, c.current_location]}

	runner.free()
	return {"name": "test_starting_locations_validity", "passed": true}

static func _test_pure_simulation_separation() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()

	for c in runner.get_all_characters():
		var obj: Variant = c
		if obj is Node:
			runner.free()
			return {"name": "test_pure_simulation_separation", "passed": false, "error": "CharacterState must not inherit from Node"}
		if not (c is RefCounted):
			runner.free()
			return {"name": "test_pure_simulation_separation", "passed": false, "error": "CharacterState must inherit from RefCounted"}

	runner.free()
	return {"name": "test_pure_simulation_separation", "passed": true}

static func _test_debug_output_and_inspection() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner._ready()

	var protagonist = runner.get_protagonist()
	var state_dict = protagonist.to_dict()

	var expected_keys: Array[String] = [
		"id", "name", "is_protagonist", "current_location",
		"personality", "needs", "emotions", "inventory",
		"goals", "memories", "beliefs", "relationships", "current_action"
	]

	for k in expected_keys:
		if not state_dict.has(k):
			runner.free()
			return {"name": "test_debug_output_and_inspection", "passed": false, "error": "to_dict() missing key: %s" % k}

	var debug_str: String = protagonist.get_debug_summary()
	if not debug_str.contains(protagonist.name) or not debug_str.contains("Personality") or not debug_str.contains("Needs") or not debug_str.contains("Emotions"):
		runner.free()
		return {"name": "test_debug_output_and_inspection", "passed": false, "error": "get_debug_summary() is incomplete"}

	runner.free()
	return {"name": "test_debug_output_and_inspection", "passed": true}

static func _test_attribute_clamping() -> Dictionary:
	var c = CharacterStateClass.new("test_char", "Test", "lobby", false)

	# Over-max and under-min clamping
	c.set_personality_trait("empathy", 1.8)
	if not is_equal_approx(c.get_personality_trait("empathy"), 1.0):
		return {"name": "test_attribute_clamping", "passed": false, "error": "Trait above 1.0 was not clamped to 1.0"}

	c.set_personality_trait("empathy", -0.5)
	if not is_equal_approx(c.get_personality_trait("empathy"), 0.0):
		return {"name": "test_attribute_clamping", "passed": false, "error": "Trait below 0.0 was not clamped to 0.0"}

	c.set_need("food", 2.0)
	if not is_equal_approx(c.get_need("food"), 1.0):
		return {"name": "test_attribute_clamping", "passed": false, "error": "Need above 1.0 was not clamped to 1.0"}

	c.set_emotion("anger", -1.0)
	if not is_equal_approx(c.get_emotion("anger"), 0.0):
		return {"name": "test_attribute_clamping", "passed": false, "error": "Emotion below 0.0 was not clamped to 0.0"}

	return {"name": "test_attribute_clamping", "passed": true}

