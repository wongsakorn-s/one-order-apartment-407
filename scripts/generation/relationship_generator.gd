class_name RelationshipGenerator
extends RefCounted

## RelationshipGenerator generates initial directional social relationships between all characters
## based on archetypes, backstories, and seeded variation.
## Pure simulation logic; decoupled from scene nodes.

const RelationshipClass = preload("res://scripts/characters/relationship.gd")

const BASELINE_RELATIONSHIP: Dictionary = {
	"trust": 0.45,
	"fear": 0.05,
	"attraction": 0.10,
	"respect": 0.50,
	"debt": 0.00,
	"suspicion": 0.25
}

## Specific narrative baseline overrides for character pairs: (A -> B)
## Keys formatted as "source_id:target_id"
const NARRATIVE_OVERRIDES: Dictionary = {
	# Elena (beloved elder / manager)
	"npc_elena:npc_nina": {"trust": 0.70, "fear": 0.0, "attraction": 0.10, "respect": 0.65, "debt": 0.0, "suspicion": 0.10},
	"npc_nina:npc_elena": {"trust": 0.75, "fear": 0.0, "attraction": 0.10, "respect": 0.80, "debt": 0.0, "suspicion": 0.10},
	"npc_elena:npc_tom": {"trust": 0.60, "fear": 0.0, "attraction": 0.05, "respect": 0.55, "debt": 0.0, "suspicion": 0.20},
	"npc_tom:npc_elena": {"trust": 0.70, "fear": 0.05, "attraction": 0.05, "respect": 0.75, "debt": 0.0, "suspicion": 0.15},
	"npc_elena:npc_bob": {"trust": 0.35, "fear": 0.10, "attraction": 0.0, "respect": 0.40, "debt": 0.0, "suspicion": 0.60},
	"npc_bob:npc_elena": {"trust": 0.40, "fear": 0.05, "attraction": 0.0, "respect": 0.65, "debt": 0.0, "suspicion": 0.35},

	# Bob (shady opportunist / criminal history)
	"npc_bob:npc_nina": {"trust": 0.30, "fear": 0.0, "attraction": 0.25, "respect": 0.40, "debt": 0.0, "suspicion": 0.35},
	"npc_nina:npc_bob": {"trust": 0.20, "fear": 0.30, "attraction": 0.05, "respect": 0.25, "debt": 0.0, "suspicion": 0.65},
	"npc_bob:npc_david": {"trust": 0.35, "fear": 0.0, "attraction": 0.0, "respect": 0.45, "debt": 0.0, "suspicion": 0.40},
	"npc_david:npc_bob": {"trust": 0.25, "fear": 0.25, "attraction": 0.0, "respect": 0.30, "debt": 0.35, "suspicion": 0.60},

	# Nina & Tom (supportive neighbors)
	"npc_nina:npc_tom": {"trust": 0.70, "fear": 0.0, "attraction": 0.20, "respect": 0.65, "debt": 0.0, "suspicion": 0.15},
	"npc_tom:npc_nina": {"trust": 0.65, "fear": 0.05, "attraction": 0.25, "respect": 0.70, "debt": 0.10, "suspicion": 0.15},

	# Sarah (investigative journalist)
	"npc_sarah:npc_bob": {"trust": 0.15, "fear": 0.15, "attraction": 0.05, "respect": 0.25, "debt": 0.0, "suspicion": 0.80},
	"npc_bob:npc_sarah": {"trust": 0.20, "fear": 0.25, "attraction": 0.10, "respect": 0.40, "debt": 0.0, "suspicion": 0.70},
	"npc_sarah:npc_marcus": {"trust": 0.30, "fear": 0.10, "attraction": 0.05, "respect": 0.45, "debt": 0.0, "suspicion": 0.65},
	"npc_marcus:npc_sarah": {"trust": 0.20, "fear": 0.10, "attraction": 0.05, "respect": 0.40, "debt": 0.0, "suspicion": 0.65},

	# Marcus (isolated rooftop recluse)
	"npc_marcus:npc_elena": {"trust": 0.45, "fear": 0.0, "attraction": 0.05, "respect": 0.60, "debt": 0.0, "suspicion": 0.35},
	"npc_marcus:npc_bob": {"trust": 0.15, "fear": 0.15, "attraction": 0.0, "respect": 0.20, "debt": 0.0, "suspicion": 0.75},

	# Mia (popular / friendly socialite)
	"npc_mia:npc_nina": {"trust": 0.75, "fear": 0.0, "attraction": 0.30, "respect": 0.70, "debt": 0.0, "suspicion": 0.10},
	"npc_nina:npc_mia": {"trust": 0.70, "fear": 0.0, "attraction": 0.20, "respect": 0.65, "debt": 0.0, "suspicion": 0.15},
	"npc_mia:npc_elena": {"trust": 0.70, "fear": 0.0, "attraction": 0.10, "respect": 0.75, "debt": 0.0, "suspicion": 0.10},
	"npc_mia:char_protagonist": {"trust": 0.55, "fear": 0.0, "attraction": 0.30, "respect": 0.55, "debt": 0.0, "suspicion": 0.20},
	"char_protagonist:npc_mia": {"trust": 0.55, "fear": 0.0, "attraction": 0.30, "respect": 0.55, "debt": 0.0, "suspicion": 0.20},

	# David & Elena
	"npc_david:npc_elena": {"trust": 0.65, "fear": 0.0, "attraction": 0.05, "respect": 0.75, "debt": 0.0, "suspicion": 0.15}
}

