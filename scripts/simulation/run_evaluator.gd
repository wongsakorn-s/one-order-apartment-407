class_name RunEvaluator
extends RefCounted

## RunEvaluator produces the end-of-run summary for TASK-016: WANT success/
## partial/failure, NEVER respected/violated, a non-scored BELIEVE narrative
## summary, major relationships/memories, which generated secrets (including
## the Room 407 scenario) actually surfaced during play, and a simple
## chronological causal timeline. Pure simulation logic operating only on
## already-recorded state (events, beliefs, memories, relationships); it
## never mutates the simulation.

const CharacterStateClass = preload("res://scripts/characters/character_state.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")
const SimulationRunnerClass = preload("res://scripts/simulation/simulation_runner.gd")

## Maps a generic secret's type to the belief predicate (keyed on the secret's
## subject_id) that would reveal it to someone else. "owes_money" is
## deliberately absent: both parties already know it from the moment it's
## generated, so there is nothing left to "discover".
const SECRET_TYPE_PREDICATE: Dictionary = {
	"stole_item": "stole_item_from",
	"secretly_likes": "secretly_likes",
	"planning_to_leave": "planning_to_leave_tonight",
	"has_room_407_key": "has_key_to",
	"hiding_item": "hiding_item",
}

const ROOM407_TYPE_SELF_PREDICATE: Dictionary = {
	"hidden_money": "hid_money_in",
	"stolen_goods": "stashed_item_in",
	"secret_meeting": "met_secretly_in",
	"someone_hiding": "hiding_from",
}
const ROOM407_TYPE_STATUS_ONLY: Array[String] = ["missing_tenant", "abandoned_belongings", "innocent_noise"]

const HIGH_IMPORTANCE_EVENT_TYPES: Array[String] = ["confront", "take_item", "help", "give_item", "refuse", "flee"]
const TIMELINE_CAP: int = 20

## Build the full end-of-run summary Dictionary for the given runner.
static func evaluate(runner: SimulationRunner) -> Dictionary:
	var protagonist: CharacterState = runner.get_protagonist()
	if protagonist == null:
		return {}

	var directive_ids: Dictionary = runner.get_player_directive_ids()
	var directives: Dictionary = runner.get_player_directives()
	var want_dir = directives.get("want", null)
	var never_dir = directives.get("never", null)
	var believe_dir = directives.get("believe", null)

	var events: Array[Dictionary] = runner.get_events()

	var want_result: Dictionary = _evaluate_want(protagonist, directive_ids.get("want", ""), events, runner)
	var never_result: Dictionary = _evaluate_never(protagonist, directive_ids.get("never", ""), events)
	var believe_summary: String = _summarize_believe(protagonist, believe_dir, events)

	return {
		"want": {
			"id": directive_ids.get("want", ""),
			"title": want_dir.title if want_dir != null else "",
			"status": want_result.get("status", "failure"),
			"reason": want_result.get("reason", "")
		},
		"never": {
			"id": directive_ids.get("never", ""),
			"title": never_dir.title if never_dir != null else "",
			"status": never_result.get("status", "respected"),
			"violating_event_id": never_result.get("event_id", "")
		},
		"believe": {
			"id": directive_ids.get("believe", ""),
			"title": believe_dir.title if believe_dir != null else "",
			"summary": believe_summary
		},
		"protagonist_final_state": _final_state_summary(protagonist),
		"major_relationships": _major_relationships(protagonist, runner),
		"discovered_secrets": _discovered_secrets(runner),
		"major_memories": _major_memories(protagonist),
		"causal_timeline": _build_causal_timeline(protagonist, want_dir, events)
	}

