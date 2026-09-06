class_name CharacterState
extends RefCounted

## CharacterState data model representing an autonomous character (Protagonist or NPC).
## Contains personality traits, basic needs, emotional state, location, goals, and knowledge.
## Pure simulation data object; decoupled from scene nodes.

const PERSONALITY_TRAITS: Array[String] = [
	"empathy",
	"greed",
	"fear",
	"aggression",
	"curiosity",
	"honesty",
	"sociability",
	"impulsiveness"
]

const BASIC_NEEDS: Array[String] = [
	"safety",
	"money",
	"social",
	"information",
	"rest",
	"food"
]

const EMOTIONS: Array[String] = [
	"happiness",
	"fear",
	"anger",
	"stress"
]

var id: String = ""
var name: String = ""
var is_protagonist: bool = false
var current_location: String = ""

const BaseActionClass = preload("res://scripts/actions/base_action.gd")
const RelationshipClass = preload("res://scripts/characters/relationship.gd")
const MemoryClass = preload("res://scripts/characters/memory.gd")
const BeliefClass = preload("res://scripts/characters/belief.gd")

const MAX_MEMORIES: int = 30

var personality: Dictionary = {}
var needs: Dictionary = {}
var emotions: Dictionary = {}
var inventory: Array = []
var goals: Array = []
var memories: Array = []
var beliefs: Dictionary = {}
var relationships: Dictionary = {}
var active_action: BaseAction = null
var current_action: Dictionary = {
	"id": "idle",
	"description": "Idle"
}
var last_decision: Dictionary = {}
var directives: Dictionary = {}

func set_directives(p_want: Variant, p_never: Variant, p_believe: Variant) -> void:
	directives["want"] = p_want
	directives["never"] = p_never
	directives["believe"] = p_believe

func get_directive(type: String) -> Variant:
	return directives.get(type, null)

func has_directives() -> bool:
	return not directives.is_empty() and (directives.get("want") != null or directives.get("never") != null or directives.get("believe") != null)

func _init(
	p_id: String = "",
	p_name: String = "",
	p_location: String = "",
	p_is_protagonist: bool = false
) -> void:
	id = p_id
	name = p_name
	current_location = p_location
	is_protagonist = p_is_protagonist

	_init_default_attributes()

func _init_default_attributes() -> void:
	# Default normalized baseline (0.5 for traits, 0.5 for needs, 0.1-0.2 for initial stress/anger)
	for trait_name in PERSONALITY_TRAITS:
		if not personality.has(trait_name):
			personality[trait_name] = 0.5

	for need_name in BASIC_NEEDS:
		if not needs.has(need_name):
			needs[need_name] = 0.5

	for emotion_name in EMOTIONS:
		if not emotions.has(emotion_name):
			emotions[emotion_name] = 0.2

	emotions["happiness"] = 0.6

func set_personality_trait(trait_name: String, value: float) -> void:
	if trait_name in PERSONALITY_TRAITS:
		personality[trait_name] = clampf(value, 0.0, 1.0)

func get_personality_trait(trait_name: String) -> float:
	return personality.get(trait_name, 0.5)

func set_need(need_name: String, value: float) -> void:
	if need_name in BASIC_NEEDS:
		needs[need_name] = clampf(value, 0.0, 1.0)

func get_need(need_name: String) -> float:
	return needs.get(need_name, 0.5)

func set_emotion(emotion_name: String, value: float) -> void:
	if emotion_name in EMOTIONS:
		emotions[emotion_name] = clampf(value, 0.0, 1.0)

func get_emotion(emotion_name: String) -> float:
	return emotions.get(emotion_name, 0.0)

## Relationship helper methods
func get_relationship(other_id: String) -> Relationship:
	if not relationships.has(other_id):
		relationships[other_id] = RelationshipClass.new(other_id)
	elif relationships[other_id] is Dictionary:
		var rel = RelationshipClass.new(other_id)
		rel.from_dict(relationships[other_id])
		relationships[other_id] = rel
	return relationships[other_id]

