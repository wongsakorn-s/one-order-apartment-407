extends SceneTree

## TASK-018: Emergent Story Stress Test.
## Developer diagnostic mode: runs many full simulations with sequential
## seeds, collects StressTestMetrics for each, prints a readable aggregate
## summary, and flags pathological patterns (repetitive NPC behavior, long
## idle stretches, identical goals across NPCs, Room 407 dominating every
## run, or the protagonist always succeeding/failing). Never forces outcomes
## to balance the numbers -- it only reports what the simulation actually did.
##
## Invoke via:
##   godot --headless -s res://scripts/tools/stress_test_runner.gd
## Optional: pass a run count as the last CLI argument, e.g.
##   godot --headless -s res://scripts/tools/stress_test_runner.gd -- 100

const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")
const StressTestMetricsClass = preload("res://scripts/tools/stress_test_metrics.gd")

const DEFAULT_RUN_COUNT: int = 50
const TICK_COUNT: int = 150
const TICK_SIM_DELTA: float = 4.0
const START_SEED: int = 100000

## Fraction of a character's own actions in one run that must be the same
## type before it's flagged as "repeating the same action".
const REPEAT_ACTION_THRESHOLD: float = 0.7
## Fraction of idle/rest actions before a character is flagged as passive.
const PASSIVE_THRESHOLD: float = 0.7
## Fraction of runs where Room 407 must dominate before we flag it globally.
const ROOM_407_DOMINATION_RUN_FRACTION: float = 0.5
const ROOM_407_DOMINATION_EVENT_FRACTION: float = 0.25

func _init() -> void:
	var run_count: int = DEFAULT_RUN_COUNT
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		run_count = int(args[0])

	print("========================================")
	print(" EMERGENT STORY STRESS TEST (TASK-018)")
	print(" Running %d simulations with sequential seeds starting at %d" % [run_count, START_SEED])
	print("========================================")

	var all_metrics: Array[Dictionary] = []
	var start_ms: int = Time.get_ticks_msec()
	var crashed: bool = false

	for i in range(run_count):
		var seed_val: int = START_SEED + i
		var runner := SimulationRunnerClass.new()
		runner.initial_seed = seed_val
		runner._init_simulation()
		runner.set_player_directives("learn_room_407", "never_steal", "everyone_hiding_something")

		for t in range(TICK_COUNT):
			runner._tick_simulation(TICK_SIM_DELTA)

		var metrics: Dictionary = StressTestMetricsClass.collect(runner)
		metrics["seed"] = seed_val
		all_metrics.append(metrics)
		runner.free()

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	_print_summary(all_metrics, elapsed_ms, run_count)
	quit(0 if not crashed else 1)