static func _evaluate_want(protagonist: CharacterState, want_id: String, events: Array[Dictionary], runner: SimulationRunner) -> Dictionary:
	match want_id:
		"learn_room_407":
			var learned: bool = (protagonist.has_belief("room_407", "status") and protagonist.get_belief_value("room_407", "status") != "locked") \
				or protagonist.has_belief("room_407", "key_holder") \
				or protagonist.has_belief("room_407", "contained_item")
			var attempted: bool = learned
			if not attempted:
				for m in protagonist.get_memories():
					var loc: String = m.location if m is MemoryClass else str(m.get("location", ""))
					if loc == "room_407":
						attempted = true
						break
			if learned:
				return {"status": "success", "reason": "%s learned something concrete about Room 407." % protagonist.name}
			elif attempted:
				return {"status": "partial", "reason": "%s looked into Room 407 but never confirmed anything definitive." % protagonist.name}
			return {"status": "failure", "reason": "%s never looked into Room 407 at all." % protagonist.name}

		"earn_money":
			var valuable_items: Array[String] = ["cash", "hidden_cash", "stolen_jewelry"]
			var count: int = 0
			for item in protagonist.inventory:
				if item in valuable_items:
					count += 1
			for item in protagonist.hidden_items:
				if item in valuable_items:
					count += 1
			if count >= 2:
				return {"status": "success", "reason": "%s ended the night holding valuable items." % protagonist.name}
			elif count == 1:
				return {"status": "partial", "reason": "%s picked up a little money, but not much." % protagonist.name}
			return {"status": "failure", "reason": "%s ended the night without any real money." % protagonist.name}

		"make_friend":
			var best_trust: float = 0.0
			for other_id in protagonist.relationships.keys():
				best_trust = maxf(best_trust, protagonist.get_relationship_value(other_id, "trust"))
			if best_trust >= 0.7:
				return {"status": "success", "reason": "%s formed a real bond with someone tonight." % protagonist.name}
			elif best_trust >= 0.5:
				return {"status": "partial", "reason": "%s got along with people, but nothing deep formed." % protagonist.name}
			return {"status": "failure", "reason": "%s didn't connect with anyone tonight." % protagonist.name}

		"survive_night":
			var confront_count: int = 0
			for evt in events:
				if evt.get("event_type", "") == "confront" and evt.get("target_id", "") == protagonist.id:
					confront_count += 1
			if confront_count == 0:
				return {"status": "success", "reason": "%s made it to morning without incident." % protagonist.name}
			elif confront_count == 1:
				return {"status": "partial", "reason": "%s was confronted once, but got through the night." % protagonist.name}
			return {"status": "failure", "reason": "%s was confronted repeatedly tonight." % protagonist.name}

		"be_trusted":
			var total: float = 0.0
			var n: int = 0
			for c in runner.get_all_characters():
				if c.id == protagonist.id:
					continue
				total += c.get_relationship_value(protagonist.id, "trust")
				n += 1
			var avg: float = total / n if n > 0 else 0.0
			if avg >= 0.6:
				return {"status": "success", "reason": "%s earned the building's trust." % protagonist.name}
			elif avg >= 0.45:
				return {"status": "partial", "reason": "%s made a decent impression on some residents." % protagonist.name}
			return {"status": "failure", "reason": "%s remained a stranger to most residents." % protagonist.name}

	return {"status": "failure", "reason": "Unknown WANT directive."}

static func _evaluate_never(protagonist: CharacterState, never_id: String, events: Array[Dictionary]) -> Dictionary:
	for evt in events:
		if evt.get("actor_id", "") != protagonist.id:
			continue
		var etype: String = evt.get("event_type", "")

		match never_id:
			"never_steal":
				var state_changes: Dictionary = evt.get("state_changes", {})
				if etype == "take_item" and state_changes.get("item_transfer", {}).has("from"):
					return {"status": "violated", "event_id": evt.get("id", "")}
			"never_hurt_anyone":
				if etype == "confront":
					return {"status": "violated", "event_id": evt.get("id", "")}
			"never_enter_room_407":
				if (etype == "move_to" or etype == "flee") and evt.get("location_id", "") == "room_407":
					return {"status": "violated", "event_id": evt.get("id", "")}
				if etype == "investigate" and evt.get("target_id", "") == "room_407":
					return {"status": "violated", "event_id": evt.get("id", "")}
			"never_lie":
				if etype == "lie":
					return {"status": "violated", "event_id": evt.get("id", "")}
			"never_trust_police":
				if etype in ["call_police", "report_to_police"]:
					return {"status": "violated", "event_id": evt.get("id", "")}

	return {"status": "respected", "event_id": ""}

## BELIEVE is never scored pass/fail; summarize decisions it visibly swayed,
## reusing the same structured "reasons" breakdown TASK-013 already attaches
## to every causal event.
static func _summarize_believe(protagonist: CharacterState, believe_dir, events: Array[Dictionary]) -> String:
	var believe_title: String = believe_dir.title if believe_dir != null else ""
	var influenced: Array[String] = []
	for evt in events:
		if evt.get("actor_id", "") != protagonist.id:
			continue
		var reasons: Dictionary = evt.get("reasons", {})
		if absf(float(reasons.get("believe", 0.0))) >= 0.5:
			influenced.append(evt.get("description", ""))

	if influenced.is_empty():
		return "%s's belief ('%s') didn't noticeably steer any major decision tonight." % [protagonist.name, believe_title]

	var shown: Array = influenced.slice(0, mini(3, influenced.size()))
	return "%s's belief ('%s') shaped %d decision(s), including: %s" % [protagonist.name, believe_title, influenced.size(), "; ".join(shown)]

static func _final_state_summary(protagonist: CharacterState) -> Dictionary:
	return {
		"name": protagonist.name,
		"location": protagonist.current_location,
		"emotions": protagonist.emotions.duplicate(),
		"needs": protagonist.needs.duplicate(),
		"inventory": protagonist.inventory.duplicate()
	}