func set_relationship(other_id: String, rel: Relationship) -> void:
	relationships[other_id] = rel

func modify_relationship(other_id: String, metric: String, delta: float) -> void:
	var rel: Relationship = get_relationship(other_id)
	rel.modify(metric, delta)

func get_relationship_value(other_id: String, metric: String) -> float:
	var rel: Relationship = get_relationship(other_id)
	return rel.get_value(metric)

## Memory management methods
func add_memory(memory: Memory) -> void:
	if memory == null:
		return

	# If at capacity, evict the lowest-importance memory (oldest if tied)
	if memories.size() >= MAX_MEMORIES:
		var lowest_idx: int = -1
		var lowest_imp: float = 999.0
		var oldest_time: float = 999999999.0

		for i in range(memories.size()):
			var m = memories[i]
			var m_imp: float = m.importance if m is MemoryClass else float(m.get("importance", 0.5))
			var m_time: float = m.timestamp if m is MemoryClass else float(m.get("timestamp", 0.0))

			if m_imp < lowest_imp:
				lowest_imp = m_imp
				oldest_time = m_time
				lowest_idx = i
			elif is_equal_approx(m_imp, lowest_imp) and m_time < oldest_time:
				oldest_time = m_time
				lowest_idx = i

		# If the new memory has lower importance than existing lowest, drop it
		if memory.importance < lowest_imp:
			return

		if lowest_idx >= 0:
			memories.remove_at(lowest_idx)

	memories.append(memory)

func get_memories() -> Array:
	return memories

func get_memory_count() -> int:
	return memories.size()

func get_memories_about(char_id: String) -> Array:
	var result: Array = []
	for m in memories:
		if m is MemoryClass:
			if m.involves_character(char_id):
				result.append(m)
		elif m is Dictionary:
			var parts = m.get("participants", [])
			if char_id in parts:
				result.append(m)
	return result

func has_memory_of_type(type: String) -> bool:
	for m in memories:
		var m_type: String = m.event_type if m is MemoryClass else str(m.get("event_type", ""))
		if m_type == type:
			return true
	return false

func clear_memories() -> void:
	memories.clear()

## Belief and Knowledge management methods
func set_belief(subject: String, predicate: String, value: Variant, confidence: float = 1.0, source: String = "self", timestamp: float = 0.0) -> Belief:
	var key: String = "%s:%s" % [subject, predicate]
	var belief = BeliefClass.new(subject, predicate, value, confidence, source, timestamp)
	beliefs[key] = belief
	return belief

func add_belief(belief: Belief) -> void:
	if belief != null:
		beliefs[belief.get_key()] = belief

func get_belief(subject: String, predicate: String) -> Belief:
	var key: String = "%s:%s" % [subject, predicate]
	if beliefs.has(key):
		var b = beliefs[key]
		if b is BeliefClass:
			return b
		elif b is Dictionary:
			var restored = BeliefClass.new()
			restored.from_dict(b)
			beliefs[key] = restored
			return restored
	return null

func get_belief_value(subject: String, predicate: String, default_val: Variant = null) -> Variant:
	var b: Belief = get_belief(subject, predicate)
	if b != null:
		return b.value
	return default_val

func has_belief(subject: String, predicate: String) -> bool:
	var key: String = "%s:%s" % [subject, predicate]
	return beliefs.has(key)

func get_beliefs() -> Array[Belief]:
	var list: Array[Belief] = []
	for k in beliefs.keys():
		var parts = k.split(":")
		if parts.size() >= 2:
			var b = get_belief(parts[0], parts[1])
			if b != null:
				list.append(b)
	return list

func get_beliefs_about(subject: String) -> Array[Belief]:
	var list: Array[Belief] = []
	for b in get_beliefs():
		if b.subject == subject:
			list.append(b)
	return list