func _print_summary(all_metrics: Array[Dictionary], elapsed_ms: int, run_count: int) -> void:
	var totals: Dictionary = {
		"interactions": 0, "conversations": 0, "information_transfers": 0,
		"lies": 0, "relationship_changes": 0, "investigations": 0,
		"conflicts": 0, "secrets_total": 0, "secrets_discovered": 0
	}
	var want_counts: Dictionary = {"success": 0, "partial": 0, "failure": 0}
	var never_counts: Dictionary = {"respected": 0, "violated": 0}
	var signatures: Dictionary = {}
	var global_action_counts: Dictionary = {}
	var room_407_fractions: Array[float] = []
	var identical_goal_runs: int = 0
	var repeat_action_flags: int = 0
	var passive_flags: int = 0

	for metrics in all_metrics:
		for key in totals.keys():
			totals[key] = int(totals[key]) + int(metrics.get(key, 0))

		want_counts[metrics.get("want_status", "")] = int(want_counts.get(metrics.get("want_status", ""), 0)) + 1
		never_counts[metrics.get("never_status", "")] = int(never_counts.get(metrics.get("never_status", ""), 0)) + 1

		signatures[StressTestMetricsClass.signature(metrics)] = true

		room_407_fractions.append(float(metrics.get("room_407_event_fraction", 0.0)))

		var goal_types: Array = metrics.get("primary_goal_types", [])
		if goal_types.size() > 1:
			var all_same: bool = true
			for g in goal_types:
				if g != goal_types[0]:
					all_same = false
					break
			if all_same:
				identical_goal_runs += 1

		var npc_actions: Dictionary = metrics.get("npc_action_counts", {})
		for char_id in npc_actions.keys():
			var per_char: Dictionary = npc_actions[char_id]
			var char_total: int = 0
			var max_count: int = 0
			var idle_count: int = 0
			for action_type in per_char.keys():
				var count: int = int(per_char[action_type])
				char_total += count
				max_count = maxi(max_count, count)
				if action_type in StressTestMetricsClass.IDLE_LIKE_TYPES:
					idle_count += count
				global_action_counts[action_type] = int(global_action_counts.get(action_type, 0)) + count
			if char_total > 0:
				if float(max_count) / float(char_total) >= REPEAT_ACTION_THRESHOLD and char_total >= 5:
					repeat_action_flags += 1
				if float(idle_count) / float(char_total) >= PASSIVE_THRESHOLD and char_total >= 5:
					passive_flags += 1

	print("\n--- EXECUTION ---")
	print("Runs completed: %d / %d" % [all_metrics.size(), run_count])
	print("Total time: %d ms (%.1f ms/run)" % [elapsed_ms, float(elapsed_ms) / float(maxi(run_count, 1))])

	print("\n--- AGGREGATE METRICS (across %d runs) ---" % all_metrics.size())
	for key in ["interactions", "conversations", "information_transfers", "lies", "relationship_changes", "investigations", "conflicts"]:
		print("%s: total=%d, avg/run=%.1f" % [key, totals[key], float(totals[key]) / float(maxi(all_metrics.size(), 1))])
	print("secrets: discovered %d / %d generated (%.0f%%)" % [
		totals["secrets_discovered"], totals["secrets_total"],
		100.0 * float(totals["secrets_discovered"]) / float(maxi(totals["secrets_total"], 1))
	])

	print("\n--- WANT / NEVER ---")
	print("WANT success rate: %.0f%% success, %.0f%% partial, %.0f%% failure" % [
		100.0 * float(want_counts.get("success", 0)) / float(maxi(all_metrics.size(), 1)),
		100.0 * float(want_counts.get("partial", 0)) / float(maxi(all_metrics.size(), 1)),
		100.0 * float(want_counts.get("failure", 0)) / float(maxi(all_metrics.size(), 1))
	])
	print("NEVER violation rate: %.0f%% violated, %.0f%% respected" % [
		100.0 * float(never_counts.get("violated", 0)) / float(maxi(all_metrics.size(), 1)),
		100.0 * float(never_counts.get("respected", 0)) / float(maxi(all_metrics.size(), 1))
	])

	print("\n--- STORY VARIETY ---")
	print("Unique major event sequences: %d / %d runs" % [signatures.size(), all_metrics.size()])

	print("\n--- NPC ACTION DISTRIBUTION (global, all runs) ---")
	var action_keys: Array = global_action_counts.keys()
	action_keys.sort_custom(func(a, b): return int(global_action_counts[a]) > int(global_action_counts[b]))
	var global_total: int = 0
	for k in action_keys:
		global_total += int(global_action_counts[k])
	for k in action_keys:
		var count: int = int(global_action_counts[k])
		print("  %s: %d (%.0f%%)" % [k, count, 100.0 * float(count) / float(maxi(global_total, 1))])

	print("\n--- PATHOLOGY DETECTION ---")
	var avg_room_407_fraction: float = 0.0
	var runs_dominated_by_room_407: int = 0
	for f in room_407_fractions:
		avg_room_407_fraction += f
		if f >= ROOM_407_DOMINATION_EVENT_FRACTION:
			runs_dominated_by_room_407 += 1
	avg_room_407_fraction /= float(maxi(room_407_fractions.size(), 1))

	_report_check(
		"NPC repeatedly performing the same action (>=%.0f%% of one character's actions)" % (REPEAT_ACTION_THRESHOLD * 100.0),
		repeat_action_flags, all_metrics.size(),
		"%d NPC-run instances flagged" % repeat_action_flags
	)
	_report_check(
		"Characters passive/idle for long stretches (>=%.0f%% idle+rest)" % (PASSIVE_THRESHOLD * 100.0),
		passive_flags, all_metrics.size(),
		"%d NPC-run instances flagged" % passive_flags
	)
	_report_check(
		"Every NPC choosing an identical primary goal type",
		identical_goal_runs, all_metrics.size(),
		"%d / %d runs had fully identical NPC goals" % [identical_goal_runs, all_metrics.size()]
	)
	var room_407_dominates_globally: bool = float(runs_dominated_by_room_407) / float(maxi(all_metrics.size(), 1)) >= ROOM_407_DOMINATION_RUN_FRACTION
	print("%s Room 407 dominance: avg %.0f%% of events per run reference it; %d / %d runs exceed %.0f%%%s" % [
		"[WARN]" if room_407_dominates_globally else "[OK]  ",
		avg_room_407_fraction * 100.0, runs_dominated_by_room_407, all_metrics.size(),
		ROOM_407_DOMINATION_EVENT_FRACTION * 100.0,
		" -- Room 407 may be dominating every run" if room_407_dominates_globally else ""
	])

	var success_rate: float = float(want_counts.get("success", 0)) / float(maxi(all_metrics.size(), 1))
	var failure_rate: float = float(want_counts.get("failure", 0)) / float(maxi(all_metrics.size(), 1))
	print("%s Protagonist always succeeding: success rate = %.0f%%%s" % [
		"[WARN]" if is_equal_approx(success_rate, 1.0) else "[OK]  ", success_rate * 100.0,
		" -- WANT never fails or partially fails" if is_equal_approx(success_rate, 1.0) else ""
	])
	print("%s Protagonist always failing: failure rate = %.0f%%%s" % [
		"[WARN]" if is_equal_approx(failure_rate, 1.0) else "[OK]  ", failure_rate * 100.0,
		" -- WANT never succeeds or partially succeeds" if is_equal_approx(failure_rate, 1.0) else ""
	])
	print("%s Unique event sequences: %d / %d%s" % [
		"[WARN]" if signatures.size() <= 1 and all_metrics.size() > 1 else "[OK]  ", signatures.size(), all_metrics.size(),
		" -- every run produced the exact same event sequence" if signatures.size() <= 1 and all_metrics.size() > 1 else ""
	])
	print("%s Secrets never discovered: %d / %d discovered%s" % [
		"[WARN]" if totals["secrets_discovered"] == 0 and totals["secrets_total"] > 0 else "[OK]  ",
		totals["secrets_discovered"], totals["secrets_total"],
		" -- no generated secret was ever discovered across all runs" if totals["secrets_discovered"] == 0 and totals["secrets_total"] > 0 else ""
	])

	print("\n========================================")
	print(" STRESS TEST COMPLETE")
	print("========================================")

func _report_check(label: String, flagged: int, total_runs: int, detail: String) -> void:
	var fraction: float = float(flagged) / float(maxi(total_runs, 1))
	var warn: bool = fraction >= 0.5
	print("%s %s: %s" % ["[WARN]" if warn else "[OK]  ", label, detail])