static func _major_relationships(protagonist: CharacterState, runner: SimulationRunner) -> Array[String]:
	var scored: Array = []
	for other_id in protagonist.relationships.keys():
		var rel: Relationship = protagonist.get_relationship(other_id)
		var intensity: float = absf(rel.trust - 0.5) + rel.suspicion + rel.fear + rel.attraction + rel.debt + absf(rel.respect - 0.5)
		var other = runner.get_character(other_id)
		var other_name: String = other.name if other != null else other_id
		scored.append({"name": other_name, "intensity": intensity, "summary": rel.get_summary()})

	scored.sort_custom(func(a, b): return a["intensity"] > b["intensity"])

	var lines: Array[String] = []
	for i in range(mini(4, scored.size())):
		lines.append("%s -> %s" % [scored[i]["name"], scored[i]["summary"]])
	return lines

static func _major_memories(protagonist: CharacterState) -> Array[String]:
	var mems: Array = protagonist.get_memories().duplicate()
	mems.sort_custom(func(a, b):
		var ia: float = a.importance if a is MemoryClass else float(a.get("importance", 0.0))
		var ib: float = b.importance if b is MemoryClass else float(b.get("importance", 0.0))
		return ia > ib
	)

	var lines: Array[String] = []
	for i in range(mini(5, mems.size())):
		var m = mems[i]
		lines.append(m.get_summary() if m is MemoryClass else str(m))
	return lines

static func _discovered_secrets(runner: SimulationRunner) -> Array[Dictionary]:
	var characters: Array[CharacterState] = runner.get_all_characters()
	var world_graph: WorldGraph = runner.get_world_graph()
	var result: Array[Dictionary] = []

	for secret in runner.get_secrets():
		result.append({
			"description": secret.get("description", ""),
			"discovered": _is_generic_secret_discovered(secret, characters)
		})

	var scenario: Dictionary = runner.get_room_407_scenario()
	if not scenario.is_empty():
		result.append({
			"description": scenario.get("description", ""),
			"discovered": _is_room_407_discovered(scenario, characters, world_graph)
		})

	return result

static func _is_generic_secret_discovered(secret: Dictionary, characters: Array[CharacterState]) -> bool:
	var subject_id: String = secret.get("subject_id", "")
	if subject_id.is_empty():
		return false
	var s_type: String = secret.get("type", "")

	var belief_subject: String = subject_id
	var predicate: String = str(SECRET_TYPE_PREDICATE.get(s_type, ""))

	if s_type == "saw_something_near_407":
		belief_subject = "room_407"
		predicate = "status"
	elif s_type == "lied_about":
		predicate = str(secret.get("detail", ""))
	elif s_type == "owes_money":
		# Bilateral by design: both parties already know from the start.
		return true

	if predicate.is_empty():
		return false

	for c in characters:
		if c.id == subject_id:
			continue
		if c.get_belief(belief_subject, predicate) != null:
			return true
	return false

static func _is_room_407_discovered(scenario: Dictionary, characters: Array[CharacterState], world_graph: WorldGraph) -> bool:
	var s_type: String = scenario.get("type", "")
	if s_type.is_empty() or s_type == "irrelevant":
		return false

	var detail: String = str(scenario.get("detail", ""))
	if not detail.is_empty() and world_graph != null and world_graph.has_location("room_407"):
		if not world_graph.get_location("room_407").has_item(detail):
			for c in characters:
				if detail in c.inventory or c.has_hidden_item(detail):
					return true

	var subject_id: String = scenario.get("subject_id", "")
	if subject_id.is_empty():
		return false

	if ROOM407_TYPE_SELF_PREDICATE.has(s_type):
		var predicate: String = str(ROOM407_TYPE_SELF_PREDICATE[s_type])
		for c in characters:
			if c.id == subject_id:
				continue
			if c.get_belief(subject_id, predicate) != null:
				return true
	elif s_type in ROOM407_TYPE_STATUS_ONLY:
		for c in characters:
			if c.id == subject_id:
				continue
			if c.get_belief("room_407", "status") != null:
				return true

	return false

## Simple chronological vertical timeline (not a causal graph): the player's
## WANT framed as the starting intention, followed by significant events
## (protagonist-involved, or inherently high-importance action types) in
## time order, capped to a readable length.
static func _build_causal_timeline(protagonist: CharacterState, want_dir, events: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	if want_dir != null:
		lines.append("Player directive: %s" % want_dir.title)

	var significant: Array[Dictionary] = []
	for evt in events:
		var etype: String = evt.get("event_type", "")
		var involves_protagonist: bool = evt.get("actor_id", "") == protagonist.id or evt.get("target_id", "") == protagonist.id
		if involves_protagonist or etype in HIGH_IMPORTANCE_EVENT_TYPES:
			significant.append(evt)

	var start_idx: int = maxi(0, significant.size() - TIMELINE_CAP)
	for i in range(start_idx, significant.size()):
		var evt: Dictionary = significant[i]
		var total_seconds: int = int(float(evt.get("timestamp", 0.0)))
		var hours: int = (total_seconds / 3600) % 24
		var minutes: int = (total_seconds % 3600) / 60
		lines.append("%02d:%02d %s" % [hours, minutes, evt.get("description", "")])

	return lines
