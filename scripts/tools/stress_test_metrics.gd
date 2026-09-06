class_name StressTestMetrics
extends RefCounted

## StressTestMetrics extracts per-run statistics from a completed
## SimulationRunner for TASK-018's emergent story stress test: interactions,
## conversations, information transfers, lies, relationship changes,
## investigations, conflicts, secrets discovered, WANT/NEVER outcome, per-
## character action distribution, and an event-type sequence signature used
## to detect how many distinct "shapes" of story occurred across many runs.
## Pure read-only analysis; never mutates the runner.

const RunEvaluatorClass = preload("res://scripts/simulation/run_evaluator.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")

const INTERACTION_TYPES: Array[String] = [
	"talk", "help", "refuse", "confront", "give_item", "take_item",
	"ask_question", "share_information", "lie"
]

const IDLE_LIKE_TYPES: Array[String] = ["idle", "rest"]

## Collect a single run's metrics Dictionary from an already-ticked runner.
static func collect(runner: SimulationRunner) -> Dictionary:
	var events: Array[Dictionary] = runner.get_events()
	var protagonist = runner.get_protagonist()
	var protagonist_id: String = protagonist.id if protagonist != null else ""

	var metrics: Dictionary = {
		"interactions": 0,
		"conversations": 0,
		"information_transfers": 0,
		"lies": 0,
		"relationship_changes": 0,
		"investigations": 0,
		"conflicts": 0,
		"action_counts": {},
		"npc_action_counts": {},
		"event_type_sequence": [] as Array[String],
		"room_407_event_count": 0
	}

	for evt in events:
		var etype: String = evt.get("event_type", "")
		metrics["event_type_sequence"].append(etype)
		metrics["action_counts"][etype] = int(metrics["action_counts"].get(etype, 0)) + 1

		if etype in INTERACTION_TYPES:
			metrics["interactions"] = int(metrics["interactions"]) + 1
		if etype == "talk":
			metrics["conversations"] = int(metrics["conversations"]) + 1
		if etype == "investigate":
			metrics["investigations"] = int(metrics["investigations"]) + 1
		if etype == "confront":
			metrics["conflicts"] = int(metrics["conflicts"]) + 1
		if etype == "lie":
			metrics["lies"] = int(metrics["lies"]) + 1

		var meta: Dictionary = evt.get("metadata", {})
		match etype:
			"talk":
				if meta.get("shared_facts", []).size() > 0:
					metrics["information_transfers"] = int(metrics["information_transfers"]) + 1
			"share_information":
				metrics["information_transfers"] = int(metrics["information_transfers"]) + 1
			"ask_question":
				var outcome: String = str(meta.get("outcome", ""))
				if outcome == "truth":
					metrics["information_transfers"] = int(metrics["information_transfers"]) + 1
				elif outcome == "lie":
					metrics["lies"] = int(metrics["lies"]) + 1

		var state_changes: Dictionary = evt.get("state_changes", {})
		for key in state_changes.keys():
			if "relationship" in str(key):
				metrics["relationship_changes"] = int(metrics["relationship_changes"]) + 1
				break

		if evt.get("location_id", "") == "room_407":
			metrics["room_407_event_count"] = int(metrics["room_407_event_count"]) + 1

		var actor_id: String = evt.get("actor_id", "")
		if not actor_id.is_empty() and actor_id != protagonist_id:
			if not metrics["npc_action_counts"].has(actor_id):
				metrics["npc_action_counts"][actor_id] = {}
			var per_char: Dictionary = metrics["npc_action_counts"][actor_id]
			per_char[etype] = int(per_char.get(etype, 0)) + 1

	metrics["total_events"] = events.size()
	metrics["room_407_event_fraction"] = float(metrics["room_407_event_count"]) / float(maxi(events.size(), 1))

	var eval_result: Dictionary = RunEvaluatorClass.evaluate(runner)
	var discovered_secrets: Array = eval_result.get("discovered_secrets", [])
	var discovered_count: int = 0
	for s in discovered_secrets:
		if s.get("discovered", false):
			discovered_count += 1

	metrics["secrets_total"] = discovered_secrets.size()
	metrics["secrets_discovered"] = discovered_count
	metrics["want_status"] = eval_result.get("want", {}).get("status", "")
	metrics["never_status"] = eval_result.get("never", {}).get("status", "")

	metrics["primary_goal_types"] = _primary_goal_types(runner)

	return metrics

## Each non-protagonist NPC's primary (first) goal type, for detecting
## "everyone chose identical goals" across a run.
static func _primary_goal_types(runner: SimulationRunner) -> Array[String]:
	var types: Array[String] = []
	for c in runner.get_all_characters():
		if c.is_protagonist:
			continue
		if not c.goals.is_empty() and c.goals[0] is Dictionary:
			types.append(str(c.goals[0].get("type", "")))
	return types

## A compact, order-preserving signature of "what happened" this run, used to
## count how many distinct event-sequence shapes occurred across many runs.
static func signature(metrics: Dictionary) -> String:
	var seq: Array = metrics.get("event_type_sequence", [])
	return ",".join(seq)
