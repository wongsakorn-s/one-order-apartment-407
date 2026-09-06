class_name TestDeterminismSuite
extends RefCounted

## Automated test suite for TASK-017: Determinism & Test Suite.
## This is a consolidated, headless proof of reproducibility that exercises
## the FULL simulation loop (many ticks of autonomous AI decisions and
## completed actions), not just isolated generation-time components:
##
## 1. Seed Determinism  -- same seed + same directives, ticked many times,
##    produces an identical important-event sequence (and identical RNG
##    stream position afterward).
## 2. Seed Variation     -- a different seed diverges.
## 3. Knowledge Isolation
## 4. Relationship Directionality
## 5. NEVER Rule
## 6. Memory Capacity (importance-based eviction)
## 7. Causal Reference (child events referencing parent events)
##
## Runs entirely via TestRunner (res://tests/test_runner.gd), Godot's existing
## headless SceneTree-based test harness -- no rendering, no dependency on
## frame rate, callable repeatedly with identical results.

const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")
const ConfrontActionClass = preload("res://scripts/actions/confront_action.gd")
const HelpActionClass = preload("res://scripts/actions/help_action.gd")
const UtilityAIClass = preload("res://scripts/ai/utility_ai.gd")

const TICK_COUNT: int = 150
const TICK_SIM_DELTA: float = 4.0

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(test_seed_determinism_full_run())
	results.append(test_seed_variation_full_run())
	results.append(test_knowledge_isolation())
	results.append(test_relationship_directionality())
	results.append(test_never_rule_prohibited_action())
	results.append(test_memory_capacity_prioritizes_importance())
	results.append(test_causal_reference_parent_child())
	return results

static func _run_full_simulation(seed_val: int) -> SimulationRunner:
	var runner = SimulationRunnerClass.new()
	runner.initial_seed = seed_val
	runner._init_simulation()
	runner.set_player_directives("learn_room_407", "never_steal", "everyone_hiding_something")
	for i in range(TICK_COUNT):
		runner._tick_simulation(TICK_SIM_DELTA)
	return runner

## Reduce an event log to just the fields that define "what happened", so
## comparison isn't accidentally sensitive to incidental Dictionary key
## ordering.
static func _event_signatures(events: Array[Dictionary]) -> Array[String]:
	var sigs: Array[String] = []
	for evt in events:
		sigs.append("%s|%s|%s|%s|%s" % [
			evt.get("event_type", ""), evt.get("actor_id", ""), evt.get("target_id", ""),
			evt.get("location_id", ""), evt.get("description", "")
		])
	return sigs

static func test_seed_determinism_full_run() -> Dictionary:
	var test_name = "test_seed_determinism_full_run"

	var runner_a = _run_full_simulation(12345)
	var runner_b = _run_full_simulation(12345)

	var sig_a = _event_signatures(runner_a.get_events())
	var sig_b = _event_signatures(runner_b.get_events())

	if sig_a.size() != sig_b.size():
		runner_a.free()
		runner_b.free()
		return {"name": test_name, "passed": false, "error": "Event count differs for identical seed 12345 over %d ticks: %d vs %d" % [TICK_COUNT, sig_a.size(), sig_b.size()]}

	if sig_a.is_empty():
		runner_a.free()
		runner_b.free()
		return {"name": test_name, "passed": false, "error": "No events were recorded at all; test setup did not exercise the simulation"}

	for i in range(sig_a.size()):
		if sig_a[i] != sig_b[i]:
			runner_a.free()
			runner_b.free()
			return {"name": test_name, "passed": false, "error": "Event #%d differs for identical seed: '%s' vs '%s'" % [i, sig_a[i], sig_b[i]]}

	# The shared RandomService stream itself must also be bit-identical
	# afterward, not just the events it happened to produce.
	var next_a: float = runner_a.get_random_service().rand_float()
	var next_b: float = runner_b.get_random_service().rand_float()
	runner_a.free()
	runner_b.free()

	if not is_equal_approx(next_a, next_b):
		return {"name": test_name, "passed": false, "error": "RNG stream position diverged after an identical run: %f vs %f" % [next_a, next_b]}

	return {"name": test_name, "passed": true}

