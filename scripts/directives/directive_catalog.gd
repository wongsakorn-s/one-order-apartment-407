class_name DirectiveCatalog
extends RefCounted

## DirectiveCatalog serves as the centralized registry of player directives.
## Provides predefined WANT, NEVER, and BELIEVE directives and factory helpers.

const WantDirectiveClass = preload("res://scripts/directives/want_directive.gd")
const NeverDirectiveClass = preload("res://scripts/directives/never_directive.gd")
const BeliefDirectiveClass = preload("res://scripts/directives/belief_directive.gd")

static func get_available_wants() -> Array[WantDirective]:
	var list: Array[WantDirective] = []
	list.append(WantDirectiveClass.new(
		"learn_room_407",
		"Learn the truth about Room 407",
		"Uncover what is really going on behind the locked door of Apartment 407."
	))
	list.append(WantDirectiveClass.new(
		"earn_money",
		"Earn 5,000 money",
		"Accumulate wealth and valuable possessions before sunrise."
	))
	list.append(WantDirectiveClass.new(
		"make_friend",
		"Make a friend",
		"Form a genuine bond with at least one other resident in the building."
	))
	list.append(WantDirectiveClass.new(
		"survive_night",
		"Survive until morning",
		"Keep yourself safe and alive until 06:00 without taking unnecessary risks."
	))
	list.append(WantDirectiveClass.new(
		"be_trusted",
		"Become trusted by most residents",
		"Earn the respect and confidence of the building's tenants by helping them."
	))
	return list

static func get_available_nevers() -> Array[NeverDirective]:
	var list: Array[NeverDirective] = []
	list.append(NeverDirectiveClass.new(
		"never_steal",
		"Never steal",
		"Do not take items or possessions belonging to other residents."
	))
	list.append(NeverDirectiveClass.new(
		"never_hurt_anyone",
		"Never hurt anyone",
		"Refuse to engage in violence, aggression, or hostile confrontations."
	))
	list.append(NeverDirectiveClass.new(
		"never_enter_room_407",
		"Never enter Room 407",
		"Stay completely away from Room 407 and do not set foot inside."
	))
	list.append(NeverDirectiveClass.new(
		"never_lie",
		"Never lie",
		"Always speak the truth and never deceive fellow residents."
	))
	list.append(NeverDirectiveClass.new(
		"never_trust_police",
		"Never trust police",
		"Do not cooperate with or call external authorities."
	))
	return list

static func get_available_beliefs() -> Array[BeliefDirective]:
	var list: Array[BeliefDirective] = []
	list.append(BeliefDirectiveClass.new(
		"everyone_hiding_something",
		"Everyone is hiding something",
		"Treat statements with healthy skepticism and investigate suspicious clues."
	))
	list.append(BeliefDirectiveClass.new(
		"most_people_trusted",
		"Most people can be trusted",
		"Assume goodwill in others and lean towards cooperation and openness."
	))
	list.append(BeliefDirectiveClass.new(
		"money_solves_problems",
		"Money solves problems",
		"Believe that economic leverage and possessions are the key to security."
	))
	list.append(BeliefDirectiveClass.new(
		"helping_pays_off",
		"Helping people pays off",
		"Believe that altruism and assisting others will eventually bring reward."
	))
	list.append(BeliefDirectiveClass.new(
		"nobody_gives_anything_for_free",
		"Nobody gives anything for free",
		"Believe that every favor comes with hidden strings; maintain independence."
	))
	return list

static func get_want_by_id(p_id: String) -> WantDirective:
	for w in get_available_wants():
		if w.id == p_id:
			return w
	# Default fallback
	return get_available_wants()[0]

static func get_want(p_id: String) -> WantDirective:
	return get_want_by_id(p_id)

static func get_never_by_id(p_id: String) -> NeverDirective:
	for n in get_available_nevers():
		if n.id == p_id:
			return n
	return get_available_nevers()[0]

static func get_never(p_id: String) -> NeverDirective:
	return get_never_by_id(p_id)

static func get_belief_by_id(p_id: String) -> BeliefDirective:
	for b in get_available_beliefs():
		if b.id == p_id:
			return b
	return get_available_beliefs()[0]

static func get_belief(p_id: String) -> BeliefDirective:
	return get_belief_by_id(p_id)

static func get_default_directives() -> Dictionary:
	return {
		"want": get_want_by_id("learn_room_407"),
		"never": get_never_by_id("never_steal"),
		"believe": get_belief_by_id("everyone_hiding_something")
	}
