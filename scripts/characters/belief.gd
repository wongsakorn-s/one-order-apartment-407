class_name Belief
extends RefCounted

## Represents a subjective piece of knowledge or belief held by an NPC.
## Used in TASK-010: Knowledge & Belief Propagation.
## Subject: what or who the belief is about (e.g. "room_407", "npc_marcus", "key_item")
## Predicate: the attribute or relation (e.g. "status", "location", "has_item")
## Value: the believed value (e.g. "locked", "room_101", true)
## Confidence: float in [0.0, 1.0] representing how strongly the character believes it
## Source: origin of the information ("self" for direct observation, or character ID e.g. "npc_elena")
## Timestamp: in-game simulation seconds when this belief was formed or updated

var subject: String = ""
var predicate: String = ""
var value: Variant = null
var confidence: float = 1.0
var source: String = "self"
var timestamp: float = 0.0

func _init(
	p_subject: String = "",
	p_predicate: String = "",
	p_value: Variant = null,
	p_confidence: float = 1.0,
	p_source: String = "self",
	p_timestamp: float = 0.0
) -> void:
	subject = p_subject
	predicate = p_predicate
	value = p_value
	confidence = clampf(p_confidence, 0.0, 1.0)
	source = p_source
	timestamp = p_timestamp

func get_key() -> String:
	return "%s:%s" % [subject, predicate]

func to_dict() -> Dictionary:
	return {
		"subject": subject,
		"predicate": predicate,
		"value": value,
		"confidence": confidence,
		"source": source,
		"timestamp": timestamp
	}

func from_dict(d: Dictionary) -> void:
	subject = d.get("subject", "")
	predicate = d.get("predicate", "")
	value = d.get("value", null)
	confidence = float(d.get("confidence", 1.0))
	source = d.get("source", "self")
	timestamp = float(d.get("timestamp", 0.0))

func get_summary() -> String:
	return "%s:%s = %s (Conf: %.2f, Src: %s)" % [
		subject,
		predicate,
		str(value),
		confidence,
		source
	]
