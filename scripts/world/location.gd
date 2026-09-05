class_name Location
extends RefCounted

## Location represents a logical place within Apartment 407.
## Used strictly by the simulation graph; contains no rendering or node dependencies.

var id: String = ""
var display_name: String = ""
var neighbors: Array[String] = []
var capacity: int = 10
var tags: Array[String] = []

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_neighbors: Array[String] = [],
	p_capacity: int = 10,
	p_tags: Array[String] = []
) -> void:
	id = p_id
	display_name = p_display_name
	neighbors = p_neighbors.duplicate()
	capacity = p_capacity
	tags = p_tags.duplicate()

## Add an adjacent location ID if not already present.
func add_neighbor(neighbor_id: String) -> void:
	if not neighbor_id.is_empty() and neighbor_id != id and not neighbor_id in neighbors:
		neighbors.append(neighbor_id)

## Remove an adjacent location ID.
func remove_neighbor(neighbor_id: String) -> void:
	var idx: int = neighbors.find(neighbor_id)
	if idx >= 0:
		neighbors.remove_at(idx)

## Check whether a given location ID is directly adjacent.
func has_neighbor(neighbor_id: String) -> bool:
	return neighbor_id in neighbors

## Check if this location has a specific tag.
func has_tag(tag: String) -> bool:
	return tag in tags

## Add a classification tag.
func add_tag(tag: String) -> void:
	if not tag.is_empty() and not tag in tags:
		tags.append(tag)

