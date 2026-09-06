class_name Relationship
extends RefCounted

## Relationship represents a directional social connection from one character to another (A -> B).
## Tracks six distinct dimensions: trust, fear, attraction, respect, debt, suspicion.
## All metrics are normalized between 0.0 and 1.0.

const METRICS: Array[String] = [
	"trust",
	"fear",
	"attraction",
	"respect",
	"debt",
	"suspicion"
]

var target_id: String = ""
var trust: float = 0.5
var fear: float = 0.0
var attraction: float = 0.1
var respect: float = 0.5
var debt: float = 0.0
var suspicion: float = 0.2

func _init(
	p_target_id: String = "",
	p_trust: float = 0.5,
	p_fear: float = 0.0,
	p_attraction: float = 0.1,
	p_respect: float = 0.5,
	p_debt: float = 0.0,
	p_suspicion: float = 0.2
) -> void:
	target_id = p_target_id
	trust = clampf(p_trust, 0.0, 1.0)
	fear = clampf(p_fear, 0.0, 1.0)
	attraction = clampf(p_attraction, 0.0, 1.0)
	respect = clampf(p_respect, 0.0, 1.0)
	debt = clampf(p_debt, 0.0, 1.0)
	suspicion = clampf(p_suspicion, 0.0, 1.0)

func get_value(metric: String) -> float:
	match metric:
		"trust":
			return trust
		"fear":
			return fear
		"attraction":
			return attraction
		"respect":
			return respect
		"debt":
			return debt
		"suspicion":
			return suspicion
	return 0.0

func set_value(metric: String, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	match metric:
		"trust":
			trust = clamped
		"fear":
			fear = clamped
		"attraction":
			attraction = clamped
		"respect":
			respect = clamped
		"debt":
			debt = clamped
		"suspicion":
			suspicion = clamped

func modify(metric: String, delta: float) -> void:
	var current: float = get_value(metric)
	set_value(metric, current + delta)

func to_dict() -> Dictionary:
	return {
		"target_id": target_id,
		"trust": snappedf(trust, 0.01),
		"fear": snappedf(fear, 0.01),
		"attraction": snappedf(attraction, 0.01),
		"respect": snappedf(respect, 0.01),
		"debt": snappedf(debt, 0.01),
		"suspicion": snappedf(suspicion, 0.01)
	}

func from_dict(data: Dictionary) -> void:
	target_id = str(data.get("target_id", target_id))
	trust = clampf(float(data.get("trust", trust)), 0.0, 1.0)
	fear = clampf(float(data.get("fear", fear)), 0.0, 1.0)
	attraction = clampf(float(data.get("attraction", attraction)), 0.0, 1.0)
	respect = clampf(float(data.get("respect", respect)), 0.0, 1.0)
	debt = clampf(float(data.get("debt", debt)), 0.0, 1.0)
	suspicion = clampf(float(data.get("suspicion", suspicion)), 0.0, 1.0)

func get_summary() -> String:
	return "Trust: %.2f | Fear: %.2f | Suspicion: %.2f | Debt: %.2f | Respect: %.2f | Attraction: %.2f" % [
		trust, fear, suspicion, debt, respect, attraction
	]
