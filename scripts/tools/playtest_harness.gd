extends SceneTree

## PLAYTEST-001: Playtest Analysis Harness.
## Executes the 10+ playtest matrix across groups A, B, C and diverse seeds.
## Extracts rich qualitative and quantitative records for player experience evaluation.

const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const StressTestMetricsClass = preload("res://scripts/tools/stress_test_metrics.gd")
const RunEvaluatorClass = preload("res://scripts/simulation/run_evaluator.gd")

const RUN_MATRIX: Array[Dictionary] = [
	# Group A: Truth of Room 407 + Never Lie + Everyone Hiding Something
	{"group": "A", "seed": 10001, "want": "learn_room_407", "never": "never_lie", "believe": "everyone_hiding_something", "name": "Run 1 (A-10001)"},
	{"group": "A", "seed": 20002, "want": "learn_room_407", "never": "never_lie", "believe": "everyone_hiding_something", "name": "Run 2 (A-20002)"},
	{"group": "A", "seed": 30003, "want": "learn_room_407", "never": "never_lie", "believe": "everyone_hiding_something", "name": "Run 3 (A-30003)"},

	# Group B: Make Friend + Never Hurt Anyone + Most People Trusted
	{"group": "B", "seed": 10001, "want": "make_friend", "never": "never_hurt_anyone", "believe": "most_people_trusted", "name": "Run 4 (B-10001)"},
	{"group": "B", "seed": 40004, "want": "make_friend", "never": "never_hurt_anyone", "believe": "most_people_trusted", "name": "Run 5 (B-40004)"},
	{"group": "B", "seed": 50005, "want": "make_friend", "never": "never_hurt_anyone", "believe": "most_people_trusted", "name": "Run 6 (B-50005)"},

	# Group C: Earn Money + Never Steal + Money Solves Problems
	{"group": "C", "seed": 10001, "want": "earn_money", "never": "never_steal", "believe": "money_solves_problems", "name": "Run 7 (C-10001)"},
	{"group": "C", "seed": 60006, "want": "earn_money", "never": "never_steal", "believe": "money_solves_problems", "name": "Run 8 (C-60006)"},
	{"group": "C", "seed": 70007, "want": "earn_money", "never": "never_steal", "believe": "money_solves_problems", "name": "Run 9 (C-70007)"},

	# Replay Run 1 with exact same seed and directives
	{"group": "A", "seed": 10001, "want": "learn_room_407", "never": "never_lie", "believe": "everyone_hiding_something", "name": "Run 10 (Replay A-10001)"},

	# Exploratory runs
	{"group": "A", "seed": 88888, "want": "learn_room_407", "never": "never_lie", "believe": "everyone_hiding_something", "name": "Run 11 (A-88888)"},
	{"group": "B", "seed": 99999, "want": "make_friend", "never": "never_hurt_anyone", "believe": "most_people_trusted", "name": "Run 12 (B-99999)"}
]

const TICKS_PER_RUN: int = 200
const SIM_DELTA_PER_TICK: float = 4.0

func _init() -> void:
	print("============================================================")
	print(" PLAYTEST-001: EXECUTING %d REAL SIMULATION RUNS" % RUN_MATRIX.size())
	print("============================================================")

	var run_records: Array[Dictionary] = []

	for cfg in RUN_MATRIX:
		var rec = _execute_run(cfg)
		run_records.append(rec)
		_print_run_report(rec)

	print("\n============================================================")
	print(" PLAYTEST-001: CROSS-RUN COMPARISON & REPLAY ANALYSIS")
	print("============================================================")
	_print_comparisons(run_records)

	quit(0)

