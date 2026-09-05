class_name TestWorldGraph
extends RefCounted

## Automated unit tests for Location and WorldGraph.

const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const LocationClass = preload("res://scripts/world/location.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_all_locations_exist())
	results.append(_test_graph_connectivity())
	results.append(_test_bidirectional_symmetry())
	results.append(_test_route_calculation())
	results.append(_test_invalid_destinations_fail_safely())
	results.append(_test_next_step_navigation())
	results.append(_test_pure_simulation_separation())
	return results

static func _test_all_locations_exist() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	var required_ids: Array[String] = [
		"lobby", "hallway_1", "hallway_2", "stairwell", "laundry_room", "rooftop",
		"room_101", "room_102", "room_103",
		"room_201", "room_202", "room_203",
		"room_407"
	]

	if graph.get_all_locations().size() != 13:
		return {"name": "test_all_locations_exist", "passed": false, "error": "Expected 13 locations, got %d" % graph.get_all_locations().size()}

	for loc_id in required_ids:
		if not graph.has_location(loc_id):
			return {"name": "test_all_locations_exist", "passed": false, "error": "Missing required location: %s" % loc_id}

		var loc = graph.get_location(loc_id)
		if loc.display_name.is_empty():
			return {"name": "test_all_locations_exist", "passed": false, "error": "Location %s has empty display_name" % loc_id}

		if loc.tags.is_empty():
			return {"name": "test_all_locations_exist", "passed": false, "error": "Location %s has no tags" % loc_id}

	return {"name": "test_all_locations_exist", "passed": true}

static func _test_graph_connectivity() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	# Every location must be reachable from lobby (single connected component)
	var all_ids = graph.get_all_location_ids()
	for target_id in all_ids:
		var route = graph.find_route("lobby", target_id)
		if route.is_empty():
			return {"name": "test_graph_connectivity", "passed": false, "error": "No route found from lobby to %s" % target_id}

	return {"name": "test_graph_connectivity", "passed": true}

static func _test_bidirectional_symmetry() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	for loc in graph.get_all_locations():
		for neighbor_id in loc.neighbors:
			var neighbor = graph.get_location(neighbor_id)
			if neighbor == null:
				return {"name": "test_bidirectional_symmetry", "passed": false, "error": "Location %s references non-existent neighbor %s" % [loc.id, neighbor_id]}
			if not neighbor.has_neighbor(loc.id):
				return {"name": "test_bidirectional_symmetry", "passed": false, "error": "Asymmetric connection: %s -> %s exists, but %s -> %s does not" % [loc.id, neighbor_id, neighbor_id, loc.id]}

	return {"name": "test_bidirectional_symmetry", "passed": true}

static func _test_route_calculation() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	# Test 1: Room 101 to Room 407
	var route_101_407 = graph.find_route("room_101", "room_407")
	var expected_101_407: Array[String] = ["room_101", "hallway_1", "stairwell", "hallway_2", "room_407"]
	if route_101_407 != expected_101_407:
		return {"name": "test_route_calculation", "passed": false, "error": "Route room_101 -> room_407 expected %s, got %s" % [str(expected_101_407), str(route_101_407)]}

	# Verify every step along the route is actually a neighbor
	for i in range(route_101_407.size() - 1):
		var step_a = graph.get_location(route_101_407[i])
		if not step_a.has_neighbor(route_101_407[i + 1]):
			return {"name": "test_route_calculation", "passed": false, "error": "Route step gap: %s is not connected to %s" % [route_101_407[i], route_101_407[i + 1]]}

	# Test 2: Lobby to Rooftop
	var route_lobby_roof = graph.find_route("lobby", "rooftop")
	var expected_lobby_roof: Array[String] = ["lobby", "stairwell", "rooftop"]
	if route_lobby_roof != expected_lobby_roof:
		return {"name": "test_route_calculation", "passed": false, "error": "Route lobby -> rooftop expected %s, got %s" % [str(expected_lobby_roof), str(route_lobby_roof)]}

	# Test 3: Same origin and destination
	var same_route = graph.find_route("room_202", "room_202")
	if same_route != ["room_202"]:
		return {"name": "test_route_calculation", "passed": false, "error": "Self route expected ['room_202'], got %s" % str(same_route)}

	# Test 4: Distance calculation
	if graph.get_route_distance("room_101", "room_407") != 4:
		return {"name": "test_route_calculation", "passed": false, "error": "Expected distance 4, got %d" % graph.get_route_distance("room_101", "room_407")}
	if graph.get_route_distance("lobby", "lobby") != 0:
		return {"name": "test_route_calculation", "passed": false, "error": "Self distance expected 0, got %d" % graph.get_route_distance("lobby", "lobby")}

	return {"name": "test_route_calculation", "passed": true}

static func _test_invalid_destinations_fail_safely() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	# Non-existent destination
	var r1 = graph.find_route("room_101", "secret_bunker")
	if not r1.is_empty():
		return {"name": "test_invalid_destinations_fail_safely", "passed": false, "error": "Expected empty array for non-existent destination"}

	# Non-existent origin
	var r2 = graph.find_route("secret_bunker", "room_101")
	if not r2.is_empty():
		return {"name": "test_invalid_destinations_fail_safely", "passed": false, "error": "Expected empty array for non-existent origin"}

	# Empty strings
	var r3 = graph.find_route("", "")
	if not r3.is_empty():
		return {"name": "test_invalid_destinations_fail_safely", "passed": false, "error": "Expected empty array for empty inputs"}

	# Safe helpers with invalid destinations
	if graph.get_next_step("room_101", "fake_room") != "":
		return {"name": "test_invalid_destinations_fail_safely", "passed": false, "error": "get_next_step should return empty string for invalid destination"}

	if graph.get_route_distance("room_101", "fake_room") != -1:
		return {"name": "test_invalid_destinations_fail_safely", "passed": false, "error": "get_route_distance should return -1 for invalid destination"}

	return {"name": "test_invalid_destinations_fail_safely", "passed": true}

static func _test_next_step_navigation() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()

	# Navigation step-by-step from Room 101 to Room 407
	var current: String = "room_101"
	var target: String = "room_407"
	var steps_taken: Array[String] = [current]

	var max_iterations: int = 10
	while current != target and max_iterations > 0:
		var next_loc = graph.get_next_step(current, target)
		if next_loc.is_empty():
			return {"name": "test_next_step_navigation", "passed": false, "error": "get_next_step returned empty midway at %s" % current}
		current = next_loc
		steps_taken.append(current)
		max_iterations -= 1

	if current != target:
		return {"name": "test_next_step_navigation", "passed": false, "error": "Failed to reach target via step navigation"}

	var expected_steps: Array[String] = ["room_101", "hallway_1", "stairwell", "hallway_2", "room_407"]
	if steps_taken != expected_steps:
		return {"name": "test_next_step_navigation", "passed": false, "error": "Steps taken %s did not match expected %s" % [str(steps_taken), str(expected_steps)]}

	# get_next_step when already at target
	if graph.get_next_step("room_407", "room_407") != "":
		return {"name": "test_next_step_navigation", "passed": false, "error": "get_next_step at destination should return empty string"}

	return {"name": "test_next_step_navigation", "passed": true}

static func _test_pure_simulation_separation() -> Dictionary:
	var graph = WorldGraphClass.create_default_apartment()
	var loc = graph.get_location("room_407")

	# Verify Location and WorldGraph are pure RefCounted objects (not Nodes)
	if loc is Node:
		return {"name": "test_pure_simulation_separation", "passed": false, "error": "Location must not inherit from Node"}

	if graph is Node:
		return {"name": "test_pure_simulation_separation", "passed": false, "error": "WorldGraph must not inherit from Node"}

	return {"name": "test_pure_simulation_separation", "passed": true}

