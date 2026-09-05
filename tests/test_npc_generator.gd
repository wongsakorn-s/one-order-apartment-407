class_name TestNPCGenerator
extends RefCounted

## Automated tests for TASK-004: NPC Procedural Generation.
## Verifies seed determinism (seed 123 identical every run, seed 456 diverges),
## valid entity and location references in goals, and actionable goal guarantees.

const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")
const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const NPCGeneratorClass = preload("res://scripts/generation/npc_generator.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_seed_123_deterministic_reproducibility())
	results.append(_test_seed_123_differs_from_seed_456())
	results.append(_test_starting_locations_strictly_valid())
	results.append(_test_goals_reference_valid_entities())
	results.append(_test_every_npc_has_at_least_one_actionable_goal())
	results.append(_test_runner_reset_preserves_seed_determinism())
	results.append(_test_no_major_gameplay_events_generated())
	return results

static func _test_seed_123_deterministic_reproducibility() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	var rng_a = RandomServiceClass.new(123)
	var gen_a = NPCGeneratorClass.new()
	var npcs_a = gen_a.generate_npcs(rng_a, graph, "char_protagonist", "Alex")

	var rng_b = RandomServiceClass.new(123)
	var gen_b = NPCGeneratorClass.new()
	var npcs_b = gen_b.generate_npcs(rng_b, graph, "char_protagonist", "Alex")

	if npcs_a.size() != npcs_b.size():
		return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Size mismatch"}

	for i in range(npcs_a.size()):
		var char_a = npcs_a[i]
		var char_b = npcs_b[i]

		if char_a.id != char_b.id or char_a.name != char_b.name:
			return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Identity mismatch at %d" % i}

		if char_a.current_location != char_b.current_location:
			return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Location mismatch for %s: %s vs %s" % [char_a.name, char_a.current_location, char_b.current_location]}

		# Compare personality
		for trait_name in char_a.personality:
			var val_a = char_a.personality[trait_name]
			var val_b = char_b.personality.get(trait_name, -1.0)
			if not is_equal_approx(val_a, val_b):
				return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Trait %s mismatch for %s: %f vs %f" % [trait_name, char_a.name, val_a, val_b]}

		# Compare needs
		for need_name in char_a.needs:
			var val_a = char_a.needs[need_name]
			var val_b = char_b.needs.get(need_name, -1.0)
			if not is_equal_approx(val_a, val_b):
				return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Need %s mismatch for %s: %f vs %f" % [need_name, char_a.name, val_a, val_b]}

		# Compare emotions
		for emotion_name in char_a.emotions:
			var val_a = char_a.emotions[emotion_name]
			var val_b = char_b.emotions.get(emotion_name, -1.0)
			if not is_equal_approx(val_a, val_b):
				return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Emotion %s mismatch for %s" % [emotion_name, char_a.name]}

		# Compare inventory
		if char_a.inventory != char_b.inventory:
			return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Inventory mismatch for %s" % char_a.name}

		# Compare goals
		if char_a.goals.size() != char_b.goals.size():
			return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Goal count mismatch for %s" % char_a.name}

		for g_idx in range(char_a.goals.size()):
			var ga = char_a.goals[g_idx]
			var gb = char_b.goals[g_idx]
			if ga != gb:
				return {"name": "test_seed_123_deterministic_reproducibility", "passed": false, "error": "Goal content mismatch for %s: %s vs %s" % [char_a.name, str(ga), str(gb)]}

	return {"name": "test_seed_123_deterministic_reproducibility", "passed": true}

static func _test_seed_123_differs_from_seed_456() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	var rng_123 = RandomServiceClass.new(123)
	var gen = NPCGeneratorClass.new()
	var npcs_123 = gen.generate_npcs(rng_123, graph, "char_protagonist", "Alex")

	var rng_456 = RandomServiceClass.new(456)
	var npcs_456 = gen.generate_npcs(rng_456, graph, "char_protagonist", "Alex")

	var differences_found: int = 0

	for i in range(npcs_123.size()):
		var c_123 = npcs_123[i]
		var c_456 = npcs_456[i]

		# Check location differences
		if c_123.current_location != c_456.current_location:
			differences_found += 1

		# Check personality differences
		for t in c_123.personality:
			if not is_equal_approx(c_123.personality[t], c_456.personality.get(t, -1.0)):
				differences_found += 1

		# Check goals differences
		if str(c_123.goals) != str(c_456.goals):
			differences_found += 1

		# Check inventory differences
		if c_123.inventory != c_456.inventory:
			differences_found += 1

	if differences_found < 10:
		return {"name": "test_seed_123_differs_from_seed_456", "passed": false, "error": "Expected meaningful differences between seed 123 and 456, only found %d" % differences_found}

	return {"name": "test_seed_123_differs_from_seed_456", "passed": true}

static func _test_starting_locations_strictly_valid() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()
	var gen = NPCGeneratorClass.new()

	# Test across 5 distinct seeds
	var test_seeds: Array[int] = [1, 42, 123, 777, 9999]
	for s in test_seeds:
		var rng = RandomServiceClass.new(s)
		var npcs = gen.generate_npcs(rng, graph, "char_protagonist", "Alex")
		for c in npcs:
			if not graph.has_location(c.current_location):
				return {"name": "test_starting_locations_strictly_valid", "passed": false, "error": "Seed %d generated invalid location %s for %s" % [s, c.current_location, c.name]}

	return {"name": "test_starting_locations_strictly_valid", "passed": true}

static func _test_goals_reference_valid_entities() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()
	var gen = NPCGeneratorClass.new()

	var test_seeds: Array[int] = [12, 123, 456, 888]
	for s in test_seeds:
		var rng = RandomServiceClass.new(s)
		var npcs = gen.generate_npcs(rng, graph, "char_protagonist", "Alex")

		var valid_char_ids: Array[String] = ["char_protagonist"]
		for c in npcs:
			valid_char_ids.append(c.id)

		for c in npcs:
			for g in c.goals:
				if not (g is Dictionary):
					return {"name": "test_goals_reference_valid_entities", "passed": false, "error": "Goal is not a dictionary"}

				var goal_dict: Dictionary = g as Dictionary
				var g_type: String = goal_dict.get("id", "")
				var g_desc: String = goal_dict.get("description", "")
				if g_desc.is_empty():
					return {"name": "test_goals_reference_valid_entities", "passed": false, "error": "Goal has empty description in %s" % c.name}

				# Entity validation for character-targeted goals
				if g_type in ["AvoidCharacter", "MeetCharacter", "RepairRelationship"]:
					var target_id: String = goal_dict.get("target", "")
					if not target_id in valid_char_ids:
						return {"name": "test_goals_reference_valid_entities", "passed": false, "error": "Goal %s references invalid character target '%s'" % [g_type, target_id]}
					if target_id == c.id:
						return {"name": "test_goals_reference_valid_entities", "passed": false, "error": "Character %s targeted self for goal %s" % [c.name, g_type]}

				# Entity validation for location-targeted goals
				if g_type in ["InvestigateLocation", "Rest"]:
					var target_loc: String = goal_dict.get("target", "")
					if not graph.has_location(target_loc):
						return {"name": "test_goals_reference_valid_entities", "passed": false, "error": "Goal %s references invalid location target '%s'" % [g_type, target_loc]}

				if g_type == "HideItem" and goal_dict.has("target_location"):
					var target_loc: String = goal_dict.get("target_location", "")
					if not graph.has_location(target_loc):
						return {"name": "test_goals_reference_valid_entities", "passed": false, "error": "HideItem references invalid location target '%s'" % target_loc}

	return {"name": "test_goals_reference_valid_entities", "passed": true}

static func _test_every_npc_has_at_least_one_actionable_goal() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()
	var gen = NPCGeneratorClass.new()

	var test_seeds: Array[int] = [10, 50, 100, 200, 500, 1000]
	for s in test_seeds:
		var rng = RandomServiceClass.new(s)
		var npcs = gen.generate_npcs(rng, graph, "char_protagonist", "Alex")
		for c in npcs:
			if c.goals.is_empty():
				return {"name": "test_every_npc_has_at_least_one_actionable_goal", "passed": false, "error": "Seed %d: Character %s has 0 goals" % [s, c.name]}
			var primary_goal = c.goals[0]
			if not (primary_goal is Dictionary) or primary_goal.get("id", "").is_empty():
				return {"name": "test_every_npc_has_at_least_one_actionable_goal", "passed": false, "error": "Seed %d: Character %s primary goal is not actionable" % [s, c.name]}

	return {"name": "test_every_npc_has_at_least_one_actionable_goal", "passed": true}

static func _test_runner_reset_preserves_seed_determinism() -> Dictionary:
	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 123
	runner._ready()

	var snapshot_1: Dictionary = {}
	for c in runner.get_all_characters():
		snapshot_1[c.id] = c.to_dict()

	# Reset with same seed
	runner.reset_simulation()
	var snapshot_2: Dictionary = {}
	for c in runner.get_all_characters():
		snapshot_2[c.id] = c.to_dict()

	for char_id in snapshot_1:
		var d1 = snapshot_1[char_id]
		var d2 = snapshot_2.get(char_id, {})
		if str(d1) != str(d2):
			runner.free()
			return {"name": "test_runner_reset_preserves_seed_determinism", "passed": false, "error": "State mismatch after reset on character %s" % char_id}

	# Reset with seed 456
	runner.reset_simulation(456)
	var snapshot_3: Dictionary = {}
	for c in runner.get_all_characters():
		snapshot_3[c.id] = c.to_dict()

	var differences: int = 0
	for char_id in snapshot_1:
		if str(snapshot_1[char_id]) != str(snapshot_3.get(char_id, {})):
			differences += 1

	runner.free()
	if differences == 0:
		return {"name": "test_runner_reset_preserves_seed_determinism", "passed": false, "error": "Seed 456 reset did not produce different characters"}

	return {"name": "test_runner_reset_preserves_seed_determinism", "passed": true}

static func _test_no_major_gameplay_events_generated() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()
	var gen = NPCGeneratorClass.new()
	var rng = RandomServiceClass.new(999)

	var npcs = gen.generate_npcs(rng, graph, "char_protagonist", "Alex")

	for c in npcs:
		# NPCs start in idle action, not active events
		if c.current_action.get("id", "") != "idle":
			return {"name": "test_no_major_gameplay_events_generated", "passed": false, "error": "NPC spawned with non-idle action: %s" % str(c.current_action)}
		# Memories should be empty at initialization (no pre-scripted events)
		if not c.memories.is_empty():
			return {"name": "test_no_major_gameplay_events_generated", "passed": false, "error": "NPC spawned with pre-baked memories: %s" % str(c.memories)}

	return {"name": "test_no_major_gameplay_events_generated", "passed": true}