static func test_seed_variation_full_run() -> Dictionary:
	var test_name = "test_seed_variation_full_run"

	var runner_a = _run_full_simulation(12345)
	var runner_b = _run_full_simulation(54321)

	var sig_a = _event_signatures(runner_a.get_events())
	var sig_b = _event_signatures(runner_b.get_events())

	# Compare NPC starting configuration too, per the acceptance criteria's
	# "NPC configuration OR important event sequence should differ".
	var config_differs: bool = false
	for c in runner_a.get_all_characters():
		var other = runner_b.get_character(c.id)
		if other == null or other.current_location != c.current_location or str(other.goals) != str(c.goals):
			config_differs = true
			break

	var events_differ: bool = (sig_a.size() != sig_b.size())
	if not events_differ:
		for i in range(sig_a.size()):
			if sig_a[i] != sig_b[i]:
				events_differ = true
				break

	runner_a.free()
	runner_b.free()

	if not config_differs and not events_differ:
		return {"name": test_name, "passed": false, "error": "Seeds 12345 and 54321 produced identical NPC configuration AND identical event sequence"}

	return {"name": test_name, "passed": true}

static func test_knowledge_isolation() -> Dictionary:
	var test_name = "test_knowledge_isolation"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 13579
	runner._init_simulation()

	var actor = runner.get_character("npc_bob")
	var target = runner.get_character("npc_tom")
	var outsider = runner.get_character("npc_sarah")
	actor.current_location = "room_103"
	target.current_location = "room_103"
	outsider.current_location = "rooftop"

	outsider.beliefs.clear()

	var context = runner.get_simulation_context()
	var confront = ConfrontActionClass.new(actor.id, target.id, 1.0)
	confront.start(context)
	confront.tick(1.0, context)
	var evt = confront._create_completion_event(context)
	runner._record_event(evt)

	# The outsider, physically elsewhere and never told, must not have gained
	# any knowledge of an event they neither observed nor received secondhand.
	if outsider.has_belief(actor.id, "hostile_towards") or outsider.has_belief(actor.id, "location") or outsider.get_memory_count() > 0:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Outsider character gained knowledge of an event they never observed"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_relationship_directionality() -> Dictionary:
	var test_name = "test_relationship_directionality"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 24680
	runner._init_simulation()

	var a = runner.get_character("npc_elena")
	var b = runner.get_character("npc_marcus")

	var b_to_a_before: float = b.get_relationship_value(a.id, "trust")
	a.modify_relationship(b.id, "trust", 0.35)

	if not is_equal_approx(b.get_relationship_value(a.id, "trust"), b_to_a_before):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Modifying A->B overwrote B->A: expected %f, got %f" % [b_to_a_before, b.get_relationship_value(a.id, "trust")]}

	if is_equal_approx(a.get_relationship_value(b.id, "trust"), b.get_relationship_value(a.id, "trust")):
		runner.free()
		return {"name": test_name, "passed": false, "error": "A->B and B->A ended up identical; directionality could not be demonstrated"}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_never_rule_prohibited_action() -> Dictionary:
	var test_name = "test_never_rule_prohibited_action"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 11235
	runner._init_simulation()
	runner.set_player_directives("survive_night", "never_hurt_anyone", "everyone_hiding_something")

	var protagonist = runner.get_protagonist()
	var npc = runner.get_character("npc_bob")
	protagonist.current_location = "lobby"
	npc.current_location = "lobby"

	var ai = UtilityAIClass.new()
	var context = runner.get_simulation_context()
	var confront = ConfrontActionClass.new(protagonist.id, npc.id, 5.0)
	var eval = ai.score_action(protagonist, confront, context)

	if not eval["reasons"].has("never") or eval["reasons"]["never"] >= 0.0:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Prohibited action was not penalized by the NEVER directive: %s" % str(eval.get("reasons", {}))}

	runner.free()
	return {"name": test_name, "passed": true}

