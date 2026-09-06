class_name Memory
extends RefCounted

## Memory data model representing an experienced or observed event in a character's mind.
## Pure simulation data class decoupled from scene nodes.
## Implements requirements for TASK-009: id, timestamp, event_type, participants,
## location, importance, emotional_impact, related_event_id, and facts.

var id: String = ""
var timestamp: float = 0.0
var event_type: String = ""
var participants: Array[String] = []
var location: String = ""
var importance: float = 0.5
var emotional_impact: float = 0.0
var related_event_id: String = ""
var facts: Dictionary = {}
var description: String = ""

func _init(
	p_id: String = "",
	p_timestamp: float = 0.0,
	p_event_type: String = "",
	p_participants: Array[String] = [],
	p_location: String = "",
	p_importance: float = 0.5,
	p_emotional_impact: float = 0.0,
	p_related_event_id: String = "",
	p_facts: Dictionary = {},
	p_description: String = ""
) -> void:
	id = p_id
	timestamp = p_timestamp
	event_type = p_event_type
	participants = p_participants.duplicate()
	location = p_location
	importance = clampf(p_importance, 0.0, 1.0)
	emotional_impact = clampf(p_emotional_impact, -1.0, 1.0)
	related_event_id = p_related_event_id
	facts = p_facts.duplicate()
	description = p_description

func involves_character(char_id: String) -> bool:
	return char_id in participants

func to_dict() -> Dictionary:
	return {
		"id": id,
		"timestamp": timestamp,
		"event_type": event_type,
		"participants": participants.duplicate(),
		"location": location,
		"importance": snappedf(importance, 0.01),
		"emotional_impact": snappedf(emotional_impact, 0.01),
		"related_event_id": related_event_id,
		"facts": facts.duplicate(),
		"description": description
	}

func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	timestamp = float(data.get("timestamp", timestamp))
	event_type = str(data.get("event_type", event_type))
	participants.clear()
	var raw_parts = data.get("participants", [])
	for p in raw_parts:
		participants.append(str(p))
	location = str(data.get("location", location))
	importance = clampf(float(data.get("importance", importance)), 0.0, 1.0)
	emotional_impact = clampf(float(data.get("emotional_impact", emotional_impact)), -1.0, 1.0)
	related_event_id = str(data.get("related_event_id", related_event_id))
	facts = data.get("facts", {}).duplicate()
	description = str(data.get("description", description))

func get_summary() -> String:
	var total_seconds: int = int(timestamp)
	var hours: int = (total_seconds / 3600) % 24
	var minutes: int = (total_seconds % 3600) / 60
	var time_str: String = "%02d:%02d" % [hours, minutes]
	var impact_sign: String = "+" if emotional_impact >= 0.0 else ""
	var desc_str: String = description if not description.is_empty() else event_type
	return "[%s] %s (Imp: %.2f, Impact: %s%.2f)" % [
		time_str,
		desc_str,
		importance,
		impact_sign,
		emotional_impact
	]