func _execute_run(cfg: Dictionary) -> Dictionary:
	var runner := SimulationRunnerClass.new()
	runner.initial_seed = int(cfg["seed"])
	runner._init_simulation()
	runner.set_player_directives(cfg["want"], cfg["never"], cfg["believe"])

	var protagonist = runner.get_protagonist()
	var protag_start_loc = protagonist.current_location if protagonist != null else ""
	var protag_start_inv = protagonist.inventory.duplicate() if protagonist != null else []

	var secrets = runner._secrets.duplicate(true)
	var room_407_scen = runner._room_407_scenario.duplicate(true)

	# Execute ticks
	for t in range(TICKS_PER_RUN):
		runner._tick_simulation(SIM_DELTA_PER_TICK)

	# Extract evaluation & metrics
	var eval_result = RunEvaluatorClass.evaluate(runner)
	var metrics = StressTestMetricsClass.collect(runner)
	var events: Array[Dictionary] = runner.get_events()

	# Analyze protagonist behavior
	var protag_actions: Array[Dictionary] = []
	var protag_action_type_counts: Dictionary = {}
	for evt in events:
		if evt.get("actor_id", "") == protagonist.id:
			var etype = evt.get("event_type", "")
			protag_action_type_counts[etype] = int(protag_action_type_counts.get(etype, 0)) + 1
			protag_actions.append({
				"time": evt.get("timestamp", 0.0),
				"type": etype,
				"target": evt.get("target_id", ""),
				"location": evt.get("location_id", ""),
				"desc": evt.get("description", ""),
				"reasons": evt.get("metadata", {}).get("decision_reasons", {}),
				"parents": evt.get("parent_event_ids", [])
			})

	# Action distribution & repetitions across all characters
	var character_action_counts: Dictionary = {}
	var character_move_counts: Dictionary = {}
	var most_repeated_action_per_char: Dictionary = {}

	for evt in events:
		var aid: String = evt.get("actor_id", "")
		var etype: String = evt.get("event_type", "")
		if not aid.is_empty():
			if not character_action_counts.has(aid):
				character_action_counts[aid] = {}
				character_move_counts[aid] = 0
			character_action_counts[aid][etype] = int(character_action_counts[aid].get(etype, 0)) + 1
			if etype == "move_to":
				character_move_counts[aid] = int(character_move_counts[aid]) + 1

	for aid in character_action_counts.keys():
		var counts = character_action_counts[aid]
		var max_act = ""
		var max_c = 0
		var total_c = 0
		for act in counts.keys():
			total_c += counts[act]
			if counts[act] > max_c:
				max_c = counts[act]
				max_act = act
		var frac = float(max_c) / float(maxi(total_c, 1))
		most_repeated_action_per_char[aid] = {"action": max_act, "count": max_c, "fraction": frac}

	# Identify interesting causal chains
	var causal_events: Array[Dictionary] = []
	for evt in events:
		var parents: Array = evt.get("parent_event_ids", [])
		if not parents.is_empty():
			causal_events.append({
				"event_id": evt.get("event_id", ""),
				"type": evt.get("event_type", ""),
				"actor": evt.get("actor_id", ""),
				"target": evt.get("target_id", ""),
				"desc": evt.get("description", ""),
				"parents": parents
			})

	# Pacing & gaps
	var timestamps: Array[float] = []
	for evt in events:
		if evt.get("event_type", "") in ["talk", "help", "confront", "take_item", "give_item", "lie"]:
			timestamps.append(float(evt.get("timestamp", 0.0)))
	var max_gap: float = 0.0
	for i in range(1, timestamps.size()):
		var gap = timestamps[i] - timestamps[i-1]
		if gap > max_gap:
			max_gap = gap

	var result = {
		"config": cfg,
		"seed": cfg["seed"],
		"directives": {"want": cfg["want"], "never": cfg["never"], "believe": cfg["believe"]},
		"total_events": events.size(),
		"metrics": metrics,
		"eval": eval_result,
		"secrets": secrets,
		"room_407_scenario": room_407_scen,
		"protag_start_loc": protag_start_loc,
		"protag_end_loc": protagonist.current_location if protagonist != null else "",
		"protag_actions": protag_actions,
		"protag_action_counts": protag_action_type_counts,
		"protag_end_emotions": protagonist.emotions.duplicate() if protagonist != null else {},
		"protag_end_inv": protagonist.inventory.duplicate() if protagonist != null else [],
		"most_repeated_per_char": most_repeated_action_per_char,
		"character_moves": character_move_counts,
		"causal_event_count": causal_events.size(),
		"causal_samples": causal_events.slice(0, mini(causal_events.size(), 3)),
		"max_gap_between_interactions": max_gap,
		"event_signature": StressTestMetricsClass.signature(metrics)
	}

	runner.free()
	return result