func receive_belief(subject: String, predicate: String, value: Variant, confidence: float, from_char_id: String, timestamp: float) -> void:
	var existing: Belief = get_belief(subject, predicate)
	if existing == null:
		set_belief(subject, predicate, value, confidence, from_char_id, timestamp)
	else:
		# If received info has higher confidence than existing belief, update it
		if confidence > existing.confidence:
			existing.value = value
			existing.confidence = confidence
			existing.source = from_char_id
			existing.timestamp = timestamp
		# If same value, reinforce confidence slightly
		elif str(existing.value) == str(value):
			existing.confidence = minf(1.0, existing.confidence + 0.15)
			existing.timestamp = timestamp
		# If conflicting value from less trusted source, discount confidence slightly
		else:
			existing.confidence = maxf(0.1, existing.confidence - 0.10)

## Assign an active action to the character.
func set_active_action(action: BaseAction) -> void:
	active_action = action
	if action != null:
		current_action = action.to_dict()
	else:
		current_action = {
			"id": "idle",
			"description": "Idle"
		}

## Cancel the currently active action if running or pending.
func cancel_current_action(reason: String = "Cancelled") -> void:
	if active_action != null:
		active_action.cancel(reason)
		current_action = active_action.to_dict()
		active_action = null

## Advance character's active action by delta_sim_seconds.
func tick_action(delta_sim_seconds: float, context: Dictionary) -> Variant:
	if active_action == null:
		return null

	active_action.tick(delta_sim_seconds, context)
	current_action = active_action.to_dict()

	if active_action.status == BaseActionClass.Status.COMPLETED:
		var completed_action = active_action
		active_action = null
		return completed_action
	elif active_action.status == BaseActionClass.Status.FAILED or active_action.status == BaseActionClass.Status.CANCELLED:
		active_action = null
		return null

	return null

## Export full state as a structured dictionary for serialization and debug inspection.
func to_dict() -> Dictionary:
	var serialized_relationships: Dictionary = {}
	for target_id in relationships:
		var rel = relationships[target_id]
		if rel is RelationshipClass or (rel != null and rel.has_method("to_dict")):
			serialized_relationships[target_id] = rel.to_dict()
		elif rel is Dictionary:
			serialized_relationships[target_id] = rel.duplicate()
		else:
			serialized_relationships[target_id] = rel

	var serialized_memories: Array = []
	for m in memories:
		if m is MemoryClass or (m != null and m.has_method("to_dict")):
			serialized_memories.append(m.to_dict())
		elif m is Dictionary:
			serialized_memories.append(m.duplicate())
		else:
			serialized_memories.append(m)

	var serialized_beliefs: Dictionary = {}
	for k in beliefs:
		var b = beliefs[k]
		if b is BeliefClass or (b != null and b.has_method("to_dict")):
			serialized_beliefs[k] = b.to_dict()
		elif b is Dictionary:
			serialized_beliefs[k] = b.duplicate()
		else:
			serialized_beliefs[k] = b

	return {
		"id": id,
		"name": name,
		"is_protagonist": is_protagonist,
		"current_location": current_location,
		"personality": personality.duplicate(),
		"needs": needs.duplicate(),
		"emotions": emotions.duplicate(),
		"inventory": inventory.duplicate(),
		"goals": goals.duplicate(),
		"memories": serialized_memories,
		"beliefs": serialized_beliefs,
		"relationships": serialized_relationships,
		"current_action": current_action.duplicate(),
		"last_decision": last_decision.duplicate(true),
		"directives": {
			"want": directives["want"].to_dict() if directives.get("want") != null else null,
			"never": directives["never"].to_dict() if directives.get("never") != null else null,
			"believe": directives["believe"].to_dict() if directives.get("believe") != null else null
		}
	}

