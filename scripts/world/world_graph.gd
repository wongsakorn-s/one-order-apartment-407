class_name WorldGraph
extends RefCounted

## Topological World Graph representing the apartment building.
## Manages locations, connections, and graph-based navigation without any 2D/3D Node dependencies.

const LocationClass = preload("res://scripts/world/location.gd")

var _locations: Dictionary = {}

## Add a Location to the graph.
func add_location(loc: Location) -> void:
	if loc != null and not loc.id.is_empty():
		_locations[loc.id] = loc

## Retrieve a Location by ID, or null if it does not exist.
func get_location(location_id: String) -> Location:
	return _locations.get(location_id, null)

## Check whether a location exists in the graph.
func has_location(location_id: String) -> bool:
	return _locations.has(location_id)

## Return an array of all Location instances.
func get_all_locations() -> Array[Location]:
	var result: Array[Location] = []
	for loc in _locations.values():
		result.append(loc as Location)
	return result

## Return an array of all location IDs.
func get_all_location_ids() -> Array[String]:
	var result: Array[String] = []
	for loc_id in _locations.keys():
		result.append(loc_id as String)
	return result

## Add an edge connecting two locations.
func add_edge(from_id: String, to_id: String, bidirectional: bool = true) -> bool:
	var loc_a: Location = get_location(from_id)
	var loc_b: Location = get_location(to_id)
	if loc_a == null or loc_b == null:
		return false

	loc_a.add_neighbor(to_id)
	if bidirectional:
		loc_b.add_neighbor(from_id)
	return true

## Check if two locations are directly connected neighbors.
func are_locations_connected(from_id: String, to_id: String) -> bool:
	var loc = get_location(from_id)
	if loc == null:
		return false
	return loc.has_neighbor(to_id)

## Calculate a valid shortest route between two locations using Breadth-First Search (BFS).
## Returns an ordered array of location IDs from from_id to to_id inclusive (e.g. ["room_101", "hallway_1", ...]).
## If from_id == to_id, returns [from_id].
## If either destination is invalid, or if no route exists, fails safely by returning an empty array [].
func find_route(from_id: String, to_id: String) -> Array[String]:
	if from_id.is_empty() or to_id.is_empty():
		return []

	var start_loc: Location = get_location(from_id)
	var end_loc: Location = get_location(to_id)
	if start_loc == null or end_loc == null:
		return []

	if from_id == to_id:
		return [from_id]

	var queue: Array[String] = [from_id]
	var visited: Dictionary = {from_id: ""}

	var found: bool = false
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		if current_id == to_id:
			found = true
			break

		var current_loc: Location = get_location(current_id)
		if current_loc == null:
			continue

		for neighbor_id in current_loc.neighbors:
			if not visited.has(neighbor_id) and has_location(neighbor_id):
				visited[neighbor_id] = current_id
				queue.push_back(neighbor_id)

	if not found:
		return []

	# Reconstruct path backwards from to_id to from_id
	var path: Array[String] = []
	var step: String = to_id
	while not step.is_empty():
		path.push_front(step)
		step = visited.get(step, "")

	return path

## Returns the immediate next location ID towards to_id, or empty string if already there or unreachable.
func get_next_step(from_id: String, to_id: String) -> String:
	var route: Array[String] = find_route(from_id, to_id)
	if route.size() >= 2:
		return route[1]
	return ""

## Returns the number of edges (hops) along the shortest path, or -1 if unreachable or invalid.
func get_route_distance(from_id: String, to_id: String) -> int:
	var route: Array[String] = find_route(from_id, to_id)
	if route.is_empty():
		return -1
	return route.size() - 1

## Factory to create the standard 13-location Apartment 407 world model.
static func create_default_apartment() -> WorldGraph:
	var graph: WorldGraph = WorldGraph.new()

	# 1. Common / Circulation areas
	graph.add_location(LocationClass.new("lobby", "Lobby", [], 15, ["public", "ground_floor", "entrance"]))
	graph.add_location(LocationClass.new("laundry_room", "Laundry Room", [], 6, ["public", "utility", "ground_floor"]))
	graph.add_location(LocationClass.new("stairwell", "Stairwell", [], 12, ["public", "circulation", "stairs"]))
	graph.add_location(LocationClass.new("hallway_1", "Hallway Floor 1", [], 10, ["public", "floor_1", "hallway"]))
	graph.add_location(LocationClass.new("hallway_2", "Hallway Floor 2", [], 10, ["public", "floor_2", "hallway"]))
	graph.add_location(LocationClass.new("rooftop", "Rooftop", [], 20, ["public", "outdoor", "rooftop"]))

	# 2. Floor 1 residential rooms
	graph.add_location(LocationClass.new("room_101", "Room 101", [], 4, ["private", "residential", "floor_1"]))
	graph.add_location(LocationClass.new("room_102", "Room 102", [], 4, ["private", "residential", "floor_1"]))
	graph.add_location(LocationClass.new("room_103", "Room 103", [], 4, ["private", "residential", "floor_1"]))

	# 3. Floor 2 residential rooms
	graph.add_location(LocationClass.new("room_201", "Room 201", [], 4, ["private", "residential", "floor_2"]))
	graph.add_location(LocationClass.new("room_202", "Room 202", [], 4, ["private", "residential", "floor_2"]))
	graph.add_location(LocationClass.new("room_203", "Room 203", [], 4, ["private", "residential", "floor_2"]))

	# 4. Special Room 407
	graph.add_location(LocationClass.new("room_407", "Room 407", [], 4, ["private", "special", "floor_2", "mystery"]))

	# Connectivity
	# Ground floor connections
	graph.add_edge("lobby", "hallway_1")
	graph.add_edge("lobby", "stairwell")
	graph.add_edge("lobby", "laundry_room")

	# Floor 1 hallway connections
	graph.add_edge("hallway_1", "stairwell")
	graph.add_edge("hallway_1", "room_101")
	graph.add_edge("hallway_1", "room_102")
	graph.add_edge("hallway_1", "room_103")

	# Stairwell connections across all levels
	graph.add_edge("stairwell", "hallway_2")
	graph.add_edge("stairwell", "rooftop")

	# Floor 2 hallway connections
	graph.add_edge("hallway_2", "room_201")
	graph.add_edge("hallway_2", "room_202")
	graph.add_edge("hallway_2", "room_203")
	graph.add_edge("hallway_2", "room_407")

	return graph