func _print_run_report(rec: Dictionary) -> void:
	var cfg = rec["config"]
	var ev = rec["eval"]
	var m = rec["metrics"]

	print("\n------------------------------------------------------------")
	print("[%s] Seed: %d | Group: %s" % [cfg["name"], rec["seed"], cfg["group"]])
	print("Directives -> WANT: %s | NEVER: %s | BELIEVE: %s" % [cfg["want"], cfg["never"], cfg["believe"]])
	print("Room 407 Scenario: %s" % rec["room_407_scenario"].get("description", "None"))
	print("Secrets Generated (%d):" % rec["secrets"].size())
	for s in rec["secrets"]:
		print("  * [%s] %s" % [s.get("type", ""), s.get("description", "")])

	print("\n[Protagonist Outcomes & Behavior]")
	print("  Ending Location: %s (Started in %s)" % [rec["protag_end_loc"], rec["protag_start_loc"]])
	print("  Ending Inventory: %s" % str(rec["protag_end_inv"]))
	print("  WANT Status: %s (%s)" % [ev.get("want", {}).get("status", "none"), ev.get("want", {}).get("reason", "")])
	print("  NEVER Status: %s (%s)" % [ev.get("never", {}).get("status", "none"), ev.get("never", {}).get("reason", "")])
	print("  BELIEVE Summary: %s" % ev.get("believe", {}).get("summary", ""))
	print("  Protagonist Actions Total: %d | Counts: %s" % [rec["protag_actions"].size(), str(rec["protag_action_counts"])])

	if not rec["protag_actions"].is_empty():
		print("  Sample Protagonist Journey:")
		var sample_count = mini(rec["protag_actions"].size(), 6)
		for i in range(sample_count):
			var a = rec["protag_actions"][i]
			print("    T=%.0fs | %s -> %s (%s)" % [a["time"], a["type"], a["target"], a["location"]])

	print("\n[World Simulation Metrics]")
	print("  Total Events: %d | Interactions: %d | Conversations: %d | Info Transfers: %d" % [
		rec["total_events"], m.get("interactions", 0), m.get("conversations", 0), m.get("information_transfers", 0)
	])
	print("  Lies: %d | Conflicts: %d | Investigations: %d | Room 407 Events: %d" % [
		m.get("lies", 0), m.get("conflicts", 0), m.get("investigations", 0), m.get("room_407_event_count", 0)
	])
	print("  Secrets Discovered: %d / %d" % [m.get("secrets_discovered", 0), m.get("secrets_total", 0)])
	print("  Causal Linked Events: %d" % rec["causal_event_count"])
	if not rec["causal_samples"].is_empty():
		print("  Sample Causal Chains:")
		for cs in rec["causal_samples"]:
			print("    * [%s] %s (Caused by parent events: %s)" % [cs["type"], cs["desc"], str(cs["parents"])])

	print("\n[Repetition & Pacing Diagnostics]")
	print("  Max Silence Between Social Interactions: %.1fs" % rec["max_gap_between_interactions"])
	print("  Most Repeated Action per Character:")
	for cid in rec["most_repeated_per_char"].keys():
		var rep = rec["most_repeated_per_char"][cid]
		var moves = rec["character_moves"].get(cid, 0)
		print("    * %s: Top action '%s' (%d times = %.1f%%) | Moves: %d" % [
			cid, rep["action"], rep["count"], rep["fraction"] * 100.0, moves
		])

func _print_comparisons(records: Array[Dictionary]) -> void:
	# 1. Replay Determinism Check (Run 1 vs Run 10)
	var r1 = records[0]
	var r10 = records[9]
	var match_events: bool = (r1["total_events"] == r10["total_events"])
	var match_want: bool = (r1["eval"]["want"]["status"] == r10["eval"]["want"]["status"])
	var match_sig: bool = (r1["event_signature"] == r10["event_signature"])
	print("Replay Determinism Check (Run 1 vs Run 10 Replay):")
	print("  Event Counts Match: %s (%d vs %d)" % [str(match_events), r1["total_events"], r10["total_events"]])
	print("  WANT Status Match: %s (%s vs %s)" % [str(match_want), r1["eval"]["want"]["status"], r10["eval"]["want"]["status"]])
	print("  Event Signature Match: %s" % str(match_sig))

	# 2. Same Seed Different Directives (Run 1 vs Run 4 vs Run 7 - Seed 10001)
	var r4 = records[3]
	var r7 = records[6]
	print("\nDirective Impact on Same Seed (Seed 10001):")
	print("  Run 1 (Group A - Learn 407): Protag Actions: %s | WANT: %s | Room 407 Evts: %d" % [
		str(r1["protag_action_counts"]), r1["eval"]["want"]["status"], r1["metrics"]["room_407_event_count"]
	])
	print("  Run 4 (Group B - Make Friend): Protag Actions: %s | WANT: %s | Room 407 Evts: %d" % [
		str(r4["protag_action_counts"]), r4["eval"]["want"]["status"], r4["metrics"]["room_407_event_count"]
	])
	print("  Run 7 (Group C - Earn Money): Protag Actions: %s | WANT: %s | Room 407 Evts: %d" % [
		str(r7["protag_action_counts"]), r7["eval"]["want"]["status"], r7["metrics"]["room_407_event_count"]
	])

	# 3. Aggregate Diversity
	var unique_signatures: Dictionary = {}
	for r in records:
		unique_signatures[r["event_signature"]] = true
	print("\nStory Diversity Across %d Runs:" % records.size())
	print("  Unique Narrative Signatures: %d / %d" % [unique_signatures.size(), records.size()])