## Populates initial directional relationships for all pairs in characters array.
## Deterministic based on rng seed.
func generate_initial_relationships(rng: RandomService, characters: Array) -> void:
	if characters.is_empty():
		return

	# Sort characters deterministically by ID to ensure repeatable RNG sequence
	var sorted_chars: Array = characters.duplicate()
	sorted_chars.sort_custom(func(a, b): return a.id < b.id)

	for a in sorted_chars:
		for b in sorted_chars:
			if a.id == b.id:
				continue

			var pair_key: String = "%s:%s" % [a.id, b.id]
			var base_values: Dictionary = BASELINE_RELATIONSHIP.duplicate()

			if NARRATIVE_OVERRIDES.has(pair_key):
				var overrides: Dictionary = NARRATIVE_OVERRIDES[pair_key]
				for metric in overrides:
					base_values[metric] = overrides[metric]
			else:
				# Archetype adjustments for default neighbors
				if b.id == "npc_bob":
					base_values["suspicion"] = 0.55
					base_values["trust"] = 0.30
				elif b.id == "npc_elena":
					base_values["trust"] = 0.65
					base_values["respect"] = 0.70
					base_values["suspicion"] = 0.15
				elif b.id == "npc_marcus":
					base_values["fear"] = 0.15
					base_values["suspicion"] = 0.40

				if a.id == "npc_marcus":
					base_values["suspicion"] = clampf(float(base_values["suspicion"]) + 0.15, 0.0, 1.0)
					base_values["trust"] = clampf(float(base_values["trust"]) - 0.15, 0.0, 1.0)

			# Apply controlled seeded noise (+/- 0.05)
			var trust_val: float = clampf(float(base_values["trust"]) + (rng.rand_range_float(-0.05, 0.05) if rng != null else 0.0), 0.0, 1.0)
			var fear_val: float = clampf(float(base_values["fear"]) + (rng.rand_range_float(-0.03, 0.03) if rng != null else 0.0), 0.0, 1.0)
			var attraction_val: float = clampf(float(base_values["attraction"]) + (rng.rand_range_float(-0.04, 0.04) if rng != null else 0.0), 0.0, 1.0)
			var respect_val: float = clampf(float(base_values["respect"]) + (rng.rand_range_float(-0.05, 0.05) if rng != null else 0.0), 0.0, 1.0)
			var debt_val: float = clampf(float(base_values["debt"]), 0.0, 1.0) # Debt is usually exact/intentional
			var suspicion_val: float = clampf(float(base_values["suspicion"]) + (rng.rand_range_float(-0.05, 0.05) if rng != null else 0.0), 0.0, 1.0)

			var rel = RelationshipClass.new(
				b.id,
				trust_val,
				fear_val,
				attraction_val,
				respect_val,
				debt_val,
				suspicion_val
			)
			a.set_relationship(b.id, rel)