static func test_memory_capacity_prioritizes_importance() -> Dictionary:
	var test_name = "test_memory_capacity_prioritizes_importance"

	var c = CharacterStateClass.new("test_char", "Tester", "room_101", false)
	c.clear_memories()

	var vital = MemoryClass.new("mem_vital", 0.0, "confront", ["npc_x", "test_char"], "room_101", 0.98, -0.9, "", {}, "A vital confrontation")
	c.add_memory(vital)

	for i in range(1, 30):
		c.add_memory(MemoryClass.new("mem_trivial_%d" % i, float(i * 10), "talk", ["npc_y"], "room_101", 0.2, 0.05, "", {}, "Trivial chat %d" % i))

	if c.get_memory_count() != 30:
		return {"name": test_name, "passed": false, "error": "Expected exactly 30 memories at capacity, got %d" % c.get_memory_count()}

	# Push past capacity with more low-importance memories -- these should be
	# rejected/evicted before the single high-importance "vital" memory ever is.
	for i in range(30, 45):
		c.add_memory(MemoryClass.new("mem_trivial_%d" % i, float(i * 10), "idle", ["npc_y"], "room_101", 0.15, 0.0, "", {}, "More trivial idling %d" % i))

	if c.get_memory_count() > 30:
		return {"name": test_name, "passed": false, "error": "Memory capacity exceeded 30: got %d" % c.get_memory_count()}

	var vital_survived: bool = false
	for m in c.get_memories():
		if m.id == "mem_vital":
			vital_survived = true
	if not vital_survived:
		return {"name": test_name, "passed": false, "error": "High-importance memory was evicted before low-importance ones"}

	return {"name": test_name, "passed": true}

static func test_causal_reference_parent_child() -> Dictionary:
	var test_name = "test_causal_reference_parent_child"

	var runner = SimulationRunnerClass.new()
	runner.initial_seed = 90210
	runner._init_simulation()

	var actor = runner.get_character("npc_nina")
	var target = runner.get_character("npc_tom")
	actor.current_location = "room_102"
	target.current_location = "room_102"

	var context = runner.get_simulation_context()

	# Parent event: target helps actor, giving actor a memory that references it.
	var parent_action = HelpActionClass.new(target.id, actor.id, 1.0)
	parent_action.start(context)
	parent_action.tick(1.0, context)
	var parent_evt = parent_action._create_completion_event(context)
	runner._record_event(parent_evt)

	# Child decision: actor considers helping target back; the memory of being
	# helped should surface as a contributing event for that candidate.
	var ai = UtilityAIClass.new()
	var help_candidate = HelpActionClass.new(actor.id, target.id, 5.0)
	var eval = ai.score_action(actor, help_candidate, runner.get_simulation_context())
	var contributing: Array = eval.get("contributing_event_ids", [])

	if not (parent_evt.id in contributing):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Child decision did not reference the parent event's ID among contributing_event_ids: %s" % str(contributing)}

	help_candidate.parent_event_ids.assign(contributing)
	help_candidate.start(runner.get_simulation_context())
	help_candidate.tick(5.0, runner.get_simulation_context())
	var child_evt = help_candidate._create_completion_event(runner.get_simulation_context())

	if not (parent_evt.id in child_evt.parent_event_ids):
		runner.free()
		return {"name": test_name, "passed": false, "error": "Completed child event does not carry the parent event's ID in parent_event_ids"}
	if child_evt.id == parent_evt.id:
		runner.free()
		return {"name": test_name, "passed": false, "error": "Parent and child events must have distinct IDs"}

	runner.free()
	return {"name": test_name, "passed": true}
