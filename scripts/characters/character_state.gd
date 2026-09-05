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
		"memories": memories.duplicate(),
		"beliefs": beliefs.duplicate(),
		"relationships": relationships.duplicate(),
		"current_action": current_action.duplicate()
	}

## Return human-readable multiline debug representation of character state.
func get_debug_summary() -> String:
	var lines: Array[String] = []
	lines.append("=== Character [%s: %s] %s ===" % [id, name, "(PROTAGONIST)" if is_protagonist else "(NPC)"])
	lines.append("Location: %s" % current_location)
	lines.append("Action: %s (%s)" % [current_action.get("id", "none"), current_action.get("description", "")])

	lines.append("\n[Personality]")
	for t in PERSONALITY_TRAITS:
		lines.append("  %s: %.2f" % [t, personality.get(t, 0.0)])

	lines.append("\n[Needs]")
	for n in BASIC_NEEDS:
		lines.append("  %s: %.2f" % [n, needs.get(n, 0.0)])

	lines.append("\n[Emotions]")
	for e in EMOTIONS:
		lines.append("  %s: %.2f" % [e, emotions.get(e, 0.0)])

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

