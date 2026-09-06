class_name TestMemories
extends RefCounted

## Automated test suite for TASK-009: Memory System.
## Validates memory formation for experienced events, isolation of unobserved events,
## limited capacity (30 max) with importance-based retention and eviction,
## memory influence on Utility AI decision scoring, debug UI inspection, and serialization.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const SimulationEventClass = preload("res://scripts/events/simulation_event.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")

const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const ConfrontActionClass = preload("res://scripts/actions/confront_action.gd")
const TalkActionClass = preload("res://scripts/actions/talk_action.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_characters_remember_experienced_events())
	results.append(test_characters_do_not_remember_unobserved_events())
	results.append(test_important_events_survive_longer_than_trivial_events())
	results.append(test_memories_affect_ai_decision_scoring())
	results.append(test_memory_list_inspectable_in_debug_ui())
	results.append(test_memory_serialization_and_reconstruction())
	return results

static func test_characters_remember_experienced_events() -> Dictionary:
	var test_name = "test_characters_remember_experienced_events"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")

	actor.current_location = "room_102"
	target.current_location = "room_102"

	var initial_actor_mem_count = actor.get_memory_count()
	var initial_target_mem_count = target.get_memory_count()

	var help_action = HelpActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()

	if not help_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "HelpAction failed to start: %s" % help_action.failure_reason}

	help_action.tick(1.0, context)
	var evt = help_action._create_completion_event(context)
	runner._record_event(evt)

	if actor.get_memory_count() != initial_actor_mem_count + 1:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Actor did not gain a memory for the experienced event"}

	if target.get_memory_count() != initial_target_mem_count + 1:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target did not gain a memory for the experienced event"}

	var target_mem: Memory = target.get_memories()[-1]
	if target_mem.event_type != "help":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected target memory event_type 'help', got '%s'" % target_mem.event_type}

	if target_mem.location != "room_102":
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected target memory location 'room_102', got '%s'" % target_mem.location}

	if target_mem.emotional_impact <= 0.0:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Target should have positive emotional impact from being helped"}

	if target_mem.importance <= 0.5:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Direct help event should have high importance (> 0.5), got %f" % target_mem.importance}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_characters_do_not_remember_unobserved_events() -> Dictionary:
	var test_name = "test_characters_do_not_remember_unobserved_events"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	var bystander = runner.get_character("char_protagonist")
	var outside_char = runner.get_character("npc_marcus")

	actor.current_location = "room_102"
	target.current_location = "room_102"
	bystander.current_location = "room_102"
	outside_char.current_location = "rooftop"

	var initial_outside_mem_count = outside_char.get_memory_count()
	var initial_bystander_mem_count = bystander.get_memory_count()

	var confront_action = ConfrontActionClass.new(actor.id, target.id, 1.0)
	var context = runner.get_simulation_context()

	if not confront_action.start(context):
		runner.free()
		return {"name": test_name, "passed": false, "error": "ConfrontAction failed to start"}

	confront_action.tick(1.0, context)
	var evt = confront_action._create_completion_event(context)
	runner._record_event(evt)

	# Outside character on rooftop must NOT receive a memory of an event in room_102
	if outside_char.get_memory_count() != initial_outside_mem_count:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Character on rooftop gained memory of unobserved event in room_102"}

	# Bystander in the same room MUST receive a memory of observing the event
	if bystander.get_memory_count() != initial_bystander_mem_count + 1:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Co-located bystander did not gain memory of observed event"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_important_events_survive_longer_than_trivial_events() -> Dictionary:
	var test_name = "test_important_events_survive_longer_than_trivial_events"

	var char_state = CharacterStateClass.new("test_char", "Tester", "room_101")
	char_state.clear_memories()

	# 1. Insert high-importance memory (Confrontation, importance = 0.95)
	var high_imp_mem = MemoryClass.new(
		"mem_vital",
		100.0,
		"confront",
		["npc_bob", "test_char"],
		"room_101",
		0.95,
		-0.85,
		"evt_vital",
		{},
		"Attacked by Bob"
	)
	char_state.add_memory(high_imp_mem)

	# 2. Fill memory to MAX_MEMORIES (30) with moderate/low importance memories (importance = 0.35)
	for i in range(1, 30):
		var filler = MemoryClass.new(
			"mem_filler_%d" % i,
			float(100 + i * 10),
			"talk",
			["npc_nina"],
			"room_101",
			0.35,
			0.10,
			"evt_filler_%d" % i,
			{},
			"Chatted with Nina %d" % i
		)
		char_state.add_memory(filler)

	if char_state.get_memory_count() != 30:
		return {"name": test_name, "passed": false, "error": "Expected 30 memories, got %d" % char_state.get_memory_count()}

	# 3. Add 15 newer events with medium importance (0.60)
	# This exceeds capacity, triggering evictions
	for j in range(1, 16):
		var new_mem = MemoryClass.new(
			"mem_medium_%d" % j,
			float(500 + j * 10),
			"give_item",
			["npc_sarah"],
			"room_101",
			0.60,
			0.30,
			"evt_new_%d" % j,
			{},
			"Exchanged item %d" % j
		)
		char_state.add_memory(new_mem)

	# Capacity must never exceed 30
	if char_state.get_memory_count() > 30:
		return {"name": test_name, "passed": false, "error": "Memory capacity exceeded 30: count = %d" % char_state.get_memory_count()}

	# The high-importance memory (0.95) MUST still be retained!
	var found_high_imp: bool = false
	for m in char_state.get_memories():
		if m.id == "mem_vital":
			found_high_imp = true
			break

	if not found_high_imp:
		return {"name": test_name, "passed": false, "error": "High importance memory was evicted prematurely before lower importance memories"}

	return {"name": test_name, "passed": true}