## Return human-readable multiline debug representation of character state.
func get_debug_summary() -> String:
	var lines: Array[String] = []
	lines.append("=== Character [%s: %s] %s ===" % [id, name, "(PROTAGONIST)" if is_protagonist else "(NPC)"])
	lines.append("Location: %s" % current_location)
	lines.append("Action: %s (%s)" % [current_action.get("id", "none"), current_action.get("description", "")])

	if has_directives():
		lines.append("\n[Directives (Player)]")
		if directives.get("want") != null:
			lines.append("  WANT: %s (%s)" % [directives["want"].title, directives["want"].id])
		if directives.get("never") != null:
			lines.append("  NEVER: %s (%s)" % [directives["never"].title, directives["never"].id])
		if directives.get("believe") != null:
			lines.append("  BELIEVE: %s (%s)" % [directives["believe"].title, directives["believe"].id])

	if not last_decision.is_empty():
		lines.append("\n[Utility Decision]")
		lines.append("  Chosen: %s (Score: %.2f)" % [last_decision.get("action_name", last_decision.get("action_id", "")), float(last_decision.get("score", 0.0))])
		lines.append("  Why: %s" % last_decision.get("explanation", ""))
		var candidates_list = last_decision.get("candidates", [])
		if not candidates_list.is_empty():
			lines.append("  Top Candidates:")
			var top_slice = candidates_list.slice(0, mini(candidates_list.size(), 5))
			for c in top_slice:
				var candidate_name: String = c.get("action_name", c.get("action_id", ""))
				var target_str: String = " -> %s" % c.get("target_id", "") if not str(c.get("target_id", "")).is_empty() else ""
				lines.append("    * %s%s: %.2f" % [candidate_name, target_str, float(c.get("score", 0.0))])

	lines.append("\n[Personality]")
	for t in PERSONALITY_TRAITS:
		lines.append("  %s: %.2f" % [t, personality.get(t, 0.0)])

	lines.append("\n[Needs]")
	for n in BASIC_NEEDS:
		lines.append("  %s: %.2f" % [n, needs.get(n, 0.0)])

	lines.append("\n[Emotions]")
	for e in EMOTIONS:
		lines.append("  %s: %.2f" % [e, emotions.get(e, 0.0)])

	if not relationships.is_empty():
		lines.append("\n[Relationships]")
		for target_id in relationships:
			var rel = relationships[target_id]
			if rel is RelationshipClass or (rel != null and rel.has_method("get_summary")):
				lines.append("  -> %s: %s" % [target_id, rel.get_summary()])
			elif rel is Dictionary:
				lines.append("  -> %s: %s" % [target_id, str(rel)])

	lines.append("\n[Memories (%d/%d)]" % [memories.size(), MAX_MEMORIES])
	if memories.is_empty():
		lines.append("  (None)")
	else:
		var recent_count: int = mini(memories.size(), 8)
		var start_idx: int = memories.size() - recent_count
		for i in range(memories.size() - 1, start_idx - 1, -1):
			var m = memories[i]
			if m is MemoryClass or (m != null and m.has_method("get_summary")):
				lines.append("  * %s" % m.get_summary())
			elif m is Dictionary:
				lines.append("  * %s" % str(m))

	var all_beliefs: Array[Belief] = get_beliefs()
	lines.append("\n[Beliefs & Knowledge (%d)]" % all_beliefs.size())
	if all_beliefs.is_empty():
		lines.append("  (None)")
	else:
		var belief_count: int = mini(all_beliefs.size(), 8)
		for i in range(belief_count):
			lines.append("  * %s" % all_beliefs[i].get_summary())

	lines.append("\n[Inventory]: %s" % str(inventory))
	lines.append("[Goals]:")
	if goals.is_empty():
		lines.append("  (None)")
	else:
		for i in range(goals.size()):
			var g = goals[i]
			var prefix = "Primary" if i == 0 else "Secondary"
			if g is Dictionary:
				lines.append("  * [%s] %s (%s)" % [prefix, g.get("description", g.get("id", "Goal")), g.get("id", "")])
			else:
				lines.append("  * [%s] %s" % [prefix, str(g)])
	return "\n".join(lines)