static func test_memories_affect_ai_decision_scoring() -> Dictionary:
	var test_name = "test_memories_affect_ai_decision_scoring"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 12345
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("char_protagonist")

	actor.current_location = "room_102"
	target.current_location = "room_102"

	var ai = UtilityAIClass.new()
	var context = runner.get_simulation_context()
	var help_action = HelpActionClass.new(actor.id, target.id, 8.0)

	# 1. Score without benefactor memory
	actor.clear_memories()
	var eval_without = ai.score_action(actor, help_action, context)
	var score_without = float(eval_without.get("score", 0.0))

	# 2. Add memory that target helped actor
	var benefactor_mem = MemoryClass.new(
		"mem_help_test",
		50.0,
		"help",
		[target.id, actor.id],
		"room_102",
		0.80,
		0.75,
		"evt_test_1",
		{"actor": target.id, "target": actor.id},
		"Alex helped Nina"
	)
	actor.add_memory(benefactor_mem)

	# 3. Score with benefactor memory
	var eval_with = ai.score_action(actor, help_action, context)
	var score_with = float(eval_with.get("score", 0.0))
	var reasons = eval_with.get("reasons", {})
	var explanation = str(eval_with.get("explanation", ""))

	if not reasons.has("memory"):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Scoring evaluation reasons missing 'memory' key"}

	var memory_mod = float(reasons.get("memory", 0.0))
	if memory_mod <= 0.5:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Expected positive memory modifier for helping a past benefactor, got: %f" % memory_mod}

	if score_with <= score_without:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Utility score with benefactor memory (%f) not greater than without (%f)" % [score_with, score_without]}

	if not "memory:" in explanation:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Explanation text missing 'memory:': %s" % explanation}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_memory_list_inspectable_in_debug_ui() -> Dictionary:
	var test_name = "test_memory_list_inspectable_in_debug_ui"

	var char_state = CharacterStateClass.new("npc_nina", "Nina", "room_102")
	char_state.clear_memories()

	var mem = MemoryClass.new(
		"mem_inspect_test",
		3665.0, # ~01:01
		"help",
		["char_protagonist", "npc_nina"],
		"room_102",
		0.75,
		0.65,
		"evt_101",
		{},
		"Alex helped Nina in Room 102"
	)
	char_state.add_memory(mem)

	var summary = char_state.get_debug_summary()

	if not "[Memories (1/30)]" in summary:
		return {"name": test_name, "passed": false, "error": "Summary missing '[Memories (1/30)]' header: %s" % summary}

	if not "Alex helped Nina in Room 102" in summary:
		return {"name": test_name, "passed": false, "error": "Summary missing memory description: %s" % summary}

	if not "Imp: 0.75" in summary:
		return {"name": test_name, "passed": false, "error": "Summary missing importance indicator: %s" % summary}

	return {"name": test_name, "passed": true}

static func test_memory_serialization_and_reconstruction() -> Dictionary:
	var test_name = "test_memory_serialization_and_reconstruction"

	var mem1 = MemoryClass.new(
		"mem_serialize_test",
		1234.5,
		"confront",
		["npc_bob", "npc_tom"],
		"lobby",
		0.85,
		-0.70,
		"evt_202",
		{"actor": "npc_bob", "target": "npc_tom"},
		"Bob confronted Tom in Lobby"
	)

	var d = mem1.to_dict()
	var mem2 = MemoryClass.new()
	mem2.from_dict(d)

	if mem2.id != mem1.id or mem2.event_type != mem1.event_type or mem2.location != mem1.location:
		return {"name": test_name, "passed": false, "error": "Reconstructed memory fields do not match original"}

	if not is_equal_approx(mem2.importance, mem1.importance) or not is_equal_approx(mem2.emotional_impact, mem1.emotional_impact):
		return {"name": test_name, "passed": false, "error": "Reconstructed floats do not match original"}

	var char_state = CharacterStateClass.new("npc_nina", "Nina", "room_102")
	char_state.add_memory(mem1)
	var char_dict = char_state.to_dict()

	if not char_dict.has("memories") or not (char_dict["memories"] is Array):
		return {"name": test_name, "passed": false, "error": "CharacterState.to_dict() missing serialized memories array"}

	var serialized_mem = char_dict["memories"][0]
	if serialized_mem.get("id", "") != "mem_serialize_test":
		return {"name": test_name, "passed": false, "error": "Serialized memory ID mismatch in CharacterState.to_dict()"}

	return {"name": test_name, "passed": true}
